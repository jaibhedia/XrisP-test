const { ethers } = require("hardhat");

async function main() {
  console.log("=== WALLET VERIFICATION ===");
  
  // From private key
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.log("❌ No PRIVATE_KEY in .env file");
    return;
  }
  
  const wallet = new ethers.Wallet(privateKey);
  console.log("Address from private key:", wallet.address);
  
  // From signer
  const [deployer] = await ethers.getSigners();
  console.log("Address from signer:", deployer.address);
  
  if (wallet.address.toLowerCase() === deployer.address.toLowerCase()) {
    console.log("✅ Addresses match!");
  } else {
    console.log("❌ Address mismatch!");
  }
}

main().catch(console.error);