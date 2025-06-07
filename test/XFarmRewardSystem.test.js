const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("XFarm Reward System", function () {
  let harvestToken, cropNFT, farmRewardSystem;
  let owner, farmer1, farmer2, teamWallet, marketingWallet, liquidityWallet, reserveWallet;
  
  const INITIAL_SUPPLY = ethers.parseEther("100000000"); // 100M tokens
  const SECONDS_IN_DAY = 86400;
  
  beforeEach(async function () {
    [owner, farmer1, farmer2, teamWallet, marketingWallet, liquidityWallet, reserveWallet] = await ethers.getSigners();
      // Deploy Harvest Token
    const HarvestToken = await ethers.getContractFactory("HarvestToken");
    harvestToken = await HarvestToken.deploy(
      teamWallet.address,
      marketingWallet.address,
      liquidityWallet.address,
      reserveWallet.address
    );
    
    // Deploy Crop NFT
    const CropNFT = await ethers.getContractFactory("CropNFT");
    cropNFT = await CropNFT.deploy();
    
    // Deploy Farm Reward System
    const FarmRewardSystem = await ethers.getContractFactory("FarmRewardSystem");
    farmRewardSystem = await FarmRewardSystem.deploy(
      await harvestToken.getAddress(),
      await cropNFT.getAddress()
    );
      // Setup connections
    await harvestToken.setRewardPool(await farmRewardSystem.getAddress());
    await harvestToken.addAuthorizedMinter(await farmRewardSystem.getAddress());
    await cropNFT.addAuthorizedFarm(await farmRewardSystem.getAddress());
    await cropNFT.setFarmRewardSystem(await farmRewardSystem.getAddress());
  });
  
  describe("Harvest Token", function () {
    it("Should deploy with correct initial supply and distribution", async function () {
      const totalSupply = await harvestToken.totalSupply();
      expect(totalSupply).to.equal(INITIAL_SUPPLY);
        // Check allocations
      const teamBalance = await harvestToken.balanceOf(teamWallet.address);
      const expectedTeamBalance = INITIAL_SUPPLY * 15n / 100n; // 15%
      expect(teamBalance).to.equal(expectedTeamBalance);
      
      const marketingBalance = await harvestToken.balanceOf(marketingWallet.address);
      const expectedMarketingBalance = INITIAL_SUPPLY * 10n / 100n; // 10%
      expect(marketingBalance).to.equal(expectedMarketingBalance);
    });
      it("Should allow authorized minters to mint rewards", async function () {
      const mintAmount = ethers.parseEther("1000");
      const initialBalance = await harvestToken.balanceOf(farmer1.address);
      
      // Add owner as authorized minter and mint tokens
      await harvestToken.addAuthorizedMinter(owner.address);
      await harvestToken.mintRewards(farmer1.address, mintAmount);
      
      const finalBalance = await harvestToken.balanceOf(farmer1.address);
      expect(finalBalance).to.equal(initialBalance + mintAmount);
    });      it("Should enforce max supply limit", async function () {
      const maxSupply = await harvestToken.MAX_SUPPLY();
      const currentSupply = await harvestToken.totalSupply();
      const excessAmount = maxSupply - currentSupply + 1n;
      
      // Add owner as authorized minter to test the limit
      await harvestToken.addAuthorizedMinter(owner.address);
      
      await expect(
        harvestToken.mintRewards(farmer1.address, excessAmount)
      ).to.be.revertedWith("Minting would exceed max supply");
    });
    
    it("Should enforce transfer limits for non-excluded addresses", async function () {
      const maxTransferAmount = await harvestToken.maxTransferAmount();
      const excessAmount = maxTransferAmount + 1n;
      
      // Transfer some tokens to farmer1 first
      await harvestToken.connect(teamWallet).transfer(farmer1.address, maxTransferAmount);
      
      // Try to transfer more than allowed
      await expect(
        harvestToken.connect(farmer1).transfer(farmer2.address, excessAmount)
      ).to.be.revertedWith("Transfer amount exceeds maximum allowed");
    });
  });
  
  describe("Crop NFT", function () {
    it("Should plant crops with correct properties", async function () {
      const cropType = 0; // TOMATO
      const bonusMultiplier = 125; // 1.25x
      
      await cropNFT.addAuthorizedFarm(owner.address);
      const tx = await cropNFT.plantCrop(farmer1.address, cropType, bonusMultiplier);
      const receipt = await tx.wait();
      
      const tokenId = 0; // First token
      const cropInfo = await cropNFT.getCropInfo(tokenId);
      
      expect(cropInfo.cropType).to.equal(cropType);
      expect(cropInfo.bonusMultiplier).to.equal(bonusMultiplier);
      expect(cropInfo.isHarvested).to.be.false;
    });
    
    it("Should allow watering crops to speed up growth", async function () {
      const cropType = 0; // TOMATO
      await cropNFT.addAuthorizedFarm(owner.address);
      await cropNFT.plantCrop(farmer1.address, cropType, 100);
      
      const tokenId = 0;
      const initialCropInfo = await cropNFT.getCropInfo(tokenId);
      
      // Fast forward 1 hour and water
      await time.increase(3600);
      await cropNFT.connect(farmer1).waterCrop(tokenId);
      
      const updatedCropInfo = await cropNFT.getCropInfo(tokenId);
      expect(updatedCropInfo.harvestableAt).to.be.lt(initialCropInfo.harvestableAt);
    });
    
    it("Should update growth stages correctly", async function () {
      const cropType = 0; // TOMATO (7 days growth)
      await cropNFT.addAuthorizedFarm(owner.address);
      await cropNFT.plantCrop(farmer1.address, cropType, 100);
      
      const tokenId = 0;
      
      // Check initial stage
      let cropInfo = await cropNFT.getCropInfo(tokenId);
      expect(cropInfo.growthStage).to.equal(0); // SEED
      
      // Fast forward 25% of growth time
      await time.increase(7 * SECONDS_IN_DAY * 0.25);
      await cropNFT.updateGrowthStage(tokenId);
      
      cropInfo = await cropNFT.getCropInfo(tokenId);
      expect(cropInfo.growthStage).to.equal(1); // SPROUTING
      
      // Fast forward to full growth
      await time.increase(7 * SECONDS_IN_DAY * 0.75);
      await cropNFT.updateGrowthStage(tokenId);
      
      cropInfo = await cropNFT.getCropInfo(tokenId);
      expect(cropInfo.growthStage).to.equal(4); // HARVESTABLE
    });
    
    it("Should allow harvesting only when crop is ready", async function () {
      const cropType = 0; // TOMATO
      await cropNFT.addAuthorizedFarm(owner.address);
      await cropNFT.plantCrop(farmer1.address, cropType, 100);
      
      const tokenId = 0;
      
      // Try to harvest before ready
      await expect(
        cropNFT.connect(farmer1).harvestCrop(tokenId)
      ).to.be.revertedWith("Crop not ready for harvest");
        // Fast forward to harvest time
      await time.increase(7 * SECONDS_IN_DAY + 1);
      await cropNFT.updateGrowthStage(tokenId);      // Should be able to harvest now
      await cropNFT.connect(farmer1).harvestCrop(tokenId);
      
      // NFT should be burned after harvest
      await expect(cropNFT.ownerOf(tokenId)).to.be.revertedWithCustomError(cropNFT, "ERC721NonexistentToken");
    });
  });
  
  describe("Farm Reward System", function () {    beforeEach(async function () {
      // Register farmers
      await farmRewardSystem.connect(farmer1).registerFarmer(ethers.ZeroAddress);
      await farmRewardSystem.connect(farmer2).registerFarmer(farmer1.address); // farmer2 refers farmer1
    });
    
    it("Should register farmers correctly", async function () {
      const farmer1Info = await farmRewardSystem.farmers(farmer1.address);
      expect(farmer1Info.lastCheckIn).to.be.gt(0);
      expect(farmer1Info.referrer).to.equal(ethers.ZeroAddress);
      
      const farmer2Info = await farmRewardSystem.farmers(farmer2.address);
      expect(farmer2Info.referrer).to.equal(farmer1.address);
      
      const totalRegistered = await farmRewardSystem.totalFarmersRegistered();
      expect(totalRegistered).to.equal(2);
    });    it("Should allow daily check-ins with streak bonuses", async function () {
      const initialBalance = await harvestToken.balanceOf(farmer1.address);
      
      // First check-in
      await farmRewardSystem.connect(farmer1).dailyCheckIn();
      
      let balance = await harvestToken.balanceOf(farmer1.address);
      expect(balance).to.be.gt(initialBalance);
        // Wait 20+ hours and check-in again (cooldown is 20 hours)
      await time.increase(20 * 3600 + 1); // 20 hours + 1 second
      await farmRewardSystem.connect(farmer1).dailyCheckIn();
      
      const finalBalance = await harvestToken.balanceOf(farmer1.address);
      expect(finalBalance).to.be.gt(balance); // Should have streak bonus
    });
      it("Should handle staking and reward distribution", async function () {      // Give farmer1 some tokens to stake
      const stakeAmount = ethers.parseEther("1000");
      await harvestToken.connect(teamWallet).transfer(farmer1.address, stakeAmount);
      await harvestToken.connect(farmer1).approve(await farmRewardSystem.getAddress(), stakeAmount);
      
      // Stake tokens
      await farmRewardSystem.connect(farmer1).stakeTokens(0, stakeAmount);
      
      const stakeInfo = await farmRewardSystem.stakes(farmer1.address);
      expect(stakeInfo.amount).to.equal(stakeAmount);
      
      // Fast forward time to accumulate rewards
      await time.increase(24 * 3600); // 1 day
      
      const earnedRewards = await farmRewardSystem.earned(farmer1.address, 0);
      expect(earnedRewards).to.be.gt(0);
      
      // Claim rewards
      const initialBalance = await harvestToken.balanceOf(farmer1.address);
      await farmRewardSystem.connect(farmer1).claimRewards(0);
      
      const finalBalance = await harvestToken.balanceOf(farmer1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });
      it("Should handle referral bonuses", async function () {      // Give farmer2 some tokens to stake
      const stakeAmount = ethers.parseEther("1000");
      await harvestToken.connect(teamWallet).transfer(farmer2.address, stakeAmount);
      await harvestToken.connect(farmer2).approve(await farmRewardSystem.getAddress(), stakeAmount);
      
      // Stake and fast forward
      await farmRewardSystem.connect(farmer2).stakeTokens(0, stakeAmount);
      await time.increase(24 * 3600);
      
      // Check farmer1's balance before farmer2 claims (referrer)
      const farmer1InitialBalance = await harvestToken.balanceOf(farmer1.address);
      
      // Farmer2 claims rewards (should trigger referral bonus for farmer1)
      await farmRewardSystem.connect(farmer2).claimRewards(0);
      
      const farmer1FinalBalance = await harvestToken.balanceOf(farmer1.address);
      expect(farmer1FinalBalance).to.be.gt(farmer1InitialBalance); // Referral bonus received
    });    it("Should handle crop planting and harvesting through farm system", async function () {
      // Plant a crop
      await farmRewardSystem.connect(farmer1).plantCrop(0); // TOMATO
      
      const farmerCrops = await farmRewardSystem.getFarmerCrops(farmer1.address);
      expect(farmerCrops.length).to.equal(1);
      
      const tokenId = farmerCrops[0];
        // Fast forward to harvest time
      await time.increase(7 * SECONDS_IN_DAY + 1);
      await cropNFT.updateGrowthStage(tokenId);
        // Harvest crop through FarmRewardSystem
      const initialBalance = await harvestToken.balanceOf(farmer1.address);
      await farmRewardSystem.connect(farmer1).harvestCrop(tokenId);
      
      // Check that rewards were distributed
      const finalBalance = await harvestToken.balanceOf(farmer1.address);
      expect(finalBalance).to.be.gt(initialBalance);
      
      // Crop should be removed from farmer's list
      const updatedCrops = await farmRewardSystem.getFarmerCrops(farmer1.address);
      expect(updatedCrops.length).to.equal(0);
    });      it("Should provide staking bonuses for crop rewards", async function () {
      // Give farmer1 a large stake to get bonus multiplier
      const largeStake = ethers.parseEther("10000");
      await harvestToken.connect(teamWallet).transfer(farmer1.address, largeStake);
      await harvestToken.connect(farmer1).approve(await farmRewardSystem.getAddress(), largeStake);
      await farmRewardSystem.connect(farmer1).stakeTokens(0, largeStake);
      
      // Plant crop (should get bonus multiplier due to large stake)
      await farmRewardSystem.connect(farmer1).plantCrop(0);
      
      const farmerCrops = await farmRewardSystem.getFarmerCrops(farmer1.address);
      const tokenId = farmerCrops[0];
      
      const cropInfo = await cropNFT.getCropInfo(tokenId);
      expect(cropInfo.bonusMultiplier).to.be.gt(100); // Should have bonus
    });
  });
    describe("Integration Tests", function () {
    it("Should handle complete farming lifecycle", async function () {
      // Setup: Register farmer and give initial tokens
      await farmRewardSystem.connect(farmer1).registerFarmer(ethers.ZeroAddress);
      
      // Verify farmer is registered
      const farmerInfo = await farmRewardSystem.farmers(farmer1.address);
      expect(farmerInfo.lastCheckIn).to.not.equal(0);
      
      const initialTokens = ethers.parseEther("5000");
      await harvestToken.connect(teamWallet).transfer(farmer1.address, initialTokens);
      
      // 1. Daily check-in
      await farmRewardSystem.connect(farmer1).dailyCheckIn();
        // 2. Stake tokens
      const stakeAmount = ethers.parseEther("1000");
      await harvestToken.connect(farmer1).approve(await farmRewardSystem.getAddress(), stakeAmount);
      await farmRewardSystem.connect(farmer1).stakeTokens(0, stakeAmount);
      
      // 3. Plant crops
      await farmRewardSystem.connect(farmer1).plantCrop(0); // TOMATO
      await farmRewardSystem.connect(farmer1).plantCrop(1); // CORN
      
      // 4. Fast forward and do daily activities
      await time.increase(SECONDS_IN_DAY);
      await farmRewardSystem.connect(farmer1).dailyCheckIn();
      
      // Water crops
      const crops = await farmRewardSystem.getFarmerCrops(farmer1.address);
      await farmRewardSystem.connect(farmer1).waterCrop(crops[0]);
      await farmRewardSystem.connect(farmer1).waterCrop(crops[1]);
      
      // 5. Fast forward to harvest tomato (7 days)
      await time.increase(6 * SECONDS_IN_DAY);
      await cropNFT.updateGrowthStage(crops[0]);
      
      const initialBalance = await harvestToken.balanceOf(farmer1.address);
      
      // 6. Harvest tomato
      await farmRewardSystem.connect(farmer1).harvestCrop(crops[0]);
      
      // 7. Claim staking rewards
      await farmRewardSystem.connect(farmer1).claimRewards(0);
      
      const finalBalance = await harvestToken.balanceOf(farmer1.address);
      expect(finalBalance).to.be.gt(initialBalance);
      
      // Verify remaining crop (corn) is still growing
      const remainingCrops = await farmRewardSystem.getFarmerCrops(farmer1.address);
      expect(remainingCrops.length).to.equal(1);
      expect(remainingCrops[0]).to.equal(crops[1]);
    });
  });
});
