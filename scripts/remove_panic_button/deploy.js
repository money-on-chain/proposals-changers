/* eslint-disable no-console */
/**
 * Deploys the RemovePanicButtonProposal changer using parameters from a JSON file.
 * Config resolution:
 *  1) DEPLOY_CONFIG_PATH env var
 *  2) <repoRoot>/config/remove_panic_button/deployConfig-<network>.json
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import hre from "hardhat";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");

// Tx type mapping (uint8). Must match on-chain ids
const MAP_TX = {
  MINT_BPRO_FEES_RBTC: 1,
  REDEEM_BPRO_FEES_RBTC: 2,
  MINT_DOC_FEES_RBTC: 3,
  REDEEM_DOC_FEES_RBTC: 4,
  MINT_BTCX_FEES_RBTC: 5,
  REDEEM_BTCX_FEES_RBTC: 6,
  MINT_BPRO_FEES_MOC: 7,
  REDEEM_BPRO_FEES_MOC: 8,
  MINT_DOC_FEES_MOC: 9,
  REDEEM_DOC_FEES_MOC: 10,
  MINT_BTCX_FEES_MOC: 11,
  REDEEM_BTCX_FEES_MOC: 12,
};

// ----- HH3 helpers -----
function selectedNetworkName(hre) {
  return hre.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? "hardhat";
}
function defaultConfigPath(repoRoot, networkName) {
  return path.join(repoRoot, "config", "remove_panic_button", `deployConfig-${networkName}.json`);
}
function resolveConfigPath(hre, repoRoot) {
  const fromEnv = process.env.DEPLOY_CONFIG_PATH;
  return fromEnv
    ? path.isAbsolute(fromEnv)
      ? fromEnv
      : path.resolve(fromEnv)
    : defaultConfigPath(repoRoot, selectedNetworkName(hre));
}
function loadConfigOrDie(cfgPath) {
  if (!fs.existsSync(cfgPath)) throw new Error(`Config not found: ${cfgPath}`);
  return JSON.parse(fs.readFileSync(cfgPath, "utf8"));
}
function assertAddress(name, value) {
  if (typeof value !== "string" || !value.startsWith("0x") || value.length < 10) {
    throw new Error(`Invalid ${name} address in config: ${value}`);
  }
}

async function main() {
  // HH3: obtain ethers from the connection
  const { ethers } = await hre.network.connect();

  const net = selectedNetworkName(hre);
  const cfgPath = resolveConfigPath(hre, repoRoot);
  const cfg = loadConfigOrDie(cfgPath);

  const [signer] = await ethers.getSigners();
  const from = await signer.getAddress();

  console.log("Selected network:", net);
  console.log("Config file:", cfgPath);
  console.log("Deployer:", from);
  console.log("Balance (wei):", (await ethers.provider.getBalance(from)).toString());

  assertAddress("MoC", cfg.MoC);
  console.log("MoC:", cfg.MoC);

  const Factory = await ethers.getContractFactory("RemovePanicButtonProposal");
  const changer = await Factory.deploy(cfg.MoC);
  const rcpt = await changer.deploymentTransaction().wait();

  console.log("Changer deployed at:", changer.target);
  console.log("Gas used:", rcpt.gasUsed.toString());

  cfg.changerAddress = changer.target;
  fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2));
  console.log("Config updated with changerAddress.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
