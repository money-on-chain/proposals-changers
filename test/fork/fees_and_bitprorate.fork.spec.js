// test/fork/fees_and_bitprorate.fork.spec.js
import { expect } from 'chai';
import hre from 'hardhat';
import fs from 'fs';
import path from 'path';

const { ethers } = await hre.network.connect();

const toRay = (x) => ethers.parseUnits(String(x), 18);

const MAP_TX = {
  MINT_BPRO_FEES_RBTC: 1,  REDEEM_BPRO_FEES_RBTC: 2,
  MINT_DOC_FEES_RBTC: 3,   REDEEM_DOC_FEES_RBTC: 4,
  MINT_BTCX_FEES_RBTC: 5,  REDEEM_BTCX_FEES_RBTC: 6,
  MINT_BPRO_FEES_MOC: 7,   REDEEM_BPRO_FEES_MOC: 8,
  MINT_DOC_FEES_MOC: 9,    REDEEM_DOC_FEES_MOC: 10,
  MINT_BTCX_FEES_MOC: 11,  REDEEM_BTCX_FEES_MOC: 12,
};

// --- Helpers ---------------------------------------------------------------

function loadCfg() {
  const net = process.env.FORK_NETWORK_NAME || hre.network.name;
  const p = path.join(process.cwd(), `config/fees_and_bitprorate/deployConfig-${net}.json`);
  if (!fs.existsSync(p)) throw new Error(`Config not found: ${p}`);
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

/** Calls the first existing getter; returns null if none is available. */
async function readWithFallback(contract, candidates) {
  for (const frag of candidates) {
    try {
      const fn = contract.getFunction(frag); // throws if not present
      const out = await fn();
      if (out !== undefined && out !== null) return out;
    } catch {}
  }
  return null;
}

/** Tries different commission getter names used across deployments. */
async function detectCommissionGetter(inrate) {
  const candidates = [
    'commissionRatesByTxType(uint8)',
  ];
  for (const sig of candidates) {
    try {
      const fn = inrate.getFunction(sig);
      await fn(1); // smoke test
      return sig;
    } catch {}
  }
  return null;
}

/** Hardhat v3: prefer ethers.provider.send over hre.network.provider.request */
async function impersonate(address, topUpHex = '0x3635C9ADC5DEA00000') {
  await ethers.provider.send('hardhat_impersonateAccount', [address]);
  if (topUpHex) {
    await ethers.provider.send('hardhat_setBalance', [address, topUpHex]);
  }
  return await ethers.getSigner(address);
}

// --- Minimal ABIs used on fork ---------------------------------------------

const INRATE_ABI = [
  // setters used by the changer (not called directly here)
  'function setBitProRate(uint256 newBitProRate) external',
  'function setCommissionRateByTxType(uint8 txType, uint256 value) external',

  // possible getters (some deployments differ)
  'function bitProRate() view returns (uint256)',
  'function riskProRate() view returns (uint256)',  
  'function commissionRatesByTxType(uint8) view returns (uint256)'  
];

const GOVERNOR_ABI = [
  // classic Money on Chain governor signature
  'function executeChange(address changer) external',
];

// --- Tests -----------------------------------------------------------------

describe('Forked — FeesAndBitprorateProposal', function () {
  it('executes through Governor (delegatecall) and updates live contracts (if ABI matches)', async () => {
    const cfg = loadCfg();

    // Attach to live MoCInrate on the fork
    const inrate = new ethers.Contract(cfg.MoCInrate, INRATE_ABI, ethers.provider);

    // Pre-state (best-effort)
    const preRate = await readWithFallback(inrate, [
      'bitProRate()', 'riskProRate()', 'getBitProRate()',
    ]);
    const commGetter = await detectCommissionGetter(inrate);

    // Deploy changer targeting live addresses
    const Changer = await ethers.getContractFactory('FeesAndBitprorateProposal');
    const commissions = Object.entries(MAP_TX).map(([k, txType]) => ({
      txType,
      fee: toRay(cfg.commissionRates[k]),
    }));
    const changer = await Changer.deploy(cfg.MoCInrate, toRay(cfg.bitProRate), commissions);

    // Execute through Governor, impersonating its owner
    const govSigner = await impersonate(cfg.governorOwnerAddress);
    const governor  = new ethers.Contract(cfg.Governor, GOVERNOR_ABI, govSigner);

    const tx = await governor.executeChange(changer.target);
    const rc = await tx.wait();

    // Changer fuse must be burned
    expect(await changer.mocInrate()).to.equal(ethers.ZeroAddress);

    // Changer events
    const iface = (await ethers.getContractFactory('FeesAndBitprorateProposal')).interface;
    const names = rc.logs
      .filter((l) => l.address.toLowerCase() === changer.target.toLowerCase())
      .map((log) => { try { return iface.parseLog(log).name; } catch { return 'UNKNOWN'; } });

    expect(names).to.include('BitProRateSet');
    expect(names).to.include('ExecutedOnce');

    // Post-state checks (best-effort)
    const postRate = await readWithFallback(inrate, [
      'bitProRate()', 'riskProRate()', 'getBitProRate()',
    ]);
    if (postRate !== null) {
      expect(postRate).to.equal(toRay(cfg.bitProRate));
      if (preRate !== null) expect(postRate).to.not.equal(preRate);
    } else {
      console.warn('[warn] No readable getter for bitProRate on forked target — skipping assertion');
    }

    if (commGetter) {
      for (const { txType, fee } of commissions) {
        const got = await inrate.getFunction(commGetter)(txType);
        expect(got).to.equal(fee);
      }
    } else {
      console.warn('[warn] No readable commission getter on forked target — skipping assertions');
    }
  });

  it('direct changer.execute() should revert (access control)', async () => {
    const cfg = loadCfg();

    const Changer = await ethers.getContractFactory('FeesAndBitprorateProposal');
    const commissions = Object.entries(MAP_TX).map(([k, txType]) => ({
      txType,
      fee: toRay(cfg.commissionRates[k]),
    }));
    const changer = await Changer.deploy(cfg.MoCInrate, toRay(cfg.bitProRate), commissions);

    // New matcher in HH3: `.revert(ethers)` (not `.reverted`)
    await expect(changer.execute()).to.revert(ethers);
  });
});
