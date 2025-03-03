// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract Events {
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed tokenCollateralAddress, uint256 amount
    );
}
