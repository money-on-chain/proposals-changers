// test/fees_and_bitprorate.spec.js
import hre from "hardhat";

import { expect } from "chai";

// HH3: get ethers from the active connection
const { ethers } = await hre.network.connect();

const toRay = (x) => ethers.parseUnits(String(x), 18);

// txType mapping used by MoC V1 commissions
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

// ROC v2 fee keys (must match RocV2FeeKey enum in the contract)
const ROC_KEYS = {
  TcMintFee: 0,
  TcRedeemFee: 1,
  SwapTPforTPFee: 2,
  SwapTPforTCFee: 3,
  SwapTCforTPFee: 4,
  RedeemTCandTPFee: 5,
  MintTCandTPFee: 6,
  FeeTokenPct: 7,
};

async function freshDeploy() {
  // Deploy mocks
  const InrateFactory = await ethers.getContractFactory("MoCInrateMock");
  const RocV2Factory = await ethers.getContractFactory("MoCv2Mock");
  const inrate = await InrateFactory.deploy();
  const rocV2 = await RocV2Factory.deploy();

  // Inputs for the changer
  const bitProRate = toRay("0.000098");

  const commissions = [
    { txType: MAP_TX.MINT_BPRO_FEES_RBTC, fee: toRay("0.0015") },
    { txType: MAP_TX.REDEEM_BPRO_FEES_RBTC, fee: toRay("0.0015") },
    { txType: MAP_TX.MINT_DOC_FEES_RBTC, fee: toRay("0.0015") },
    { txType: MAP_TX.REDEEM_DOC_FEES_RBTC, fee: toRay("0.0015") },
    { txType: MAP_TX.MINT_BTCX_FEES_RBTC, fee: toRay("0.0015") },
    { txType: MAP_TX.REDEEM_BTCX_FEES_RBTC, fee: toRay("0.0015") },
    { txType: MAP_TX.MINT_BPRO_FEES_MOC, fee: toRay("0.0012") },
    { txType: MAP_TX.REDEEM_BPRO_FEES_MOC, fee: toRay("0.0012") },
    { txType: MAP_TX.MINT_DOC_FEES_MOC, fee: toRay("0.0012") },
    { txType: MAP_TX.REDEEM_DOC_FEES_MOC, fee: toRay("0.0012") },
    { txType: MAP_TX.MINT_BTCX_FEES_MOC, fee: toRay("0.0012") },
    { txType: MAP_TX.REDEEM_BTCX_FEES_MOC, fee: toRay("0.0012") },
  ];

  // Example ROC v2 fee schedule payload (same precision 1e18)
  const rocV2Fees = [
    { key: ROC_KEYS.TcMintFee, value: toRay("0.0020") },
    { key: ROC_KEYS.TcRedeemFee, value: toRay("0.0025") },
    { key: ROC_KEYS.SwapTPforTPFee, value: toRay("0.0005") },
    { key: ROC_KEYS.SwapTPforTCFee, value: toRay("0.0007") },
    { key: ROC_KEYS.SwapTCforTPFee, value: toRay("0.0009") },
    { key: ROC_KEYS.RedeemTCandTPFee, value: toRay("0.0011") },
    { key: ROC_KEYS.MintTCandTPFee, value: toRay("0.0013") },
    { key: ROC_KEYS.FeeTokenPct, value: toRay("0.50") }, // 50% of the base op fee
  ];

  // Deploy changer with both targets (MoC V1 + ROC V2)
  const ChangerFactory = await ethers.getContractFactory("FeesAndBitprorateProposal");
  const changer = await ChangerFactory.deploy(
    inrate.target,
    rocV2.target,
    bitProRate,
    commissions,
    rocV2Fees,
  );

  return { inrate, rocV2, changer, bitProRate, commissions, rocV2Fees };
}

