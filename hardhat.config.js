require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

const fs = require("fs");
const privateKey = fs.readFileSync(".secret").toString();
const projectId = "959dde76f6ab4023870800531d390fc6";

module.exports = {
  networks: {
    hardhat: {
      chainId: 1337
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${projectId}`,
      accounts: [privateKey]
    },
    poly_mainnet: {
      url: `https://polygon-mainnet.infura.io/v3/${projectId}`,
      accounts: [privateKey]
    },
    eth_mainnet: {
      url: `https://mainnet.infura.io/v3/${projectId}`,
      accounts: [privateKey]
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${projectId}`,
      accounts: [privateKey]
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${projectId}`,
      accounts: [privateKey]
    }
  },
  etherscan: {
    apiKey: "4JHKY445WD2PAADWD1VT6JQY2EVAYYUUH1"
  },
  solidity: {
    compilers: [
      {
        version: "0.8.4"
      }
    ]
  },
};
