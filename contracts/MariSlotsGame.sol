// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";

/**
 * @title MariSlotsGame
 * @dev A decentralized slot game with Uniswap integration
 */
contract MariSlotsGame is
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeMathUpgradeable for uint256;

    // Structs
    struct BetInfo {
        uint256[8] betValues; // Slot bets in token amount
        uint256 totalBet; // Total bet amount
        bool isSpun; // Spin status
        uint256 reward; // Reward amount in token
    }

    // State variables
    mapping(address => mapping(address => BetInfo)) public betUsers; // tokenAddress => userAddress => BetInfo
    mapping(address => uint256[8]) public tokenMultipliers; // Per-token multipliers
    mapping(address => uint256) public tokenHouseFees; // Per-token house fees
    mapping(address => uint256) public houseBalances; // House balance per token

    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Factory public uniswapFactory;
    address public WETH;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address public platformAddress;

    uint256 public funds; // Total pool of funds (all bets)
    uint256[8] public multipliers; // Per-token multipliers

    // Events
    event BetPlaced(
        address indexed token,
        address indexed player,
        uint256[8] betValues,
        uint256 totalBet
    );

    event SpinResult(
        address indexed token,
        address indexed player,
        uint256 winningSlot,
        uint256 reward
    );

    event RewardClaimed(
        address indexed token,
        address indexed player,
        uint256 amount
    );

    event TokenWhitelisted(address indexed token, bool status);
    event MultipliersUpdated(uint256[8] multipliers);
    event HouseFeeUpdated(address indexed token, uint256 fee);
    event FundsInjected(address indexed from, uint256 amount);
    event FundsDeposited(address indexed from, uint256 amount);

    function initialize(
        address _uniswapRouter,
        address _uniswapFactory,
        address _weth,
        address _platformAddress
    ) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        uniswapFactory = IUniswapV2Factory(_uniswapFactory);
        platformAddress = _platformAddress;
        WETH = _weth;
        funds = 0;
        multipliers = [4, 6, 3, 12, 4, 6, 25, 3];
    }

    /**
     * @dev Place bets on multiple slots
     * @param _tokenAddress Address of the token
     * @param _betValues Array of bet amounts for each slot
     */
    function bet(
        address _tokenAddress,
        uint256[8] calldata _betValues
    ) external payable nonReentrant whenNotPaused {
        _validateToken(_tokenAddress);

        uint256 totalBet;
        for (uint256 i = 0; i < 8; i++) {
            totalBet = totalBet.add(_betValues[i]);
        }
        require(totalBet > 0, "Bet amount must be greater than 0");

        // ERC20 token bet
        require(msg.value >= totalBet, "token bet amount must be greater than total bet");
        _swapETHForTokens(totalBet, _tokenAddress);
        // Add bet to total funds
        funds = funds.add(totalBet);

        betUsers[_tokenAddress][msg.sender] = BetInfo({
            betValues: _betValues,
            totalBet: totalBet,
            isSpun: false,
            reward: 0
        });

        emit BetPlaced(_tokenAddress, msg.sender, _betValues, totalBet);
    }

    /**
     * @dev Spin the slot machine
     * @param _tokenAddress Address of the token
     */
    function spin(address _tokenAddress) external nonReentrant whenNotPaused {
        BetInfo storage betInfo = betUsers[_tokenAddress][msg.sender];
        require(betInfo.totalBet > 0, "No active bet");
        require(!betInfo.isSpun, "Already spun");

        uint256 winningSlot = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
            )
        ) % 8;

        if (betInfo.betValues[winningSlot] > 0) {
            uint256 houseFee = tokenHouseFees[_tokenAddress];

            uint256 grossReward = betInfo.betValues[winningSlot].mul(
                multipliers[winningSlot]
            );
            uint256 feeAmount = grossReward.mul(houseFee).div(100);
            betInfo.reward = grossReward.sub(feeAmount);
            houseBalances[_tokenAddress] = houseBalances[_tokenAddress].add(
                feeAmount
            );
        }

        betInfo.isSpun = true;
        emit SpinResult(_tokenAddress, msg.sender, winningSlot, betInfo.reward);
    }

    /**
     * @dev Claim rewards from fund pool - Swap ETH to tokens, then send to user
     * @param _tokenAddress Address of the token
     */
    function claimReward(address _tokenAddress) external nonReentrant {
        BetInfo storage betInfo = betUsers[_tokenAddress][msg.sender];
        require(betInfo.isSpun, "Not spun yet");
        require(betInfo.reward > 0, "No reward to claim");
        require(funds >= betInfo.reward, "Insufficient funds in pool");

        uint256 reward = betInfo.reward;

        // Reset all values in the bet struct
        betInfo.reward = 0;
        betInfo.totalBet = 0;
        betInfo.betValues = [0, 0, 0, 0, 0, 0, 0, 0];

        // Reduce funds by the reward amount
        funds = funds.sub(reward);

        // Swap ETH to tokens and send to user
        if (_tokenAddress == address(0)) {
            // For native token, just send ETH
            payable(msg.sender).transfer(reward);
        } else {
            // First check if we have enough token balance
            IERC20Upgradeable token = IERC20Upgradeable(_tokenAddress);
            uint256 contractTokenBalance = token.balanceOf(address(this));

            if (contractTokenBalance >= reward) {
                // If we have enough tokens, send directly
                require(
                    token.transfer(msg.sender, reward),
                    "Token transfer failed"
                );
            } else {
                // If not enough tokens, swap ETH for tokens then send
                // First swap ETH for tokens
                _swapETHForTokensAndSend(reward, _tokenAddress, msg.sender);
            }
        }

        emit RewardClaimed(_tokenAddress, msg.sender, reward);
    }

    /**
     * @dev Admin function to inject funds into the pool
     */
    function injectFund() external payable onlyRole(ADMIN_ROLE) {
        require(msg.value > 0, "Must send ETH");
        funds = funds.add(msg.value);
        emit FundsInjected(msg.sender, msg.value);
    }

    /**
     * @dev User function to deposit funds into the pool
     */
    function deposit() external payable whenNotPaused {
        require(msg.value > 0, "Must send ETH");
        funds = funds.add(msg.value);
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Update house fee (owner only)
     * @param _token Address of the token
     * @param _fee New house fee percentage
     */
    function updateHouseFee(
        address _token,
        uint256 _fee
    ) external onlyRole(ADMIN_ROLE) {
        require(_fee <= 20, "Fee too high"); // Max 20%
        tokenHouseFees[_token] = _fee;
        emit HouseFeeUpdated(_token, _fee);
    }

    /**
     * @dev Withdraw house fees (owner only)
     * @param _token Address of the token
     */
    function withdrawHouseFees(address _token) external onlyRole(ADMIN_ROLE) {
        uint256 amount = houseBalances[_token];
        houseBalances[_token] = 0;
        if (_token == address(0)) {
            payable(platformAddress).transfer(amount);
        } else {
            require(
                IERC20Upgradeable(_token).transfer(platformAddress, amount),
                "Transfer failed"
            );
        }
    }

    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function updateMultipliers(uint256[8] calldata _multipliers) external onlyRole(ADMIN_ROLE) {
        multipliers = _multipliers;
        emit MultipliersUpdated(_multipliers);
    }

    /**
     * @dev Internal function to swap ETH for tokens
     */
    function _swapETHForTokens(uint256 _amount, address _token) internal {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = _token;

        uniswapRouter.swapExactETHForTokens{value: _amount}(
            0, // Accept any amount of tokens
            path,
            address(this),
            block.timestamp + 300 // 5 minute deadline
        );
    }

    /**
     * @dev Internal function to swap ETH for tokens and send to user
     */
    function _swapETHForTokensAndSend(
        uint256 _amount,
        address _token,
        address _to
    ) internal {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = _token;

        uniswapRouter.swapExactETHForTokens{value: _amount}(
            0, // Accept any amount of tokens
            path,
            _to,
            block.timestamp + 300 // 5 minute deadline
        );
    }

    /**
     * @dev Internal function to swap tokens for ETH
     */
    function _swapTokensForETH(uint256 _amount, address _token) internal {
        require(
            IERC20Upgradeable(_token).approve(address(uniswapRouter), _amount),
            "Approve failed"
        );

        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = uniswapRouter.WETH();

        uniswapRouter.swapExactTokensForETH(
            _amount,
            0, // Accept any amount of ETH
            path,
            msg.sender,
            block.timestamp // 5 minute deadline
        );
    }

    function _validateToken(address _token) internal view {
        require(_token != address(0), "Native token not accepted");
        address pair = IUniswapV2Factory(uniswapFactory).getPair(_token, WETH);
        require(pair != address(0), "Token not whitelisted");
    }

    // Function to receive ETH
    receive() external payable {}

    function getBetValues(address _token, address _user) external view returns (uint256[8] memory) {
        return betUsers[_token][_user].betValues;
    }

}