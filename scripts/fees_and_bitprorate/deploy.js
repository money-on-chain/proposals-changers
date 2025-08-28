/* eslint-disable no-console */
/**
 * Deploys the FeesAndBitprorateProposal changer using parameters from a JSON file.
 * Config resolution order:
 *  1) DEPLOY_CONFIG_PATH env var (absolute or relative to cwd)
 *  2) <repoRoot>/config/fees_and_bitprorate/deployConfig-<network>.json
 *
 * Expected config shape (example):
 * {
 *   "MoCInrate": "0x....",
 *   "RocV2": "0x....",
 *   "bitProRate": 0.000098,
 *   "commissionRates": {
 *     "MINT_BPRO_FEES_RBTC": 0.0015,
 *     "REDEEM_BPRO_FEES_RBTC": 0.0015,
 *     ...
 *   },
 *   "rocV2Fees": {
 *     // you may use either TitleCase (enum labels) or camelCase (setter-style) keys:
 *     "TcMintFee": 0.0015,           // preferred
 *     "tcRedeemFee": 0.0015,         // also accepted
 *     "SwapTPforTPFee": 0.0012,
 *     "SwapTPforTCFee": 0.0012,
 *     "SwapTCforTPFee": 0.0012,
 *     "RedeemTCandTPFee": 0.0012,
 *     "MintTCandTPFee": 0.0012,
 *     "FeeTokenPct": 0.50
 *   }
 * }
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import hre from 'hardhat';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..', '..');

// ----- Tx type mapping for MoC V1 (uint8). Must match on-chain ids -----
const MAP_TX_V1 = {
  MINT_BPRO_FEES_RBTC: 1,  REDEEM_BPRO_FEES_RBTC: 2,
  MINT_DOC_FEES_RBTC: 3,   REDEEM_DOC_FEES_RBTC: 4,
  MINT_BTCX_FEES_RBTC: 5,  REDEEM_BTCX_FEES_RBTC: 6,
  MINT_BPRO_FEES_MOC: 7,   REDEEM_BPRO_FEES_MOC: 8,
  MINT_DOC_FEES_MOC: 9,    REDEEM_DOC_FEES_MOC: 10,
  MINT_BTCX_FEES_MOC: 11,  REDEEM_BTCX_FEES_MOC: 12,
};

// ----- ROC V2 fee enum mapping (RocV2FeeKey) -----
// Accept both TitleCase enum labels and camelCase setter-style keys.
const MAP_ROCV2_KEY = {
  // Preferred (enum labels)
  TcMintFee: 0,
  TcRedeemFee: 1,
  SwapTPforTPFee: 2,
  SwapTPforTCFee: 3,
  SwapTCforTPFee: 4,
  RedeemTCandTPFee: 5,
  MintTCandTPFee: 6,
  FeeTokenPct: 7,

  // Aliases (camelCase commonly seen in configs)
  tcMintFee: 0,
  tcRedeemFee: 1,
  swapTPforTPFee: 2,
  swapTPforTCFee: 3,
  swapTCforTPFee: 4,
  redeemTCandTPFee: 5,
  mintTCandTPFee: 6,
  feeTokenPct: 7,
};

// ----- Hardhat v3 helpers -----
function selectedNetworkName(hre_) {
  return hre_.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? 'hardhat';
}
function defaultConfigPath(root, networkName) {
  return path.join(root, 'config', 'fees_and_bitprorate', `deployConfig-${networkName}.json`);
}
function resolveConfigPath(hre_, root) {
  const fromEnv = process.env.DEPLOY_CONFIG_PATH;
  return fromEnv ? (path.isAbsolute(fromEnv) ? fromEnv : path.resolve(fromEnv))
                 : defaultConfigPath(root, selectedNetworkName(hre_));
}
function loadConfigOrDie(cfgPath) {
  if (!fs.existsSync(cfgPath)) throw new Error(`Config not found: ${cfgPath}`);
  return JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
}
function assertAddress(name, value) {
  if (typeof value !== 'string' || !value.startsWith('0x') || value.length < 10) {
    throw new Error(`Invalid ${name} address in config: ${value}`);
  }
}

function buildV1Commissions(cfg, toRay, cfgPath) {
  const src = cfg.commissionRates || {};
  const out = [];
  for (const [key, txType] of Object.entries(MAP_TX_V1)) {
    const v = src[key];
    if (v === undefined || v === null) throw new Error(`Missing commissionRates.${key} in ${cfgPath}`);
    out.push({ txType, fee: toRay(v) });
  }
  if (out.length === 0) throw new Error('commissionRates produced an empty array');
  if (out.length > 50) throw new Error('commissionRates length must be between 1 and 50');
  return out;
}

function buildRocV2Fees(cfg, toRay, cfgPath) {
  const src = cfg.rocV2Fees || {};
  const out = [];

  for (const [key, val] of Object.entries(src)) {
    const enumId = MAP_ROCV2_KEY[key];
    if (enumId === undefined) {
      throw new Error(`Unknown rocV2Fees key "${key}" in ${cfgPath}`);
    }
    if (val === undefined || val === null) {
      throw new Error(`Missing value for rocV2Fees.${key} in ${cfgPath}`);
    }
    out.push({ key: enumId, value: toRay(val) });
  }

  if (out.length === 0) throw new Error('rocV2Fees produced an empty array');
  if (out.length > 50) throw new Error('rocV2Fees length must be between 1 and 50');
  // Optional: ensure we included all known keys (comment out if not mandatory)
  // const expectedCount = 8;
  // if (out.length !== expectedCount) throw new Error(`rocV2Fees should have ${expectedCount} entries`);
  return out;
}

async function main() {
  // Hardhat v3: obtain ethers from the connection
  const { ethers } = await hre.network.connect();

  const net = selectedNetworkName(hre);
  const cfgPath = resolveConfigPath(hre, repoRoot);
  const cfg = loadConfigOrDie(cfgPath);

  const toRay  = (x) => ethers.parseUnits(String(x), 18);
  const pretty = (v) => ethers.formatUnits(v, 18);

  const [signer] = await ethers.getSigners();
  const from = await signer.getAddress();

  console.log('Selected network:', net);
  console.log('Config file:', cfgPath);
  console.log('Deployer:', from);
  console.log('Balance (wei):', (await ethers.provider.getBalance(from)).toString());

  // Basic sanity checks
  assertAddress('MoCInrate', cfg.MoCInrate);
  assertAddress('RocV2', cfg.RocV2);
  if (cfg.bitProRate === undefined || cfg.bitProRate === null) {
    throw new Error(`bitProRate missing in ${cfgPath}`);
  }

  // Build constructor params
  const bitProRateRay = toRay(cfg.bitProRate);
  const v1Commissions = buildV1Commissions(cfg, toRay, cfgPath);
  const rocV2Fees     = buildRocV2Fees(cfg, toRay, cfgPath);

  console.log('MoCInrate:', cfg.MoCInrate);
  console.log('RocV2    :', cfg.RocV2);
  console.log('bitProRate (1e18):', bitProRateRay.toString(), `(~ ${pretty(bitProRateRay)})`);
  console.log('V1 commissions count:', v1Commissions.length);
  console.log('ROC V2 fees count   :', rocV2Fees.length);

  // Deploy
  const Factory = await ethers.getContractFactory('FeesAndBitprorateProposal');
  const changer = await Factory.deploy(cfg.MoCInrate, cfg.RocV2, bitProRateRay, v1Commissions, rocV2Fees);
  const rcpt = await changer.deploymentTransaction().wait();

  console.log('Changer deployed at:', changer.target);
  console.log('Gas used:', rcpt.gasUsed.toString());

  // Quick read-back (human-friendly getters)
  const storedRate = await changer.bitProRate();
  const onV1 = await changer.getCommissionRates();
  const onV2 = await changer.getRocV2Fees();

  console.log('bitProRate (on-chain 1e18):', storedRate.toString(), `(~ ${pretty(storedRate)})`);
  console.log('getCommissionRates():', onV1.length, 'items');
  console.log('getRocV2Fees()     :', onV2.length, 'items');

  // Persist address
  cfg.changerAddress = changer.target;
  fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2));
  console.log('Config updated with changerAddress.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
