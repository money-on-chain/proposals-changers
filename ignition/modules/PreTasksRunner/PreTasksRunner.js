import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// ethers.encodeBytes32String("TASKSRUNNER")
const TASKS_RUNNER_NAME = "0x5441534b5352554e4e455200000000000000000000000000000000000000000000";

export default buildModule("PreTasksRunnerModule", (m) => {
  const oracleManagerProxy = m.getParameter("oracleManagerProxy");
  const upgradeDelegator = m.getParameter("upgradeDelegator");
  const proxyAdmin = m.getParameter("proxyAdmin");
  const pauser = m.getParameter("pauser");

  // TasksRunner initializer parameters
  const governor = m.getParameter("governor");
  const tokenAddress = m.getParameter("tokenAddress");
  const registry = m.getParameter("registry");
  const minOraclesPerRound = m.getParameter("minOraclesPerRound");
  const maxOraclesPerRound = m.getParameter("maxOraclesPerRound");
  const maxSubscribedOraclesPerRound = m.getParameter("maxSubscribedOraclesPerRound");
  const roundLockPeriod = m.getParameter("roundLockPeriod");
  const maxMissedSigRounds = m.getParameter("maxMissedSigRounds");
  const maxTasksPerBatch = m.getParameter("maxTasksPerBatch");
  const tokenToCoinbasePriceProvider = m.getParameter("tokenToCoinbasePriceProvider");
  const sharesCapMultiplier = m.getParameter("sharesCapMultiplier");

  // Deploy new OracleManager implementation
  const newOracleManagerImplementation = m.contract("DeployableOracleManager", [], {
    id: "OracleManagerImplementation",
  });

  // Deploy a single new CoinPairPrice implementation (used for all CoinPairs)
  const newCoinPairImplementation = m.contract("DeployableCoinPairPrice", [], {
    id: "CoinPairImplementation",
  });

  // Deploy BasefeeProvider (no proxy needed)
  const baseFeeProvider = m.contract("DeployableBasefeeProvider", [], {
    id: "BasefeeProvider",
  });

  // Deploy TasksRunner implementation
  const tasksRunnerImplementation = m.contract("DeployableTasksRunner", [], {
    id: "TasksRunnerImplementation",
  });

  // Deploy the TasksRunner proxy with empty init data (initialized via m.call below)
  const tasksRunnerProxy = m.contract(
    "DeployableAdminUpgradeabilityProxy",
    [tasksRunnerImplementation, proxyAdmin, "0x"],
    { id: "TasksRunnerProxy" },
  );

  // Bind to the proxy as a TasksRunner to call initialize through delegatecall
  const tasksRunnerAtProxy = m.contractAt("DeployableTasksRunner", tasksRunnerProxy, {
    id: "TasksRunnerAtProxy",
  });

  // Initialize the TasksRunner proxy
  m.call(
    tasksRunnerAtProxy,
    "initialize",
    [
      governor,
      TASKS_RUNNER_NAME,
      [], // no initial tasks
      tokenAddress,
      [maxOraclesPerRound, maxSubscribedOraclesPerRound, roundLockPeriod, maxMissedSigRounds],
      oracleManagerProxy,
      registry,
      minOraclesPerRound,
      [maxTasksPerBatch, tokenToCoinbasePriceProvider, baseFeeProvider, sharesCapMultiplier],
    ],
    { id: "InitializeTasksRunner" },
  );

  // Deploy the PreTasksRunner changer
  // CoinPair proxies are read dynamically from the OracleManager at construction time
  const changer = m.contract("PreTasksRunner", [
    oracleManagerProxy,
    upgradeDelegator,
    newOracleManagerImplementation,
    newCoinPairImplementation,
    pauser,
    tasksRunnerProxy,
    TASKS_RUNNER_NAME,
  ]);

  return {
    newOracleManagerImplementation,
    newCoinPairImplementation,
    baseFeeProvider,
    tasksRunnerImplementation,
    tasksRunnerProxy,
    changer,
  };
});
