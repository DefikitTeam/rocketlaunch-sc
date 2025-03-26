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
contract MariSlotsGame is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;
    
    // Structs
    struct BetInfo {
        uint256[8] betValues;    // Slot bets in token amount
        uint256 totalBet;        // Total bet amount
        bool isSpun;             // Spin status
        uint256 reward;          // Reward amount in token
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
    event MultipliersUpdated(address indexed token, uint256[8] multipliers);
    event HouseFeeUpdated(address indexed token, uint256 fee);

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

        if (_tokenAddress == address(0)) {
            // Native token bet
            require(msg.value == totalBet, "Incorrect native token amount");
            _swapETHForTokens(msg.value, _tokenAddress);
        } else {
            // ERC20 token bet
            require(msg.value == 0, "Native token not accepted for token bet");
            IERC20Upgradeable token = IERC20Upgradeable(_tokenAddress);
            require(token.transferFrom(msg.sender, address(this), totalBet), "Token transfer failed");
        }

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

        uint256 winningSlot = uint256(keccak256(
            abi.encodePacked(
                block.timestamp,
                block.difficulty,
                msg.sender
            )
        )) % 8;

        if (betInfo.betValues[winningSlot] > 0) {
            uint256[8] memory multipliers = tokenMultipliers[_tokenAddress];
            uint256 houseFee = tokenHouseFees[_tokenAddress];
            
            uint256 grossReward = betInfo.betValues[winningSlot].mul(multipliers[winningSlot]);
            uint256 feeAmount = grossReward.mul(houseFee).div(100);
            betInfo.reward = grossReward.sub(feeAmount);
            houseBalances[_tokenAddress] = houseBalances[_tokenAddress].add(feeAmount);
        }

        betInfo.isSpun = true;
        emit SpinResult(_tokenAddress, msg.sender, winningSlot, betInfo.reward);
    }

    /**
     * @dev Claim rewards in game tokens
     * @param _tokenAddress Address of the token
     */
    function claimReward(address _tokenAddress) external nonReentrant {
        BetInfo storage betInfo = betUsers[_tokenAddress][msg.sender];
        require(betInfo.isSpun, "Not spun yet");
        require(betInfo.reward > 0, "No reward to claim");

        uint256 reward = betInfo.reward;
        
        // Reset all values in the bet struct
        betInfo.reward = 0;
        betInfo.totalBet = 0;
        betInfo.betValues = [0, 0, 0, 0, 0, 0, 0, 0];

        if (_tokenAddress == address(0)) {
            _swapTokensForETH(reward, _tokenAddress);
        } else {
            require(
                IERC20Upgradeable(_tokenAddress).transfer(msg.sender, reward),
                "Token transfer failed"
            );
        }

        emit RewardClaimed(_tokenAddress, msg.sender, reward);
    }

    /**
     * @dev Update slot multipliers (owner only)
     * @param _token Address of the token
     * @param _multipliers Array of new multipliers for each slot
     */
    function updateTokenMultipliers(
        address _token,
        uint256[8] calldata _multipliers
    ) external onlyRole(ADMIN_ROLE) {
        tokenMultipliers[_token] = _multipliers;
        emit MultipliersUpdated(_token, _multipliers);
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
    function withdrawHouseFees(
        address _token
    ) external onlyRole(ADMIN_ROLE) {
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
     * @dev Internal function to swap tokens for ETH
     */
    function _swapTokensForETH(uint256 _amount, address _token) internal {
        require(IERC20Upgradeable(_token).approve(address(uniswapRouter), _amount), "Approve failed");

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
}
