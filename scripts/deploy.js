const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting XFarm Reward System deployment...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "BNB");
  
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
  await harvestToken.deployed();
  
  console.log("✅ Harvest Token deployed to:", harvestToken.address);
  console.log("   Team Wallet:", teamWallet);
  console.log("   Marketing Wallet:", marketingWallet);
  console.log("   Liquidity Wallet:", liquidityWallet);
  console.log("   Reserve Wallet:", reserveWallet);
  
  // Deploy Crop NFT
  console.log("🌱 Deploying Crop NFT...");
  const CropNFT = await ethers.getContractFactory("CropNFT");
  const cropNFT = await CropNFT.deploy();
  await cropNFT.deployed();
  
  console.log("✅ Crop NFT deployed to:", cropNFT.address);
  
  // Deploy Farm Reward System
  console.log("🚜 Deploying Farm Reward System...");
  const FarmRewardSystem = await ethers.getContractFactory("FarmRewardSystem");
  const farmRewardSystem = await FarmRewardSystem.deploy(
    harvestToken.address,
    cropNFT.address
  );
  await farmRewardSystem.deployed();
  
  console.log("✅ Farm Reward System deployed to:", farmRewardSystem.address);
  
  // Setup contract connections
  console.log("🔗 Setting up contract connections...");
  
  // Set Farm Reward System as reward pool in Harvest Token
  await harvestToken.setRewardPool(farmRewardSystem.address);
  console.log("   ✓ Set Farm Reward System as reward pool");
  
  // Add Farm Reward System as authorized minter
  await harvestToken.addAuthorizedMinter(farmRewardSystem.address);
  console.log("   ✓ Added Farm Reward System as authorized minter");
  
  // Add Farm Reward System as authorized farm in Crop NFT
  await cropNFT.addAuthorizedFarm(farmRewardSystem.address);
  console.log("   ✓ Added Farm Reward System as authorized farm");
  
  // Verify initial token distribution
  console.log("📊 Verifying token distribution...");
  const totalSupply = await harvestToken.totalSupply();
  const teamBalance = await harvestToken.balanceOf(teamWallet);
  const marketingBalance = await harvestToken.balanceOf(marketingWallet);
  const liquidityBalance = await harvestToken.balanceOf(liquidityWallet);
  const reserveBalance = await harvestToken.balanceOf(reserveWallet);
  const rewardPoolBalance = await harvestToken.balanceOf(farmRewardSystem.address);
  
  console.log("   Total Supply:", ethers.utils.formatEther(totalSupply), "HARVEST");
  console.log("   Team Balance:", ethers.utils.formatEther(teamBalance), "HARVEST");
  console.log("   Marketing Balance:", ethers.utils.formatEther(marketingBalance), "HARVEST");
  console.log("   Liquidity Balance:", ethers.utils.formatEther(liquidityBalance), "HARVEST");
  console.log("   Reserve Balance:", ethers.utils.formatEther(reserveBalance), "HARVEST");
  console.log("   Reward Pool Balance:", ethers.utils.formatEther(rewardPoolBalance), "HARVEST");
  
  // Display deployment summary
  console.log("\\n🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
  console.log("====================================");
  console.log("Contract Addresses:");
  console.log("• Harvest Token:", harvestToken.address);
  console.log("• Crop NFT:", cropNFT.address);
  console.log("• Farm Reward System:", farmRewardSystem.address);
  console.log("====================================");
  
  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      HarvestToken: harvestToken.address,
      CropNFT: cropNFT.address,
      FarmRewardSystem: farmRewardSystem.address
    },
    wallets: {
      team: teamWallet,
      marketing: marketingWallet,
      liquidity: liquidityWallet,
      reserve: reserveWallet
    }
  };
  
  console.log("\\n📝 Deployment info saved:");
  console.log(JSON.stringify(deploymentInfo, null, 2));
  
  // Verification instructions
  if (hre.network.name !== "hardhat") {
    console.log("\\n🔍 To verify contracts on BSCScan, run:");
    console.log(`npx hardhat verify --network ${hre.network.name} ${harvestToken.address} "${teamWallet}" "${marketingWallet}" "${liquidityWallet}" "${reserveWallet}"`);
    console.log(`npx hardhat verify --network ${hre.network.name} ${cropNFT.address}`);
    console.log(`npx hardhat verify --network ${hre.network.name} ${farmRewardSystem.address} "${harvestToken.address}" "${cropNFT.address}"`);
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
