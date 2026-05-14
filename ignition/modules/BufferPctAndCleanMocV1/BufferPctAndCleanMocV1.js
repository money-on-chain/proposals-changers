import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("BufferPctAndCleanMocV1Module", (m) => {
  const coinPairProxy = m.getParameter("coinPairProxy");
  const mocRewardsBufferProxy = m.getParameter("mocRewardsBufferProxy");
  const mocV1Proxy = m.getParameter("mocV1Proxy");
  const mocExchangeV1Proxy = m.getParameter("mocExchangeV1Proxy");
  const mocSettlementV1Proxy = m.getParameter("mocSettlementV1Proxy");
  const upgradeDelegatorOracle = m.getParameter("upgradeDelegatorOracle");
  const upgradeDelegatorMoc = m.getParameter("upgradeDelegatorMoc");
  const moCHelperLib = m.getParameter("moCHelperLib");

  const coinPairPriceImplementation = m.contract("DeployableCoinPairPrice", [], {
    id: "CoinPairPriceImplementation",
  });

  const mocImplementation = m.contract("DeployableMoC", [], {
    id: "MoCImplementation",
  });

  const mocExchangeImplementation = m.contract("DeployableMoCExchange", [], {
    id: "MoCExchangeImplementation",
    libraries: {
      MoCHelperLib: moCHelperLib,
    },
  });

  const mocSettlementImplementation = m.contract("DeployableMoCSettlement", [], {
    id: "MoCSettlementImplementation",
  });

  const changer = m.contract("BufferPctAndCleanMocV1", [
    coinPairProxy,
    mocRewardsBufferProxy,
    mocV1Proxy,
    mocExchangeV1Proxy,
    mocSettlementV1Proxy,
    upgradeDelegatorOracle,
    upgradeDelegatorMoc,
    coinPairPriceImplementation,
    mocImplementation,
    mocExchangeImplementation,
    mocSettlementImplementation,
  ]);

  return {
    coinPairPriceImplementation,
    mocImplementation,
    mocExchangeImplementation,
    mocSettlementImplementation,
    changer,
  };
});
