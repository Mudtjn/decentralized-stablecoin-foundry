// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__AddressMustBeValid();
    error DecentralizedStableCoin__BurntAmountMustBeMoreThanAvailable();

    string private s_coinName;
    string private s_coinSymbol;

    constructor(string memory coinName, string memory coinSymbol) ERC20(coinName, coinSymbol) Ownable(msg.sender) {
        s_coinName = coinName;
        s_coinSymbol = coinSymbol;
    }

    modifier amountMustBeMoreThanZero(uint256 _amount) {
        if (_amount <= 0) revert DecentralizedStableCoin__MustBeMoreThanZero();
        _;
    }

    function burn(uint256 _amount) public override amountMustBeMoreThanZero(_amount) onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurntAmountMustBeMoreThanAvailable();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external amountMustBeMoreThanZero(_amount) onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__AddressMustBeValid();
        }
        super._mint(_to, _amount);
        return true;
    }
}
