// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CropNFT
 * @dev NFT contract representing virtual crops in the farming system
 * Features:
 * - Different crop types with varying rarity and growth times
 * - Growth stages that affect reward multipliers
 * - Metadata stored on-chain for transparency
 * - Burning mechanism for harvest rewards
 */
contract CropNFT is ERC721, ERC721URIStorage, ERC721Burnable, Ownable, Pausable {
    
    uint256 private _tokenIdCounter;
    
    enum CropType {
        TOMATO,     // Basic crop - 7 days growth
        CORN,       // Medium crop - 14 days growth  
        WHEAT,      // Advanced crop - 21 days growth
        SPECIAL_FRUIT // Rare crop - 30 days growth
    }
    
    enum GrowthStage {
        SEED,       // Just planted
        SPROUTING,  // 25% grown
        GROWING,    // 50% grown
        MATURE,     // 75% grown
        HARVESTABLE // 100% grown - ready for rewards
    }
    
    struct Crop {
        CropType cropType;
        GrowthStage growthStage;
        uint256 plantedAt;
        uint256 lastWatered;
        uint256 harvestableAt;
        bool isHarvested;
        uint256 baseReward;
        uint256 bonusMultiplier; // 100 = 1x, 150 = 1.5x, etc.
    }
    
    // Mapping from token ID to crop data
    mapping(uint256 => Crop) public crops;
    
    // Mapping from crop type to growth duration (in seconds)
    mapping(CropType => uint256) public growthDurations;
    
    // Mapping from crop type to base reward amount
    mapping(CropType => uint256) public baseRewards;
      // Authorized farming contracts that can mint/burn NFTs
    mapping(address => bool) public authorizedFarms;
    
    // The FarmRewardSystem contract address
    address public farmRewardSystem;
    
    // Events
    event CropPlanted(uint256 indexed tokenId, address indexed farmer, CropType cropType);
    event CropWatered(uint256 indexed tokenId, address indexed farmer);
    event CropGrowthUpdated(uint256 indexed tokenId, GrowthStage newStage);
    event CropHarvested(uint256 indexed tokenId, address indexed farmer, uint256 reward);
    event AuthorizedFarmAdded(address indexed farm);
    event AuthorizedFarmRemoved(address indexed farm);
    
    constructor() ERC721("XFarm Crops", "CROP") Ownable(msg.sender) {
        _initializeCropTypes();
    }
    
    /**
     * @dev Initialize crop types with their properties
     */
    function _initializeCropTypes() private {
        // Growth durations (in seconds)
        growthDurations[CropType.TOMATO] = 7 days;
        growthDurations[CropType.CORN] = 14 days;
        growthDurations[CropType.WHEAT] = 21 days;
        growthDurations[CropType.SPECIAL_FRUIT] = 30 days;
        
        // Base rewards (in token wei)
        baseRewards[CropType.TOMATO] = 10 * 10**18;        // 10 HARVEST
        baseRewards[CropType.CORN] = 25 * 10**18;          // 25 HARVEST
        baseRewards[CropType.WHEAT] = 50 * 10**18;         // 50 HARVEST
        baseRewards[CropType.SPECIAL_FRUIT] = 100 * 10**18; // 100 HARVEST
    }
    
    /**
     * @dev Plants a new crop NFT
     * @param _farmer Address of the farmer
     * @param _cropType Type of crop to plant
     * @param _bonusMultiplier Bonus multiplier for rewards (100 = 1x)
     */
    function plantCrop(
        address _farmer,
        CropType _cropType,
        uint256 _bonusMultiplier
    ) external returns (uint256) {
        require(authorizedFarms[msg.sender], "Only authorized farms can plant crops");
        require(_farmer != address(0), "Farmer cannot be zero address");
        require(_bonusMultiplier >= 100, "Bonus multiplier cannot be less than 100");
          uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        uint256 currentTime = block.timestamp;
        uint256 harvestTime = currentTime + growthDurations[_cropType];
        
        crops[tokenId] = Crop({
            cropType: _cropType,
            growthStage: GrowthStage.SEED,
            plantedAt: currentTime,
            lastWatered: currentTime,
            harvestableAt: harvestTime,
            isHarvested: false,
            baseReward: baseRewards[_cropType],
            bonusMultiplier: _bonusMultiplier
        });
        
        _safeMint(_farmer, tokenId);
        _setTokenURI(tokenId, _generateTokenURI(tokenId));
        
        emit CropPlanted(tokenId, _farmer, _cropType);
        
        return tokenId;
    }
      /**
     * @dev Waters a crop to potentially speed up growth
     * @param _tokenId ID of the crop to water
     */    function waterCrop(uint256 _tokenId) external {
        require(_ownerOf(_tokenId) != address(0), "Crop does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Only crop owner can water");
        
        _waterCrop(_tokenId);
    }
    
    /**
     * @dev Waters a crop on behalf of owner (called by FarmRewardSystem)
     * @param _tokenId ID of the crop to water
     * @param _owner The owner of the crop
     */
    function waterCropForOwner(uint256 _tokenId, address _owner) external {
        require(msg.sender == farmRewardSystem, "Only FarmRewardSystem can water for owner");
        require(_ownerOf(_tokenId) != address(0), "Crop does not exist");
        require(ownerOf(_tokenId) == _owner, "Invalid owner");
        
        _waterCrop(_tokenId);
    }
    
    /**
     * @dev Internal watering logic
     * @param _tokenId ID of the crop to water
     */
    function _waterCrop(uint256 _tokenId) internal {
        Crop storage crop = crops[_tokenId];
        require(!crop.isHarvested, "Crop already harvested");
        require(block.timestamp >= crop.lastWatered + 1 hours, "Crop was watered recently");
        
        crop.lastWatered = block.timestamp;
        
        // Watering can reduce growth time by 1 hour (up to 50% of original time)
        uint256 maxReduction = growthDurations[crop.cropType] / 2;
        uint256 currentReduction = crop.plantedAt + growthDurations[crop.cropType] - crop.harvestableAt;
        
        if (currentReduction < maxReduction) {
            crop.harvestableAt -= 1 hours;
        }
        
        _updateGrowthStage(_tokenId);
        _setTokenURI(_tokenId, _generateTokenURI(_tokenId));
        
        emit CropWatered(_tokenId, ownerOf(_tokenId));
    }
      /**
     * @dev Updates the growth stage of a crop based on elapsed time
     * @param _tokenId ID of the crop to update
     */
    function updateGrowthStage(uint256 _tokenId) external {
        require(_ownerOf(_tokenId) != address(0), "Crop does not exist");
        _updateGrowthStage(_tokenId);
        _setTokenURI(_tokenId, _generateTokenURI(_tokenId));
    }
    
    /**
     * @dev Internal function to update growth stage
     * @param _tokenId ID of the crop to update
     */
    function _updateGrowthStage(uint256 _tokenId) internal {
        Crop storage crop = crops[_tokenId];
        
        if (crop.isHarvested) return;
        
        uint256 currentTime = block.timestamp;
        uint256 totalGrowthTime = growthDurations[crop.cropType];
        uint256 elapsedTime = currentTime - crop.plantedAt;
        
        GrowthStage newStage;
        
        if (currentTime >= crop.harvestableAt) {
            newStage = GrowthStage.HARVESTABLE;
        } else if (elapsedTime >= (totalGrowthTime * 75) / 100) {
            newStage = GrowthStage.MATURE;
        } else if (elapsedTime >= (totalGrowthTime * 50) / 100) {
            newStage = GrowthStage.GROWING;
        } else if (elapsedTime >= (totalGrowthTime * 25) / 100) {
            newStage = GrowthStage.SPROUTING;
        } else {
            newStage = GrowthStage.SEED;
        }
        
        if (newStage != crop.growthStage) {
            crop.growthStage = newStage;
            emit CropGrowthUpdated(_tokenId, newStage);
        }
    }    /**
     * @dev Harvests a crop (burns the NFT and triggers reward)
     * @param _tokenId ID of the crop to harvest
     */
    function harvestCrop(uint256 _tokenId) external returns (uint256 reward) {
        require(_ownerOf(_tokenId) != address(0), "Crop does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Only crop owner can harvest");
        
        return _harvestCrop(_tokenId);
    }
    
    /**
     * @dev Harvests a crop on behalf of owner (called by FarmRewardSystem)
     * @param _tokenId ID of the crop to harvest
     * @param _owner The owner of the crop
     */
    function harvestCropForOwner(uint256 _tokenId, address _owner) external returns (uint256 reward) {
        require(msg.sender == farmRewardSystem, "Only FarmRewardSystem can harvest for owner");
        require(_ownerOf(_tokenId) != address(0), "Crop does not exist");
        require(ownerOf(_tokenId) == _owner, "Invalid owner");
        
        return _harvestCrop(_tokenId);
    }
    
    /**
     * @dev Internal harvest logic
     * @param _tokenId ID of the crop to harvest
     */
    function _harvestCrop(uint256 _tokenId) internal returns (uint256 reward) {
        Crop storage crop = crops[_tokenId];
        require(!crop.isHarvested, "Crop already harvested");
        require(crop.growthStage == GrowthStage.HARVESTABLE, "Crop not ready for harvest");
        
        crop.isHarvested = true;
        
        // Calculate final reward with bonus multiplier
        reward = (crop.baseReward * crop.bonusMultiplier) / 100;
        
        address owner = ownerOf(_tokenId);
        emit CropHarvested(_tokenId, owner, reward);
        
        // Burn the NFT after harvest
        _burn(_tokenId);
        
        return reward;
    }
    
    /**
     * @dev Generates metadata URI for a crop NFT
     * @param _tokenId ID of the crop
     */
    function _generateTokenURI(uint256 _tokenId) internal view returns (string memory) {
        Crop memory crop = crops[_tokenId];
        
        // This would typically return a URL to JSON metadata
        // For this example, we'll return a simple string
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _encodeMetadata(_tokenId, crop)
        ));
    }
    
    /**
     * @dev Encodes crop metadata as base64 JSON
     * @param _tokenId ID of the crop
     * @param _crop Crop data
     */
    function _encodeMetadata(uint256 _tokenId, Crop memory _crop) internal pure returns (string memory) {
        // Simplified metadata encoding
        // In production, you'd use a proper base64 encoding library
        return string(abi.encodePacked(
            '{"name":"Crop #', _toString(_tokenId),
            '","description":"A virtual crop in XFarm",',
            '"attributes":[',
                '{"trait_type":"Crop Type","value":"', _getCropTypeName(_crop.cropType), '"},',
                '{"trait_type":"Growth Stage","value":"', _getGrowthStageName(_crop.growthStage), '"},',
                '{"trait_type":"Base Reward","value":"', _toString(_crop.baseReward), '"},',
                '{"trait_type":"Bonus Multiplier","value":"', _toString(_crop.bonusMultiplier), '"}',
            ']}'
        ));
    }
    
    /**
     * @dev Returns crop type name
     */
    function _getCropTypeName(CropType _cropType) internal pure returns (string memory) {
        if (_cropType == CropType.TOMATO) return "Tomato";
        if (_cropType == CropType.CORN) return "Corn";
        if (_cropType == CropType.WHEAT) return "Wheat";
        if (_cropType == CropType.SPECIAL_FRUIT) return "Special Fruit";
        return "Unknown";
    }
    
    /**
     * @dev Returns growth stage name
     */
    function _getGrowthStageName(GrowthStage _stage) internal pure returns (string memory) {
        if (_stage == GrowthStage.SEED) return "Seed";
        if (_stage == GrowthStage.SPROUTING) return "Sprouting";
        if (_stage == GrowthStage.GROWING) return "Growing";
        if (_stage == GrowthStage.MATURE) return "Mature";
        if (_stage == GrowthStage.HARVESTABLE) return "Harvestable";
        return "Unknown";
    }
    
    /**
     * @dev Converts uint256 to string
     */
    function _toString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) return "0";
        
        uint256 temp = _value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (_value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(_value % 10)));
            _value /= 10;
        }
        
        return string(buffer);
    }
    
    /**
     * @dev Adds an authorized farm contract
     * @param _farm Address of the farm contract
     */
    function addAuthorizedFarm(address _farm) external onlyOwner {
        require(_farm != address(0), "Farm cannot be zero address");
        authorizedFarms[_farm] = true;
        emit AuthorizedFarmAdded(_farm);
    }
      /**
     * @dev Removes an authorized farm contract
     * @param _farm Address of the farm contract
     */
    function removeAuthorizedFarm(address _farm) external onlyOwner {
        authorizedFarms[_farm] = false;
        emit AuthorizedFarmRemoved(_farm);
    }
    
    /**
     * @dev Sets the FarmRewardSystem contract address
     * @param _farmRewardSystem Address of the FarmRewardSystem contract
     */
    function setFarmRewardSystem(address _farmRewardSystem) external onlyOwner {
        require(_farmRewardSystem != address(0), "FarmRewardSystem cannot be zero address");
        farmRewardSystem = _farmRewardSystem;
    }
    
    /**
     * @dev Pauses all NFT operations
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpauses NFT operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
      /**
     * @dev Gets crop information
     * @param _tokenId ID of the crop
     */
    function getCropInfo(uint256 _tokenId) external view returns (
        CropType cropType,
        GrowthStage growthStage,
        uint256 plantedAt,
        uint256 harvestableAt,
        bool isHarvested,
        uint256 baseReward,
        uint256 bonusMultiplier
    ) {
        require(_ownerOf(_tokenId) != address(0), "Crop does not exist");
        Crop memory crop = crops[_tokenId];
        
        return (
            crop.cropType,
            crop.growthStage,
            crop.plantedAt,
            crop.harvestableAt,
            crop.isHarvested,
            crop.baseReward,
            crop.bonusMultiplier
        );
    }
      /**
     * @dev Checks if a crop is ready for harvest
     * @param _tokenId ID of the crop
     */
    function isHarvestable(uint256 _tokenId) external view returns (bool) {
        if (_ownerOf(_tokenId) == address(0)) return false;
        Crop memory crop = crops[_tokenId];
        return !crop.isHarvested && block.timestamp >= crop.harvestableAt;    }
    
    // Required overrides for ERC721URIStorage
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
      function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
