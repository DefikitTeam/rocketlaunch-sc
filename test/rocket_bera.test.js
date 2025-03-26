// const { expect } = require("chai");
// const { ethers, upgrades } = require("hardhat");
// const { BigNumber } = require("ethers");
// const { time } = require("@nomicfoundation/hardhat-network-helpers");

// describe("RocketBera", function () {
//     let owner;
//     let platformAddr;
//     let feeAddr;
//     let routerAddr;
//     let factoryAddr;
//     let addr1;
//     let addr2;
//     let addr3;
//     let addr4;
//     let tokenFactory;
//     let rocketBera;
//     let mockToken;
//     let mockRouter;
//     let mockFactory;
//     let startTime;

//     const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
//     const BASE_DENOMINATOR = 10000;
//     const PLATFORM_FEE = ethers.utils.parseEther("0.1");
//     const FEE = ethers.utils.parseEther("0.01");
//     const BLOCK_INTERVAL = 2;
//     const MIN_CAP = ethers.utils.parseEther("0.02");

//     beforeEach(async () => {
//         [owner, platformAddr, feeAddr, routerAddr, factoryAddr, addr1, addr2, addr3, addr4] = await ethers.getSigners();

//         // Deploy Mock Router
//         const MockRouter = await ethers.getContractFactory("MockUniswapV2Router02");
//         mockRouter = await MockRouter.deploy();
//         await mockRouter.deployed();

//         // Deploy Mock Factory
//         const MockFactory = await ethers.getContractFactory("MockUniswapV2Factory");
//         mockFactory = await MockFactory.deploy();
//         await mockFactory.deployed();

//         // Deploy Token Factory
//         const TokenFactory = await ethers.getContractFactory("RocketTokenFactory");
//         tokenFactory = await TokenFactory.deploy();
//         await tokenFactory.deployed();

//         // Deploy RocketBera
//         const RocketBera = await ethers.getContractFactory("RocketBartio");
//         rocketBera = await upgrades.deployProxy(RocketBera, [
//             platformAddr.address,
//             PLATFORM_FEE,
//             feeAddr.address,
//             FEE,
//             mockRouter.address,
//             BLOCK_INTERVAL,
//             MIN_CAP,
//             tokenFactory.address
//         ]);
//         await rocketBera.deployed();

//         // Set up mock router and factory
//         await mockRouter.setFactory(mockFactory.address);
//         await mockFactory.setRouter(mockRouter.address);

//         // Get current timestamp
//         startTime = (await ethers.provider.getBlock("latest")).timestamp;
//     });

//     describe("Pool Creation and Lottery Setup", function () {
//         let poolParams;

//         beforeEach(async () => {
//             poolParams = {
//                 name: "Test Token",
//                 symbol: "TEST",
//                 decimals: 18,
//                 totalSupply: ethers.utils.parseEther("1000000"),
//                 fixedCapETH: ethers.utils.parseEther("5"),
//                 tokenForAirdrop: ethers.utils.parseEther("10000"),
//                 tokenForFarm: ethers.utils.parseEther("40000"),
//                 tokenForSale: ethers.utils.parseEther("750000"),
//                 tokenForAddLP: ethers.utils.parseEther("200000"),
//                 tokenPerPurchase: ethers.utils.parseEther("100"),
//                 maxRepeatPurchase: 100,
//                 startTime: startTime + 3600,
//                 minDurationSell: 86400,
//                 maxDurationSell: 604800,
//                 metadata: "Test Pool",
//                 numberBatch: 0,
//                 maxAmountETH: 0,
//                 referrer: ZERO_ADDRESS
//             };
//         });

//         it("Should create pool and initialize lottery correctly", async function () {
//             await rocketBera.launchPool(poolParams, { value: PLATFORM_FEE });
            
//             const tokenAddress = await tokenFactory.getLastToken();
//             const lottery = await rocketBera.lotteries(tokenAddress);
            
//             expect(lottery.fundDeposit).to.equal(0);
//             expect(lottery.participants).to.be.empty;
//         });

//         it("Should not allow pool creation without platform fee", async function () {
//             await expect(
//                 rocketBera.launchPool(poolParams)
//             ).to.be.revertedWith("plat fee");
//         });
//     });

//     describe("Lottery Deposits", function () {
//         let tokenAddress;

//         beforeEach(async () => {
//             // Create pool first
//             await rocketBera.launchPool(poolParams, { value: PLATFORM_FEE });
//             tokenAddress = await tokenFactory.getLastToken();
            
//             // Move time to start time
//             await time.increaseTo(poolParams.startTime);
//         });

//         it("Should accept deposits during lottery period", async function () {
//             const depositAmount = ethers.utils.parseEther("1");
//             await rocketBera.connect(addr1).depositForLottery(
//                 tokenAddress,
//                 depositAmount,
//                 ZERO_ADDRESS,
//                 { value: depositAmount }
//             );

//             const lottery = await rocketBera.lotteries(tokenAddress);
//             expect(lottery.fundDeposit).to.equal(depositAmount);

//             const userLottery = await rocketBera.lotteryParticipants(tokenAddress, addr1.address);
//             expect(userLottery.ethAmount).to.equal(depositAmount);
//         });

//         it("Should track multiple deposits from same user", async function () {
//             const deposit1 = ethers.utils.parseEther("1");
//             const deposit2 = ethers.utils.parseEther("2");

