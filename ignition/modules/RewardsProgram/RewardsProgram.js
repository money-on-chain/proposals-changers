import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("RewardsProgramModule", (m) => {
  const coinerProxy = m.getParameter("coinerProxy");
  const distributor = m.getParameter("distributor");
  const tasksRunner = m.getParameter("tasksRunner");

  const changer = m.contract("RewardsProgram", [coinerProxy, distributor, tasksRunner]);

  return {
    changer,
  };
});
