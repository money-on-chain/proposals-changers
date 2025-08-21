// scripts/remove_panic_button/verify.js (ESM)
import hre from "hardhat";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { parseUnits } from "ethers";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const MAP_TX = {
  MINT_BPRO_FEES_RBTC: 1,  REDEEM_BPRO_FEES_RBTC: 2,
  MINT_DOC_FEES_RBTC: 3,   REDEEM_DOC_FEES_RBTC: 4,
  MINT_BTCX_FEES_RBTC: 5,  REDEEM_BTCX_FEES_RBTC: 6,
  MINT_BPRO_FEES_MOC: 7,   REDEEM_BPRO_FEES_MOC: 8,
  MINT_DOC_FEES_MOC: 9,    REDEEM_DOC_FEES_MOC: 10,
  MINT_BTCX_FEES_MOC: 11,  REDEEM_BTCX_FEES_MOC: 12,
};
const toRay = (x) => parseUnits(String(x), 18).toString();

function selectedNetworkName(hre) {
  return hre.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? 'hardhat';
}

function loadConfig(networkName) {
  const cfgPath =
    process.env.DEPLOY_CONFIG_PATH ??
    path.join(__dirname, `../../config/fees_and_bitprorate/deployConfig-${networkName}.json`);
  if (!fs.existsSync(cfgPath)) throw new Error(`Config not found: ${cfgPath}`);
  return { cfgPath, cfg: JSON.parse(fs.readFileSync(cfgPath, "utf8")) };
}

async function main() {
  
  const net = selectedNetworkName(hre);
  const { cfg } = loadConfig(net);

  const address = process.env.VERIFY_ADDRESS || cfg.changerAddress;
  if (!address) throw new Error("Missing address: set VERIFY_ADDRESS or cfg.changerAddress");

  const commissions = Object.keys(MAP_TX).map((k) => [MAP_TX[k], toRay(cfg.commissionRates[k])]);
  const constructorArgs = [cfg.MoCInrate, toRay(cfg.bitProRate), commissions];

  console.log("Verifying...");
  console.log("  Network:", net);
  console.log("  Address:", address);
  
  await verifyContract(
    {
      address,
      constructorArgs,
      provider: "blockscout"
    },
    hre
  );

  console.log("✔ Verification request submitted.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
