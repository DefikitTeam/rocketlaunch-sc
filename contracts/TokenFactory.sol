// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Token.sol";
contract TokenFactory {
    constructor() {
    }

    function createNewToken(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_
    ) public returns (address) {
        Token newToken = new Token(name_, symbol_, decimals_, totalSupply_, msg.sender);
        return address(newToken);
    }
}
