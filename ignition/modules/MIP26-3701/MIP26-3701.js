import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { batchModule } from "ignition-utils";

const MIP263701Module = buildModule("MIP263701Module", (m) => {
  const mocProxy = m.getParameter("mocProxy");
  const mocStateProxy = m.getParameter("mocStateProxy");
  const mocInrateProxy = m.getParameter("mocInrateProxy");
  const coinerProxy = m.getParameter("coinerProxy");
  const supporters = m.getParameter("supporters");
  const rifOnChain = m.getParameter("rifOnChain");
  const btcUsdCoinPair = m.getParameter("btcUsdCoinPair");
  const rifUsdCoinPair = m.getParameter("rifUsdCoinPair");
  const tasksRunner = m.getParameter("tasksRunner");
  const mocUpgradeDelegator = m.getParameter("mocUpgradeDelegator");
  const flowUpgradeDelegator = m.getParameter("flowUpgradeDelegator");
  const roundLockPeriod = m.getParameter("roundLockPeriod");

  const mocImplementation = m.contract("@moc/rbtc/contracts/MoC.sol:MoC", [], {
    id: "MoCImplementation",
  });
  const mocStateImplementation = m.contract("@moc/rbtc/contracts/MoCState.sol:MoCState", [], {
    id: "MoCStateImplementation",
  });
  const mocInrateImplementation = m.contract("@moc/rbtc/contracts/MoCInrate.sol:MoCInrate", [], {
    id: "MoCInrateImplementation",
  });
  const coinerImplementation = m.contract("@moc/flow/contracts/Coiner.sol:Coiner", [], {
    id: "CoinerImplementation",
  });
  const supportersImplementation = m.contract(
    "@moc/oracles/contracts/Supporters.sol:Supporters",
    [],
    {
      id: "SupportersImplementation",
    },
  );
  const coinPairPriceImplementation = m.contract(
    "@moc/oracles/contracts/CoinPairPrice.sol:CoinPairPrice",
    [],
    {
      id: "CoinPairPriceImplementation",
    },
  );
  const tasksRunnerImplementation = m.contract(
    "@moc/oracles/contracts/TasksRunner.sol:TasksRunner",
    [],
    {
      id: "TasksRunnerImplementation",
    },
  );
  const changer = m.contract("MIP263701UseTimestamps", [
    [mocProxy, mocStateProxy, mocInrateProxy, coinerProxy],
    [supporters, rifOnChain, btcUsdCoinPair, rifUsdCoinPair, tasksRunner],
    [mocUpgradeDelegator, flowUpgradeDelegator],
    [
      mocImplementation,
      mocStateImplementation,
      mocInrateImplementation,
      coinerImplementation,
      supportersImplementation,
      coinPairPriceImplementation,
      tasksRunnerImplementation,
    ],
    roundLockPeriod,
  ]);

  return {
    mocImplementation,
    mocStateImplementation,
    mocInrateImplementation,
    coinerImplementation,
    supportersImplementation,
    coinPairPriceImplementation,
    tasksRunnerImplementation,
    changer,
  };
});

export default batchModule(MIP263701Module);
