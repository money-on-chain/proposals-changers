import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MIP264301Module", (m) => {
  const coinerImplementation = m.contract("@moc/flow/contracts/Coiner.sol:Coiner", [], {
    id: "CoinerImplementation",
  });
  const coinPairPriceImplementation = m.contract(
    "@moc/oracles/contracts/CoinPairPrice.sol:CoinPairPrice",
    [],
    {
      id: "CoinPairPriceImplementation",
    },
  );
  const deprecatedSplitTask = m.contractAt(
    "IMIP264301SplitTask",
    m.getParameter("deprecatedSplitTask"),
  );
  const newSplitTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/commissionSplitter/TaskSplit.sol:TaskSplit",
    [
      m.staticCall(deprecatedSplitTask, "commissionSplitter"),
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
      m.staticCall(deprecatedSplitTask, "tokenBalanceThreshold"),
      m.staticCall(deprecatedSplitTask, "feeTokenBalanceThreshold"),
    ],
    { id: "RBTCOnlySplitTask" },
  );
  const triggerOrderTasks = [];
  const newTriggerOrderTasks = {};
  for (let i = 1; i <= 13; i++) {
    const deprecatedTask = m.contractAt(
      "IMIP264301TriggerOrderTask",
      m.getParameter(`deprecatedTriggerOrderTask${i}`),
      { id: `DeprecatedTriggerOrderTask${i}` },
    );
    const replacement = m.contract(
      "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol:TaskTriggerOrder",
      [m.staticCall(deprecatedTask, "reverseAuction"), 5 * 60, 10 * 60 * 60],
      { id: `TriggerOrderTask${i}` },
    );
    triggerOrderTasks.push([deprecatedTask, replacement]);
    newTriggerOrderTasks[`triggerOrderTask${i}`] = replacement;
  }
  const changer = m.contract("MIP264301FlowUpdate", [
    m.getParameter("coinerProxy"),
    m.getParameter("flowUpgradeDelegator"),
    coinerImplementation,
    m.getParameter("multisigRewards"),
    m.getParameter("coinerBuffer"),
    m.getParameter("tasksRunner"),
    m.getParameter("coinerBufferFlushTask"),
    m.getParameter("coinerBufferLiquidateTask"),
    m.getParameter("tasksRunnerBuffer"),
    m.getParameter("tasksRunnerBufferFlushTask"),
    m.getParameter("tasksRunnerBufferLiquidateTask"),
    m.getParameter("mocRewardsBuffer"),
    m.getParameter("btcUsdCoinPair"),
    [
      m.getParameter("reverseAuctionRifToMoc"),
      m.getParameter("reverseAuctionRifToMoc2"),
      m.getParameter("reverseAuctionRifToMoc3"),
    ],
    [deprecatedSplitTask, newSplitTask],
    triggerOrderTasks,
    m.getParameter("rifUsdCoinPair"),
    coinPairPriceImplementation,
    m.getParameter("rifBucket"),
    m.getParameter("mocRifPriceProvider"),
  ]);

  return {
    coinerImplementation,
    coinPairPriceImplementation,
    newSplitTask,
    ...newTriggerOrderTasks,
    changer,
  };
});
