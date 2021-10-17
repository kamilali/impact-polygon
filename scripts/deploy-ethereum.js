const hre = require("hardhat");

async function main() {
  const tokenAddresses = ["0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735"];
  const swapRouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const forwarderAddress = "0x83A54884bE4657706785D7309cf46B58FE5f6e8a";
  const relayHubAddress = "0x6650d69225CA31049DB7Bd210aE4671c0B1ca132";

  const ImpactPayment = await hre.ethers.getContractFactory("ImpactPayment");
  const impactPayment = await ImpactPayment.deploy(tokenAddresses, forwarderAddress);
  await impactPayment.deployed();
  console.log("Impact Payment contract deployed to:", impactPayment.address);
  
  const ImpactPaymaster = await hre.ethers.getContractFactory("ImpactPaymaster");
  const impactPaymaster = await ImpactPaymaster.deploy(tokenAddresses, swapRouterAddress);
  const paymasterInstance = await impactPaymaster.deployed();
  paymasterInstance.setTrustedForwarder(forwarderAddress);
  paymasterInstance.setRelayHub(relayHubAddress);
  console.log("Impact Paymaster contract deployed to:", impactPaymaster.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
