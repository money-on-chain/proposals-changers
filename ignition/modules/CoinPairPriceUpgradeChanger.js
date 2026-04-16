import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// Hardcoded constructor addresses for CoinPairPriceUpgradeProposal.
const COIN_PAIR_PRICE_PROXY = "0xa288319eCb63301e21963E21EF3Ca8fb720d2672";
const ORACLE_MANAGER_PROXY = "0x64A5634b2d1f17DC7C4765aAcD222f8e9Eb7712C";
const UPGRADE_DELEGATOR = "0x131564703310a294C1bFDC09D10EC0659f18E253";

export default buildModule("CoinPairPriceUpgradeChangerModule", (m) => {
  const coinPairPriceImplementation = m.contract("DeployableCoinPairPrice", [], {
    id: "CoinPairPriceImplementation",
  });

  const oracleManagerImplementation = m.contract("DeployableOracleManager", [], {
    id: "OracleManagerImplementation",
  });

  const changer = m.contract("CoinPairPriceUpgradeProposal", [
    COIN_PAIR_PRICE_PROXY,
    ORACLE_MANAGER_PROXY,
    UPGRADE_DELEGATOR,
    coinPairPriceImplementation,
    oracleManagerImplementation,
  ]);

  return {
    coinPairPriceImplementation,
    oracleManagerImplementation,
    changer,
  };
});
