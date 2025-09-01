/* eslint-disable no-console */
/**
 * Validates the on-chain storage of the deployed changer *before* governance vote.
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
const eqAddr = (a, b) => String(a).toLowerCase() === String(b).toLowerCase();

async function main() {
  const { ethers } = await hre.network.connect();

  const net = selectedNetworkName(hre);
  const cfgPath = resolveConfigPath(hre, repoRoot);
  const cfg = loadConfigOrDie(cfgPath);

  if (!cfg.changerAddress) throw new Error(`changerAddress missing in ${cfgPath} (deploy first).`);

  const changer = await ethers.getContractAt("RemovePanicButtonProposal", cfg.changerAddress);
  const onMoc = await changer.moc();

  console.log("Selected network:", net);
  console.log("Config file:", cfgPath);
  console.log("Changer:", changer.target);
  console.log("moc       (on-chain):", onMoc);

  console.log(
    eqAddr(onMoc, cfg.MoC)
      ? "OK. moc matches config"
      : `ERROR. moc mismatch (on=${onMoc}, cfg=${cfg.MoC})`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
