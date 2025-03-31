const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("MariSlotsGame", function () {
    let mariGame;
    let mockToken;
    let weth;
    let uniswapFactory;
    let uniswapRouter;
    let owner;
    let player;
    let platform;

    const INITIAL_SUPPLY = ethers.utils.parseEther("1000000");
    const BET_AMOUNT = ethers.utils.parseEther("1");
    const FUND_AMOUNT = ethers.utils.parseEther("10");

    beforeEach(async function () {
        [owner, player, platform] = await ethers.getSigners();

        // Deploy WETH
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        weth = await MockERC20.deploy("Wrapped ETH", "WETH", INITIAL_SUPPLY);

        // Deploy mock token
        mockToken = await MockERC20.deploy("Mock Token", "MTK", INITIAL_SUPPLY);

        // Deploy Uniswap Factory
        const MockUniswapV2Factory = await ethers.getContractFactory("MockUniswapV2Factory");
        uniswapFactory = await MockUniswapV2Factory.deploy();

        // Deploy Uniswap Router with WETH
        const MockUniswapV2Router02 = await ethers.getContractFactory("MockUniswapV2Router02");
        uniswapRouter = await MockUniswapV2Router02.deploy(weth.address);

        // Set up factory and router
        await uniswapRouter.setFactory(uniswapFactory.address);
        await uniswapFactory.setRouter(uniswapRouter.address);

        // Create pair
        await uniswapFactory.createPair(mockToken.address, weth.address);

        // Deploy MariSlotsGame
        const MariSlotsGame = await ethers.getContractFactory("MariSlotsGame");
        mariGame = await upgrades.deployProxy(MariSlotsGame, [
            uniswapRouter.address,
            uniswapFactory.address,
            weth.address,
            platform.address
        ]);
        await mariGame.deployed();

        // Set up token rates in mock router
        await uniswapRouter.setRate(mockToken.address, 1000); // 1 ETH = 1000 tokens

        // Transfer some tokens to player
        await mockToken.transfer(player.address, INITIAL_SUPPLY.div(4));
        await mockToken.transfer(mariGame.address, INITIAL_SUPPLY.div(2));

        // Approve tokens
        await mockToken.approve(mariGame.address, INITIAL_SUPPLY);
        await mockToken.connect(player).approve(mariGame.address, INITIAL_SUPPLY);
    });

    describe("Initialization", function () {
        it("Should initialize with correct values", async function () {
            expect(await mariGame.uniswapRouter()).to.equal(uniswapRouter.address);
            expect(await mariGame.uniswapFactory()).to.equal(uniswapFactory.address);
            expect(await mariGame.WETH()).to.equal(weth.address);
            expect(await mariGame.platformAddress()).to.equal(platform.address);
        });
    });

    describe("Betting", function () {
        it("Should allow betting with tokens", async function () {
            const betValues = Array(8).fill(0);
            betValues[0] = BET_AMOUNT;

            await expect(
                mariGame.connect(player).bet(mockToken.address, betValues)
            ).to.emit(mariGame, "BetPlaced")
                .withArgs(mockToken.address, player.address, betValues, BET_AMOUNT);

            const bet = await mariGame.betUsers(mockToken.address, player.address);
            expect(bet.totalBet).to.equal(BET_AMOUNT);
            expect(bet.isSpun).to.be.false;
        });

        it("Should reject bet with zero total amount", async function () {
            const betValues = Array(8).fill(0);
            await expect(
                mariGame.connect(player).bet(mockToken.address, betValues)
            ).to.be.revertedWith("Bet amount must be greater than 0");
        });
    });

    describe("Spinning", function () {
        beforeEach(async function () {
            const betValues = Array(8).fill(0);
            betValues[0] = BET_AMOUNT;
            await mariGame.connect(player).bet(mockToken.address, betValues);
        });

        it("Should allow spinning with active bet", async function () {
            await expect(
                mariGame.connect(player).spin(mockToken.address)
            ).to.emit(mariGame, "SpinResult");
        });
    });

    describe("Admin Functions", function () {
        it("Should allow admin to update multipliers", async function () {
            const newMultipliers = [4, 6, 3, 12, 4, 6, 25, 3];
            await expect(
                mariGame.updateTokenMultipliers(mockToken.address, newMultipliers)
            ).to.emit(mariGame, "MultipliersUpdated")
                .withArgs(mockToken.address, newMultipliers);
        });

        it("Should allow admin to pause and unpause", async function () {
            await mariGame.pause();
            expect(await mariGame.paused()).to.be.true;

            await mariGame.unpause();
            expect(await mariGame.paused()).to.be.false;
        });
    });

    describe("Funds Management", function () {
        it("Should initialize with zero funds", async function () {
            expect(await mariGame.funds()).to.equal(0);
        });

        it("Should increase funds when placing bets", async function () {
            const betValues = Array(8).fill(0);
            betValues[0] = BET_AMOUNT;

            await mariGame.connect(player).bet(mockToken.address, betValues);
            expect(await mariGame.funds()).to.equal(BET_AMOUNT);

            // Place another bet
            await mariGame.connect(player).bet(mockToken.address, betValues);
            expect(await mariGame.funds()).to.equal(BET_AMOUNT.mul(2));
        });

        it("Should allow admin to inject funds", async function () {
            const initialFunds = await mariGame.funds();
            
            await expect(mariGame.injectFund({ value: FUND_AMOUNT }))
                .to.emit(mariGame, "FundsInjected")
                .withArgs(owner.address, FUND_AMOUNT);
            
            const finalFunds = await mariGame.funds();
            expect(finalFunds).to.equal(initialFunds.add(FUND_AMOUNT));
        });

        it("Should reject fund injection with zero amount", async function () {
            await expect(mariGame.injectFund({ value: 0 }))
                .to.be.revertedWith("Must send ETH");
        });

        it("Should reject fund injection from non-admin", async function () {
            await expect(mariGame.connect(player).injectFund({ value: FUND_AMOUNT }))
                .to.be.reverted; // Access control error
        });

        it("Should allow users to deposit funds", async function () {
            const initialFunds = await mariGame.funds();
            
            await expect(mariGame.connect(player).deposit({ value: FUND_AMOUNT }))
                .to.emit(mariGame, "FundsDeposited")
                .withArgs(player.address, FUND_AMOUNT);
            
            const finalFunds = await mariGame.funds();
            expect(finalFunds).to.equal(initialFunds.add(FUND_AMOUNT));
        });

        it("Should reject deposit with zero amount", async function () {
            await expect(mariGame.connect(player).deposit({ value: 0 }))
                .to.be.revertedWith("Must send ETH");
        });

        it("Should not allow deposits when paused", async function () {
            await mariGame.pause();
            
            await expect(mariGame.connect(player).deposit({ value: FUND_AMOUNT }))
                .to.be.reverted; // Pausable error
            
            await mariGame.unpause();
            await expect(mariGame.connect(player).deposit({ value: FUND_AMOUNT }))
                .to.emit(mariGame, "FundsDeposited");
        });

        it("Should decrease funds when claiming rewards", async function () {
            // Set up multipliers for testing
            const multipliers = [2, 3, 4, 5, 6, 7, 8, 9];
            await mariGame.updateTokenMultipliers(mockToken.address, multipliers);
            
            // Set house fee to 10%
            await mariGame.updateHouseFee(mockToken.address, 10);
            
            // Place bet on slot 0
            const betValues = Array(8).fill(0);
            betValues[0] = BET_AMOUNT;
            await mariGame.connect(player).bet(mockToken.address, betValues);
            
            // Initial funds from bet
            const initialFunds = await mariGame.funds();
            expect(initialFunds).to.equal(BET_AMOUNT);
            
            // Spin and get result
            const spinTx = await mariGame.connect(player).spin(mockToken.address);
            const receipt = await spinTx.wait();
            
            // Find SpinResult event
            const spinEvent = receipt.events?.find(e => e.event === "SpinResult");
            const reward = spinEvent.args.reward;
            
            // Only test claiming if there was a reward
            if (reward.gt(0)) {
                // Claim reward
                await mariGame.connect(player).claimReward(mockToken.address);
                
                // Check funds were decreased by the reward amount
                const finalFunds = await mariGame.funds();
                expect(finalFunds).to.equal(initialFunds.sub(reward));
            }
        });
    });

    describe("Claiming Rewards", function () {
        beforeEach(async function () {
            // Set up multipliers for testing
            const multipliers = [2, 3, 4, 5, 6, 7, 8, 9];
            await mariGame.updateTokenMultipliers(mockToken.address, multipliers);

            // Set house fee to 10%
            await mariGame.updateHouseFee(mockToken.address, 10);

            // Place bet on slot 0
            const betValues = Array(8).fill(0);
            betValues[0] = BET_AMOUNT; // 1 ETH worth of tokens
            await mariGame.connect(player).bet(mockToken.address, betValues);

        });

        it("Should not allow claiming before spinning", async function () {
            await expect(
                mariGame.connect(player).claimReward(mockToken.address)
            ).to.be.revertedWith("Not spun yet");
        });

        it("Should not allow claiming with no reward", async function () {
            await mariGame.connect(player).spin(mockToken.address);
            const bet1 = await mariGame.betUsers(mockToken.address, player.address);
            if (bet1.reward.eq(0)) {
                await expect(
                    mariGame.connect(player).claimReward(mockToken.address)
                ).to.be.revertedWith("No reward to claim");
            }
        });

        it("Should allow claiming valid rewards", async function () {
            // Get initial balance
            const initialBalance = await mockToken.balanceOf(player.address);

            // Spin and get result
            const spinTx = await mariGame.connect(player).spin(mockToken.address);
            const receipt = await spinTx.wait();

            // Find SpinResult event
            const spinEvent = receipt.events?.find(e => e.event === "SpinResult");
            const reward = spinEvent.args.reward;

            // Only test claiming if there was a reward
            if (reward.gt(0)) {
                // Claim reward
                await expect(
                    mariGame.connect(player).claimReward(mockToken.address)
                ).to.emit(mariGame, "RewardClaimed")
                    .withArgs(mockToken.address, player.address, reward);

                // Check balance increased
                const finalBalance = await mockToken.balanceOf(player.address);
                expect(finalBalance).to.equal(initialBalance.add(reward));

                // Check bet info was reset
                const betInfo = await mariGame.betUsers(mockToken.address, player.address);
                expect(betInfo.reward).to.equal(0);
                expect(betInfo.totalBet).to.equal(0);

                // Ensure can't claim twice
                await expect(
                    mariGame.connect(player).claimReward(mockToken.address)
                ).to.be.revertedWith("No reward to claim");
            }
        });

        it("Should handle house fees correctly when claiming", async function () {
            // Get initial house balance
            const initialHouseBalance = await mariGame.houseBalances(mockToken.address);

            // Spin and get result
            const spinTx = await mariGame.connect(player).spin(mockToken.address);
            const receipt = await spinTx.wait();

            const spinEvent = receipt.events?.find(e => e.event === "SpinResult");
            const reward = spinEvent.args.reward;

            if (reward.gt(0)) {
                // Calculate expected house fee (10% of gross reward)
                const grossReward = reward.mul(100).div(90); // Since net = gross - 10%
                const expectedFee = grossReward.mul(10).div(100);

                // Claim reward
                await mariGame.connect(player).claimReward(mockToken.address);

                // Check house balance increased by fee
                const finalHouseBalance = await mariGame.houseBalances(mockToken.address);
                expect(finalHouseBalance).to.equal(initialHouseBalance.add(expectedFee));
            }
        });

        it("Should handle multiple claims from different users", async function () {
            // Set up second player
            const [, , secondPlayer] = await ethers.getSigners();
            await mockToken.transfer(secondPlayer.address, INITIAL_SUPPLY.div(4));
            await mockToken.connect(secondPlayer).approve(mariGame.address, INITIAL_SUPPLY);

            // Place bets for both players
            const betValues = Array(8).fill(0);
            betValues[0] = BET_AMOUNT;
            betValues[1] = BET_AMOUNT;
            betValues[2] = BET_AMOUNT;
            betValues[3] = BET_AMOUNT;
            betValues[4] = BET_AMOUNT;
            betValues[5] = BET_AMOUNT;
            betValues[6] = BET_AMOUNT;
            betValues[7] = BET_AMOUNT;
            await mariGame.connect(secondPlayer).bet(mockToken.address, betValues);

            // Spin and claim for both players
            await mariGame.connect(player).spin(mockToken.address);
            await mariGame.connect(secondPlayer).spin(mockToken.address);

            // Get rewards
            const bet1 = await mariGame.betUsers(mockToken.address, player.address);
            const bet2 = await mariGame.betUsers(mockToken.address, secondPlayer.address);

            // Claim rewards if any
            if (bet1.reward.gt(0)) {
                await mariGame.connect(player).claimReward(mockToken.address);
                const finalBet1 = await mariGame.betUsers(mockToken.address, player.address);
                expect(finalBet1.reward).to.equal(0);
                expect(finalBet1.totalBet).to.equal(0);
            }
            if (bet2.reward.gt(0)) {
                await mariGame.connect(secondPlayer).claimReward(mockToken.address);
                const finalBet2 = await mariGame.betUsers(mockToken.address, secondPlayer.address);

                expect(finalBet2.reward).to.equal(0);
                expect(finalBet2.totalBet).to.equal(0);
            }
        });
    });
});
