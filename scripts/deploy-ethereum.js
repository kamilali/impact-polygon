const hre = require("hardhat");

async function main() {
  const tokenAddresses = ["0x6b175474e89094c44da98b954eedeac495271d0f"];
  const baseTokenAddress = "0x6b175474e89094c44da98b954eedeac495271d0f"
  const wETH9TokenAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
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
