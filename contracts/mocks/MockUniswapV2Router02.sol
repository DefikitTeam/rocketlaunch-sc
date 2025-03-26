// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV2Router02 {
    address public factory;
    address public WETH;
    mapping(address => uint256) public rates;

    constructor(address _weth) {
        WETH = _weth;
    }

    function setFactory(address _factory) external {
        factory = _factory;
    }

    function setRate(address token, uint256 rate) external {
        rates[token] = rate;
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        require(path[0] == WETH, "Invalid path");
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = msg.value * rates[path[1]];
        return amounts;
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        require(path[1] == WETH, "Invalid path");
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn / rates[path[0]];
        return amounts;
    }

    receive() external payable {}
} 