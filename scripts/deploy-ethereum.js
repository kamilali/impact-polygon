const hre = require("hardhat");

async function main() {
  const ImpactPayments = await hre.ethers.getContractFactory("ImpactPayments");
  const impactPayments = await ImpactPayments.deploy([]);
  await impactPayments.deployed();
  console.log("Impact Payment contract deployed to:", impactPayments.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
