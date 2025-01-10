// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

library TokenLibrary {
    // mint params for Uniswap V3
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
}
