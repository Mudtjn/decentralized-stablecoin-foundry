// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Events} from "../Events.t.sol";

contract DscEngineTest is Test, CodeConstants, Events {
    HelperConfig public helperConfig;
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    address wethUsdPriceFeed;
    address weth;
    address wbtcUsdPriceFeed;
    address wbtc;
    address user = makeAddr("user");

    uint256 public constant WETH_BALANCE = 10e18;
    uint256 public constant WBTC_BALANCE = 10e18;

    function setUp() public {
        DeployDsc deployer = new DeployDsc();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
    }

    address[] public tokenAddresses;
    address[] public feedAddresses;

    // constructor tests

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(wethUsdPriceFeed);
        feedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAndPriceFeedAddressesMustBeEqualInLength.selector);
        new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
    }

    modifier depositWethAndWbtcForUser(uint256 amount) {
        ERC20Mock(weth).mint(user, amount);
        ERC20Mock(wbtc).mint(user, amount);
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), amount);
        ERC20Mock(wbtc).approve(address(dscEngine), amount);
        vm.stopPrank();
        _;
    }

    // getUsdValue tests
    function testGetUsdValue() public view {
        uint256 ethAmount = 15 ether;
        (, int256 expectedUsdValue,,,) = AggregatorV3Interface(wethUsdPriceFeed).latestRoundData();
        uint256 feedPrecision = 10 ** DECIMALS;
        uint256 totalExpectedUsdValue = (uint256(expectedUsdValue) * ethAmount) / feedPrecision;
        uint256 actualUsdValue = dscEngine.getUsdValue(weth, ethAmount);
        assertEq(totalExpectedUsdValue, actualUsdValue);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether; 
        (, int256 expectedUsdValue,,,) = AggregatorV3Interface(wethUsdPriceFeed).latestRoundData(); 
        uint256 feedPrecision = 1e10; 
        uint256 expectedTokenFromUsdAmount = (usdAmount * PRECISION) / (uint256(expectedUsdValue) * feedPrecision); 
        uint256 actualTokenFromUsdAmount = dscEngine.getTokenAmountFromUsd(weth, usdAmount); 
        assertEq(expectedTokenFromUsdAmount, actualTokenFromUsdAmount); 
    }

    // depositCollateral tests

    function testRevertsIfDepositCollateralIsZero() public depositWethAndWbtcForUser(WETH_BALANCE) {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfDepositCollateralReceivesInvalidToken() public {
        vm.startPrank(user);
        ERC20Mock newToken = new ERC20Mock("TestToken", "TT", user, 1000e18);
        newToken.approve(address(dscEngine), 1000e18);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotValid.selector);
        dscEngine.depositCollateral(address(newToken), 100e18);
        vm.stopPrank();
    }

    function testDepositCollateralRevertsOnFailedTransfer() public {
        // setup
        uint256 amountCollateral = 10 ether;
        address owner = msg.sender;
        vm.startPrank(owner);
        MockFailedTransfer mockToken = new MockFailedTransfer("MockToken", "MCK");
        ERC20Mock mockDsc = new ERC20Mock(COIN_NAME, COIN_SYMBOL, msg.sender, 1000e8);
        tokenAddresses = [address(mockToken)];
        feedAddresses = [wethUsdPriceFeed];
        DSCEngine mockDscEngine = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
        mockToken.mint(owner, amountCollateral);
        mockToken.approve(address(mockDscEngine), amountCollateral);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenTransferFailed.selector, address(mockToken)));
        mockDscEngine.depositCollateral(address(mockToken), amountCollateral);
    }

    function testDepositCollateralUpdatesDataStructures() public depositWethAndWbtcForUser(WETH_BALANCE) {
        uint256 expectedDepositedAmount = 1e18;
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, expectedDepositedAmount);
        uint256 actualDepositedAmount = dscEngine.getCollateralDeposited(user, weth);
        vm.stopPrank();
        assertEq(expectedDepositedAmount, actualDepositedAmount);
    }

    // getHealthFactor
    function testGetHealthFactor() public depositWethAndWbtcForUser(WETH_BALANCE) {
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, WETH_BALANCE / 10);
        vm.stopPrank();
        uint256 healthFactor = dscEngine.getHealthFactor();
        assertEq(healthFactor, dscEngine.HEALTH_FACTOR_IN_CASE_NO_DSC_MINTED());
    }

    // mintDsc tests
    function testMintDscRevertsOnZeroMintAmount() public depositWethAndWbtcForUser(WETH_BALANCE) {
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, WETH_BALANCE / 10);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function testMintRevertsWhenHealthFactorBreaks() public depositWethAndWbtcForUser(WETH_BALANCE) {
        uint256 depositAmount = WETH_BALANCE;
        uint256 totalCollateralValue = dscEngine.getUsdValue(weth, depositAmount);
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, depositAmount);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector));
        dscEngine.mintDsc(totalCollateralValue);
        vm.stopPrank();
    }

    function testmintDscUpdatesDataStructures() public depositWethAndWbtcForUser(WETH_BALANCE) {
        uint256 depositAmount = WETH_BALANCE;
        uint256 totalCollateralValue = dscEngine.getUsdValue(weth, depositAmount);
        uint256 expectedDscMinted = totalCollateralValue / 2; 
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, depositAmount);
        dscEngine.mintDsc(expectedDscMinted);
        uint256 actualDscMinted = dscEngine.getDscMinted(user);        
        vm.stopPrank();
        uint256 userDscBalance = dsc.balanceOf(user); 
        assertEq(expectedDscMinted, actualDscMinted); 
        assertEq(actualDscMinted, userDscBalance); 
    }

    //redeemCollateral tests
    function testRedeemCollateralRevertsWhenRequestedCollateralMoreThanDepositedCollateral() public depositWethAndWbtcForUser(WETH_BALANCE) {
        uint256 depositAmount = WETH_BALANCE; 
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, depositAmount); 
        vm.expectRevert(); 
        dscEngine.redeemCollateral(weth, depositAmount + 1);  
        vm.stopPrank();     
    }


    function testRedeemCollateralEmitsCollateralRedeemed() public depositWethAndWbtcForUser(WETH_BALANCE) {
        uint256 depositAmount = WETH_BALANCE; 
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, depositAmount);
        vm.expectEmit(address(dscEngine));  
        emit CollateralRedeemed(user, user, weth, depositAmount); 
        dscEngine.redeemCollateral(weth, depositAmount);  
        vm.stopPrank();
    }

    function testRedeemCollateralRevertsWhenHealthFactorIsBroken() public depositWethAndWbtcForUser(WETH_BALANCE) {
        uint256 depositAmount = WETH_BALANCE; 
        uint256 totalCollateralValue = dscEngine.getUsdValue(weth, depositAmount);
        uint256 expectedDscMinted = totalCollateralValue / 2;
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, depositAmount);
        dscEngine.mintDsc(expectedDscMinted); 
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        dscEngine.redeemCollateral(weth, depositAmount/2);  
        vm.stopPrank();
    }

    //burn dsc tests
    function testBurnDscRevertsForZeroAmountBurn() public {
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector); 
        dscEngine.burnDsc(0); 
    }

    function testBurnDscRevertsWhenBurnAmountMoreThanMinted() public depositWethAndWbtcForUser(WETH_BALANCE) {
        uint256 depositAmount = WETH_BALANCE; 
        uint256 totalCollateralValue = dscEngine.getUsdValue(weth, depositAmount);
        uint256 expectedDscMinted = totalCollateralValue / 2;
        vm.startPrank(user);
        dscEngine.depositCollateral(weth, depositAmount);
        dscEngine.mintDsc(expectedDscMinted); 
        vm.expectRevert(); 
        dscEngine.burnDsc(expectedDscMinted + 1);
        vm.stopPrank();
    }

}