//             await rocketBera.connect(addr1).depositForLottery(
//                 tokenAddress,
//                 deposit1,
//                 ZERO_ADDRESS,
//                 { value: deposit1 }
//             );

//             await rocketBera.connect(addr1).depositForLottery(
//                 tokenAddress,
//                 deposit2,
//                 ZERO_ADDRESS,
//                 { value: deposit2 }
//             );

//             const userLottery = await rocketBera.lotteryParticipants(tokenAddress, addr1.address);
//             expect(userLottery.ethAmount).to.equal(deposit1.add(deposit2));
//         });

//         it("Should not accept deposits after lottery period", async function () {
//             await time.increaseTo(poolParams.startTime + poolParams.minDurationSell + 1);

//             const depositAmount = ethers.utils.parseEther("1");
//             await expect(
//                 rocketBera.connect(addr1).depositForLottery(
//                     tokenAddress,
//                     depositAmount,
//                     ZERO_ADDRESS,
//                     { value: depositAmount }
//                 )
//             ).to.be.revertedWith("Not in lottery period");
//         });
//     });

//     describe("Lottery Spin", function () {
//         let tokenAddress;

//         beforeEach(async () => {
//             // Create pool
//             await rocketBera.launchPool(poolParams, { value: PLATFORM_FEE });
//             tokenAddress = await tokenFactory.getLastToken();
            
//             // Move to start time
//             await time.increaseTo(poolParams.startTime);

//             // Make deposits
//             const deposit1 = ethers.utils.parseEther("1");
//             const deposit2 = ethers.utils.parseEther("2");
            
//             await rocketBera.connect(addr1).depositForLottery(
//                 tokenAddress,
//                 deposit1,
//                 ZERO_ADDRESS,
//                 { value: deposit1 }
//             );

//             await rocketBera.connect(addr2).depositForLottery(
//                 tokenAddress,
//                 deposit2,
//                 ZERO_ADDRESS,
//                 { value: deposit2 }
//             );
//         });

//         it("Should successfully spin lottery and allocate batches", async function () {
//             await rocketBera.connect(owner).spinLottery(tokenAddress);

//             // Check if batches were allocated
//             const pool = await rocketBera.pools(tokenAddress);
//             expect(pool.soldBatch).to.be.gt(0);

//             // Check if deposits were processed
//             const lottery = await rocketBera.lotteries(tokenAddress);
//             expect(lottery.fundDeposit).to.be.lt(ethers.utils.parseEther("3")); // Some funds should be used
//         });

//         it("Should allocate batches proportionally to deposits", async function () {
//             await rocketBera.connect(owner).spinLottery(tokenAddress);

//             const user1Info = await rocketBera.users(addr1.address, tokenAddress);
//             const user2Info = await rocketBera.users(addr2.address, tokenAddress);

//             // User2 should have more chance to win due to larger deposit
//             expect(user2Info.balance).to.be.gte(user1Info.balance);
//         });

//         it("Should emit correct events during spin", async function () {
//             await expect(rocketBera.connect(owner).spinLottery(tokenAddress))
//                 .to.emit(rocketBera, "LotteryWinner");
//         });
//     });

//     describe("Integration Tests", function () {
//         it("Should handle full lifecycle of lottery", async function () {
//             // 1. Create pool
//             await rocketBera.launchPool(poolParams, { value: PLATFORM_FEE });
//             const tokenAddress = await tokenFactory.getLastToken();

//             // 2. Move to start time
//             await time.increaseTo(poolParams.startTime);

//             // 3. Multiple users deposit
//             const deposits = [
//                 ethers.utils.parseEther("1"),
//                 ethers.utils.parseEther("2"),
//                 ethers.utils.parseEther("1.5")
//             ];

//             await rocketBera.connect(addr1).depositForLottery(
//                 tokenAddress,
//                 deposits[0],
//                 ZERO_ADDRESS,
//                 { value: deposits[0] }
//             );

//             await rocketBera.connect(addr2).depositForLottery(
//                 tokenAddress,
//                 deposits[1],
//                 ZERO_ADDRESS,
//                 { value: deposits[1] }
//             );

//             await rocketBera.connect(addr3).depositForLottery(
//                 tokenAddress,
//                 deposits[2],
//                 ZERO_ADDRESS,
//                 { value: deposits[2] }
//             );

//             // 4. Spin lottery multiple times
//             await rocketBera.spinLottery(tokenAddress);
//             await rocketBera.spinLottery(tokenAddress);

//             // 5. Verify final state
//             const pool = await rocketBera.pools(tokenAddress);
//             const lottery = await rocketBera.lotteries(tokenAddress);

//             expect(pool.soldBatch).to.be.gt(0);
//             expect(lottery.fundDeposit).to.be.lt(deposits[0].add(deposits[1]).add(deposits[2]));

//             // 6. Check user states
//             const users = [addr1, addr2, addr3];
//             for (const user of users) {
//                 const userInfo = await rocketBera.users(user.address, tokenAddress);
//                 const userLottery = await rocketBera.lotteryParticipants(tokenAddress, user.address);
                
//                 // Either user won some batches or still has their deposit
//                 expect(
//                     userInfo.balance.gt(0) || userLottery.ethAmount.gt(0)
//                 ).to.be.true;
//             }
//         });
//     });
// });
