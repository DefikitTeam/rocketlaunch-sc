const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

describe("DistributionRFA", function () {
  let distributionRFA;
  let owner, operator, user1, user2, user3, nonOperator;
  let merkleTree;
  let merkleRoot;
  let merkleProofs = {};
  let currentTimestamp;

  // Campaign Types enum
  const CampaignType = {
    NONE: 0,
    WEEKLY: 1,
    MONTHLY: 2,
    QUARTERLY: 3,
    YEARLY: 4
  };

  // Test data for merkle tree
  const airdropData = [
    { address: null, amount: ethers.utils.parseEther("1.0") }, // user1
    { address: null, amount: ethers.utils.parseEther("2.0") }, // user2
    { address: null, amount: ethers.utils.parseEther("0.5") }, // user3
  ];

  beforeEach(async function () {
    [owner, operator, user1, user2, user3, nonOperator] = await ethers.getSigners();

    // Update addresses in airdrop data
    airdropData[0].address = user1.address;
    airdropData[1].address = user2.address;
    airdropData[2].address = user3.address;

    // Create merkle tree
    const leaves = airdropData.map(data => 
      ethers.utils.solidityKeccak256(
        ["address", "uint256"], 
        [data.address, data.amount]
      )
    );
    
    merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    merkleRoot = merkleTree.getHexRoot();

    // Generate proofs for each user
    airdropData.forEach((data, index) => {
      const leaf = ethers.utils.solidityKeccak256(
        ["address", "uint256"], 
        [data.address, data.amount]
      );
      merkleProofs[data.address] = merkleTree.getHexProof(leaf);
    });

    // Deploy contract
    const DistributionRFA = await ethers.getContractFactory("DistributionRFA");
    distributionRFA = await upgrades.deployProxy(DistributionRFA, [operator.address]);
    await distributionRFA.deployed();

    // Get current timestamp
    const block = await ethers.provider.getBlock("latest");
    currentTimestamp = block.timestamp;

    // Fund the contract
    await owner.sendTransaction({
      to: distributionRFA.address,
      value: ethers.utils.parseEther("100.0")
    });
  });

  describe("Deployment and Initialization", function () {
    it("Should initialize with correct owner", async function () {
      expect(await distributionRFA.owner()).to.equal(owner.address);
    });

    it("Should have correct operator", async function () {
      // Test operator functionality by creating a campaign
      await expect(
        distributionRFA.connect(operator).createNewWeeklyRetroActive(
          merkleRoot,
          ethers.utils.parseEther("5.0"),
          currentTimestamp,
          "Test Campaign"
        )
      ).to.not.be.reverted;
    });

    it("Should have contract balance", async function () {
      expect(await distributionRFA.getBalance()).to.equal(ethers.utils.parseEther("100.0"));
    });

    it("Should have correct constants", async function () {
      expect(await distributionRFA.MAX_MERKLE_PROOF_LENGTH()).to.equal(32);
      expect(await distributionRFA.MAX_CLAIM_AMOUNT_WEEKLY()).to.equal(ethers.utils.parseEther("50"));
      expect(await distributionRFA.MAX_CLAIM_AMOUNT_MONTHLY()).to.equal(ethers.utils.parseEther("100"));
      expect(await distributionRFA.MAX_CLAIM_AMOUNT_QUARTERLY()).to.equal(ethers.utils.parseEther("600"));
      expect(await distributionRFA.MAX_CLAIM_AMOUNT_YEARLY()).to.equal(ethers.utils.parseEther("1000"));
    });
  });

  describe("Weekly Campaign Management", function () {
    describe("Create New Weekly Campaign", function () {
      it("Should create a new weekly campaign successfully", async function () {
        const timestamp = currentTimestamp + 1000;
        
        await expect(
          distributionRFA.connect(operator).createNewWeeklyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            timestamp,
            "Test Weekly Campaign"
          )
        ).to.emit(distributionRFA, "WeeklyCampaignCreated")
          .withArgs(timestamp, merkleRoot, ethers.utils.parseEther("5.0"), "Test Weekly Campaign");

        const campaign = await distributionRFA.weeklyRetroActive(timestamp);
        expect(campaign.merkleRoot).to.equal(merkleRoot);
        expect(campaign.amount).to.equal(ethers.utils.parseEther("5.0"));
        expect(campaign.description).to.equal("Test Weekly Campaign");
        expect(campaign.isActive).to.be.true;
      });

      it("Should revert if amount is 0", async function () {
        await expect(
          distributionRFA.connect(operator).createNewWeeklyRetroActive(
            merkleRoot,
            0,
            currentTimestamp + 1000,
            "Test Campaign"
          )
        ).to.be.revertedWith("Amount must be greater than 0");
      });

      it("Should revert if merkle root is zero", async function () {
        await expect(
          distributionRFA.connect(operator).createNewWeeklyRetroActive(
            ethers.constants.HashZero,
            ethers.utils.parseEther("5.0"),
            currentTimestamp + 1000,
            "Test Campaign"
          )
        ).to.be.revertedWith("Invalid merkle root");
      });

      it("Should revert if caller is not operator or owner", async function () {
        await expect(
          distributionRFA.connect(nonOperator).createNewWeeklyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            currentTimestamp + 1000,
            "Test Campaign"
          )
        ).to.be.revertedWith("Caller is not owner or operator");
      });

      it("Should prevent duplicate campaigns with same timestamp", async function () {
        const timestamp = currentTimestamp + 1000;
        
        await distributionRFA.connect(operator).createNewWeeklyRetroActive(
          merkleRoot,
          ethers.utils.parseEther("5.0"),
          timestamp,
          "First Campaign"
        );

        await expect(
          distributionRFA.connect(operator).createNewWeeklyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("3.0"),
            timestamp,
            "Duplicate Campaign"
          )
        ).to.be.revertedWith("Airdrop: campaign already exists");
      });
    });

    describe("Update Weekly Campaign", function () {
      beforeEach(async function () {
        await distributionRFA.connect(operator).createNewWeeklyRetroActive(
          merkleRoot,
          ethers.utils.parseEther("5.0"),
          currentTimestamp + 1000,
          "Original Campaign"
        );
      });

      it("Should update weekly campaign successfully", async function () {
        const newMerkleRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("new root"));
        const timestamp = currentTimestamp + 1000;
        
        await expect(
          distributionRFA.connect(operator).updateWeeklyRetroActive(
            newMerkleRoot,
            ethers.utils.parseEther("7.0"),
            timestamp,
            "Updated Campaign"
          )
        ).to.emit(distributionRFA, "WeeklyCampaignUpdated")
          .withArgs(timestamp, newMerkleRoot, ethers.utils.parseEther("7.0"), "Updated Campaign");

        const campaign = await distributionRFA.weeklyRetroActive(timestamp);
        expect(campaign.merkleRoot).to.equal(newMerkleRoot);
        expect(campaign.amount).to.equal(ethers.utils.parseEther("7.0"));
        expect(campaign.description).to.equal("Updated Campaign");
      });

      it("Should revert if campaign doesn't exist", async function () {
        await expect(
          distributionRFA.connect(operator).updateWeeklyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            currentTimestamp + 999999,
            "Non-existent Campaign"
          )
        ).to.be.revertedWith("Airdrop: campaign not found");
      });
    });
  });

  describe("Weekly Claiming", function () {
    const timestamp = 1000000; // Fixed timestamp for consistency

    beforeEach(async function () {
      await distributionRFA.connect(operator).createNewWeeklyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("50.0"),
        timestamp,
        "Test Weekly Campaign"
      );
    });

    it("Should allow valid weekly claim", async function () {
      const initialBalance = await user1.getBalance();
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, proof)
      ).to.emit(distributionRFA, "WeeklyRetroActiveClaimed")
        .withArgs(user1.address, timestamp, claimAmount)
        .and.to.emit(distributionRFA, "UserClaimInfo")
        .withArgs(user1.address, timestamp, claimAmount, CampaignType.WEEKLY);

      // Check user received tokens
      const finalBalance = await user1.getBalance();
      expect(finalBalance.sub(initialBalance)).to.be.closeTo(
        claimAmount,
        ethers.utils.parseEther("0.01") // Account for gas fees
      );

      // Check claim is recorded
      const userInfo = await distributionRFA.userWeeklyClaimed(timestamp, user1.address);
      expect(userInfo.claimedAmount).to.equal(claimAmount);
      expect(userInfo.hasClaimed).to.be.true;
    });

    it("Should prevent double claiming", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      // First claim should succeed
      await distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, proof);

      // Second claim should fail
      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, proof)
      ).to.be.revertedWith("Airdrop: already claimed");
    });

    it("Should revert with invalid proof", async function () {
      const claimAmount = airdropData[0].amount;
      const wrongProof = merkleProofs[user2.address]; // Wrong proof for user1

      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, wrongProof)
      ).to.be.revertedWith("Airdrop: Invalid proof");
    });

    it("Should revert if amount exceeds weekly maximum", async function () {
      const excessiveAmount = ethers.utils.parseEther("51"); // Exceeds 50 ETH weekly max
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, excessiveAmount, proof)
      ).to.be.revertedWith("Amount exceeds maximum");
    });

    it("Should revert with zero amount", async function () {
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, 0, proof)
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should revert when paused", async function () {
      await distributionRFA.connect(owner).pause();

      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, proof)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should revert with too long merkle proof", async function () {
      const claimAmount = airdropData[0].amount;
      const longProof = new Array(33).fill(ethers.constants.HashZero); // Exceeds 32 limit

      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, longProof)
      ).to.be.revertedWith("Merkle proof too long");
    });
  });

  describe("Monthly Campaign Management", function () {
    it("Should create and claim from monthly campaign", async function () {
      const timestamp = currentTimestamp + 2000;
      
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("10.0"),
        timestamp,
        "Test Monthly Campaign"
      );

      const claimAmount = airdropData[1].amount; // user2's amount
      const proof = merkleProofs[user2.address];

      await expect(
        distributionRFA.connect(user2).claimMonthlyRetroActive(timestamp, claimAmount, proof)
      ).to.emit(distributionRFA, "MonthlyRetroActiveClaimed")
        .withArgs(user2.address, timestamp, claimAmount);

      const userInfo = await distributionRFA.userMonthlyClaimed(timestamp, user2.address);
      expect(userInfo.hasClaimed).to.be.true;
    });

    it("Should enforce monthly claim limits", async function () {
      const timestamp = currentTimestamp + 2000;
      
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("200.0"),
        timestamp,
        "Test Monthly Campaign"
      );

      const excessiveAmount = ethers.utils.parseEther("101"); // Exceeds 100 ETH monthly max
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimMonthlyRetroActive(timestamp, excessiveAmount, proof)
      ).to.be.revertedWith("Amount exceeds maximum");
    });
  });

  describe("Quarterly Campaign Management", function () {
    it("Should create and claim from quarterly campaign", async function () {
      const timestamp = currentTimestamp + 3000;
      
      await distributionRFA.connect(operator).createNewQuarterlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("100.0"),
        timestamp,
        "Test Quarterly Campaign"
      );

      const claimAmount = airdropData[2].amount; // user3's amount
      const proof = merkleProofs[user3.address];

      await expect(
        distributionRFA.connect(user3).claimQuarterlyRetroActive(timestamp, claimAmount, proof)
      ).to.emit(distributionRFA, "QuarterlyRetroActiveClaimed")
        .withArgs(user3.address, timestamp, claimAmount);
    });

    it("Should enforce quarterly claim limits", async function () {
      const timestamp = currentTimestamp + 3000;
      
      await distributionRFA.connect(operator).createNewQuarterlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("1000.0"),
        timestamp,
        "Test Quarterly Campaign"
      );

      const excessiveAmount = ethers.utils.parseEther("601"); // Exceeds 600 ETH quarterly max
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimQuarterlyRetroActive(timestamp, excessiveAmount, proof)
      ).to.be.revertedWith("Amount exceeds maximum");
    });
  });

  describe("Yearly Campaign Management", function () {
    it("Should create and claim from yearly campaign", async function () {
      const timestamp = currentTimestamp + 4000;
      
      await distributionRFA.connect(operator).createNewYearlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("500.0"),
        timestamp,
        "Test Yearly Campaign"
      );

      const claimAmount = airdropData[0].amount; // user1's amount
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimYearlyRetroActive(timestamp, claimAmount, proof)
      ).to.emit(distributionRFA, "YearlyRetroActiveClaimed")
        .withArgs(user1.address, timestamp, claimAmount);
    });

    it("Should enforce yearly claim limits", async function () {
      const timestamp = currentTimestamp + 4000;
      
      await distributionRFA.connect(operator).createNewYearlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("2000.0"),
        timestamp,
        "Test Yearly Campaign"
      );

      const excessiveAmount = ethers.utils.parseEther("1001"); // Exceeds 1000 ETH yearly max
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claimYearlyRetroActive(timestamp, excessiveAmount, proof)
      ).to.be.revertedWith("Amount exceeds maximum");
    });
  });

  describe("Multi-Campaign Scenarios", function () {
    it("Should allow users to claim from multiple campaign types", async function () {
      const weeklyTimestamp = currentTimestamp + 1000;
      const monthlyTimestamp = currentTimestamp + 2000;
      
      // Create campaigns
      await distributionRFA.connect(operator).createNewWeeklyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("50.0"),
        weeklyTimestamp,
        "Weekly Campaign"
      );
      
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("100.0"),
        monthlyTimestamp,
        "Monthly Campaign"
      );

      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      // Claim from both campaigns
      await distributionRFA.connect(user1).claimWeeklyRetroActive(weeklyTimestamp, claimAmount, proof);
      await distributionRFA.connect(user1).claimMonthlyRetroActive(monthlyTimestamp, claimAmount, proof);

      // Verify both claims
      const weeklyInfo = await distributionRFA.userWeeklyClaimed(weeklyTimestamp, user1.address);
      const monthlyInfo = await distributionRFA.userMonthlyClaimed(monthlyTimestamp, user1.address);
      
      expect(weeklyInfo.hasClaimed).to.be.true;
      expect(monthlyInfo.hasClaimed).to.be.true;
    });

    it("Should keep campaign types isolated", async function () {
      const timestamp = currentTimestamp + 1000;
      
      // Create weekly campaign
      await distributionRFA.connect(operator).createNewWeeklyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("50.0"),
        timestamp,
        "Weekly Campaign"
      );

      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      // Claim from weekly
      await distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, proof);

      // Should not affect other campaign types
      const monthlyInfo = await distributionRFA.userMonthlyClaimed(timestamp, user1.address);
      expect(monthlyInfo.hasClaimed).to.be.false;
    });
  });

  describe("Access Control", function () {
    it("Should allow owner to setup operator", async function () {
      await expect(
        distributionRFA.connect(owner).setupOperator(user1.address)
      ).to.emit(distributionRFA, "OperatorUpdated")
        .withArgs(operator.address, user1.address);
    });

    it("Should revert if non-owner tries to setup operator", async function () {
      await expect(
        distributionRFA.connect(user1).setupOperator(user2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should revert if setting operator to zero address", async function () {
      await expect(
        distributionRFA.connect(owner).setupOperator(ethers.constants.AddressZero)
      ).to.be.revertedWith("Invalid operator address");
    });

    it("Should allow only owner to pause/unpause", async function () {
      await expect(distributionRFA.connect(owner).pause()).to.not.be.reverted;
      await expect(distributionRFA.connect(owner).unpause()).to.not.be.reverted;
      
      await expect(
        distributionRFA.connect(user1).pause()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow owner to withdraw funds", async function () {
      const withdrawAmount = ethers.utils.parseEther("10.0");
      
      await expect(
        distributionRFA.connect(owner).emergency(withdrawAmount)
      ).to.emit(distributionRFA, "EmergencyWithdrawal")
        .withArgs(owner.address, withdrawAmount);
    });

    it("Should revert emergency withdrawal for non-owner", async function () {
      await expect(
        distributionRFA.connect(user1).emergency(ethers.utils.parseEther("1.0"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should revert if emergency withdrawal exceeds balance", async function () {
      const excessAmount = ethers.utils.parseEther("1000.0"); // More than contract balance

      await expect(
        distributionRFA.connect(owner).emergency(excessAmount)
      ).to.be.revertedWith("Insufficient contract balance");
    });
  });

  describe("Contract Funding", function () {
    it("Should emit ContractFunded event when receiving ETH", async function () {
      const fundAmount = ethers.utils.parseEther("5.0");
      
      await expect(
        user1.sendTransaction({
          to: distributionRFA.address,
          value: fundAmount
        })
      ).to.emit(distributionRFA, "ContractFunded")
        .withArgs(user1.address, fundAmount);

      const newBalance = await distributionRFA.getBalance();
      expect(newBalance).to.equal(ethers.utils.parseEther("105.0"));
    });
  });

  describe("Gas Optimization Tests", function () {
    it("Should use reasonable gas for weekly claim", async function () {
      const timestamp = currentTimestamp + 1000;
      
      await distributionRFA.connect(operator).createNewWeeklyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("50.0"),
        timestamp,
        "Gas Test Campaign"
      );

      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      const tx = await distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, proof);
      const receipt = await tx.wait();
      
      // Gas should be reasonable (less than 150k for a claim with events)
      expect(receipt.gasUsed).to.be.below(150000);
      console.log(`Gas used for weekly claim: ${receipt.gasUsed}`);
    });
  });

  describe("Edge Cases and Security", function () {
    it("Should handle contract receiving ETH via fallback", async function () {
      const initialBalance = await distributionRFA.getBalance();
      
      // Send ETH with data to trigger fallback
      await user1.sendTransaction({
        to: distributionRFA.address,
        value: ethers.utils.parseEther("1.0"),
        data: "0x1234"
      });

      const finalBalance = await distributionRFA.getBalance();
      expect(finalBalance.sub(initialBalance)).to.equal(ethers.utils.parseEther("1.0"));
    });

    it("Should maintain state consistency with reentrancy protection", async function () {
      const timestamp = currentTimestamp + 1000;
      
      await distributionRFA.connect(operator).createNewWeeklyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("50.0"),
        timestamp,
        "Reentrancy Test"
      );
      
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, proof);
      
      // Verify state is correctly updated
      const userInfo = await distributionRFA.userWeeklyClaimed(timestamp, user1.address);
      expect(userInfo.hasClaimed).to.be.true;
      expect(userInfo.claimedAmount).to.equal(claimAmount);
    });

    it("Should handle large merkle proofs up to limit", async function () {
      const timestamp = currentTimestamp + 1000;
      
      await distributionRFA.connect(operator).createNewWeeklyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("50.0"),
        timestamp,
        "Large Proof Test"
      );

      const claimAmount = airdropData[0].amount;
      const maxProof = new Array(32).fill(ethers.constants.HashZero); // Exactly at limit

      // Should not revert due to proof length (will revert due to invalid proof though)
      await expect(
        distributionRFA.connect(user1).claimWeeklyRetroActive(timestamp, claimAmount, maxProof)
      ).to.be.revertedWith("Airdrop: Invalid proof"); // Expected due to wrong proof content
    });
  });
}); 