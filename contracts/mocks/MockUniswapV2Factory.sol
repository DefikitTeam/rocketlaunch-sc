// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV2Factory {
    address public router;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function setRouter(address _router) external {
        router = _router;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        pair = address(uint160(uint256(keccak256(abi.encodePacked(tokenA, tokenB, block.timestamp)))));
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
        allPairs.push(pair);
        return pair;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }
} 