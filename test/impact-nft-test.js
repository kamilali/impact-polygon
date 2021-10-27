const { expect } = require('chai');
require('chai').should();
require('chai').use(require("ethereum-waffle").solidity)

// Set these to the same parameters in the contract
const MAX_ELEMENTS = 8888;
const MAX_BY_MINT = 20;
const baseURI = "ipfs://QmW7JUMNYa9BnJeNNLd3fJzoaUKuCbyjxVnAGdpA3P9P3D/";
const hiddenURI = "https://gateway.pinata.cloud/ipfs/QmXDcybBohqZwarqD3Fj6bFQyNDhQvktQcNm2qHAzBAmJ6"
const creatorAddress = "0x3D3753523e901E5e14Ab4ae7aDA9c85e9D1f0C61";
const PRICE = 40000000000000000;
const CONTRACT_NAME = "ImpactNFT"
const SYMBOL = "IMPACT"

describe('Impact Nft Tests', () => {
    let Token, token, owner, addr1, addr2

    beforeEach(async () => {
        // Get the smart contract
        Token = await ethers.getContractFactory("ImpactNFT");

        // Deploy the smart contract
        token = await Token.deploy(baseURI, hiddenURI, creatorAddress);

        // Get the related data
        [owner, addr1, addr2, _] = await ethers.getSigners();
    });

    describe('Deployment', () => {

        // Expect that the contract owner is equal to the owner's address
        it('Contract Owner', async () => {
            const tokenOwner = await token.owner();
            expect(tokenOwner).to.equal(owner.address);
        });

        // Expect that the creator address is what we expect it to be
        it('Creator Address', async () => {
            expect(await token.creatorAddress()).to.equal(creatorAddress);
        });

        // Expect that the baseTokenURI is what we expect it to be
        it('Base Token URI', async () => {
            // The baseTokenURI should be what we deployed with
            expect(await token.baseTokenURI()).to.equal(baseURI)

            // Assert setting a new URI
            const testURI = "TEST_URI_1234567890_!@#$%^&*()🔥";
            await token.setBaseURI(testURI)
            expect(testURI).to.equal(testURI)

            // Revert changes
            await token.setBaseURI(baseURI)
        })

        // Expect price to be callable and it is what we expect it to be
        it('NFT Price', async () => {
            let price = (await token.PRICE())
            price.should.be.a('object');
            expect(price).to.have.property('_hex');
            expect(price).to.have.property('_isBigNumber');
            expect(parseInt(price._hex)).to.equal(PRICE);

            const numOfTokens = 5
            price = (await token.price(numOfTokens))
            price.should.be.a('object');
            expect(price).to.have.property('_hex');
            expect(price).to.have.property('_isBigNumber');
            expect(parseInt(price._hex)).to.equal(PRICE * numOfTokens);
        });

        // Assert that the contract name is what we expect it to be
        it('Contract Name', async () => {
            const name = await token.name()
            expect(name).to.equal(CONTRACT_NAME);
        });

        // Assert the max elements is what we expect it to be
        it('Max Elements', async () => {
            const max = await token.MAX_ELEMENTS();
            max.should.be.a('object');
            expect(max).to.have.property('_hex');
            expect(max).to.have.property('_isBigNumber');
            expect(parseInt(max._hex)).to.equal(MAX_ELEMENTS);
        });

        it('Max By Mint', async () => {
            const max = await token.MAX_BY_MINT();
            max.should.be.a('object');
            expect(max).to.have.property('_hex');
            expect(max).to.have.property('_isBigNumber');
            expect(parseInt(max._hex)).to.equal(MAX_BY_MINT);
        })

        it('Pause', async () => {
            // Assert the contract is paused at start
            let isPaused = await token.paused();
            expect(isPaused).to.equal(true);

            // Assert we can unpause the contract
            await token.pause(false);
            isPaused = await token.paused()
            expect(isPaused).to.equal(false)

            // Assert we can pause the contract
            await token.pause(true)
            isPaused = await token.paused();
            expect(isPaused).to.equal(true)

            // Finally, set the contract to unpaused
            await token.pause(false)
        });

        it('Initial Total Mint', async () => {
            // Get the current total mint
            const totalMint = await token.totalSupply();

            // Assert the total mint is zero
            totalMint.should.be.a('object');
            expect(totalMint).to.have.property('_hex');
            expect(totalMint).to.have.property('_isBigNumber');
            expect(parseInt(totalMint._hex)).to.equal(0);
        })

        it('Initial Total Supply', async () => {
            // Get the current total mint
            const totalMint = await token.totalSupply();

            // Assert the total supply is zero
            totalMint.should.be.a('object');
            expect(totalMint).to.have.property('_hex');
            expect(totalMint).to.have.property('_isBigNumber');
            expect(parseInt(totalMint._hex)).to.equal(0);
        })

        it('Symbol', async () => {
            // Get the token symbol
            const symbol = await token.symbol();

            // Assert the symbol is what we expect it to be
            expect(symbol).to.equal(SYMBOL)
        })
    });

    describe('Mint Exceptions', () => {
        beforeEach(async () => {
            // Unpause the contract if not already unpaused
            if(await token.paused()) await token.pause(false);
        })

        // Assert that minting while paused reverts the transaction
        it('Mint while paused', async () => {
            // Pause the contract if not already paused
            if (!await token.paused()) await token.pause(true)

            // Get the prev supply, mint, and wallet of address we want to mint to
            const prevTotalSupply = parseInt((await token.totalSupply())._hex);
            const prevWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Try to mint while paused and expect revert
            await expect((token.mint(addr1.address, 1, { value: ethers.utils.parseEther("0.5") })))
                .to.be.revertedWith('ERC721Pausable: token transfer while paused');

            // Get the new total supply, mint, and wallet
            const newTotalSupply = parseInt((await token.totalSupply())._hex);
            const newWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Ensure everything stayed the same
            expect(newTotalSupply).to.equal(prevTotalSupply)
            expect(newWalletOfOwner.length).to.equal(prevWalletOfOwner.length)
        })

        it('Mint more than the max', async () => {
            // Get the prev supply, mint, and wallet of address we want to mint to
            const prevTotalSupply = parseInt((await token.totalSupply())._hex);
            const prevWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Try to mint while paused and expect revert
            await expect((token.mint(addr1.address, MAX_BY_MINT + 1, { value: ethers.utils.parseEther("0.5") })))
                .to.be.revertedWith('Exceeds number');

            // Get the new totals
            const newTotalSupply = parseInt((await token.totalSupply())._hex);
            const newWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Ensure everything stayed the same
            expect(newTotalSupply).to.equal(prevTotalSupply)
            expect(newWalletOfOwner.length).to.equal(prevWalletOfOwner.length)
        });

        it('Mint for less than the price', async () => {
            // Get the prev supply, mint, and wallet of address we want to mint to
            const prevTotalSupply = parseInt((await token.totalSupply())._hex);
            const prevWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Try to mint with less than the price of the token
            const newPrice = ethers.utils.parseEther("0.03");

            await expect((token.mint(addr1.address, 1, { value: newPrice })))
                .to.be.revertedWith('Value below price');

            // Get the new totals
            const newTotalSupply = parseInt((await token.totalSupply())._hex);
            const newWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Ensure everything stayed the same
            expect(newTotalSupply).to.equal(prevTotalSupply)
            expect(newWalletOfOwner.length).to.equal(prevWalletOfOwner.length)
        });
    });

    describe('Mint Successes', () => {
        beforeEach(async () => {
            // Unpause the contract if not already unpaused
            if(await token.paused()) await token.pause(false);
        })

        it('Standard Mint', async () => {
            // Get the prev supply, mint, and wallet of address we want to mint to
            const prevTotalSupply = parseInt((await token.totalSupply())._hex);
            const prevWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Mint 1 token while unpaused
            expect((await token.mint(addr1.address, 1, { value: ethers.utils.parseEther("0.5") })).from)
                .to.equal(owner.address)

            // Get the new totals
            const newTotalSupply = parseInt((await token.totalSupply())._hex);
            const newWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Ensures everything accumulated properly
            expect(newTotalSupply).to.equal(prevTotalSupply + 1)
            expect(newWalletOfOwner.length).to.equal(prevWalletOfOwner.length + 1)
        });

        it('Mint max', async () => {
            // Get the prev supply, mint, and wallet of address we want to mint to
            const prevTotalSupply = parseInt((await token.totalSupply())._hex);
            const prevWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Mint MAX_BY_MINT tokens while unpaused
            expect((await token.mint(addr1.address, MAX_BY_MINT, { value: ethers.utils.parseEther("1") })).from)
                .to.equal(owner.address)

            // Get the new totals
            const newTotalSupply = parseInt((await token.totalSupply())._hex);
            const newWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Ensures everything accumulated properly
            expect(newTotalSupply).to.equal(prevTotalSupply + MAX_BY_MINT)
            expect(newWalletOfOwner.length).to.equal(prevWalletOfOwner.length + MAX_BY_MINT)
        });

        it('Mint Unique', async () => {
            // Get the prev supply, mint, and wallet of address we want to mint to
            const prevTotalSupply = parseInt((await token.totalSupply())._hex);
            const prevWalletOfOwner = await token.walletOfOwner(addr1.address);

            // Mint 1 token while unpaused
            expect((await token.mintUnique(addr1.address, 10000, { value: ethers.utils.parseEther("0.5") })).from)
                .to.equal(owner.address)

            // Get the new totals
            const newTotalSupply = parseInt((await token.totalSupply())._hex);
            const newWalletOfOwner = await token.walletOfOwner(addr1.address)

            // Ensures everything accumulated properly
            expect(newTotalSupply).to.equal(prevTotalSupply+1)

            expect(newWalletOfOwner.length).to.equal(prevWalletOfOwner.length + 1)
        });

    })

    describe("Test Hidden URI", () => {
        beforeEach(async () => {
            // Unpause the contract if not already unpaused
            if(await token.paused()) await token.pause(false);
        });

        it('Is Revealed', async () => {


            expect(await token._isRevealed()).to.equal(false);
        });

        it('Reveal() Reveals', async () => {
            //Starts off unrevealed
            expect(await token._isRevealed()).to.equal(false);

            //Calling reveal() sets isRevealed() to true
            await token.reveal();

            expect(await token._isRevealed()).to.equal(true);


        });


        it('Hide() Hides', async () => {
            //Starts off unrevealed
            expect(await token._isRevealed()).to.equal(false);

            //Calling reveal() sets isRevealed() to true
            await token.reveal();

            expect(await token._isRevealed()).to.equal(true);

            //Calling reveal() sets isRevealed() to true
            await token.hide();

            expect(await token._isRevealed()).to.equal(false);

        });

        it('Set Hidden URI', async () => {
            //Starts off unrevealed
            expect(await token._hiddenURI()).to.equal(hiddenURI);

            await token.setHiddenURI("123");

            expect(await token._hiddenURI()).to.equal("123");
        });




    });
})
