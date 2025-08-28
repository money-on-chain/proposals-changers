// scripts/fees_and_bitprorate/verify.js (ESM)
import hre from "hardhat";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

/**
 * Verifies FeesAndBitprorateProposal on Blockscout/Etherscan-compatible explorers.
 * Constructor args MUST be built exactly as in deploy.js for byte-for-byte match.
 *
 * Constructor:
 *   constructor(
 *     IMoCInrate _mocInrate,
 *     IMoCv2     _rocV2,
 *     uint256    _bitProRate,                  // 1e18 precision
 *     CommissionRates[] _commissionRates,      // [ { txType, fee }, ... ]
 *     RocV2FeeUpdate[]  _rocV2FeeBlob         // [ { key(enum uint8), value }, ... ]
 *   )
 */

// ---------------------------------------------------------------------------
// Paths / helpers
// ---------------------------------------------------------------------------
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function selectedNetworkName(hre_) {
  // Prefer CLI --network, then HARDHAT_NETWORK, else default "hardhat"
  return hre_.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? "hardhat";
}

function loadConfig(networkName) {
  // 1) DEPLOY_CONFIG_PATH overrides
  // 2) <repoRoot>/config/fees_and_bitprorate/deployConfig-<network>.json
  const cfgPath =
    process.env.DEPLOY_CONFIG_PATH ??
    path.join(__dirname, `../../config/fees_and_bitprorate/deployConfig-${networkName}.json`);
  if (!fs.existsSync(cfgPath)) throw new Error(`Config not found: ${cfgPath}`);
  const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
  return { cfgPath, cfg };
}

function requireKeys(obj, keys, prefix = "") {
  for (const k of keys) {
    if (obj[k] === undefined || obj[k] === null) {
      throw new Error(`Missing required key ${prefix}${k} in config`);
    }
  }
}

// Safe toRay helper (ethers v6 when available, BigInt fallback otherwise)
function toRay(value) {
  const s = String(value);
  if (hre.ethers?.parseUnits) return hre.ethers.parseUnits(s, 18).toString();
  if (!/^\d+(\.\d+)?$/.test(s)) throw new Error(`Non-numeric value for toRay: "${value}"`);
  if (!s.includes(".")) return (BigInt(s) * 10n ** 18n).toString();
  const [intPart, fracPartRaw] = s.split(".");
  const frac = (fracPartRaw + "000000000000000000").slice(0, 18);
  return (BigInt(intPart || "0") * 10n ** 18n + BigInt(frac || "0")).toString();
}

// ---------------------------------------------------------------------------
// On-chain mappings (must match deploy.js and contract expectations)
// ---------------------------------------------------------------------------

// MoC V1 commission txType map (uint8 ids)
const MAP_TX_V1 = {
  MINT_BPRO_FEES_RBTC: 1,  REDEEM_BPRO_FEES_RBTC: 2,
  MINT_DOC_FEES_RBTC: 3,   REDEEM_DOC_FEES_RBTC: 4,
  MINT_BTCX_FEES_RBTC: 5,  REDEEM_BTCX_FEES_RBTC: 6,
  MINT_BPRO_FEES_MOC: 7,   REDEEM_BPRO_FEES_MOC: 8,
  MINT_DOC_FEES_MOC: 9,    REDEEM_DOC_FEES_MOC: 10,
  MINT_BTCX_FEES_MOC: 11,  REDEEM_BTCX_FEES_MOC: 12,
};

// ROC V2 fee enum mapping (RocV2FeeKey)
// Accept both TitleCase (enum-like) and camelCase (setter-like) config keys
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

// Build MoC V1 commissions array as array-of-arrays (structs also work)
function buildCommissionsV1(cfg) {
  const src = cfg.commissionRates || {};
  // Deterministic order following MAP_TX_V1 (must match deploy script)
  return Object.entries(MAP_TX_V1).map(([name, txType]) => {
    const v = src[name];
    if (v === undefined || v === null) {
      throw new Error(`Missing commissionRates.${name} in config`);
    }
    return [txType, toRay(v)]; // corresponds to struct CommissionRates(uint8 txType, uint256 fee)
  });
}

// Build ROC V2 fee array (enum key, value) with a stable order
function buildRocV2Fees(cfg) {
  const src = cfg.rocV2Fees || {};
  const out = [];
  for (const [k, enumId] of Object.entries(MAP_ROCV2_KEY)) {
    if (src[k] === undefined || src[k] === null) continue;
    out.push([enumId, toRay(src[k])]); // corresponds to struct RocV2FeeUpdate(RocV2FeeKey key, uint256 value)
  }
  if (out.length === 0) {
    throw new Error("rocV2Fees is empty or has no recognized keys");
  }
  return out;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const net = selectedNetworkName(hre);
  const { cfgPath, cfg } = loadConfig(net);

  // Minimal config validation
  requireKeys(cfg, ["MoCInrate", "RocV2", "bitProRate", "commissionRates"]);
  requireKeys(cfg.commissionRates, Object.keys(MAP_TX_V1), "commissionRates.");
  if (!cfg.rocV2Fees || Object.keys(cfg.rocV2Fees).length === 0) {
    throw new Error("rocV2Fees missing or empty in config");
  }

  // Address to verify (env wins)
  const address = process.env.VERIFY_ADDRESS || cfg.changerAddress;
  if (!address) throw new Error("Missing address: set VERIFY_ADDRESS or cfg.changerAddress");

  // Build constructor args EXACTLY like deploy.js
  const commissionsV1 = buildCommissionsV1(cfg);
  const feesRocV2     = buildRocV2Fees(cfg);

  const constructorArgs = [
    cfg.MoCInrate,
    cfg.RocV2,
    toRay(cfg.bitProRate),
    commissionsV1,
    feesRocV2,
  ];

  // Choose verification provider; "blockscout" is appropriate for Rootstock
  const provider = process.env.VERIFY_PROVIDER || "blockscout";

  console.log("=== Verify FeesAndBitprorateProposal ===");
  console.log("Network         :", net);
  console.log("Config          :", cfgPath);
  console.log("Address         :", address);
  console.log("Provider        :", provider);
  console.log("Constructor args:");
  console.log("  MoCInrate     :", constructorArgs[0]);
  console.log("  RocV2         :", constructorArgs[1]);
  console.log("  bitProRate    :", cfg.bitProRate, "=>", constructorArgs[2]);
  console.log("  commissionsV1 :", JSON.stringify(commissionsV1, null, 2));
  console.log("  feesRocV2     :", JSON.stringify(feesRocV2, null, 2));

  await verifyContract(
    {
      address,
      constructorArgs,
      provider, // "blockscout" for Rootstock explorers
    },
    hre
  );

  console.log("✔ Verification request submitted.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
