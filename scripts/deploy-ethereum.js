const hre = require("hardhat");

async function main() {
  const ImpactPayments = await hre.ethers.getContractFactory("ImpactPayments");
  const impactPayments = await ImpactPayments.deploy(["0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa", "0xc2569dd7d0fd715b054fbf16e75b001e5c0c1115"]);
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
