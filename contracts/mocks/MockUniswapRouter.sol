// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../uniswapv2/interfaces/IUniswapV2Router02.sol";

contract MockUniswapRouter {
    address public immutable WETH;
    IERC20 public immutable gameToken;

    constructor(address _gameToken) {
        WETH = address(this);
        gameToken = IERC20(_gameToken);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = msg.value; // 1:1 swap ratio for testing

        require(gameToken.transfer(to, amounts[1]), "Transfer failed");
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn; // 1:1 swap ratio for testing

        require(gameToken.transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        payable(to).transfer(amounts[1]);
    }

    receive() external payable {}
} 