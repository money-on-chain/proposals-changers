// test/fork/remove_panic_button.fork.spec.js
import { expect } from 'chai';
import hre from 'hardhat';
import fs from 'fs';
import path from 'path';

const { ethers } = await hre.network.connect();


// --- Helpers ---------------------------------------------------------------

function loadCfg() {
  const net = process.env.FORK_NETWORK_NAME || hre.network.name;
  const p = path.join(process.cwd(), `config/remove_panic_button/deployConfig-${net}.json`);
  if (!fs.existsSync(p)) throw new Error(`Config not found: ${p}`);
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}


// Impersona una cuenta en Hardhat (fork)
async function impersonate(address) {
  await hre.network.provider.request({ method: 'hardhat_impersonateAccount', params: [address] });
  return await ethers.getSigner(address);
}

// --- ABI mínimos (solo lo que usamos para el fork) -------------------------

const MOC_ABI = [
  // algunos MoC deployments tienen esto, otros no; no lo usamos estrictamente
  'function makeUnstoppable() external',
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
    const moc    = new ethers.Contract(cfg.MoC,       MOC_ABI,   ethers.provider);
    
    // Deploy changer apuntando a los contratos reales
    const Changer = await ethers.getContractFactory('RemovePanicButtonProposal');    
    const changer = await Changer.deploy(cfg.MoC);

    // Ejecutar via Governor, impersonando al owner
    const govSigner = await impersonate(cfg.governorOwnerAddress);
    const governor  = new ethers.Contract(cfg.Governor, GOVERNOR_ABI, govSigner);

    const tx = await governor.executeChange(changer.target);
    const rc = await tx.wait();

    // Fuse quemado en el changer (siempre chequeable)    
    expect(await changer.moc()).to.equal(ethers.ZeroAddress);

    // Eventos del changer (siempre chequeables)
    const iface = (await ethers.getContractFactory('RemovePanicButtonProposal')).interface;
    const names = rc.logs
      .filter((l) => l.address.toLowerCase() === changer.target.toLowerCase())
      .map((log) => { try { return iface.parseLog(log).name; } catch { return 'UNKNOWN'; } });
    
    expect(names).to.include('PanicButtonRemoved');
    expect(names).to.include('ExecutedOnce');
    
  });

  it('direct changer.execute() should revert (access control)', async () => {
    const cfg = loadCfg();

    const Changer = await ethers.getContractFactory('RemovePanicButtonProposal');
    
    const changer = await Changer.deploy(cfg.MoC);

    // 🔁 Nuevo matcher en HH3: use `.revert(ethers)` (no `.reverted`)
    await expect(changer.execute()).to.revert(ethers);
    // Si querés chequear el reason exacto (si lo hay):
    // await expect(changer.execute()).to.revertWith(ethers, 'Only governor');
  });
});
