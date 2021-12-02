const { expect } = require('chai');
const { ethers } = require('hardhat');
require('chai').should();
require('chai').use(require("ethereum-waffle").solidity)
// Set these to the same parameters in the contract
const MAX_ELEMENTS = 8888;
const MAX_BY_MINT = 20;
const baseURI = "ipfs://QmW7JUMNYa9BnJeNNLd3fJzoaUKuCbyjxVnAGdpA3P9P3D/";
const hiddenURI = "https://gateway.pinata.cloud/ipfs/QmXDcybBohqZwarqD3Fj6bFQyNDhQvktQcNm2qHAzBAmJ6"
const creatorAddress = "0x3D3753523e901E5e14Ab4ae7aDA9c85e9D1f0C61";
const PRICE = 40000000000000000;
const CONTRACT_NAME = "ImpactKAB_NFT"
const SYMBOL = "KAB"
let minters = ["0x54b17b76260Da5dB8A62B6E70A09d086050C7C13"];
const withdrawAllAddress = minters[0];

describe('ImpactNFTTests', () => {
    let Marketplace, marketplace, Token, token, owner, addr1, addr2, addr3
    beforeEach(async () => {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();
        minters.push(addr3.address);
        Marketplace = await ethers.getContractFactory("ImpactMarket");
        marketplace = await Marketplace.deploy();
        await marketplace.deployed();
        // Get the smart contract
        Token = await ethers.getContractFactory("ImpactKAB_NFT");
        // Deploy the smart contract
        token = await Token.deploy(baseURI, hiddenURI, withdrawAllAddress, minters, marketplace.address);
    });
    describe('Deployment', () => {
        // Expect that the contract owner is equal to the owner's address
        it('Contract Owner', async () => {
            const tokenOwner = await token.owner();
            expect(tokenOwner).to.equal(owner.address);
        }),
        it('Minting no tokens', async() => {
            await token.mint(addr2.address, [0,0,0]);
        }),
        it('Minting no tokens', async() => {
            await token.mint(addr2.address, [1,0,0]);
        })
    });
})