const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { BigNumber } = require("ethers");

describe("Rocket Lauch", async function () {
  let owner;
  let platFormAddr;
  let routerAddr;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let addr5;
  let tokenSale1;
  let rocketSC;
  before(async () => {
    // assign address
    [owner, platFormAddr, routerAddr, addr1, addr2, addr3, addr4, addr5] =
      await ethers.getSigners();

    // need mock routerV2

    // Deploy Rocket contract
    const Rocket = await ethers.getContractFactory("Rocket");
    rocketSC = await upgrades.deployProxy(Rocket, [platFormAddr.address, routerAddr.address]);

    // Deploy mock token
    const MockTokenFactory = await ethers.getContractFactory("MockToken");
    tokenSale1 = await MockTokenFactory.deploy();
    await tokenSale1.transfer(rocketSC.address, "1000000000000000000000000000");
  });

  describe("Check Buy & Sell", function () {
    it("Can buy", async function () {
      // Can not buy if pool not active
      await expect(
        rocketSC
          .connect(addr1)
          .buy(
            tokenSale1.address,
            "1000000000000000000",
            addr2.address,
            { value: "1000000000000000000" }
          )
      ).to.be.revertedWith("Pool not active or full or finished");
      // Start sale
      await rocketSC.activePool(
        tokenSale1.address
      );

      await rocketSC
        .connect(addr1)
        .buy(
          tokenSale1.address,
          "1000000000000000000",
          addr2.address,
          { value: "1000000000000000000" }
        );
      const balanceAddr1 = await rocketSC.users(addr1.address, tokenSale1.address);
      expect(balanceAddr1.balance).to.equal("251968503937007874015748031"); // = ((1 * 1600000000)/(5.35 + 1)) * 10^18
      const balanceAddr2 = await rocketSC.users(addr2.address, tokenSale1.address);
      expect(balanceAddr2.refBalance).to.equal("251968503937007874015748031"); // = (1 * 1600000000)/(5.35 + 1) * 10^18
    });

    it("Buy Maximum", async function () {
      await rocketSC
        .connect(addr3)
        .buy(
          tokenSale1.address,
          "3000000000000000000",
          addr4.address,
          { value: "3000000000000000000" }
        ); // Wallet3 buy 3 ETH
      await rocketSC
        .connect(addr4)
        .buy(
          tokenSale1.address,
          "3000000000000000000",
          addr5.address,
          { value: "3000000000000000000" }
        ); // Wallet4 buy 3 ETH -> Over 5.35 ETH
      await expect(
        rocketSC
          .connect(addr5)
          .buy(
            tokenSale1.address,
            "1000000000000000000",
            addr1.address,
            { value: "1000000000000000000" }
          )
      ).to.be.revertedWith("Pool not active or full or finished");
      const poolInfo = await rocketSC.pools(tokenSale1.address);
      console.log(poolInfo);
      expect(poolInfo.status).to.equal(2); // Pool status = 2 (FULL)
      expect(poolInfo.totalRaisedInETH).to.equal("5350000000000000000"); // Total raised = 5.35 ETH
      expect(poolInfo.totalSoldInToken).to.equal("800000000000000000000000000"); // Total sold = 800,000,000 token
    });
  });
});
