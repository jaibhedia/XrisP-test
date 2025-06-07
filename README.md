# XFarm Reward System 🌾

A comprehensive NFT-based farming reward system built on Binance Smart Chain (BSC) using Solidity. This project implements a gamified farming ecosystem where users can stake tokens, plant virtual crops, and earn rewards through various activities.

## Project Overview

This project implements a complete blockchain-based farming reward system inspired by "Nori Farm" concepts, featuring:

- **Custom Fungible Token (HARVEST)**: ERC20 token with advanced tokenomics
- **NFT Crop System**: ERC721 tokens representing virtual crops with growth mechanics
- **Staking & Farming**: Time-based reward distribution system
- **Gamification**: Daily check-ins, referral bonuses, and streak rewards
- **Anti-whale Protection**: Transfer limits and fair distribution mechanisms

## Architecture

### Smart Contracts

1. **HarvestToken.sol** - Custom ERC20 token with:
   - 1 billion max supply with initial 100M distribution
   - Tokenomics: 40% rewards, 25% liquidity, 15% team, 10% marketing, 10% reserves
   - Anti-whale protection with transfer limits
   - Authorized minting for reward contracts
   - Burnable mechanism for deflationary pressure

2. **CropNFT.sol** - ERC721 NFT representing crops with:
   - 4 crop types: Tomato (7 days), Corn (14 days), Wheat (21 days), Special Fruit (30 days)
   - Growth stages: Seed → Sprouting → Growing → Mature → Harvestable
   - Watering mechanism to speed up growth
   - Bonus multipliers based on staking levels
   - On-chain metadata generation

3. **FarmRewardSystem.sol** - Main contract managing:
   - Farmer registration and referral system
   - Token staking with multiple pools
   - Daily check-in rewards with streak bonuses
   - Crop planting and harvesting
   - Reward distribution and calculation

## Tokenomics

### HARVEST Token Distribution
- **Total Supply**: 1,000,000,000 HARVEST
- **Initial Supply**: 100,000,000 HARVEST

| Allocation | Percentage | Amount | Purpose |
|------------|------------|---------|---------|
| Reward Pool | 40% | 40M HARVEST | Farming and staking rewards |
| Liquidity | 25% | 25M HARVEST | DEX liquidity provision |
| Team | 15% | 15M HARVEST | Team allocation (vested) |
| Marketing | 10% | 10M HARVEST | Marketing and partnerships |
| Reserve | 10% | 10M HARVEST | Emergency reserves |

### Reward Mechanisms

1. **Daily Check-in Rewards**
   - Base: 1 HARVEST per day
   - Streak bonus: +5% per consecutive day (max 30 days)
   - Maximum daily reward: 2.5 HARVEST (with 30-day streak)

2. **Staking Rewards**
   - Variable APY based on pool configuration
   - Default: 100 tokens per second per staked token
   - Compounds automatically

3. **Crop Harvesting**
   - Tomato: 10 HARVEST base reward
   - Corn: 25 HARVEST base reward
   - Wheat: 50 HARVEST base reward
   - Special Fruit: 100 HARVEST base reward
   - Bonus multipliers: 1.25x for 1K+ stake, 1.5x for 10K+ stake

4. **Referral System**
   - 10% bonus on all referee's rewards
   - Unlimited referrals per user
   - Instant payout on reward claims

## Getting Started

### Prerequisites

- Node.js v16+ and npm
- Git
- MetaMask or compatible Web3 wallet
- BNB for gas fees (testnet or mainnet)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/jaibhedia/XrisP-test.git
cd XrisP-test
```

2. **Install dependencies** 
```bash
npm install
```

3. **Environment setup**
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values
PRIVATE_KEY=your_wallet_private_key
BSC_TESTNET_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
BSCSCAN_API_KEY=your_bscscan_api_key
```

### 🧪 Testing

Run the comprehensive test suite:

```bash
# Compile contracts
npm run compile

# Run tests
npm test

# Run tests with gas reporting
npx hardhat test --gas-reporter
```

### 📦 Deployment

#### Testnet Deployment (BSC Testnet)

