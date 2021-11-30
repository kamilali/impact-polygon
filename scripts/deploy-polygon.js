const hre = require("hardhat");

async function main() {
  const ImpactMarket = await hre.ethers.getContractFactory("ImpactMarket");
  const impactMarket = await ImpactMarket.deploy();
  await impactMarket.deployed();
  console.log("Impact Market contract deployed to:", impactMarket.address);

  const minters = ["0x54b17b76260Da5dB8A62B6E70A09d086050C7C13"];
  const withdrawAllAddress = minters[0];
  const baseTokenURI = "ipfs://QmQopLqopaEquC8ajy1zcstMVvi4ZEAz19s2EjnrwmDgqy/";
  const hiddenTokenURI = "";
  const ImpactNFT = await hre.ethers.getContractFactory("ImpactKAB_NFT");
  const impactNFT = await ImpactNFT.deploy(baseTokenURI, hiddenTokenURI, withdrawAllAddress, minters, impactMarket.address);
  await impactNFT.deployed();
  console.log("Impact NFT contract deployed to:", impactNFT.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
