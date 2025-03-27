# MariSlots Game - Frontend Integration Guide

## Read Functions

### 1. betUsers(address tokenAddress, address userAddress) → BetInfo
Get user's current bet information for a specific token.
- **Parameters:**
  - `tokenAddress`: Address of the token being used
  - `userAddress`: Address of the user
- **Returns:**
  ```typescript
  {
    betValues: uint256[8], // Array of bet amounts for each slot
    totalBet: uint256,     // Total bet amount
    isSpun: boolean,       // Whether the bet has been spun
    reward: uint256        // Current reward amount (if won)
  }
  ```

### 2. tokenMultipliers(address token) → uint256[8]
Get the current multipliers for each slot for a specific token.
- **Parameters:**
  - `token`: Address of the token
- **Returns:** Array of 8 multiplier values for each slot

### 3. paused() → boolean
Check if the game is currently paused.
- **Returns:** True if game is paused, false otherwise

## Write Functions

### 1. bet(address tokenAddress, uint256[8] betValues)
Place bets on multiple slots.
- **Parameters:**
  - `tokenAddress`: Address of the token to bet with
  - `betValues`: Array of 8 values representing bet amounts for each slot
- **Requirements:**
  - Total bet amount must be greater than 0
  - For ERC20 tokens: Must approve contract first
  - For native token (ETH): Must send correct ETH amount
- **Events Emitted:** `BetPlaced(token, player, betValues, totalBet)`

### 2. spin(address tokenAddress)
Spin the slot machine for an active bet.
- **Parameters:**
  - `tokenAddress`: Address of the token used in the bet
- **Requirements:**
  - Must have an active bet
  - Bet must not have been spun already
- **Events Emitted:** `SpinResult(token, player, winningSlot, reward)`

### 3. claimReward(address tokenAddress)
Claim rewards from a winning spin.
- **Parameters:**
  - `tokenAddress`: Address of the token to claim rewards in
- **Requirements:**
  - Must have spun the bet
  - Must have a reward to claim
- **Events Emitted:** `RewardClaimed(token, player, amount)`

## Events to Listen For

### 1. BetPlaced
```solidity
event BetPlaced(
    address indexed token,
    address indexed player,
    uint256[8] betValues,
    uint256 totalBet
)
```

### 2. SpinResult
```solidity
event SpinResult(
    address indexed token,
    address indexed player,
    uint256 winningSlot,
    uint256 reward
)
```

### 3. RewardClaimed
```solidity
event RewardClaimed(
    address indexed token,
    address indexed player,
    uint256 amount
)
```

## Common Error Messages

- "No active bet": User needs to place a bet first
- "Already spun": Current bet has already been spun
- "Not spun yet": Need to spin before claiming rewards
- "No reward to claim": No rewards available for claiming
- "Token transfer failed": ERC20 token transfer failed
- "Token not whitelisted": Token is not supported by the game
- "Native token not accepted": When trying to bet with native token if not supported
- "Incorrect native token amount": When sent ETH amount doesn't match bet amount

## Typical User Flow

1. Check if token is supported
2. For ERC20 tokens: Approve contract to spend tokens
3. Place bet with desired amounts for each slot
4. Spin the slot machine
5. If won, claim rewards
