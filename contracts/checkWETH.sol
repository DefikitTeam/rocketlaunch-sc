// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
interface WBERA {
    function deposit() external payable;
}

contract CheckWBERA {

    address public wbera = 0x7507c1dc16935B82698e4C63f2746A2fCf994dF8;
    constructor() {}

    function deposit() public payable {
        WBERA(wbera).deposit{value: msg.value}();
        IERC20(wbera).transfer(msg.sender, msg.value);
    }
}