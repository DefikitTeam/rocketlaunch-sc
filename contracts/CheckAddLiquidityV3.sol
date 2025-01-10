// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./libraries/TokenLibrary.sol";

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);
}

interface INonfungiblePositionManager {
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external returns (address pool);

    function mint(
        TokenLibrary.MintParams memory params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

contract CheckAddLiquidityV3 is Initializable {
    using SafeMathUpgradeable for uint256;

    address public WETH;

    uint256 internal constant X96 = 79228162514264337593543950336;
    address public router;
    address public DEAD_ADDR;

    function initialize(address _router, address _WETH) public initializer {
        router = _router;
        WETH = _WETH;
        DEAD_ADDR = 0x000000000000000000000000000000000000dEaD;
    }

    // Receive native token function
    receive() external payable {}

    fallback() external payable {}

    function addLiquidityV3(
        uint256 amountETH,
        uint256 amountToken,
        address token
    ) external {
        IERC20Upgradeable(token).approve(router, amountToken);
        uint256 sqrtPrice = Math.sqrt(amountETH.mul(1e18).div(amountToken));
        IWETH(WETH).deposit{value: amountETH}();
        IWETH(WETH).approve(router, amountETH);
        uint256 sqrtPriceX96 = X96.mul(sqrtPrice).div(1e9); // The initial square root price of the pool as a Q64.96 value
        bool isToken0 = token < WETH;
        (address token0, address token1) = isToken0
            ? (token, WETH)
            : (WETH, token);
        INonfungiblePositionManager(router).createAndInitializePoolIfNecessary(
            token0,
            token1,
            3000,
            uint160(sqrtPriceX96)
        );
        INonfungiblePositionManager(router).mint(
            TokenLibrary.MintParams({
                token0: isToken0 ? token : WETH,
                token1: isToken0 ? WETH : token,
                fee: 3000,
                tickLower: -887220, // ?
                tickUpper: 887220, // ?
                amount0Desired: isToken0 ? amountToken : amountETH,
                amount1Desired: isToken0 ? amountETH : amountToken,
                amount0Min: 0,
                amount1Min: 0,
                recipient: tx.origin,
                deadline: block.timestamp
            })
        );
    }
}
