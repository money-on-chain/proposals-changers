import { expect } from 'chai';
import hre from 'hardhat';

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

async function freshDeploy() {
  const InrateFactory = await ethers.getContractFactory('MoCInrateMock');  
  const inrate = await InrateFactory.deploy();
  
  const bitProRate = toRay('0.000098');

  const commissions = [
    { txType: MAP_TX.MINT_BPRO_FEES_RBTC,  fee: toRay('0.0015') },
    { txType: MAP_TX.REDEEM_BPRO_FEES_RBTC, fee: toRay('0.0015') },
    { txType: MAP_TX.MINT_DOC_FEES_RBTC,    fee: toRay('0.0015') },
    { txType: MAP_TX.REDEEM_DOC_FEES_RBTC,  fee: toRay('0.0015') },
    { txType: MAP_TX.MINT_BTCX_FEES_RBTC,   fee: toRay('0.0015') },
    { txType: MAP_TX.REDEEM_BTCX_FEES_RBTC, fee: toRay('0.0015') },
    { txType: MAP_TX.MINT_BPRO_FEES_MOC,    fee: toRay('0.0012') },
    { txType: MAP_TX.REDEEM_BPRO_FEES_MOC,  fee: toRay('0.0012') },
    { txType: MAP_TX.MINT_DOC_FEES_MOC,     fee: toRay('0.0012') },
    { txType: MAP_TX.REDEEM_DOC_FEES_MOC,   fee: toRay('0.0012') },
    { txType: MAP_TX.MINT_BTCX_FEES_MOC,    fee: toRay('0.0012') },
    { txType: MAP_TX.REDEEM_BTCX_FEES_MOC,  fee: toRay('0.0012') },
  ];

  const ChangerFactory = await ethers.getContractFactory('FeesAndBitprorateProposal');
  const changer = await ChangerFactory.deploy(inrate.target, bitProRate, commissions);

  return { inrate, changer, bitProRate, commissions };
}

describe('FeesAndBitprorateProposal', function () {
  it('stores constructor params correctly', async () => {
    const { changer, bitProRate, commissions } = await freshDeploy();

    const onRate = await changer.bitProRate();
    expect(onRate).to.equal(bitProRate);

    const len = await changer.commissionRatesLength();
    expect(Number(len)).to.equal(commissions.length);

    const first = await changer.commissionRates(0);
    expect(Number(first[0])).to.equal(commissions[0].txType);
    expect(first[1]).to.equal(commissions[0].fee);

    const last = await changer.commissionRates(commissions.length - 1);
    expect(Number(last[0])).to.equal(commissions[commissions.length - 1].txType);
    expect(last[1]).to.equal(commissions[commissions.length - 1].fee);
  });

  it('execute() applies, and burns fuse', async () => {
    const { changer, inrate, bitProRate, commissions } = await freshDeploy();

    const tx = await changer.execute();
    const rc = await tx.wait();

    expect(await inrate.bitProRate()).to.equal(bitProRate);

    for (const { txType, fee } of commissions) {
      expect(await inrate.commissionByTxType(txType)).to.equal(fee);
    }
    
    expect(await changer.mocInrate()).to.equal(ethers.ZeroAddress);    

    const iface = (await ethers.getContractFactory('FeesAndBitprorateProposal')).interface;
    const names = rc.logs
      .filter((l) => l.address.toLowerCase() === changer.target.toLowerCase())
      .map((log) => { try { return iface.parseLog(log).name; } catch { return 'UNKNOWN'; } });

    expect(names).to.include('BitProRateSet');
    expect(names).to.include('ExecutedOnce');
    expect(names.filter((n) => n === 'CommissionRateSet').length).to.equal(commissions.length);
  });

  it('execute() cannot be called twice', async () => {
    const { changer } = await freshDeploy();
    await changer.execute();
    await expect(changer.execute()).to.be.revertedWith('This changer was already executed');
  });
});
