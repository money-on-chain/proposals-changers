import type { HardhatUserConfig } from "hardhat/config";

import hardhatEthers from "@nomicfoundation/hardhat-ethers";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import { configVariable } from "hardhat/config";

import { config as dotenvConfig } from "dotenv";
dotenvConfig();

const config: HardhatUserConfig = {
  plugins: [hardhatEthers, hardhatToolboxMochaEthers, hardhatVerify],
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
    ],
  },
  networks: {
    // Red local/embebida (opcional)
    hardhat: {
      type: "edr-simulated",
      forking: {
        url: configVariable("FORK_URL"), // <- needit
        blockNumber: process.env.FORK_BLOCK ? Number(process.env.FORK_BLOCK) : undefined,
        // headers y timeout opcionales si usás un RPC público que a veces demora:
        // httpHeaders: { /* ... */ },
        // timeout: 120000,
      },
    },

    // RSK Testnet (HTTP RPC)
    rskAlphaTestnet: {
      type: "http",
      url: process.env.RPC_URL_RSK_TESTNET, // ej: https://public-node.testnet.rsk.co
      chainId: 31,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      // gasPrice: 60000000n, // opcional (wei)
    },

    // RSK Testnet (HTTP RPC)
    rskTestnet: {
      type: "http",
      url: process.env.RPC_URL_RSK_TESTNET, // ej: https://public-node.testnet.rsk.co
      chainId: 31,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      // gasPrice: 60000000n, // opcional (wei)
    },

    // RSK Mainnet (HTTP RPC)
    rskMainnet: {
      type: "http",
      url: process.env.RPC_URL_RSK_MAINNET,
      chainId: 30,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  // ✅ En HH3 se usa `verify`, no `etherscan` toplevel
  verify: {
    // opcional: desactivar Etherscan si no lo usás
    etherscan: { enabled: false },
    // opcional: explicitar Blockscout (default: enabled)
    blockscout: { enabled: true },
  },
  chainDescriptors: {
    31: {
      name: "Rootstock Testnet",
      blockExplorers: {
        blockscout: {
          name: "Rootstock Testnet Blockscout",
          url: "https://rootstock-testnet.blockscout.com",
          apiUrl: "https://rootstock-testnet.blockscout.com/api",
        },
      },
    },
    30: {
      name: "Rootstock Mainnet",
      blockExplorers: {
        blockscout: {
          name: "Rootstock Blockscout",
          url: "https://rootstock.blockscout.com",
          apiUrl: "https://rootstock.blockscout.com/api",
        },
      },
    },
  },
};

export default config;
