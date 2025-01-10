// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Multisend {
    address owner;

    constructor() {
        owner = msg.sender;
    }

    function sendToken(
        address tokenAddress,
        address[] calldata users,
        uint256[] calldata amounts
    ) external {
        require(users.length == amounts.length, "Length not match");
        for (uint256 i = 0; i < users.length; i++) {
            IERC20(tokenAddress).transferFrom(msg.sender, users[i], amounts[i]);
        }
    }

    function sendNative(
        address[] calldata users,
        uint256[] calldata amounts
    ) external payable {
        require(users.length == amounts.length, "Length not match");
        for (uint256 i = 0; i < users.length; i++) {
            require(msg.value >= amounts[i], "Insufficient value sent");
            (bool success, ) = payable(users[i]).call{value: amounts[i]}("");
            require(success, "Transfer failed");
        }
    }

    function emergency(address tokenAddress) external {
        require(owner == msg.sender);
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(owner, balance);
    }
}
