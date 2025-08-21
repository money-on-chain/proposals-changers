// hardhat.config.js (ESM)
//import 'dotenv/config';
import 'dotenv-safe/config';
//import '@nomicfoundation/hardhat-ethers';
//import '@nomicfoundation/hardhat-ethers-chai-matchers';

import * as hardhatEthersMod from '@nomicfoundation/hardhat-ethers';
import * as toolboxMochaEthersMod from '@nomicfoundation/hardhat-toolbox-mocha-ethers';

const hardhatEthers = hardhatEthersMod.default ?? hardhatEthersMod;
const hardhatToolboxMochaEthers = toolboxMochaEthersMod.default ?? toolboxMochaEthersMod;



export default {
  plugins: [hardhatEthers, hardhatToolboxMochaEthers],
  solidity: {
    compilers: [
      {
        version: '0.8.24',
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
    ],
  },
  networks: {
    // Red local/embebida (opcional)
    hardhat: {
      type: 'edr-simulated', // la nueva “hardhat network” en Hardhat v3
    },

    // RSK Testnet (HTTP RPC)
    rskAlphaTestnet: {
      type: 'http',                         
      url: process.env.RPC_URL_RSK_TESTNET, // ej: https://public-node.testnet.rsk.co
      chainId: 31,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      // gasPrice: 60000000n, // opcional (wei)
    },

    // RSK Testnet (HTTP RPC)
    rskTestnet: {
      type: 'http',                         
      url: process.env.RPC_URL_RSK_TESTNET, // ej: https://public-node.testnet.rsk.co
      chainId: 31,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      // gasPrice: 60000000n, // opcional (wei)
    },

    // RSK Mainnet (HTTP RPC)
    rskMainnet: {
      type: 'http',                        
      url: process.env.RPC_URL_RSK_MAINNET,
      chainId: 30,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  /*etherscan: {
    apiKey: {
      rskAlphaTestnet: 'abc',
      rskMainnet: 'abc',
    },
    customChains: [
      {
        network: 'rskAlphaTestnet',
        chainId: 31,
        urls: {
          apiURL: 'https://rootstock-testnet.blockscout.com/api',
          browserURL: 'https://rootstock-testnet.blockscout.com',
        },
      },
      {
        network: 'rskTestnet',
        chainId: 31,
        urls: {
          apiURL: 'https://rootstock-testnet.blockscout.com/api',
          browserURL: 'https://rootstock-testnet.blockscout.com',
        },
      },
      {
        network: 'rskMainnet',
        chainId: 30,
        urls: {
          apiURL: 'https://rootstock.blockscout.com/api',
          browserURL: 'https://rootstock.blockscout.com',
        },
      },
    ],
  },*/
};
