// scripts/remove_panic_button/verify.js (ESM)
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
import fs from "fs";
import hre from "hardhat";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function selectedNetworkName(hre) {
  return hre.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? "hardhat";
}

function loadConfig(networkName) {
  const cfgPath =
    process.env.DEPLOY_CONFIG_PATH ??
    path.join(__dirname, `../../config/remove_panic_button/deployConfig-${networkName}.json`);
  if (!fs.existsSync(cfgPath)) throw new Error(`Config not found: ${cfgPath}`);
  return { cfgPath, cfg: JSON.parse(fs.readFileSync(cfgPath, "utf8")) };
}

async function main() {
  const net = selectedNetworkName(hre);
  const { cfg } = loadConfig(net);

  const address = process.env.VERIFY_ADDRESS || cfg.changerAddress;
  if (!address) throw new Error("Missing address: set VERIFY_ADDRESS or cfg.changerAddress");

  const constructorArgs = [cfg.MoC];

  console.log("Verifying...");
  console.log("  Network:", net);
  console.log("  Address:", address);

  await verifyContract(
    {
      address,
      constructorArgs,
      provider: "blockscout",
    },
    hre,
  );

  console.log("✔ Verification request submitted.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
