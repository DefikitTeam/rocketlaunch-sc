## Lottery Implementation Plan

This document outlines the plan to implement a lottery mechanism in the `RocketBera.sol` contract.

### Overview

The goal is to integrate a lottery mechanism to prevent bots/snipers from buying all the tokens during the `minDurationSell` period.

### Implementation Details

*   **Create a `Lottery` struct:**
    *   `uint256 fundDeposit`: Total ETH deposited for the lottery.
    *   `mapping(address => uint256) lotteryParticipants`: Requested number of batches for each participant.
*   **Add the `depositForLottery` function:**
    *   This function allows users to deposit ETH and request to buy `numberBatch` of tokens.
    *   It requires the lottery to be active and the current time to be within the `minDurationSell` period.
    *   It adds the deposited ETH to the `lottery.fundDeposit` of the `Pool` struct.
    *   It stores the user's requested `numberBatch` in the `lottery.lotteryParticipants` mapping.
    *   It emits a `DepositForLottery` event.
*   **Add the `spinLottery` function:**
    *   This function can be called by anyone at any time to trigger the lottery.
    *   It gets the `lottery.fundDeposit` and available batches from the `Pool` struct.
    *   It iterates through the `lottery.lotteryParticipants` and randomly assigns batches to winners.
    *   Each winner is treated as if they executed a `buy` function for 1 batch.
    *   If there are remaining batches and `lottery.fundDeposit`, the remaining `lottery.fundDeposit` is kept for the next lottery.
