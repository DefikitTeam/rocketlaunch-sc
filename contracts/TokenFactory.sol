// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./RocketTokenNew.sol";
contract TokenFactory {
    constructor() {
    }

    function createNewToken(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_
    ) public returns (address) {
        RocketTokenNew newToken = new RocketTokenNew(name_, symbol_, decimals_, totalSupply_, msg.sender);
        return address(newToken);
    }
}
