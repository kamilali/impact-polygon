const hre = require("hardhat");

async function main() {
  const tokenAddresses = ["0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa"];
  const swapRouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const forwarderAddress = "0x7eEae829DF28F9Ce522274D5771A6Be91d00E5ED";
  const relayHubAddress = "0x727862794bdaa3b8Bc4E3705950D4e9397E3bAfd";
  const wETH9Address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

  const ImpactPayment = await hre.ethers.getContractFactory("ImpactPayment");
  const impactPayment = await ImpactPayment.deploy(tokenAddresses, forwarderAddress);
  await impactPayment.deployed();
  console.log("Impact Payment contract deployed to:", impactPayment.address);
  
  const ImpactPaymaster = await hre.ethers.getContractFactory("ImpactPaymaster");
  const impactPaymaster = await ImpactPaymaster.deploy(tokenAddresses, wETH9Address, swapRouterAddress, forwarderAddress, relayHubAddress);
  await impactPaymaster.deployed();
  console.log("Impact Paymaster contract deployed to:", impactPaymaster.address);

  const [deployerAddress, _] = await ethers.getSigners(); 
  currHubAddr = await impactPaymaster.connect(deployerAddress).getHubAddr();
  currTrustedForwarder = await impactPaymaster.connect(deployerAddress).trustedForwarder();
  console.log(currHubAddr, currTrustedForwarder);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
