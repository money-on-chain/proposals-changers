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

// Devuelve el primer getter que exista/funcione. Si ninguno, retorna null.
async function readWithFallback(contract, candidates) {
  for (const frag of candidates) {
    try {
      const fn = contract.getFunction(frag); // throws si no existe
      const out = await fn();
      if (out !== undefined && out !== null) return out;
    } catch (_) { /* try next */ }
  }
  return null;
}

// Nombre de getter para comisiones que encuentre en vivo
async function detectCommissionGetter(inrate) {
  const candidates = [
    'commissionByTxType(uint8)',
    'commissionRateByTxType(uint8)',
    'getCommissionRateByTxType(uint8)',
  ];
  for (const sig of candidates) {
    try {
      const fn = inrate.getFunction(sig);
      // Smoke test: llamar con txType=1 en static
      await fn(1);
      return sig;
    } catch (_) {}
  }
  return null;
}

// Impersona una cuenta en Hardhat (fork)
async function impersonate(address) {
  await hre.network.provider.request({ method: 'hardhat_impersonateAccount', params: [address] });
  return await ethers.getSigner(address);
}

// --- ABI mínimos (solo lo que usamos para el fork) -------------------------

const INRATE_ABI = [
  // setters usados por el changer (no los llamamos directamente en fork)
  'function setBitProRate(uint256 newBitProRate) external',
  'function setCommissionRateByTxType(uint8 txType, uint256 value) external',
  // posibles getters (algunos pueden no existir en on-chain)
  'function bitProRate() view returns (uint256)',
  'function riskProRate() view returns (uint256)',
  'function getBitProRate() view returns (uint256)',
  'function commissionByTxType(uint8) view returns (uint256)',
  'function commissionRateByTxType(uint8) view returns (uint256)',
  'function getCommissionRateByTxType(uint8) view returns (uint256)',
];

const GOVERNOR_ABI = [
  // patrón clásico de Money on Chain Governance
  'function executeChange(address changer) external',
];

// --- Tests -----------------------------------------------------------------

describe('Forked — RemovePanicButtonProposal', function () {
  it('executes through Governor (delegatecall) and updates live contracts (if ABI matches)', async () => {
    const cfg = loadCfg();

    // Attach a los contratos vivos en el fork
    const inrate = new ethers.Contract(cfg.MoCInrate, INRATE_ABI, ethers.provider);
    
    // Pre-state (best effort)
    const preRate = await readWithFallback(inrate, [
      'bitProRate()', 'riskProRate()', 'getBitProRate()',
    ]);
    const commGetter = await detectCommissionGetter(inrate);

    // Deploy changer apuntando a los contratos reales
    const Changer = await ethers.getContractFactory('FeesAndBitprorateProposal');
    const commissions = Object.entries(MAP_TX).map(([k, txType]) => ({
      txType,
      fee: toRay(cfg.commissionRates[k]),
    }));
    const changer = await Changer.deploy(cfg.MoCInrate, toRay(cfg.bitProRate), commissions);

    // Ejecutar via Governor, impersonando al owner
    const govSigner = await impersonate(cfg.governorOwnerAddress);
    const governor  = new ethers.Contract(cfg.Governor, GOVERNOR_ABI, govSigner);

    const tx = await governor.executeChange(changer.target);
    const rc = await tx.wait();

    // Fuse quemado en el changer (siempre chequeable)
    expect(await changer.mocInrate()).to.equal(ethers.ZeroAddress);
    
    // Eventos del changer (siempre chequeables)
    const iface = (await ethers.getContractFactory('FeesAndBitprorateProposal')).interface;
    const names = rc.logs
      .filter((l) => l.address.toLowerCase() === changer.target.toLowerCase())
      .map((log) => { try { return iface.parseLog(log).name; } catch { return 'UNKNOWN'; } });

    expect(names).to.include('BitProRateSet');    
    expect(names).to.include('ExecutedOnce');

    // Validación best-effort del rate (solo si existe getter on-chain)
    const postRate = await readWithFallback(inrate, [
      'bitProRate()', 'riskProRate()', 'getBitProRate()',
    ]);
    if (postRate !== null) {
      expect(postRate).to.equal(toRay(cfg.bitProRate));
      if (preRate !== null) expect(postRate).to.not.equal(preRate);
    } else {
      console.warn('[warn] No readable getter for bitProRate on forked target — skipping assertion');
    }

    // Validación best-effort de comisiones
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

    // 🔁 Nuevo matcher en HH3: use `.revert(ethers)` (no `.reverted`)
    await expect(changer.execute()).to.revert(ethers);
    // Si querés chequear el reason exacto (si lo hay):
    // await expect(changer.execute()).to.revertWith(ethers, 'Only governor');
  });
});
