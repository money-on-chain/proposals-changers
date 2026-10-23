import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MIP264301Module", (m) => {
  const coinerImplementation = m.contract("@moc/flow/contracts/Coiner.sol:Coiner", [], {
    id: "CoinerImplementation",
  });
  const changer = m.contract("MIP264301FlowUpdate", [
    m.getParameter("coinerProxy"),
    m.getParameter("flowUpgradeDelegator"),
    coinerImplementation,
    m.getParameter("destination"),
    m.getParameter("secondaryDestination"),
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
  ]);

  return { coinerImplementation, changer };
});
