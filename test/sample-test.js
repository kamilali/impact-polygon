const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ImpactMarket", function () {
  it("Should create and execute market sales", async function () {
    const ImpactMarket = await ethers.getContractFactory("ImpactMarket");
    const impactMarket = await ImpactMarket.deploy();
    await impactMarket.deployed();
    const impactMarketAddress = impactMarket.address;

    const ImpactNFT = await ethers.getContractFactory("ImpactNFT");
    const impactNFT = await ImpactNFT.deploy(impactMarketAddress);
    await impactNFT.deployed();
    const impactNFTAddress = impactNFT.address;

    let listingPrice = await impactMarket.getListingPrice();
    listingPrice = listingPrice.toString();

    const auctionPrice = ethers.utils.parseUnits('100', 'ether');

    await impactNFT.createToken("https://impactart.io/testToken1");
    await impactNFT.createToken("https://impactart.io/testToken2");

    await impactMarket.createMarketItem(impactNFTAddress, 1, auctionPrice, { value: listingPrice });
    await impactMarket.createMarketItem(impactNFTAddress, 2, auctionPrice, { value: listingPrice });
    
    const [_, buyerAddress] = await ethers.getSigners();

    await impactMarket.connect(buyerAddress).createMarketSale(impactNFTAddress, 1, { value: auctionPrice });

    let items = await impactMarket.fetchMarketItems();

    items = await Promise.all(items.map(async i => {
      const tokenUri = await impactNFT.tokenURI(i.tokenId);
      let item = {
        price: i.price.toString(),
        itemId: i.itemId.toString(),
        tokenId: i.tokenId.toString(),
        seller: i.seller,
        owner: i.owner,
        tokenUri
      }
      return item;
    }));

    console.log('items:', items);
  });
});
