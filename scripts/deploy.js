const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting XFarm Reward System deployment...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "BNB");
  
  // Deployment addresses for tokenomics
  const teamWallet = process.env.TEAM_WALLET || deployer.address;
  const marketingWallet = process.env.MARKETING_WALLET || deployer.address;
  const liquidityWallet = process.env.LIQUIDITY_WALLET || deployer.address;
  const reserveWallet = process.env.RESERVE_WALLET || deployer.address;
  
  console.log("🏗️  Deploying Harvest Token...");
  
  // Deploy Harvest Token
  const HarvestToken = await ethers.getContractFactory("HarvestToken");
  const harvestToken = await HarvestToken.deploy(
    teamWallet,
    marketingWallet,
    liquidityWallet,
    reserveWallet
  );
  await harvestToken.waitForDeployment();
  
  console.log("✅ Harvest Token deployed to:", await harvestToken.getAddress());
  console.log("   Team Wallet:", teamWallet);
  console.log("   Marketing Wallet:", marketingWallet);
  console.log("   Liquidity Wallet:", liquidityWallet);
  console.log("   Reserve Wallet:", reserveWallet);
  
  // Deploy Crop NFT
  console.log("🌱 Deploying Crop NFT...");
  const CropNFT = await ethers.getContractFactory("CropNFT");
  const cropNFT = await CropNFT.deploy();
  await cropNFT.waitForDeployment();
  
  console.log("✅ Crop NFT deployed to:", await cropNFT.getAddress());
  
  // Deploy Farm Reward System
  console.log("🚜 Deploying Farm Reward System...");
  const FarmRewardSystem = await ethers.getContractFactory("FarmRewardSystem");
  const farmRewardSystem = await FarmRewardSystem.deploy(
    await harvestToken.getAddress(),
    await cropNFT.getAddress()
  );
  await farmRewardSystem.waitForDeployment();
  
  console.log("✅ Farm Reward System deployed to:", await farmRewardSystem.getAddress());
  
  // Setup contract connections
  console.log("🔗 Setting up contract connections...");
  
  // Set Farm Reward System as reward pool in Harvest Token
  await harvestToken.setRewardPool(await farmRewardSystem.getAddress());
  console.log("   ✓ Set Farm Reward System as reward pool");
  
  // Add Farm Reward System as authorized minter
  await harvestToken.addAuthorizedMinter(await farmRewardSystem.getAddress());
  console.log("   ✓ Added Farm Reward System as authorized minter");
  
  // Add Farm Reward System as authorized farm in Crop NFT
  await cropNFT.addAuthorizedFarm(await farmRewardSystem.getAddress());
  console.log("   ✓ Added Farm Reward System as authorized farm");
  
  // Set Farm Reward System address in Crop NFT
  await cropNFT.setFarmRewardSystem(await farmRewardSystem.getAddress());
  console.log("   ✓ Set Farm Reward System address in Crop NFT");
  
  // Verify initial token distribution
  console.log("📊 Verifying token distribution...");
  const totalSupply = await harvestToken.totalSupply();
  const teamBalance = await harvestToken.balanceOf(teamWallet);
  const marketingBalance = await harvestToken.balanceOf(marketingWallet);
  const liquidityBalance = await harvestToken.balanceOf(liquidityWallet);
  const reserveBalance = await harvestToken.balanceOf(reserveWallet);
  const rewardPoolBalance = await harvestToken.balanceOf(await farmRewardSystem.getAddress());
  
  console.log("   Total Supply:", ethers.formatEther(totalSupply), "HARVEST");
  console.log("   Team Balance:", ethers.formatEther(teamBalance), "HARVEST");
  console.log("   Marketing Balance:", ethers.formatEther(marketingBalance), "HARVEST");
  console.log("   Liquidity Balance:", ethers.formatEther(liquidityBalance), "HARVEST");
  console.log("   Reserve Balance:", ethers.formatEther(reserveBalance), "HARVEST");
  console.log("   Reward Pool Balance:", ethers.formatEther(rewardPoolBalance), "HARVEST");
  
  // Display deployment summary
  console.log("\n🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
  console.log("====================================");
  console.log("Contract Addresses:");
  console.log("• Harvest Token:", await harvestToken.getAddress());
  console.log("• Crop NFT:", await cropNFT.getAddress());
  console.log("• Farm Reward System:", await farmRewardSystem.getAddress());
  console.log("====================================");
  // Replace lines around 119 in deploy.js with this:
const deploymentInfo = {
  network: hre.network.name,
  chainId: Number((await ethers.provider.getNetwork()).chainId), // Convert BigInt to Number
  deployer: deployer.address,
  timestamp: new Date().toISOString(),
  contracts: {
    HarvestToken: await harvestToken.getAddress(),
    CropNFT: await cropNFT.getAddress(),
    FarmRewardSystem: await farmRewardSystem.getAddress()
  },
  wallets: {
    team: teamWallet,
    marketing: marketingWallet,
    liquidity: liquidityWallet,
    reserve: reserveWallet
  }
};

console.log("\n📝 Deployment info saved:");
console.log(JSON.stringify(deploymentInfo, null, 2));
  
  // Verification instructions
  if (hre.network.name !== "hardhat") {
    console.log("\n🔍 To verify contracts on BSCScan, run:");
    console.log(`npx hardhat verify --network ${hre.network.name} ${await harvestToken.getAddress()} "${teamWallet}" "${marketingWallet}" "${liquidityWallet}" "${reserveWallet}"`);
    console.log(`npx hardhat verify --network ${hre.network.name} ${await cropNFT.getAddress()}`);
    console.log(`npx hardhat verify --network ${hre.network.name} ${await farmRewardSystem.getAddress()} "${await harvestToken.getAddress()}" "${await cropNFT.getAddress()}"`);
  }
  
  return deploymentInfo;
}

// Handle errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });