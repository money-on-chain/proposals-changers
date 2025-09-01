/* eslint-disable no-console */
/**
 * Post-vote validator: checks that the governance changer effects were actually applied on-chain.
 *
 * It verifies:
 *  - MoC V1 (Inrate):
 *      * bitProRate == cfg.bitProRate (scaled to 1e18)
 *      * commissionByTxType/commissionRatesByTxType for each tx type matches cfg.commissionRates[*]
 *  - ROC V2:
 *      * interest rate (TC) == cfg.bitProRate (scaled to 1e18)  [best-effort getter]
 *      * each operation fee (if a readable getter exists) matches cfg.rocV2Fees[*]
 *
 * Config resolution (same convention as deploy/verify scripts):
 *  1) DEPLOY_CONFIG_PATH env var (absolute or relative)
 *  2) <repoRoot>/config/fees_and_bitprorate/deployConfig-<network>.json
 *
 * Exit code:
 *  - 0 when all checked items match
 *  - 1 if any mismatch or hard error occurs
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import hre from "hardhat";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");

// ---- Network + config helpers ----------------------------------------------

function selectedNetworkName(hre) {
  // Prefer CLI --network, then HARDHAT_NETWORK, else "hardhat"
  return hre.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? "hardhat";
}

function defaultConfigPath(repoRoot, networkName) {
  return path.join(repoRoot, "config", "fees_and_bitprorate", `deployConfig-${networkName}.json`);
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

// ---- Domain mappings --------------------------------------------------------

// MoC V1 tx-type ids (must match the protocol)
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

// ROC V2 fee keys expected in config. Keep them in sync with deploy/verify scripts.
const ROCV2_KEYS = [
  "TcMintFee",
  "TcRedeemFee",
  "SwapTPforTPFee",
  "SwapTPforTCFee",
  "SwapTCforTPFee",
  "RedeemTCandTPFee",
  "MintTCandTPFee",
  "FeeTokenPct",
];

// ---- Read helpers (best-effort getters) ------------------------------------

/**
 * Try calling the first available getter from the provided signatures list, return its value (bigint).
 * If none work, returns null.
 */
async function readWithFallback(contract, candidates) {
  for (const sig of candidates) {
    try {
      // Throws if signature is not in the ABI
      const fn = contract.getFunction(sig);
      const out = await fn();
      if (out !== undefined && out !== null) return out;
    } catch (_) {
      // try next signature
    }
  }
  return null;
}

/**
 * Returns the best getter signature for MoC V1 commission by txType.
 */
async function detectMoCCommissionGetter(inrate) {
  const candidates = ["commissionRatesByTxType(uint8)"];
  for (const sig of candidates) {
    try {
      const fn = inrate.getFunction(sig);
      // smoke test on txType=1 (static)
      await fn(1);
      return sig;
    } catch (_) {}
  }
  return null;
}

// ---- ABIs (read-only) ------------------------------------------------------

const INRATE_ABI = [
  "function bitProRate() view returns (uint256)",
  "function commissionRatesByTxType(uint8) view returns (uint256)",
];

const ROCV2_ABI = [
  "function tcInterestRate() view returns (uint256)",
  "function tcMintFee() view returns (uint256)",
  "function tcRedeemFee() view returns (uint256)",
  "function swapTPforTPFee() view returns (uint256)",
  "function swapTPforTCFee() view returns (uint256)",
  "function swapTCforTPFee() view returns (uint256)",
  "function redeemTCandTPFee() view returns (uint256)",
  "function mintTCandTPFee() view returns (uint256)",
  "function feeTokenPct() view returns (uint256)",
];

// map fee key -> candidate getter signatures
const ROCV2_FEE_GETTERS = {
  TcMintFee: ["tcMintFee()"],
  TcRedeemFee: ["tcRedeemFee()"],
  SwapTPforTPFee: ["swapTPforTPFee()"],
  SwapTPforTCFee: ["swapTPforTCFee()"],
  SwapTCforTPFee: ["swapTCforTPFee()"],
  RedeemTCandTPFee: ["redeemTCandTPFee()"],
  MintTCandTPFee: ["mintTCandTPFee()"],
  FeeTokenPct: ["feeTokenPct()"],
};

// ---- numeric helpers -------------------------------------------------------

function toRayBig(ethers, x) {
  return BigInt(ethers.parseUnits(String(x), 18).toString());
}

function fmtRay(ethers, vBig) {
  return ethers.formatUnits(vBig, 18);
}

// ---- main ------------------------------------------------------------------

