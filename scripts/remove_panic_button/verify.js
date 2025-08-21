/* eslint-disable no-console */
/**
 * Verifies the deployed RemovePanicButtonProposal on the explorer.
 * Config resolution:
 *  1) DEPLOY_CONFIG_PATH env var
 *  2) <repoRoot>/config/remove_panic_button/deployConfig-<network>.json
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import hre from 'hardhat';
import { parseUnits } from 'ethers';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..', '..');

const MAP_TX = {
  MINT_BPRO_FEES_RBTC: 1,  REDEEM_BPRO_FEES_RBTC: 2,
  MINT_DOC_FEES_RBTC: 3,   REDEEM_DOC_FEES_RBTC: 4,
  MINT_BTCX_FEES_RBTC: 5,  REDEEM_BTCX_FEES_RBTC: 6,
  MINT_BPRO_FEES_MOC: 7,   REDEEM_BPRO_FEES_MOC: 8,
  MINT_DOC_FEES_MOC: 9,    REDEEM_DOC_FEES_MOC: 10,
  MINT_BTCX_FEES_MOC: 11,  REDEEM_BTCX_FEES_MOC: 12,
};

function selectedNetworkName(hre) {
  return hre.globalOptions?.network ?? process.env.HARDHAT_NETWORK ?? 'hardhat';
}
function defaultConfigPath(repoRoot, networkName) {
  return path.join(repoRoot, 'config', 'remove_panic_button', `deployConfig-${networkName}.json`);
}
function resolveConfigPath(hre, repoRoot) {
  const fromEnv = process.env.DEPLOY_CONFIG_PATH;
  return fromEnv ? (path.isAbsolute(fromEnv) ? fromEnv : path.resolve(fromEnv))
                 : defaultConfigPath(repoRoot, selectedNetworkName(hre));
}
function loadConfigOrDie(cfgPath) {
  if (!fs.existsSync(cfgPath)) throw new Error(`Config not found: ${cfgPath}`);
  return JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
}

const toRay = (x) => parseUnits(String(x), 18).toString();

function buildCommissionsFromConfig(cfg, cfgPath) {
  const src = cfg.commissionRates || {};
  const list = [];
  for (const [key, txType] of Object.entries(MAP_TX)) {
    const v = src[key];
    if (v === undefined || v === null) throw new Error(`Missing commissionRates.${key} in ${cfgPath}`);
    list.push([txType, toRay(v)]);
  }
  if (list.length === 0) throw new Error('commissionRates produced an empty array');
  if (list.length > 50) throw new Error('commissionRates length must be between 1 and 50');
  return list;
}

async function main() {
  const net = selectedNetworkName(hre);
  const cfgPath = resolveConfigPath(hre, repoRoot);
  const cfg = loadConfigOrDie(cfgPath);

  const address = process.env.VERIFY_ADDRESS || cfg.changerAddress;
  if (!address) {
    throw new Error(
      `Missing address to verify. Set VERIFY_ADDRESS env var or ensure changerAddress exists in ${cfgPath}`
    );
  }

  const commissions = buildCommissionsFromConfig(cfg, cfgPath);
  const constructorArgs = [cfg.MoCInrate, cfg.MoC, toRay(cfg.bitProRate), commissions];

  const maybeFqn = process.env.CONTRACT_FQN; // optionally force FQN

  console.log('Verifying...');
  console.log('  Network:', net);
  console.log('  Address:', address);
  console.log('  Config :', cfgPath);
  if (maybeFqn) console.log('  Contract FQN:', maybeFqn);

  const opts = { address, constructorArguments: constructorArgs };
  if (maybeFqn) opts.contract = maybeFqn;

  await hre.run('verify:verify', opts);
  console.log('✔ Verification request sent to explorer.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
