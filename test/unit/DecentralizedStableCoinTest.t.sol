// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract DecentralizedStableCoinTest is Test, CodeConstants {
    DecentralizedStableCoin dsc;

    function setUp() public {
        dsc = new DecentralizedStableCoin(COIN_NAME, COIN_SYMBOL);
    }

    function testNameSymbolAndOwnerOfDscIsValid() public view {
        string memory actualCoinName = dsc.name();
        string memory actualCoinSymbol = dsc.symbol();
        assert(keccak256(bytes(actualCoinName)) == keccak256(bytes(COIN_NAME)));
        assert(keccak256(bytes(actualCoinSymbol)) == keccak256(bytes(COIN_SYMBOL)));
    }

    function testMustMintMoreThanZero() public {
        vm.prank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(this), 0);
    }

    function testMustBurnMoreThanZero() public {
        vm.startPrank(dsc.owner());
        dsc.mint(address(this), 100);
        vm.expectRevert();
        dsc.burn(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanYouHave() public {
        vm.startPrank(dsc.owner());
        dsc.mint(address(this), 100);
        vm.expectRevert();
        dsc.burn(101);
        vm.stopPrank();
    }

    function testCantMintToZeroAddress() public {
        vm.startPrank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(0), 100);
        vm.stopPrank();
    }
}
