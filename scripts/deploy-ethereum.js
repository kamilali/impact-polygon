const hre = require("hardhat");

async function main() {
  const tokenAddresses = ["0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa"];
  const baseTokenAddress = "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa";

  const ImpactPayment = await hre.ethers.getContractFactory("ImpactPayment");
  const impactPayment = await ImpactPayment.deploy(tokenAddresses, baseTokenAddress);
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
