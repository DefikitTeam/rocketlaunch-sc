// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

interface Dex {
    function userCmd(uint16 command, bytes memory data) external;
}

interface WBERA {
    function deposit() external payable;
}

contract BexOperation is Initializable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    // NOTE: for bartio only
    address public dex;
    address public wBera;

    uint256 public poolIdx;

    // Constants (moved outside of storage)
    uint256 private constant PRECISION = 100000000;
    uint256 private constant Q_64 = 2 ** 64;
    uint256 private constant Q_48 = 2 ** 48;
    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    address public constant deadAddress =
        0x000000000000000000000000000000000000dEaD;

    uint256 private constant INIT_AMOUNT_ADD_LP = 13187;

    address private owner;

    address public rocketLaunch;

    function initialize(
        address _dex,
        address _wBera,
        uint256 _poolIdx,
        address _rocketLaunch
    ) public initializer {
        dex = _dex;
        wBera = _wBera;
        poolIdx = _poolIdx;
        rocketLaunch = _rocketLaunch;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function setRocketLaunch(address _rocketLaunch) public onlyOwner {
        rocketLaunch = _rocketLaunch;
    }

    function getPriceFromBaseAndQuoteAmount(
        uint256 baseAmount,
        uint256 quoteAmount
    ) public pure returns (uint256) {
        uint256 sqrtFixed = uint256(
            MathUpgradeable.sqrt((baseAmount * 1e18) / quoteAmount)
        );
        return sqrtFixed.mul(Q_64).div(1e9);
    }

    function getCrocErc20LpAddress(
        address baseToken,
        address quoteToken,
        address dexAddress
    ) public pure returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(baseToken, quoteToken));
        // NOTE: for bartio only
        bytes32 initCodeHash = 0xf8fb854b80d71035cc709012ce23accad9a804fcf7b90ac0c663e12c58a9c446;
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                dexAddress,
                                salt,
                                initCodeHash
                            )
                        )
                    )
                )
            );
    }

    function encodeInitialize(
        address baseToken,
        address quoteToken,
        uint256 crocPrice
    ) public view returns (bytes memory) {
        return
            abi.encode(
                uint8(71),
                baseToken,
                quoteToken,
                poolIdx,
                uint128(crocPrice)
            );
    }

    function encodeMintData(
        address baseToken,
        address quoteToken,
        uint256 crocPrice,
        uint256 baseAmount,
        address lpAddress
    ) internal view returns (bytes memory) {
        return
            abi.encode(
                uint8(31),
                baseToken,
                quoteToken,
                poolIdx,
                int24(0),
                int24(0),
                uint128(baseAmount),
                uint128(crocPrice),
                uint128(crocPrice),
                uint8(0),
                lpAddress
            );
    }

    function encodeMultiCmd(
        bytes memory initCalldata,
        bytes memory mintCalldata
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                uint8(2),
                uint8(3),
                initCalldata,
                uint8(128),
                mintCalldata
            );
    }

    function createPoolAndAddLP(
        address baseToken,
        uint256 baseAmount,
        uint256 wBeraAmount
    ) public {
        if (baseToken < wBera) {
            executeAddLp(baseToken, wBera, baseAmount, wBeraAmount);
        } else {
            executeAddLp(wBera, baseToken, wBeraAmount, baseAmount);
        }
    }

    function executeAddLp(
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public {
       uint256 crocPrice = getPriceFromBaseAndQuoteAmount(
            baseAmount,
            quoteAmount
        );
        ERC20Upgradeable(baseToken).approve(dex, MAX_INT);
        ERC20Upgradeable(quoteToken).approve(dex, MAX_INT);
        address lpAddress = getCrocErc20LpAddress(baseToken, quoteToken, dex);
        bytes memory initCalldata = encodeInitialize(
            baseToken,
            quoteToken,
            crocPrice
        );
        uint256 amountAddLp = baseAmount.mul(999).div(1000).sub(INIT_AMOUNT_ADD_LP);
        bytes memory mintCalldata = encodeMintData(
            baseToken,
            quoteToken,
            crocPrice,
            amountAddLp,
            lpAddress
        );
        bytes memory multiCmd = encodeMultiCmd(initCalldata, mintCalldata);
        Dex(dex).userCmd(uint16(6), multiCmd);
        // burn lp token
        ERC20Upgradeable(lpAddress).transfer(
            deadAddress,
            ERC20Upgradeable(lpAddress).balanceOf(address(this))
        );
    }

    function checkCmd(
        address baseToken,
        address quoteToken,
        uint256 baseAmount,
        uint256 quoteAmount
    ) public view returns (bytes memory) {
        uint256 crocPrice = getPriceFromBaseAndQuoteAmount(
            baseAmount,
            quoteAmount
        );
        address lpAddress = getCrocErc20LpAddress(baseToken, quoteToken, dex);
        bytes memory initCalldata = encodeInitialize(
            baseToken,
            quoteToken,
            crocPrice
        );

        uint256 amount = baseAmount.mul(999).div(1000).sub(INIT_AMOUNT_ADD_LP);
        bytes memory mintCalldata = encodeMintData(
            baseToken,
            quoteToken,
            crocPrice,
            amount,
            lpAddress
        );
        return encodeMultiCmd(initCalldata, mintCalldata);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    // emergency withdraw
    function emergencyWithdraw(address token) public onlyOwner {
        if (token == address(0)) {
            payable(owner).transfer(address(this).balance);
        } else {
            IERC20Upgradeable(token).transfer(
                owner,
                IERC20Upgradeable(token).balanceOf(address(this))
            );
        }
    }
}
