import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MIP264001Module", (m) => {
  const multiCollateralGuardAddress = m.getParameter("multiCollateralGuard");
  const multiCollateralGuard = m.contractAt("IMIP264001Guard", multiCollateralGuardAddress);
  const rifBucketAddress = m.staticCall(multiCollateralGuard, "buckets", [0]);
  const rifBucket = m.contractAt("IMIP264001Bucket", rifBucketAddress);
  const rifUsdCoinPair = m.staticCall(rifBucket, "pegContainer", [0], 1);
  const mocToken = m.staticCall(rifBucket, "feeToken");

  // The guard pays execution fees to an existing RBTC -> MOC auction. Its
  // auction settings are the established values for this new subsidy auction.
  const existingAuctionAddress = m.staticCall(multiCollateralGuard, "coinbaseExecFeeRecipient");
  const existingAuction = m.contractAt("MocReverseAuction", existingAuctionAddress);
  const rbtcToMocAuction = m.contract(
    "MocReverseAuction",
    [
      m.staticCall(multiCollateralGuard, "governor"),
      m.staticCall(existingAuction, "mocSwapper"),
      "0x0000000000000000000000000000000000000000",
      mocToken,
      rifUsdCoinPair,
      m.staticCall(existingAuction, "orderThreshold"),
      m.staticCall(existingAuction, "priceProvider"),
      m.staticCall(existingAuction, "slippage"),
    ],
    { id: "RevAuctionRBTCtoMOC_rifUsdSubsidy" },
  );

  const rbtcToMocTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol:TaskTriggerOrder",
    [rbtcToMocAuction, m.getParameter("revertSleepTime", 36000), m.getParameter("taskOwner")],
    { id: "TaskTriggerOrderRBTCtoMOC_rifUsdSubsidy" },
  );

  const changer = m.contract(
    "MIP264001RifUsdSubsidy",
    [
      m.getParameter("mocSwapperV3Multihop"),
      m.getParameter("docToMocAuction"),
      m.getParameter("mocToDocAuction"),
      multiCollateralGuardAddress,
      m.getParameter("tasksRunner"),
      rbtcToMocTask,
    ],
    { id: "MIP264001RifUsdSubsidyChanger" },
  );

  return { rbtcToMocAuction, rbtcToMocTask, changer };
});