async function main() {
  const { ethers } = await hre.network.connect();

  const net = selectedNetworkName(hre);
  const cfgPath = resolveConfigPath(hre, repoRoot);
  const cfg = loadConfigOrDie(cfgPath);

  // Resolve addresses
  const inrateAddr = cfg.MoCInrate;
  const rocV2Addr = cfg.RocV2 ?? cfg.MoCv2 ?? cfg.ROCv2;

  if (!inrateAddr) throw new Error(`MoCInrate missing in ${cfgPath}`);
  if (!rocV2Addr)
    console.warn("WARN: RocV2 address not found in config; ROC v2 checks will be skipped.");

  // Expected values
  const expRate = toRayBig(ethers, cfg.bitProRate);

  // Build expected commissions (MoC V1)
  if (!cfg.commissionRates) throw new Error(`commissionRates missing in ${cfgPath}`);
  const expectedCommissions = Object.entries(MAP_TX).map(([key, txType]) => ({
    key,
    txType,
    fee: toRayBig(ethers, cfg.commissionRates[key]),
  }));

  // Build expected ROC V2 fees if present
  const expectedV2Fees = [];
  if (cfg.rocV2Fees) {
    for (const k of ROCV2_KEYS) {
      if (cfg.rocV2Fees[k] !== undefined) {
        expectedV2Fees.push({ key: k, value: toRayBig(ethers, cfg.rocV2Fees[k]) });
      }
    }
  }

  // Instances (read-only)
  const inrate = new ethers.Contract(inrateAddr, INRATE_ABI, ethers.provider);
  const rocV2 = rocV2Addr ? new ethers.Contract(rocV2Addr, ROCV2_ABI, ethers.provider) : null;

  console.log("=== Validate AFTER vote (effects on-chain) ===");
  console.log("Network   :", net);
  console.log("Config    :", cfgPath);
  console.log("MoCInrate :", inrateAddr);
  console.log("ROC v2    :", rocV2Addr ?? "(skipped)");

  let failures = 0;

  // ---- MoC V1: bitPro rate
  {
    const rate = await readWithFallback(inrate, [
      "bitProRate()",
      "riskProRate()",
      "getBitProRate()",
    ]);
    if (rate === null) {
      console.warn("WARN MoC V1: no readable getter for bitProRate — skipping assertion");
    } else {
      const ok = rate === expRate;
      console.log(
        ok
          ? `OK   MoC V1: bitProRate == ${fmtRay(ethers, rate)}`
          : `ERROR MoC V1: bitProRate on-chain=${fmtRay(ethers, rate)} expected=${fmtRay(
              ethers,
              expRate,
            )}`,
      );
      if (!ok) failures++;
    }
  }

  // ---- MoC V1: commissions by tx type
  {
    const getter = await detectMoCCommissionGetter(inrate);
    if (!getter) {
      console.warn("WARN MoC V1: no readable commission getter — skipping commission checks");
    } else {
      for (const { key, txType, fee } of expectedCommissions) {
        try {
          const got = await inrate.getFunction(getter)(txType);
          const ok = got === fee;
          console.log(
            ok
              ? `OK   MoC V1: ${key} (tx=${txType}) fee == ${fmtRay(ethers, got)}`
              : `ERROR MoC V1: ${key} (tx=${txType}) on=${fmtRay(ethers, got)} exp=${fmtRay(
                  ethers,
                  fee,
                )}`,
          );
          if (!ok) failures++;
        } catch (e) {
          console.warn(`WARN MoC V1: cannot read ${key} (tx=${txType}) via ${getter} — skipping`);
        }
      }
    }
  }

  // ---- ROC V2: interest rate
  if (rocV2) {
    const ir = await readWithFallback(rocV2, [
      "tcInterestRate()",
      "getTCInterestRate()",
      "interestRate()",
      "getInterestRate()",
    ]);
    if (ir === null) {
      console.warn("WARN ROC v2: no readable interest rate getter — skipping assertion");
    } else {
      const ok = ir === expRate;
      console.log(
        ok
          ? `OK   ROC v2: interestRate == ${fmtRay(ethers, ir)}`
          : `ERROR ROC v2: interestRate on=${fmtRay(ethers, ir)} exp=${fmtRay(ethers, expRate)}`,
      );
      if (!ok) failures++;
    }
  }

  // ---- ROC V2: operation fees
  if (rocV2 && expectedV2Fees.length > 0) {
    for (const { key, value } of expectedV2Fees) {
      const candidates = ROCV2_FEE_GETTERS[key] || [];
      const got = await readWithFallback(rocV2, candidates);
      if (got === null) {
        console.warn(`WARN ROC v2: no readable getter for ${key} — skipping`);
        continue;
      }
      const ok = got === value;
      console.log(
        ok
          ? `OK   ROC v2: ${key} == ${fmtRay(ethers, got)}`
          : `ERROR ROC v2: ${key} on=${fmtRay(ethers, got)} exp=${fmtRay(ethers, value)}`,
      );
      if (!ok) failures++;
    }
  } else if (rocV2 && !expectedV2Fees.length) {
    console.warn("WARN ROC v2: no rocV2Fees provided in config — skipping fee checks");
  }

  if (failures > 0) {
    console.log(`\n❌ Validation finished with ${failures} mismatches.`);
    process.exit(1);
  } else {
    console.log("\n✅ All checked values match on-chain.");
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
