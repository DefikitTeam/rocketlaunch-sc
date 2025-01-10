// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RocketTokenNew is ERC20, Ownable {
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address creator_
    ) ERC20(name_, symbol_) {
        _mint(creator_, totalSupply_);
        _decimals = decimals_;
        renounceOwnership();
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
