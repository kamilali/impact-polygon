const hre = require("hardhat");

async function main() {
  const tokenAddresses = ["0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa"];
  const baseTokenAddress = "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa"
  const wETH9TokenAddress = "0xd0A1E359811322d97991E03f863a0C30C2cF029C";
  const swapRouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

  const ImpactPayment = await hre.ethers.getContractFactory("ImpactPayment");
  const impactPayment = await ImpactPayment.deploy(tokenAddresses, baseTokenAddress, wETH9TokenAddress, swapRouterAddress);
  await impactPayment.deployed();
  console.log("Impact Payment contract deployed to:", impactPayment.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
