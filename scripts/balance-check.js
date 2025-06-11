// Create scripts/check-balance.js
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const balance = await deployer.provider.getBalance(deployer.address);
  
  console.log("=== BALANCE CHECK ===");
  console.log("Account:", deployer.address);
  console.log("Balance:", ethers.formatEther(balance), "BNB");
  console.log("Balance in Wei:", balance.toString());
  
  const minRequired = ethers.parseEther("0.05");
  console.log("Required:", ethers.formatEther(minRequired), "BNB");
  
  if (balance >= minRequired) {
    console.log("✅ Ready for deployment!");
  } else {
    console.log("❌ Insufficient balance");
    console.log("💡 Check:");
    console.log("   1. Faucet transaction status");
    console.log("   2. Correct wallet address");
    console.log("   3. Network (BSC Testnet)");
  }
}

main().catch(console.error);