//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ImpactMarket is ReentrancyGuard {
    
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    
    struct MarketItem {
        uint256 itemId;
        uint256 campaignId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    event MarketItemCreated(
        uint256 indexed itemId,
        uint256 campaignId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    address payable owner;
    uint256 listingPrice = 0.025 ether;
    mapping(uint256 => MarketItem) private idToMarketItem;
    
    constructor () {
        owner = payable(msg.sender);
    }
    
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createMarketItem(address nftContract, uint256 tokenId, uint256 price, uint256 campaignId) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Price must be equal to the required listing price");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            campaignId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        emit MarketItemCreated(itemId, campaignId, nftContract, tokenId, msg.sender, address(0), price, false);
    }

    function createMarketSale(address nftContract, uint256 itemId) public payable nonReentrant {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;

        require(msg.value == price, "Value sent must be equal to the asking price");

        idToMarketItem[itemId].seller.transfer(msg.value);
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        
        _itemsSold.increment();
        payable(owner).transfer(listingPrice);
    }

    function fetchMarketItemsForCampaign(uint256 campaignId) public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        MarketItem[] memory unsoldItems = new MarketItem[](unsoldItemCount);
        uint256 currIdx = 0;

        for(uint256 i = 0; i < itemCount; i++) {
            if((idToMarketItem[i+1].owner == address(0)) && 
               (idToMarketItem[i+1].campaignId == campaignId)) {
                MarketItem storage currentMarketItem = idToMarketItem[i+1];
                unsoldItems[currIdx] = currentMarketItem;
                currIdx += 1;
            }
        }
        return unsoldItems;
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        MarketItem[] memory unsoldItems = new MarketItem[](unsoldItemCount);
        uint256 currIdx = 0;

        for(uint256 i = 0; i < itemCount; i++) {
            if(idToMarketItem[i+1].owner == address(0)) {
                MarketItem storage currentMarketItem = idToMarketItem[i+1];
                unsoldItems[currIdx] = currentMarketItem;
                currIdx += 1;
            }
        }
        return unsoldItems;
    }

    // TODO: optimize this (have a mapping that stores user counts so don't have to loop to find out)
    function fetchUserOwnedNFTs() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 userItemCount = 0;
        uint256 currIdx = 0;

        for(uint256 i = 0; i < itemCount; i++) {
            if(idToMarketItem[i+1].owner == msg.sender) {
                userItemCount += 1;
            }
        }

        MarketItem[] memory userItems = new MarketItem[](userItemCount);

        for(uint256 i = 0; i < itemCount; i++) {
            if(idToMarketItem[i+1].owner == msg.sender) {
                MarketItem storage currentMarketItem = idToMarketItem[i+1];
                userItems[currIdx] = currentMarketItem;
                currIdx += 1;
            }
        }
        return userItems;
    }
    
    function fetchUserCreatedNFTs() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 userItemCount = 0;
        uint256 currIdx = 0;

        for(uint256 i = 0; i < itemCount; i++) {
            if(idToMarketItem[i+1].seller == msg.sender) {
                userItemCount += 1;
            }
        }

        MarketItem[] memory userItems = new MarketItem[](userItemCount);

        for(uint256 i = 0; i < itemCount; i++) {
            if(idToMarketItem[i+1].seller == msg.sender) {
                MarketItem storage currentMarketItem = idToMarketItem[i+1];
                userItems[currIdx] = currentMarketItem;
                currIdx += 1;
            }
        }
        return userItems; 
    }
}