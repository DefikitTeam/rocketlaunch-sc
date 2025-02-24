// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV2Router02 {
    address public factory;
    address public WETH;

    constructor() {
        WETH = address(this);
    }

    function setFactory(address _factory) external {
        factory = _factory;
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        return (amountTokenDesired, msg.value, amountTokenDesired);
    }
} 