// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./HarvestToken.sol";
import "./CropNFT.sol";

/**
 * @title FarmRewardSystem
 * @dev Main contract managing the farming reward system
 * Features:
 * - Staking mechanism for earning rewards
 * - Time-based farming rewards
 * - NFT crop planting and harvesting
 * - Referral system for additional rewards
 * - Daily check-in bonuses
 */
contract FarmRewardSystem is ReentrancyGuard, Ownable, Pausable {
    
    HarvestToken public harvestToken;
    CropNFT public cropNFT;
    
    // Staking data
    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 lastClaimAt;
        uint256 rewardsEarned;
    }
    
    // User farming data
    struct FarmerInfo {
        uint256 totalStaked;
        uint256 totalRewardsEarned;
        uint256 lastCheckIn;
        uint256 checkInStreak;
        address referrer;
        uint256 referralRewards;
        uint256[] ownedCrops;
    }
    
    // Farming pool configuration
    struct FarmPool {
        uint256 rewardRate; // Tokens per second per staked token
        uint256 totalStaked;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 minimumStake;
        bool isActive;
    }
    
    // Mappings
    mapping(address => FarmerInfo) public farmers;
    mapping(address => StakeInfo) public stakes;
    mapping(address => mapping(uint256 => uint256)) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public hasReferred;
    
    // Farm pools
    mapping(uint256 => FarmPool) public farmPools;
    uint256 public totalPools;
    
    // Constants and variables
    uint256 public constant DAILY_CHECK_IN_REWARD = 1 * 10**18; // 1 HARVEST token
    uint256 public constant MAX_CHECK_IN_STREAK = 30; // Maximum streak for bonus
    uint256 public constant REFERRAL_BONUS = 10; // 10% referral bonus
    uint256 public constant STREAK_MULTIPLIER = 5; // 5% bonus per streak day
    
    uint256 public totalRewardsDistributed;
    uint256 public totalFarmersRegistered;
    
    // Events
    event FarmerRegistered(address indexed farmer, address indexed referrer);
    event TokensStaked(address indexed farmer, uint256 poolId, uint256 amount);
    event TokensUnstaked(address indexed farmer, uint256 poolId, uint256 amount);
    event RewardsClaimed(address indexed farmer, uint256 amount);
    event CheckInCompleted(address indexed farmer, uint256 streak, uint256 reward);
    event CropPlanted(address indexed farmer, uint256 tokenId, CropNFT.CropType cropType);
    event CropHarvested(address indexed farmer, uint256 tokenId, uint256 reward);
    event ReferralRewardPaid(address indexed referrer, address indexed referee, uint256 amount);
    event PoolCreated(uint256 indexed poolId, uint256 rewardRate, uint256 minimumStake);
    event PoolUpdated(uint256 indexed poolId, uint256 newRewardRate, bool isActive);
    
    constructor(address _harvestToken, address _cropNFT) Ownable(msg.sender) {
        require(_harvestToken != address(0), "Harvest token cannot be zero address");
        require(_cropNFT != address(0), "Crop NFT cannot be zero address");
        
        harvestToken = HarvestToken(_harvestToken);
        cropNFT = CropNFT(_cropNFT);
        
        // Create initial farming pool
        _createPool(100, 1000 * 10**18); // 100 tokens per second per staked token, 1000 minimum stake
    }
      /**
     * @dev Registers a new farmer with optional referrer
     * @param _referrer Address of the referrer (optional)
     */
    function registerFarmer(address _referrer) external {
        require(farmers[msg.sender].lastCheckIn == 0, "Farmer already registered");
        
        if (_referrer != address(0) && _referrer != msg.sender && farmers[_referrer].lastCheckIn != 0) {
            farmers[msg.sender].referrer = _referrer;
        }
        
        // Set lastCheckIn to allow immediate first check-in
        farmers[msg.sender].lastCheckIn = 1; // Non-zero to indicate registration, but allows immediate check-in
        totalFarmersRegistered = totalFarmersRegistered + 1;
        
        emit FarmerRegistered(msg.sender, _referrer);
    }
      /**
     * @dev Performs daily check-in to earn bonus rewards
     */
    function dailyCheckIn() external nonReentrant {
        require(farmers[msg.sender].lastCheckIn != 0, "Farmer not registered");
        
        // Allow first check-in immediately after registration (lastCheckIn == 1)
        if (farmers[msg.sender].lastCheckIn != 1) {
            require(block.timestamp >= farmers[msg.sender].lastCheckIn + 20 hours, "Check-in too early");
        }
        
        FarmerInfo storage farmer = farmers[msg.sender];        // Update streak
        if (farmer.lastCheckIn == 1) {
            // First check-in after registration
            farmer.checkInStreak = 1;
        } else if (block.timestamp <= farmer.lastCheckIn + 28 hours) {
            farmer.checkInStreak = farmer.checkInStreak + 1;
            if (farmer.checkInStreak > MAX_CHECK_IN_STREAK) {
                farmer.checkInStreak = MAX_CHECK_IN_STREAK;
            }
        } else {
            farmer.checkInStreak = 1; // Reset streak
        }
        
        farmer.lastCheckIn = block.timestamp;
        
        // Calculate reward with streak bonus
        uint256 baseReward = DAILY_CHECK_IN_REWARD;
        uint256 streakBonus = baseReward * farmer.checkInStreak * STREAK_MULTIPLIER / 100;
        uint256 totalReward = baseReward + streakBonus;
        
        // Mint and distribute reward
        harvestToken.mintRewards(msg.sender, totalReward);
        farmer.totalRewardsEarned = farmer.totalRewardsEarned + totalReward;
        totalRewardsDistributed = totalRewardsDistributed + totalReward;
        
        emit CheckInCompleted(msg.sender, farmer.checkInStreak, totalReward);
    }
    
    /**
     * @dev Stakes tokens in a farming pool
     * @param _poolId ID of the farming pool
     * @param _amount Amount of tokens to stake
     */
    function stakeTokens(uint256 _poolId, uint256 _amount) external nonReentrant updateReward(msg.sender, _poolId) {
        require(_poolId < totalPools, "Invalid pool ID");
        require(_amount > 0, "Amount must be greater than 0");
        require(farmers[msg.sender].lastCheckIn != 0, "Farmer not registered");
        
        FarmPool storage pool = farmPools[_poolId];
        require(pool.isActive, "Pool is not active");
        require(_amount >= pool.minimumStake, "Amount below minimum stake");
        
        // Transfer tokens from user
        harvestToken.transferFrom(msg.sender, address(this), _amount);
          // Update stake info
        stakes[msg.sender].amount = stakes[msg.sender].amount + _amount;
        stakes[msg.sender].stakedAt = block.timestamp;
        
        // Update pool and farmer info
        pool.totalStaked = pool.totalStaked + _amount;
        farmers[msg.sender].totalStaked = farmers[msg.sender].totalStaked + _amount;
        
        emit TokensStaked(msg.sender, _poolId, _amount);
    }
    
    /**
     * @dev Unstakes tokens from a farming pool
     * @param _poolId ID of the farming pool
     * @param _amount Amount of tokens to unstake
     */
    function unstakeTokens(uint256 _poolId, uint256 _amount) external nonReentrant updateReward(msg.sender, _poolId) {
        require(_poolId < totalPools, "Invalid pool ID");
        require(_amount > 0, "Amount must be greater than 0");
        require(stakes[msg.sender].amount >= _amount, "Insufficient staked amount");
        
        FarmPool storage pool = farmPools[_poolId];
          // Update stake info
        stakes[msg.sender].amount = stakes[msg.sender].amount - _amount;
        
        // Update pool and farmer info
        pool.totalStaked = pool.totalStaked - _amount;
        farmers[msg.sender].totalStaked = farmers[msg.sender].totalStaked - _amount;
        
        // Transfer tokens back to user
        harvestToken.transfer(msg.sender, _amount);
        
        emit TokensUnstaked(msg.sender, _poolId, _amount);
    }
    
    /**
     * @dev Claims accumulated farming rewards
     * @param _poolId ID of the farming pool
     */
    function claimRewards(uint256 _poolId) external nonReentrant updateReward(msg.sender, _poolId) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
          rewards[msg.sender] = 0;
        stakes[msg.sender].lastClaimAt = block.timestamp;
        stakes[msg.sender].rewardsEarned = stakes[msg.sender].rewardsEarned + reward;
        farmers[msg.sender].totalRewardsEarned = farmers[msg.sender].totalRewardsEarned + reward;
        
        // Mint rewards
        harvestToken.mintRewards(msg.sender, reward);
        totalRewardsDistributed = totalRewardsDistributed + reward;
        
        // Pay referral bonus if applicable
        address referrer = farmers[msg.sender].referrer;
        if (referrer != address(0)) {
            uint256 referralReward = reward * REFERRAL_BONUS / 100;
            harvestToken.mintRewards(referrer, referralReward);
            farmers[referrer].referralRewards = farmers[referrer].referralRewards + referralReward;
            totalRewardsDistributed = totalRewardsDistributed + referralReward;
            
            emit ReferralRewardPaid(referrer, msg.sender, referralReward);
        }
        
        emit RewardsClaimed(msg.sender, reward);
    }
    
    /**
     * @dev Plants a new crop NFT
     * @param _cropType Type of crop to plant
     */
    function plantCrop(CropNFT.CropType _cropType) external nonReentrant {
        require(farmers[msg.sender].lastCheckIn != 0, "Farmer not registered");
        
        // Calculate bonus multiplier based on farmer's stake
        uint256 bonusMultiplier = 100; // Base 1x multiplier
        if (farmers[msg.sender].totalStaked >= 10000 * 10**18) {
            bonusMultiplier = 150; // 1.5x for large stakers
        } else if (farmers[msg.sender].totalStaked >= 1000 * 10**18) {
            bonusMultiplier = 125; // 1.25x for medium stakers
        }
        
        // Plant the crop
        uint256 tokenId = cropNFT.plantCrop(msg.sender, _cropType, bonusMultiplier);
        
        // Add to farmer's crop list
        farmers[msg.sender].ownedCrops.push(tokenId);
        
        emit CropPlanted(msg.sender, tokenId, _cropType);
    }
      /**
     * @dev Harvests a crop NFT for rewards
     * @param _tokenId ID of the crop to harvest
     */
    function harvestCrop(uint256 _tokenId) external nonReentrant {
        require(cropNFT.ownerOf(_tokenId) == msg.sender, "Not crop owner");
        require(cropNFT.isHarvestable(_tokenId), "Crop not ready for harvest");
        
        // Harvest the crop and get reward amount
        uint256 reward = cropNFT.harvestCropForOwner(_tokenId, msg.sender);
          // Mint harvest rewards
        harvestToken.mintRewards(msg.sender, reward);
        farmers[msg.sender].totalRewardsEarned = farmers[msg.sender].totalRewardsEarned + reward;
        totalRewardsDistributed = totalRewardsDistributed + reward;
        
        // Remove from farmer's crop list
        _removeCropFromFarmer(msg.sender, _tokenId);
        
        emit CropHarvested(msg.sender, _tokenId, reward);
    }
      /**
     * @dev Waters a crop to potentially speed up growth
     * @param _tokenId ID of the crop to water
     */
    function waterCrop(uint256 _tokenId) external {
        require(cropNFT.ownerOf(_tokenId) == msg.sender, "Not crop owner");
        cropNFT.waterCropForOwner(_tokenId, msg.sender);
    }
    
    /**
     * @dev Creates a new farming pool
     * @param _rewardRate Reward rate in tokens per second per staked token
     * @param _minimumStake Minimum stake required
     */
    function createPool(uint256 _rewardRate, uint256 _minimumStake) external onlyOwner {
        _createPool(_rewardRate, _minimumStake);
    }
    
    /**
     * @dev Internal function to create a farming pool
     */
    function _createPool(uint256 _rewardRate, uint256 _minimumStake) internal {
        farmPools[totalPools] = FarmPool({
            rewardRate: _rewardRate,
            totalStaked: 0,
            lastUpdateTime: block.timestamp,
            rewardPerTokenStored: 0,
            minimumStake: _minimumStake,
            isActive: true
        });
          emit PoolCreated(totalPools, _rewardRate, _minimumStake);
        totalPools = totalPools + 1;
    }
    
    /**
     * @dev Updates a farming pool's parameters
     * @param _poolId ID of the pool to update
     * @param _rewardRate New reward rate
     * @param _isActive Whether the pool is active
     */
    function updatePool(uint256 _poolId, uint256 _rewardRate, bool _isActive) external onlyOwner {
        require(_poolId < totalPools, "Invalid pool ID");
        
        FarmPool storage pool = farmPools[_poolId];
        pool.rewardRate = _rewardRate;
        pool.isActive = _isActive;
        
        emit PoolUpdated(_poolId, _rewardRate, _isActive);
    }
    
    /**
     * @dev Modifier to update reward calculations
     */
    modifier updateReward(address _account, uint256 _poolId) {
        require(_poolId < totalPools, "Invalid pool ID");
        
        FarmPool storage pool = farmPools[_poolId];
        pool.rewardPerTokenStored = rewardPerToken(_poolId);
        pool.lastUpdateTime = block.timestamp;
        
        if (_account != address(0)) {
            rewards[_account] = earned(_account, _poolId);
            userRewardPerTokenPaid[_account][_poolId] = pool.rewardPerTokenStored;
        }
        _;
    }
    
    /**
     * @dev Calculates reward per token for a pool
     * @param _poolId ID of the farming pool
     */
    function rewardPerToken(uint256 _poolId) public view returns (uint256) {
        FarmPool memory pool = farmPools[_poolId];
        
        if (pool.totalStaked == 0) {
            return pool.rewardPerTokenStored;
        }
          return pool.rewardPerTokenStored + (
            (block.timestamp - pool.lastUpdateTime) * pool.rewardRate * 1e18 / pool.totalStaked
        );
    }
    
    /**
     * @dev Calculates earned rewards for a user in a pool
     * @param _account User address
     * @param _poolId ID of the farming pool
     */    function earned(address _account, uint256 _poolId) public view returns (uint256) {
        return stakes[_account].amount * (
            rewardPerToken(_poolId) - userRewardPerTokenPaid[_account][_poolId]
        ) / 1e18 + rewards[_account];
    }
    
    /**
     * @dev Removes a crop from farmer's owned crops list
     */
    function _removeCropFromFarmer(address _farmer, uint256 _tokenId) internal {
        uint256[] storage crops = farmers[_farmer].ownedCrops;
        for (uint256 i = 0; i < crops.length; i++) {
            if (crops[i] == _tokenId) {
                crops[i] = crops[crops.length - 1];
                crops.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Gets farmer's owned crops
     * @param _farmer Farmer address
     */
    function getFarmerCrops(address _farmer) external view returns (uint256[] memory) {
        return farmers[_farmer].ownedCrops;
    }
    
    /**
     * @dev Gets pool information
     * @param _poolId ID of the farming pool
     */
    function getPoolInfo(uint256 _poolId) external view returns (
        uint256 rewardRate,
        uint256 totalStaked,
        uint256 minimumStake,
        bool isActive
    ) {
        require(_poolId < totalPools, "Invalid pool ID");
        FarmPool memory pool = farmPools[_poolId];
        
        return (
            pool.rewardRate,
            pool.totalStaked,
            pool.minimumStake,
            pool.isActive
        );
    }
    
    /**
     * @dev Gets farmer statistics
     * @param _farmer Farmer address
     */
    function getFarmerStats(address _farmer) external view returns (
        uint256 totalStaked,
        uint256 totalRewardsEarned,
        uint256 checkInStreak,
        uint256 referralRewards,
        uint256 ownedCropsCount
    ) {
        FarmerInfo memory farmer = farmers[_farmer];
        
        return (
            farmer.totalStaked,
            farmer.totalRewardsEarned,
            farmer.checkInStreak,
            farmer.referralRewards,
            farmer.ownedCrops.length
        );
    }
    
    /**
     * @dev Emergency pause function
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause function
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency token recovery
     * @param _token Token address to recover
     * @param _amount Amount to recover
     */
    function recoverERC20(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(harvestToken), "Cannot recover native token");
        IERC20(_token).transfer(owner(), _amount);
    }
}