describe("FeesAndBitprorateProposal", function () {
  it("stores constructor params correctly (no reliance on array-like getters)", async () => {
    const { changer, bitProRate, commissions, rocV2Fees } = await freshDeploy();

    // Always assert immutable bitProRate
    const onRate = await changer.bitProRate();
    expect(onRate).to.equal(bitProRate);

    // Optionally assert decoded MoC V1 commission blob
    let hasGetCommissions = false;
    try {
      changer.getFunction("getCommissionRates()"); // throws if not present
      hasGetCommissions = true;
    } catch (_) {}

    if (hasGetCommissions) {
      const decoded = await changer.getCommissionRates(); // array of { txType, fee }
      expect(decoded.length).to.equal(commissions.length);

      expect(Number(decoded[0].txType)).to.equal(commissions[0].txType);
      expect(decoded[0].fee).to.equal(commissions[0].fee);

      const last = decoded[decoded.length - 1];
      expect(Number(last.txType)).to.equal(commissions[commissions.length - 1].txType);
      expect(last.fee).to.equal(commissions[commissions.length - 1].fee);
    }

    // Optionally assert decoded ROC V2 fees blob
    let hasGetRocFees = false;
    try {
      changer.getFunction("getRocV2Fee()");
      hasGetRocFees = true;
    } catch (_) {}

    if (hasGetRocFees) {
      const decodedRoc = await changer.getRocV2Fee(); // array of { key, value }
      expect(decodedRoc.length).to.equal(rocV2Fees.length);
      expect(Number(decodedRoc[0].key)).to.equal(rocV2Fees[0].key);
      expect(decodedRoc[0].value).to.equal(rocV2Fees[0].value);
    }
  });

  it("execute() applies on MoC V1 & ROC V2 (rates + fees)", async () => {
    const { changer, inrate, rocV2, bitProRate, commissions, rocV2Fees } = await freshDeploy();

    const tx = await changer.execute();
    const rc = await tx.wait();

    // Rates
    expect(await inrate.bitProRate()).to.equal(bitProRate);
    expect(await rocV2.tcInterestRate()).to.equal(bitProRate);

    // MoC V1 commissions
    for (const { txType, fee } of commissions) {
      expect(await inrate.commissionByTxType(txType)).to.equal(fee);
    }

    // ROC v2 fees
    const readRocFee = async (k) => {
      switch (k) {
        case ROC_KEYS.TcMintFee:
          return rocV2.tcMintFee();
        case ROC_KEYS.TcRedeemFee:
          return rocV2.tcRedeemFee();
        case ROC_KEYS.SwapTPforTPFee:
          return rocV2.swapTPforTPFee();
        case ROC_KEYS.SwapTPforTCFee:
          return rocV2.swapTPforTCFee();
        case ROC_KEYS.SwapTCforTPFee:
          return rocV2.swapTCforTPFee();
        case ROC_KEYS.RedeemTCandTPFee:
          return rocV2.redeemTCandTPFee();
        case ROC_KEYS.MintTCandTPFee:
          return rocV2.mintTCandTPFee();
        case ROC_KEYS.FeeTokenPct:
          return rocV2.feeTokenPct();
        default:
          throw new Error("unknown key");
      }
    };

    for (const { key, value } of rocV2Fees) {
      expect(await readRocFee(key)).to.equal(value);
    }

    // Basic event sanity (not strictly required)
    const iface = (await ethers.getContractFactory("FeesAndBitprorateProposal")).interface;
    const names = rc.logs
      .filter((l) => l.address.toLowerCase() === changer.target.toLowerCase())
      .map((log) => {
        try {
          return iface.parseLog(log).name;
        } catch {
          return "UNKNOWN";
        }
      });

    expect(names).to.include("BitProRateSet");
    expect(names).to.include("ExecutedOnce");
    // Count CommissionRateSet events equals commissions length
    expect(names.filter((n) => n === "CommissionRateSet").length).to.equal(commissions.length);
  });

  it("execute() can be called twice without reverting (idempotent)", async () => {
    const { changer, inrate, rocV2, bitProRate } = await freshDeploy();

    await (await changer.execute()).wait();
    await (await changer.execute()).wait(); // no revert

    // Values remain applied
    expect(await inrate.bitProRate()).to.equal(bitProRate);
    expect(await rocV2.tcInterestRate()).to.equal(bitProRate);
  });
});
