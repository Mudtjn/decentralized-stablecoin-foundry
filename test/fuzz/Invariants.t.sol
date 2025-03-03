// SPDX-License-Identifier: MIT

// Invariants
// 1. total supply of dsc should be less than total value of collateral
// 2. getter view functions should never revert
pragma solidity ^0.8.19; 

import {console} from "forge-std/console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol"; 
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {Handler} from "./Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvariantsTest is StdInvariant {

    DSCEngine dscEngine; 
    DecentralizedStableCoin dsc; 
    HelperConfig helperConfig; 
    Handler handler; 
    address weth; 
    address wbtc; 

    function setUp() public {
        DeployDsc deployer = new DeployDsc(); 
        (dsc, dscEngine, helperConfig) = deployer.run(); 
        (,,weth,wbtc,) = helperConfig.activeNetworkConfig(); 
        handler = new Handler(dscEngine, dsc, helperConfig); 
        targetContract(address(handler)); 
    }

    function invariant_protocolMustHaveTotalCollateralAlwaysGreaterThanTotalValueMinted() public view {
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(dscEngine)); 
        uint256 wbtcValue = dscEngine.getUsdValue(wbtc, wbtcBalance);
        
        uint256 wethBalance = IERC20(weth).balanceOf(address(dscEngine)); 
        uint256 wethValue = dscEngine.getUsdValue(weth, wethBalance);

        uint256 totalSupply = dsc.totalSupply(); 
        console.log("times mint called: ", handler.timesMintCalled()); 
        console.log("times deposit called: ", handler.timesDepositCalled()); 
        console.log("times redeem called: ", handler.timesRedeemCalled()); 
        assert(wethValue + wbtcValue >= totalSupply); 
    }

}