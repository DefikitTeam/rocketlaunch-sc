# 🎰 Mari Slots Game - Smart Contract Specification
> A decentralized slot game implementation for EVM-compatible chains

## 📑 Table of Contents
- [Core Game Mechanics](#-core-game-mechanics)
- [Technical Implementation](#-technical-implementation)
- [Security Considerations](#-security-considerations)
- [Integration Guide](#-integration-guide)
- [Development Notes](#-development-notes)

## 🎮 Core Game Mechanics

### 🎲 Betting System
- **8-Slot Machine Layout**
  - Each slot features unique multipliers
  - Default multipliers: `[3x, 5x, 2x, 10x, 3x, 5x, 20x, 2x]`

- **Betting Mechanism**
  - Players can bet on multiple slots simultaneously
  - Bet input format: `betValues[8]` array
  - Example: `[0.1 ETH, 0, 0.2 ETH, 0, 0, 0, 0, 0]`
  - Total bet must match transaction value (`msg.value`)

### 💱 Token Economics

#### Swap Mechanics (Uniswap V2)
- **Bet Processing**
  - Input: Native tokens (ETH/BNB)
  - Output: Game token (ERC-20, e.g., USDT)

- **Reward Distribution**
  - Players can claim rewards in:
    - ERC-20 tokens (direct transfer)
    - Native tokens (automatic swap)

### 🎯 Game Logic

#### Spin Mechanism
```solidity
// Random slot selection (0-7)
uint256 winningSlot = uint256(keccak256(
    abi.encodePacked(
        block.timestamp,
        block.difficulty,
        msg.sender
    )
)) % 8;
```

#### Reward Calculation
- `reward = betValue * slotMultiplier`
- House fee: 5% deduction
- Net payout: `reward * 0.95`

## 🔧 Technical Implementation

### 📊 Data Structures

```solidity
// Mapping structure for bets
mapping(address => mapping(address => BetInfo)) public betUsers; // tokenAddress => userAddress => BetInfo

struct BetInfo {
    uint256[8] betValues;    // Slot bets in token amount
    uint256 totalBet;        // Total bet amount
    bool isSpun;             // Spin status
    uint256 reward;          // Reward amount in token
}
```

### 🔄 Core Functions

#### Betting
```solidity
function bet(
    address _tokenAddress,   // Token address (address(0) for native)
    uint256[8] calldata _betValues // Bet amounts for each slot
) external payable;

function spin(address _tokenAddress) external;

function claimReward(address _tokenAddress) external;
```

## 🛡️ Security Considerations

### RNG Implementation
⚠️ **Current Limitations**
- Uses `keccak256` for randomness
- Vulnerable to miner manipulation
- Recommended upgrade: Chainlink VRF

### DeFi Integration
- **Liquidity Requirements**
  - Sufficient pool depth for token swaps
  - Slippage protection mechanisms
  - Fallback handling for failed swaps

### Smart Contract Safety
- Implementation of OpenZeppelin's:
  - `ReentrancyGuard`
  - `SafeMath`
  - `Ownable`

## 🔗 Integration Guide

### Example Game Flow

1. **Placing a Bet**
```typescript
// Player bets with USDT
betValues = [100 USDT, 200 USDT, 0, 0, 0, 0, 0, 0]
bet(USDT_ADDRESS, betValues)

// Player bets with native token (ETH/BNB)
betValues = [0.1 ETH, 0.2 ETH, 0, 0, 0, 0, 0, 0]
bet(address(0), betValues, {value: 0.3 ETH})
```

2. **Spinning and Winning**
```typescript
// Spin for USDT bet
spin(USDT_ADDRESS)

// If slot 1 wins (5x multiplier)
reward = 200 USDT * 5 = 1000 USDT
finalReward = 950 USDT (after 5% fee)
```

## 📝 Development Notes

### Required Dependencies
- OpenZeppelin Contracts
- Uniswap V2 SDK
- ERC-20 Token Contract

### Event System
```solidity
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
```

### Administrative Features
- Token whitelist management
- Per-token multiplier configuration
- House fee adjustment per token
- Emergency pause mechanism per token

### Testing Protocol
1. Local hardhat network testing
2. Testnet deployment (Sepolia/Mumbai)
3. Mainnet simulation

## 📞 Support & Resources
- Technical Documentation: `/docs`
- Issue Tracking: GitHub Issues
- Security Concerns: security@marigame.com

---
⚠️ **Disclaimer**: This implementation requires thorough testing and auditing before production deployment.