1. **Get testnet BNB**
   - Visit [BSC Testnet Faucet](https://testnet.binance.org/faucet-smart)
   - Add BSC Testnet to MetaMask (ChainID: 97)

2. **Deploy contracts**
```bash
npm run deploy:testnet
```

3. **Verify contracts on BSCScan**
```bash
# Verification commands will be provided after deployment
npx hardhat verify --network bscTestnet <contract_address> <constructor_args>
```

#### Mainnet Deployment

⚠️ **WARNING**: Mainnet deployment requires real BNB and is irreversible!

```bash
npm run deploy:mainnet
```

## 🎮 Usage Guide

### For Farmers (Users)

1. **Register as a Farmer**
```solidity
farmRewardSystem.registerFarmer(referrerAddress); // Use zero address if no referrer
```

2. **Daily Check-in**
```solidity
farmRewardSystem.dailyCheckIn(); // Earn daily rewards and build streak
```

3. **Stake Tokens**
```solidity
harvestToken.approve(farmRewardSystemAddress, stakeAmount);
farmRewardSystem.stakeTokens(poolId, stakeAmount);
```

4. **Plant Crops**
```solidity
farmRewardSystem.plantCrop(cropType); // 0=Tomato, 1=Corn, 2=Wheat, 3=Special
```

5. **Water Crops** (optional, speeds growth)
```solidity
farmRewardSystem.waterCrop(tokenId);
```

6. **Harvest Crops**
```solidity
farmRewardSystem.harvestCrop(tokenId); // When crop is ready
```

7. **Claim Staking Rewards**
```solidity
farmRewardSystem.claimRewards(poolId);
```

### For Contract Interaction

#### Web3.js Example
```javascript
const Web3 = require('web3');
const web3 = new Web3('https://bsc-dataseed.binance.org/');

// Contract instances
const farmContract = new web3.eth.Contract(farmABI, farmAddress);
const tokenContract = new web3.eth.Contract(tokenABI, tokenAddress);

// Register farmer
await farmContract.methods.registerFarmer('0x0').send({from: userAddress});

// Daily check-in
await farmContract.methods.dailyCheckIn().send({from: userAddress});

// Plant a tomato
await farmContract.methods.plantCrop(0).send({from: userAddress});
```

#### Ethers.js Example
```javascript
const { ethers } = require('ethers');

const provider = new ethers.providers.JsonRpcProvider('https://bsc-dataseed.binance.org/');
const signer = new ethers.Wallet(privateKey, provider);

const farmContract = new ethers.Contract(farmAddress, farmABI, signer);

// Get farmer statistics
const stats = await farmContract.getFarmerStats(userAddress);
console.log('Total Staked:', ethers.utils.formatEther(stats.totalStaked));
console.log('Check-in Streak:', stats.checkInStreak.toString());
```

## 🔧 Configuration

### Farming Pools
The system supports multiple farming pools with different configurations:

```solidity
struct FarmPool {
    uint256 rewardRate;       // Tokens per second per staked token
    uint256 totalStaked;      // Total tokens staked in pool
    uint256 minimumStake;     // Minimum stake required
    bool isActive;            // Whether pool accepts new stakes
}
```

### Crop Types
Each crop type has different characteristics:

| Crop | Growth Time | Base Reward | Rarity |
|------|-------------|-------------|---------|
| Tomato | 7 days | 10 HARVEST | Common |
| Corn | 14 days | 25 HARVEST | Uncommon |
| Wheat | 21 days | 50 HARVEST | Rare |
| Special Fruit | 30 days | 100 HARVEST | Legendary |

## Security Features

### Smart Contract Security
- **ReentrancyGuard**: Prevents reentrancy attacks
- **Pausable**: Emergency pause functionality
- **Access Control**: Owner-only administrative functions
- **Input Validation**: Comprehensive parameter checking
- **Safe Math**: Overflow protection using OpenZeppelin libraries

### Anti-Whale Mechanisms
- **Transfer Limits**: Maximum transfer amounts for regular users
- **Gradual Distribution**: Vested team tokens
- **Pool Limits**: Minimum stake requirements
- **Excluded Addresses**: System addresses bypass limits

## API Reference

### HarvestToken Functions

#### Read Functions
```solidity
function totalSupply() external view returns (uint256)
function balanceOf(address account) external view returns (uint256)
function getAllocationPercentages() external pure returns (uint256, uint256, uint256, uint256, uint256)
```

#### Write Functions
```solidity
function transfer(address to, uint256 amount) external returns (bool)
function approve(address spender, uint256 amount) external returns (bool)
function mintRewards(address to, uint256 amount) external // Authorized minters only
```

### CropNFT Functions

#### Read Functions
```solidity
function getCropInfo(uint256 tokenId) external view returns (CropType, GrowthStage, uint256, uint256, bool, uint256, uint256)
function isHarvestable(uint256 tokenId) external view returns (bool)
function ownerOf(uint256 tokenId) external view returns (address)
```

#### Write Functions
```solidity
function plantCrop(address farmer, CropType cropType, uint256 bonusMultiplier) external returns (uint256)
function waterCrop(uint256 tokenId) external
function harvestCrop(uint256 tokenId) external returns (uint256)
```

### FarmRewardSystem Functions

#### Read Functions
```solidity
function getFarmerStats(address farmer) external view returns (uint256, uint256, uint256, uint256, uint256)
function getFarmerCrops(address farmer) external view returns (uint256[] memory)
function earned(address account, uint256 poolId) external view returns (uint256)
function getPoolInfo(uint256 poolId) external view returns (uint256, uint256, uint256, bool)
```

#### Write Functions
```solidity
function registerFarmer(address referrer) external
function dailyCheckIn() external
function stakeTokens(uint256 poolId, uint256 amount) external
function unstakeTokens(uint256 poolId, uint256 amount) external
function claimRewards(uint256 poolId) external
function plantCrop(CropType cropType) external
function harvestCrop(uint256 tokenId) external
function waterCrop(uint256 tokenId) external
```
## 🏆 Achievements

This project demonstrates:
- ✅ Advanced Solidity development
- ✅ Complex tokenomics implementation
- ✅ NFT integration with utility
- ✅ Comprehensive testing suite
- ✅ Production-ready deployment scripts
- ✅ Security best practices
- ✅ Clear documentation

---

**Developed for XrisP Competency Assessment - Blockchain Developer Position**

*Building the future of decentralized farming, one crop at a time.* 🌱
