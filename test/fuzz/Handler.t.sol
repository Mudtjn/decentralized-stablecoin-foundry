// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol"; 
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol"; 

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc; 
    HelperConfig helperConfig; 
    address weth; 
    address wbtc; 
    address ethUsdPriceFeed; 

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; 
    uint256 public timesMintCalled = 0; 
    uint256 public timesDepositCalled = 0; 
    uint256 public timesRedeemCalled = 0; 

    address[] public usersWithCollateralDeposited; 

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc, HelperConfig _helperConfig) {
        dscEngine = _dscEngine; 
        dsc = _dsc; 
        helperConfig = _helperConfig; 
        (ethUsdPriceFeed,,weth,wbtc,) = helperConfig.activeNetworkConfig(); 
    } 

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        address tokenAddress = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);  
        ERC20Mock(tokenAddress).mint(msg.sender, amountCollateral); 
        ERC20Mock(tokenAddress).approve(address(dscEngine), amountCollateral); 
        dscEngine.depositCollateral(tokenAddress, amountCollateral);
        vm.stopPrank();  
        usersWithCollateralDeposited.push(msg.sender);
        timesDepositCalled++;  
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral, uint256 addressSeed) public {
        vm.assume(usersWithCollateralDeposited.length > 0);
        address user = _getUserFromSeed(addressSeed); 
        ERC20Mock collateral = ERC20Mock(_getCollateralFromSeed(collateralSeed)); 
        vm.prank(user); 
        uint256 maxCollateralToRedeem = dscEngine.getCollateralDeposited(user, address(collateral)); 
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        vm.assume(amountCollateral != 0);  
        vm.prank(user); 
        dscEngine.redeemCollateral(address(collateral), amountCollateral); 
        timesRedeemCalled++; 
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        timesMintCalled++;
        vm.assume(usersWithCollateralDeposited.length > 0);
        address user = _getUserFromSeed(addressSeed); 
        vm.startPrank(user); 
        (uint256 totalDscMinted, uint256 totalCollateralValue) = dscEngine.getAccountInformation(user);
        int256 maxDscToMint = int256(totalCollateralValue/2) - int256(totalDscMinted); 
        vm.assume(maxDscToMint >= 1); 
        amount = bound(amount, 0, uint256(maxDscToMint));
        vm.assume(amount > 0); 
        dscEngine.mintDsc(amount);
        vm.stopPrank();
    }

    // function updateCollateralPrices(uint96 amount) public {
    //     int256 newAmount = int256(uint(amount)); 
    //     MockV3Aggregator(ethUsdPriceFeed).updateAnswer(newAmount); 
    // }

    function _getCollateralFromSeed(uint256 collateralFromSeed) private view returns (address) {
        if(collateralFromSeed % 2 == 0){
            return weth; 
        } else {
            return wbtc; 
        }
    }

    function _getUserFromSeed(uint256 addressSeed) private view returns (address) {
        uint256 arrayLength = usersWithCollateralDeposited.length; 
        return usersWithCollateralDeposited[addressSeed % arrayLength]; 
    }

}