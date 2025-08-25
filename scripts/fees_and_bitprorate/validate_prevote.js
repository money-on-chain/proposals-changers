/* eslint-disable no-console */
/**
 * Validates the on-chain storage of the deployed changer *before* governance vote.
 * Config resolution:
 *  1) DEPLOY_CONFIG_PATH env var
 *  2) <repoRoot>/config/fees_and_bitprorate/deployConfig-<network>.json
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import hre from "hardhat";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");

const INDEX_TO_KEY = [
  ["MINT_BPRO_FEES_RBTC", 1],
  ["REDEEM_BPRO_FEES_RBTC", 2],
  ["MINT_DOC_FEES_RBTC", 3],
  ["REDEEM_DOC_FEES_RBTC", 4],
  ["MINT_BTCX_FEES_RBTC", 5],
  ["REDEEM_BTCX_FEES_RBTC", 6],
  ["MINT_BPRO_FEES_MOC", 7],
  ["REDEEM_BPRO_FEES_MOC", 8],
  ["MINT_DOC_FEES_MOC", 9],
  ["REDEEM_DOC_FEES_MOC", 10],
  ["MINT_BTCX_FEES_MOC", 11],
  ["REDEEM_BTCX_FEES_MOC", 12],
];

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

  const toRay = x => ethers.parseUnits(String(x), 18);
  const pretty = v => ethers.formatUnits(v, 18);

  const changer = await ethers.getContractAt("FeesAndBitprorateProposal", cfg.changerAddress);

  const onInrate = await changer.mocInrate();
  const onRate = await changer.bitProRate();
  const onLen = Number(await changer.commissionRatesLength());

  console.log("Selected network:", net);
  console.log("Config file:", cfgPath);
  console.log("Changer:", changer.target);
  console.log("mocInrate (on-chain):", onInrate);
  console.log("commissionRatesLength():", onLen);

  console.log(
    eqAddr(onInrate, cfg.MoCInrate)
      ? "OK. mocInrate matches config"
      : `ERROR. mocInrate mismatch (on=${onInrate}, cfg=${cfg.MoCInrate})`,
  );

  const expRate = toRay(cfg.bitProRate);
  console.log(
    onRate === expRate
      ? `OK. bitProRate matches (raw=${onRate.toString()} ~ ${pretty(onRate)})`
      : `ERROR. bitProRate mismatch (on=${onRate.toString()} ~ ${pretty(onRate)}, exp=${expRate.toString()} ~ ${pretty(expRate)})`,
  );

  console.log(
    onLen === INDEX_TO_KEY.length
      ? `OK. commissionRates length = ${onLen}`
      : `ERROR. commissionRates length = ${onLen}, expected ${INDEX_TO_KEY.length}`,
  );

  for (let i = 0; i < Math.min(onLen, INDEX_TO_KEY.length); i++) {
    const [key, expTx] = INDEX_TO_KEY[i];
    const tup = await changer.commissionRates(i); // [txType, fee]
    const txType = Number(tup[0]);
    const fee = tup[1];
    const expFee = toRay(cfg.commissionRates[key]);

    console.log(
      txType === expTx
        ? `OK.  ${i}. ${key} txType=${txType}`
        : `ERROR. ${i}. ${key} txType=${txType}, expected ${expTx}`,
    );

    console.log(
      fee === expFee
        ? `OK.  ${i}. ${key} fee (raw=${fee.toString()} ~ ${pretty(fee)})`
        : `ERROR. ${i}. ${key} fee mismatch (on=${fee.toString()} ~ ${pretty(fee)}, exp=${expFee.toString()} ~ ${pretty(expFee)})`,
    );
  }

  if (onLen > INDEX_TO_KEY.length) {
    console.log(`WARN. commissions has ${onLen - INDEX_TO_KEY.length} extra entries beyond expected`);
  }
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
