/**
 * Validates the on-chain, constructor-loaded state of the deployed changer *before* governance vote.
 *
 * Config resolution order:
 *  1) DEPLOY_CONFIG_PATH env var (absolute or relative to cwd)
 *  2) <repoRoot>/config/fees_and_bitprorate/deployConfig-<network>.json
 *
 * Checks performed:
 *  - Target addresses (MoCInrate, RocV2)
 *  - bitProRate (1e18 precision)
 *  - MoC V1 commissions: length, txType mapping, and fee values
 *  - ROC V2 fees: keys present and values
 *
 * Compatible with Hardhat v3 (ESM). Uses human-friendly getters:
 *   - changer.getCommissionRates() → (txType, fee)[]
 *   - changer.getRocV2Fees()      → (key, value)[]
 */

import fs from "fs";
import hre from "hardhat";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");

// --- MoC V1 txType map (must match on-chain ids) ---------------------------
const MAP_TX_V1 = {
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

// --- ROC V2 fee enum key map (RocV2FeeKey) --------------------------------
// Accept both TitleCase (enum labels) and camelCase (setter-style) keys.
const MAP_ROCV2_KEY = {
  TcMintFee: 0,
  TcRedeemFee: 1,
  SwapTPforTPFee: 2,
  SwapTPforTCFee: 3,
  SwapTCforTPFee: 4,
  RedeemTCandTPFee: 5,
  MintTCandTPFee: 6,
  FeeTokenPct: 7,

  // aliases
  tcMintFee: 0,
  tcRedeemFee: 1,
  swapTPforTPFee: 2,
  swapTPforTCFee: 3,
  swapTCforTPFee: 4,
  redeemTCandTPFee: 5,
  mintTCandTPFee: 6,
  feeTokenPct: 7,
};

// --- HH3 helpers -----------------------------------------------------------
function selectedNetworkName(hre_) {
  return hre_.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? "hardhat";
}
function defaultConfigPath(root, networkName) {
  return path.join(root, "config", "fees_and_bitprorate", `deployConfig-${networkName}.json`);
}
function resolveConfigPath(hre_, root) {
  const fromEnv = process.env.DEPLOY_CONFIG_PATH;
  return fromEnv
    ? path.isAbsolute(fromEnv)
      ? fromEnv
      : path.resolve(fromEnv)
    : defaultConfigPath(root, selectedNetworkName(hre_));
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

  const toRay = (x) => ethers.parseUnits(String(x), 18);
  const pretty = (v) => ethers.formatUnits(v, 18);

  const changer = await ethers.getContractAt("FeesAndBitprorateProposal", cfg.changerAddress);

  // --- Read on-chain values via view getters --------------------------------
  const onInrate = await changer.mocInrate();
  const onRocV2 = await changer.rocV2();
  const onRate = await changer.bitProRate();

  const v1List = await changer.getCommissionRates(); // array of tuples: [txType, fee]
  const v2List = await changer.getRocV2Fees(); // array of tuples: [key(enum uint8), value]

  // --- Header ----------------------------------------------------------------
  console.log("Selected network:", net);
  console.log("Config file      :", cfgPath);
  console.log("Changer          :", changer.target);
  console.log("mocInrate (on-chain):", onInrate);
  console.log("rocV2    (on-chain):", onRocV2);
  console.log("bitProRate (on-chain 1e18):", onRate.toString(), `(~ ${pretty(onRate)})`);
  console.log("MoC V1 commissions count  :", v1List.length);
  console.log("ROC V2 fees count         :", v2List.length);
  console.log();

  // --- Address checks --------------------------------------------------------
  console.log(
    eqAddr(onInrate, cfg.MoCInrate)
      ? "OK. mocInrate matches config"
      : `ERROR. mocInrate mismatch (on=${onInrate}, cfg=${cfg.MoCInrate})`,
  );
  console.log(
    eqAddr(onRocV2, cfg.RocV2)
      ? "OK. rocV2 matches config"
      : `ERROR. rocV2 mismatch (on=${onRocV2}, cfg=${cfg.RocV2})`,
  );

  // --- bitProRate check ------------------------------------------------------
  const expRate = toRay(cfg.bitProRate);
  console.log(
    onRate === expRate
      ? `OK. bitProRate matches (raw=${onRate.toString()} ~ ${pretty(onRate)})`
      : `ERROR. bitProRate mismatch (on=${onRate.toString()} ~ ${pretty(
          onRate,
        )}, exp=${expRate.toString()} ~ ${pretty(expRate)})`,
  );
  console.log();

  // --- MoC V1 commissions validation ----------------------------------------
  // Build expected map from config (txType -> fee)
  const expV1 = {};
  for (const [name, txType] of Object.entries(MAP_TX_V1)) {
    const v = cfg.commissionRates?.[name];
    if (v === undefined || v === null) {
      console.log(`ERROR. Missing commissionRates.${name} in config`);
      continue;
    }
    expV1[txType] = toRay(v);
  }

  if (v1List.length === Object.keys(MAP_TX_V1).length) {
    console.log(`OK. commissionRates length = ${v1List.length}`);
  } else {
    console.log(
      `ERROR. commissionRates length = ${v1List.length}, expected ${Object.keys(MAP_TX_V1).length}`,
    );
  }

  // Check each on-chain entry by txType
  for (let i = 0; i < v1List.length; i++) {
    const [txTypeBN, feeBN] = v1List[i]; // ethers v6 tuple (BigInt, BigInt)
    const txType = Number(txTypeBN);
    const expFee = expV1[txType];
    const knownName = Object.entries(MAP_TX_V1).find(([, v]) => v === txType)?.[0] ?? "(unknown)";

    console.log(
      expFee !== undefined
        ? `OK.  V1[${i}] ${knownName} txType=${txType}`
        : `ERROR. V1[${i}] txType=${txType} is not expected by current MAP_TX_V1`,
    );

    if (expFee !== undefined) {
      console.log(
        feeBN === expFee
          ? `OK.  V1[${i}] ${knownName} fee (raw=${feeBN.toString()} ~ ${pretty(feeBN)})`
          : `ERROR. V1[${i}] ${knownName} fee mismatch (on=${feeBN.toString()} ~ ${pretty(
              feeBN,
            )}, exp=${expFee.toString()} ~ ${pretty(expFee)})`,
      );
    }
  }

  // Extra on-chain entries?
  if (v1List.length > Object.keys(MAP_TX_V1).length) {
    console.log(
      `WARN. commissions has ${
        v1List.length - Object.keys(MAP_TX_V1).length
      } extra entries beyond expected`,
    );
  }
  console.log();

  // --- ROC V2 fees validation ------------------------------------------------
  // Build expected map from config (enumKey -> value)
  const expV2 = {};
  for (const [key, val] of Object.entries(cfg.rocV2Fees || {})) {
    const enumId = MAP_ROCV2_KEY[key];
    if (enumId === undefined) {
      console.log(`ERROR. Unknown rocV2Fees key "${key}" in config`);
      continue;
    }
    expV2[enumId] = toRay(val);
  }

  // Check all on-chain entries
  for (let i = 0; i < v2List.length; i++) {
    const [keyBN, valueBN] = v2List[i];
    const enumId = Number(keyBN);
    const expVal = expV2[enumId];

    const friendlyName =
      Object.entries(MAP_ROCV2_KEY).find(([, id]) => id === enumId)?.[0] ?? `(enum ${enumId})`;

    console.log(
      expVal !== undefined
        ? `OK.  ROCV2[${i}] ${friendlyName} present`
        : `WARN. ROCV2[${i}] ${friendlyName} not found in config (might be extra on-chain entry)`,
    );

    if (expVal !== undefined) {
      console.log(
        valueBN === expVal
          ? `OK.  ROCV2[${i}] ${friendlyName} value (raw=${valueBN.toString()} ~ ${pretty(
              valueBN,
            )})`
          : `ERROR. ROCV2[${i}] ${friendlyName} mismatch (on=${valueBN.toString()} ~ ${pretty(
              valueBN,
            )}, exp=${expVal.toString()} ~ ${pretty(expVal)})`,
      );
    }
  }

  // Missing expected entries?
  const onKeys = new Set(v2List.map(([k]) => Number(k)));
  for (const [key, enumId] of Object.entries(MAP_ROCV2_KEY)) {
    if (cfg.rocV2Fees?.[key] !== undefined && !onKeys.has(enumId)) {
      console.log(`ERROR. ROCV2 expected key "${key}" (id=${enumId}) not found on changer blob`);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
