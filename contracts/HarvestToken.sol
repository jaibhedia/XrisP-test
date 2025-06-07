// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title HarvestToken
 * @dev Custom ERC20 token for the XFarm reward system
 * Features:
 * - Burnable tokens for deflationary mechanics
 * - Pausable for emergency controls
 * - Owner-controlled minting for reward distribution
 * - Anti-whale mechanics with transfer limits
 */
contract HarvestToken is ERC20, ERC20Burnable, Ownable, Pausable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 100 million tokens
    
    // Tokenomics allocation percentages
    uint256 public constant REWARD_POOL_ALLOCATION = 40; // 40% for farming rewards
    uint256 public constant TEAM_ALLOCATION = 15; // 15% for team
    uint256 public constant MARKETING_ALLOCATION = 10; // 10% for marketing
    uint256 public constant LIQUIDITY_ALLOCATION = 25; // 25% for liquidity
    uint256 public constant RESERVE_ALLOCATION = 10; // 10% for reserves
    
    // Addresses for token allocation
    address public rewardPool;
    address public teamWallet;
    address public marketingWallet;
    address public liquidityWallet;
    address public reserveWallet;
    
    // Anti-whale mechanism
    uint256 public maxTransferAmount;
    mapping(address => bool) public isExcludedFromLimits;
    
    // Authorized minters (reward contracts)
    mapping(address => bool) public authorizedMinters;
    
    event RewardPoolUpdated(address indexed newRewardPool);
    event AuthorizedMinterAdded(address indexed minter);
    event AuthorizedMinterRemoved(address indexed minter);
    event MaxTransferAmountUpdated(uint256 newAmount);
    
    constructor(
        address _teamWallet,
        address _marketingWallet,
        address _liquidityWallet,
        address _reserveWallet
    ) ERC20("Harvest Token", "HARVEST") Ownable(msg.sender) {
        require(_teamWallet != address(0), "Team wallet cannot be zero address");
        require(_marketingWallet != address(0), "Marketing wallet cannot be zero address");
        require(_liquidityWallet != address(0), "Liquidity wallet cannot be zero address");
        require(_reserveWallet != address(0), "Reserve wallet cannot be zero address");
        
        teamWallet = _teamWallet;
        marketingWallet = _marketingWallet;
        liquidityWallet = _liquidityWallet;
        reserveWallet = _reserveWallet;
        
        // Set initial max transfer amount to 1% of total supply
        maxTransferAmount = INITIAL_SUPPLY / 100;
        
        // Exclude important addresses from transfer limits
        isExcludedFromLimits[owner()] = true;
        isExcludedFromLimits[address(this)] = true;
        isExcludedFromLimits[_teamWallet] = true;
        isExcludedFromLimits[_marketingWallet] = true;
        isExcludedFromLimits[_liquidityWallet] = true;
        isExcludedFromLimits[_reserveWallet] = true;
        
        _distributeInitialSupply();
    }
    
    /**
     * @dev Distributes initial token supply according to tokenomics
     */
    function _distributeInitialSupply() private {
        uint256 rewardPoolAmount = (INITIAL_SUPPLY * REWARD_POOL_ALLOCATION) / 100;
        uint256 teamAmount = (INITIAL_SUPPLY * TEAM_ALLOCATION) / 100;
        uint256 marketingAmount = (INITIAL_SUPPLY * MARKETING_ALLOCATION) / 100;
        uint256 liquidityAmount = (INITIAL_SUPPLY * LIQUIDITY_ALLOCATION) / 100;
        uint256 reserveAmount = (INITIAL_SUPPLY * RESERVE_ALLOCATION) / 100;
        
        // Mint tokens to contract first (for reward pool)
        _mint(address(this), rewardPoolAmount);
        _mint(teamWallet, teamAmount);
        _mint(marketingWallet, marketingAmount);
        _mint(liquidityWallet, liquidityAmount);
        _mint(reserveWallet, reserveAmount);
    }
    
    /**
     * @dev Sets the reward pool address
     * @param _rewardPool Address of the reward distribution contract
     */
    function setRewardPool(address _rewardPool) external onlyOwner {
        require(_rewardPool != address(0), "Reward pool cannot be zero address");
        rewardPool = _rewardPool;
        isExcludedFromLimits[_rewardPool] = true;
        authorizedMinters[_rewardPool] = true;
        
        // Transfer reward pool tokens to the contract
        uint256 rewardPoolBalance = balanceOf(address(this));
        if (rewardPoolBalance > 0) {
            _transfer(address(this), _rewardPool, rewardPoolBalance);
        }
        
        emit RewardPoolUpdated(_rewardPool);
    }
    
    /**
     * @dev Adds an authorized minter (reward contract)
     * @param _minter Address to authorize for minting
     */
    function addAuthorizedMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Minter cannot be zero address");
        authorizedMinters[_minter] = true;
        isExcludedFromLimits[_minter] = true;
        emit AuthorizedMinterAdded(_minter);
    }
    
    /**
     * @dev Removes an authorized minter
     * @param _minter Address to remove from authorized minters
     */
    function removeAuthorizedMinter(address _minter) external onlyOwner {
        authorizedMinters[_minter] = false;
        emit AuthorizedMinterRemoved(_minter);
    }
    
    /**
     * @dev Mints new tokens for rewards (only by authorized contracts)
     * @param _to Address to mint tokens to
     * @param _amount Amount of tokens to mint
     */
    function mintRewards(address _to, uint256 _amount) external {
        require(authorizedMinters[msg.sender], "Caller is not authorized to mint");
        require(totalSupply() + _amount <= MAX_SUPPLY, "Minting would exceed max supply");
        _mint(_to, _amount);
    }
    
    /**
     * @dev Updates maximum transfer amount for anti-whale protection
     * @param _maxTransferAmount New maximum transfer amount
     */
    function setMaxTransferAmount(uint256 _maxTransferAmount) external onlyOwner {
        require(_maxTransferAmount > 0, "Max transfer amount must be greater than 0");
        maxTransferAmount = _maxTransferAmount;
        emit MaxTransferAmountUpdated(_maxTransferAmount);
    }
    
    /**
     * @dev Excludes or includes an address from transfer limits
     * @param _account Address to update
     * @param _excluded Whether to exclude from limits
     */
    function setExcludedFromLimits(address _account, bool _excluded) external onlyOwner {
        isExcludedFromLimits[_account] = _excluded;
    }
    
    /**
     * @dev Pauses all token transfers (emergency function)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpauses token transfers
     */
    function unpause() external onlyOwner {
        _unpause();    }
    
    /**
     * @dev Override _update function to include anti-whale protection
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        // Apply transfer limits (except for excluded addresses)
        if (
            from != address(0) && // Not minting
            to != address(0) && // Not burning
            !isExcludedFromLimits[from] &&
            !isExcludedFromLimits[to]
        ) {
            require(value <= maxTransferAmount, "Transfer amount exceeds maximum allowed");
        }
        
        super._update(from, to, value);
    }
      /**
     * @dev Returns the current allocation percentages
     */
    function getAllocationPercentages() external pure returns (
        uint256 rewardPoolAllocation,
        uint256 teamAllocation,
        uint256 marketingAllocation,
        uint256 liquidityAllocation,
        uint256 reserveAllocation
    ) {
        return (
            REWARD_POOL_ALLOCATION,
            TEAM_ALLOCATION,
            MARKETING_ALLOCATION,
            LIQUIDITY_ALLOCATION,
            RESERVE_ALLOCATION
        );
    }
    
    /**
     * @dev Emergency function to recover accidentally sent tokens
     * @param _token Address of the token to recover
     * @param _amount Amount to recover
     */
    function recoverERC20(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(this), "Cannot recover native token");
        IERC20(_token).transfer(owner(), _amount);
    }
}
