import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("BufferPctAndCleanMocV1Module", (m) => {
  const oracleManagerProxy = m.getParameter("oracleManagerProxy");
  const coinPairProxy = m.getParameter("coinPairProxy");
  const mocRewardsBufferProxy = m.getParameter("mocRewardsBufferProxy");
  const mocV1Proxy = m.getParameter("mocV1Proxy");
  const rifBucketProxy = m.getParameter("rifBucketProxy");
  const upgradeDelegatorOracle = m.getParameter("upgradeDelegatorOracle");
  const upgradeDelegatorMoc = m.getParameter("upgradeDelegatorMoc");
  const moCHelperLib = m.getParameter("moCHelperLib");
  const deprecatedOracles = m.getParameter("deprecatedOracles");
  const coinPairPriceImplementation = m.getParameter("coinPairPriceImplementation");

  const rifBucket = m.contractAt("MocBaseBucket", rifBucketProxy, { id: "RifBucket" });
  const currentMaxAbsoluteOpProviderAddress = m.staticCall(
    rifBucket,
    "maxAbsoluteOpProvider",
    [],
    0,
    { id: "CurrentMaxAbsoluteOpProviderAddress" },
  );
  const currentMaxOpDiffProviderAddress = m.staticCall(rifBucket, "maxOpDiffProvider", [], 0, {
    id: "CurrentMaxOpDiffProviderAddress",
  });

  const currentMaxAbsoluteOpProvider = m.contractAt(
    "FCMaxAbsoluteOpProvider",
    currentMaxAbsoluteOpProviderAddress,
    { id: "CurrentMaxAbsoluteOpProvider" },
  );
  const currentMaxOpDiffProvider = m.contractAt(
    "FCMaxOpDifferenceProvider",
    currentMaxOpDiffProviderAddress,
    { id: "CurrentMaxOpDiffProvider" },
  );

  const maxAbsoluteOpProviderOwner = m.staticCall(currentMaxAbsoluteOpProvider, "owner", [], 0, {
    id: "CurrentMaxAbsoluteOpProviderOwner",
  });
  const maxAbsoluteOpProviderInitialData = m.staticCall(
    currentMaxAbsoluteOpProvider,
    "peek",
    [],
    0,
    { id: "CurrentMaxAbsoluteOpProviderInitialData" },
  );

  const maxOpDiffProviderOwner = m.staticCall(currentMaxOpDiffProvider, "owner", [], 0, {
    id: "CurrentMaxOpDiffProviderOwner",
  });
  const maxOpDiffProviderInitialData = m.staticCall(currentMaxOpDiffProvider, "peek", [], 0, {
    id: "CurrentMaxOpDiffProviderInitialData",
  });

  const maxAbsoluteOpProvider = m.contract(
    "FCMaxAbsoluteOpProvider",
    [maxAbsoluteOpProviderOwner, maxAbsoluteOpProviderInitialData],
    { id: "MaxAbsoluteOpProvider" },
  );
  const maxOpDifferenceProvider = m.contract(
    "FCMaxOpDifferenceProvider",
    [maxOpDiffProviderOwner, maxOpDiffProviderInitialData],
    { id: "MaxOpDifferenceProvider" },
  );

  const oracleManagerImplementation = m.contract("DeployableOracleManager", [], {
    id: "OracleManagerImplementation",
  });

  const mocImplementation = m.contract("DeployableMoC", [], {
    id: "MoCImplementation",
  });
  const mocProxy = m.contractAt("MoC", mocV1Proxy, { id: "MoCProxy" });
  const mocConnectorProxy = m.staticCall(mocProxy, "connector", [], 0, {
    id: "MoCConnectorProxy",
  });
  const mocConnector = m.contractAt("MoCConnector", mocConnectorProxy, {
    id: "MoCConnector",
  });
  const mocStateV1Proxy = m.staticCall(mocConnector, "mocState", [], 0, {
    id: "MoCStateProxy",
  });
  const mocExchangeV1Proxy = m.staticCall(mocConnector, "mocExchange", [], 0, {
    id: "MoCExchangeProxy",
  });
  const mocSettlementV1Proxy = m.staticCall(mocConnector, "mocSettlement", [], 0, {
    id: "MoCSettlementProxy",
  });
  const mocStateImplementation = m.contract("DeployableMoCState", [], {
    id: "MoCStateImplementation",
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
    oracleManagerProxy,
    coinPairProxy,
    mocRewardsBufferProxy,
    mocV1Proxy,
    mocStateV1Proxy,
    mocExchangeV1Proxy,
    mocSettlementV1Proxy,
    rifBucketProxy,
    upgradeDelegatorOracle,
    upgradeDelegatorMoc,
    coinPairPriceImplementation,
    oracleManagerImplementation,
    mocImplementation,
    mocStateImplementation,
    mocExchangeImplementation,
    mocSettlementImplementation,
    maxAbsoluteOpProvider,
    maxOpDifferenceProvider,
    deprecatedOracles,
  ]);

  return {
    coinPairPriceImplementation,
    oracleManagerImplementation,
    mocImplementation,
    mocStateImplementation,
    mocExchangeImplementation,
    mocSettlementImplementation,
    maxAbsoluteOpProvider,
    maxOpDifferenceProvider,
    changer,
  };
});
