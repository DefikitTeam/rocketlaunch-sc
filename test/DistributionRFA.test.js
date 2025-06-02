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
    distributionRFA = await upgrades.deployProxy(DistributionRFA, [owner.address]);
    await distributionRFA.deployed();

    // Setup operator
    await distributionRFA.connect(owner).setupOperator(operator.address);

    // Fund the contract
    await owner.sendTransaction({
      to: distributionRFA.address,
      value: ethers.utils.parseEther("10.0")
    });
  });

  describe("Deployment and Initialization", function () {
    it("Should initialize with correct owner", async function () {
      expect(await distributionRFA.owner()).to.equal(owner.address);
    });

    it("Should initialize nonce to 0", async function () {
      expect(await distributionRFA.nonce()).to.equal(0);
    });

    it("Should have correct operator", async function () {
      // We can't directly check operator since it's private, but we can test functionality
      await expect(
        distributionRFA.connect(operator).createNewMonthlyRetroActive(
          merkleRoot,
          ethers.utils.parseEther("5.0"),
          "Test Campaign"
        )
      ).to.not.be.reverted;
    });

    it("Should have contract balance", async function () {
      expect(await distributionRFA.getBalance()).to.equal(ethers.utils.parseEther("10.0"));
    });
  });

  describe("Campaign Management", function () {
    describe("Create New Campaign", function () {
      it("Should create a new campaign successfully", async function () {
        await expect(
          distributionRFA.connect(operator).createNewMonthlyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            "Test Campaign"
          )
        ).to.emit(distributionRFA, "NewCampaign")
          .withArgs(ethers.utils.parseEther("5.0"), 1, "Test Campaign");

        expect(await distributionRFA.nonce()).to.equal(1);
        
        const campaign = await distributionRFA.monthlyRetroActive(1);
        expect(campaign.merkleRoot).to.equal(merkleRoot);
        expect(campaign.amount).to.equal(ethers.utils.parseEther("5.0"));
        expect(campaign.description).to.equal("Test Campaign");
      });

      it("Should increment nonce correctly", async function () {
        await distributionRFA.connect(operator).createNewMonthlyRetroActive(
          merkleRoot,
          ethers.utils.parseEther("5.0"),
          "Campaign 1"
        );
        expect(await distributionRFA.nonce()).to.equal(1);

        await distributionRFA.connect(operator).createNewMonthlyRetroActive(
          merkleRoot,
          ethers.utils.parseEther("3.0"),
          "Campaign 2"
        );
        expect(await distributionRFA.nonce()).to.equal(2);
      });

      it("Should revert if amount is 0", async function () {
        await expect(
          distributionRFA.connect(operator).createNewMonthlyRetroActive(
            merkleRoot,
            0,
            "Test Campaign"
          )
        ).to.be.revertedWith("Amount must be greater than 0");
      });

      it("Should revert if merkle root is zero", async function () {
        await expect(
          distributionRFA.connect(operator).createNewMonthlyRetroActive(
            ethers.constants.HashZero,
            ethers.utils.parseEther("5.0"),
            "Test Campaign"
          )
        ).to.be.revertedWith("Invalid merkle root");
      });

      it("Should revert if caller is not operator or owner", async function () {
        await expect(
          distributionRFA.connect(nonOperator).createNewMonthlyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            "Test Campaign"
          )
        ).to.be.revertedWith("Caller is not owner or operator");
      });

      it("Should allow owner to create campaign", async function () {
        await expect(
          distributionRFA.connect(owner).createNewMonthlyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            "Test Campaign"
          )
        ).to.not.be.reverted;
      });
    });

    describe("Update Campaign", function () {
      beforeEach(async function () {
        await distributionRFA.connect(operator).createNewMonthlyRetroActive(
          merkleRoot,
          ethers.utils.parseEther("5.0"),
          "Original Campaign"
        );
      });

      it("Should update campaign successfully", async function () {
        const newMerkleRoot = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("new root"));
        
        await expect(
          distributionRFA.connect(operator).updateMonthlyRetroActive(
            newMerkleRoot,
            ethers.utils.parseEther("7.0"),
            1,
            "Updated Campaign"
          )
        ).to.emit(distributionRFA, "UpdateCampaign")
          .withArgs(ethers.utils.parseEther("7.0"), 1, "Updated Campaign");

        const campaign = await distributionRFA.monthlyRetroActive(1);
        expect(campaign.merkleRoot).to.equal(newMerkleRoot);
        expect(campaign.amount).to.equal(ethers.utils.parseEther("7.0"));
        expect(campaign.description).to.equal("Updated Campaign");
      });

      it("Should revert if campaign doesn't exist", async function () {
        await expect(
          distributionRFA.connect(operator).updateMonthlyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            999,
            "Non-existent Campaign"
          )
        ).to.be.revertedWith("Invalid nonce");
      });

      it("Should revert if amount is 0", async function () {
        await expect(
          distributionRFA.connect(operator).updateMonthlyRetroActive(
            merkleRoot,
            0,
            1,
            "Updated Campaign"
          )
        ).to.be.revertedWith("Amount must be greater than 0");
      });

      it("Should revert if nonce is 0", async function () {
        await expect(
          distributionRFA.connect(operator).updateMonthlyRetroActive(
            merkleRoot,
            ethers.utils.parseEther("5.0"),
            0,
            "Updated Campaign"
          )
        ).to.be.revertedWith("Invalid nonce");
      });
    });
  });

  describe("Claiming", function () {
    beforeEach(async function () {
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("5.0"),
        "Test Campaign"
      );
    });

    it("Should allow valid claim", async function () {
      const initialBalance = await user1.getBalance();
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claim(1, claimAmount, proof)
      ).to.emit(distributionRFA, "ClaimRetroActive")
        .withArgs(user1.address, claimAmount, 1);

      // Check user received tokens
      const finalBalance = await user1.getBalance();
      expect(finalBalance.sub(initialBalance)).to.be.closeTo(
        claimAmount,
        ethers.utils.parseEther("0.01") // Account for gas fees
      );

      // Check claim is recorded
      expect(await distributionRFA.userClaimed(1, user1.address)).to.equal(claimAmount);
      expect(await distributionRFA.hasClaimed(1, user1.address)).to.be.true;
    });

    it("Should prevent double claiming", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      // First claim should succeed
      await distributionRFA.connect(user1).claim(1, claimAmount, proof);

      // Second claim should fail
      await expect(
        distributionRFA.connect(user1).claim(1, claimAmount, proof)
      ).to.be.revertedWith("Airdrop: already claimed");
    });

    it("Should revert with invalid proof", async function () {
      const claimAmount = airdropData[0].amount;
      const wrongProof = merkleProofs[user2.address]; // Wrong proof for user1

      await expect(
        distributionRFA.connect(user1).claim(1, claimAmount, wrongProof)
      ).to.be.revertedWith("Airdrop: Invalid proof");
    });

    it("Should revert with invalid amount", async function () {
      const wrongAmount = ethers.utils.parseEther("999"); // Wrong amount
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claim(1, wrongAmount, proof)
      ).to.be.revertedWith("Airdrop: Invalid proof");
    });

    it("Should revert with zero amount", async function () {
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claim(1, 0, proof)
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should revert for non-existent campaign", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claim(999, claimAmount, proof)
      ).to.be.revertedWith("Invalid nonce");
    });

    it("Should revert if contract has insufficient balance", async function () {
      // Drain most of the contract balance
      await distributionRFA.connect(owner).emergency(ethers.utils.parseEther("9.5"));

      const claimAmount = airdropData[0].amount; // 1.0 ETH
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claim(1, claimAmount, proof)
      ).to.be.revertedWith("Insufficient contract balance");
    });

    it("Should revert when paused", async function () {
      await distributionRFA.connect(owner).pause();

      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claim(1, claimAmount, proof)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should work after unpause", async function () {
      await distributionRFA.connect(owner).pause();
      await distributionRFA.connect(owner).unpause();

      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await expect(
        distributionRFA.connect(user1).claim(1, claimAmount, proof)
      ).to.not.be.reverted;
    });
  });

  describe("Pending Retroactive", function () {
    beforeEach(async function () {
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("5.0"),
        "Test Campaign"
      );
    });

    it("Should return correct pending amount for unclaimed user", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      const pending = await distributionRFA.pendingRetroActive(
        user1.address,
        1,
        claimAmount,
        proof
      );

      expect(pending).to.equal(claimAmount);
    });

    it("Should return 0 for claimed user", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      // First claim
      await distributionRFA.connect(user1).claim(1, claimAmount, proof);

      // Check pending
      const pending = await distributionRFA.pendingRetroActive(
        user1.address,
        1,
        claimAmount,
        proof
      );

      expect(pending).to.equal(0);
    });

    it("Should return 0 for invalid nonce", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      const pending = await distributionRFA.pendingRetroActive(
        user1.address,
        999,
        claimAmount,
        proof
      );

      expect(pending).to.equal(0);
    });

    it("Should return 0 for zero nonce", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      const pending = await distributionRFA.pendingRetroActive(
        user1.address,
        0,
        claimAmount,
        proof
      );

      expect(pending).to.equal(0);
    });

    it("Should return 0 for invalid proof", async function () {
      const claimAmount = airdropData[0].amount;
      const wrongProof = merkleProofs[user2.address];

      const pending = await distributionRFA.pendingRetroActive(
        user1.address,
        1,
        claimAmount,
        wrongProof
      );

      expect(pending).to.equal(0);
    });
  });

  describe("Access Control", function () {
    it("Should allow owner to setup operator", async function () {
      await expect(
        distributionRFA.connect(owner).setupOperator(user1.address)
      ).to.not.be.reverted;
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

    it("Should allow only owner to pause", async function () {
      await expect(distributionRFA.connect(owner).pause()).to.not.be.reverted;
      
      await expect(
        distributionRFA.connect(user1).pause()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow only owner to unpause", async function () {
      await distributionRFA.connect(owner).pause();
      
      await expect(distributionRFA.connect(owner).unpause()).to.not.be.reverted;
      
      await expect(
        distributionRFA.connect(user1).unpause()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow owner to withdraw funds", async function () {
      const withdrawAmount = ethers.utils.parseEther("1.0");
      const initialOwnerBalance = await owner.getBalance();
      const initialContractBalance = await distributionRFA.getBalance();

      await expect(
        distributionRFA.connect(owner).emergency(withdrawAmount)
      ).to.not.be.reverted;

      const finalOwnerBalance = await owner.getBalance();
      const finalContractBalance = await distributionRFA.getBalance();

      expect(finalContractBalance).to.equal(initialContractBalance.sub(withdrawAmount));
      expect(finalOwnerBalance.sub(initialOwnerBalance)).to.be.closeTo(
        withdrawAmount,
        ethers.utils.parseEther("0.01") // Account for gas fees
      );
    });

    it("Should revert if non-owner tries emergency withdrawal", async function () {
      await expect(
        distributionRFA.connect(user1).emergency(ethers.utils.parseEther("1.0"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should revert if emergency withdrawal amount is 0", async function () {
      await expect(
        distributionRFA.connect(owner).emergency(0)
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should revert if emergency withdrawal exceeds balance", async function () {
      const contractBalance = await distributionRFA.getBalance();
      const excessAmount = contractBalance.add(ethers.utils.parseEther("1.0"));

      await expect(
        distributionRFA.connect(owner).emergency(excessAmount)
      ).to.be.revertedWith("Insufficient contract balance");
    });
  });

  describe("Edge Cases and Security", function () {
    it("Should handle multiple campaigns correctly", async function () {
      // Create first campaign
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("5.0"),
        "Campaign 1"
      );
      
      // Create second campaign
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("3.0"),
        "Campaign 2"
      );

      expect(await distributionRFA.nonce()).to.equal(2);

      // Users should be able to claim from both campaigns
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await distributionRFA.connect(user1).claim(1, claimAmount, proof);
      await distributionRFA.connect(user1).claim(2, claimAmount, proof);

      expect(await distributionRFA.hasClaimed(1, user1.address)).to.be.true;
      expect(await distributionRFA.hasClaimed(2, user1.address)).to.be.true;
    });

    it("Should handle contract receiving ETH", async function () {
      const initialBalance = await distributionRFA.getBalance();
      
      await user1.sendTransaction({
        to: distributionRFA.address,
        value: ethers.utils.parseEther("1.0")
      });

      const finalBalance = await distributionRFA.getBalance();
      expect(finalBalance.sub(initialBalance)).to.equal(ethers.utils.parseEther("1.0"));
    });

    it("Should maintain correct state after reentrancy protection", async function () {
      // Create campaign first
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("5.0"),
        "Test Campaign"
      );
      
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      await distributionRFA.connect(user1).claim(1, claimAmount, proof);
      
      // Verify state is correct
      expect(await distributionRFA.userClaimed(1, user1.address)).to.equal(claimAmount);
      expect(await distributionRFA.hasClaimed(1, user1.address)).to.be.true;
    });
  });

  describe("Gas Optimization Tests", function () {
    beforeEach(async function () {
      await distributionRFA.connect(operator).createNewMonthlyRetroActive(
        merkleRoot,
        ethers.utils.parseEther("5.0"),
        "Test Campaign"
      );
    });

    it("Should use reasonable gas for claim", async function () {
      const claimAmount = airdropData[0].amount;
      const proof = merkleProofs[user1.address];

      const tx = await distributionRFA.connect(user1).claim(1, claimAmount, proof);
      const receipt = await tx.wait();
      
      // Gas should be reasonable (less than 100k for a simple claim)
      expect(receipt.gasUsed).to.be.below(100000);
    });
  });
}); 