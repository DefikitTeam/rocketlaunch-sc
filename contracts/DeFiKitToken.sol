// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC20/ERC20.sol";
import "./ERC20/access/Ownable.sol";

contract DeFiKitToken is ERC20, Ownable {
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address creatorUser_,
        uint256 amountForUser_,
        address systemDefikit_,
        uint256 amountForAddLP_,
        address defikit_,
        uint256 totalSupply_,
        uint256 startTrading_
    ) ERC20(name_, symbol_, startTrading_, systemDefikit_) {
        _mint(creatorUser_, amountForUser_);
        _mint(systemDefikit_, amountForAddLP_);
        _mint(defikit_, totalSupply_ - amountForAddLP_ - amountForUser_);
        _decimals = decimals_;
        renounceOwnership();
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
