const hre = require("hardhat");

async function main() {
  const ImpactMarket = await hre.ethers.getContractFactory("ImpactMarket");
  const impactMarket = await ImpactMarket.deploy();
  await impactMarket.deployed();
  console.log("Impact Market contract deployed to:", impactMarket.address);

  const ImpactNFT = await hre.ethers.getContractFactory("ImpactNFT");
  const impactNFT = await ImpactNFT.deploy(impactMarket.address);
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
