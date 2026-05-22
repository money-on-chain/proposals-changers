import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("VotingMachineUpgradeChangerModule", (m) => {
  const votingMachineProxy = m.getParameter("votingMachineProxy");
  const upgradeDelegator = m.getParameter("upgradeDelegator");

  const votingMachineImplementation = m.contract("VotingMachine", [], {
    id: "VotingMachineImplementation",
  });

  const changer = m.contract("VotingMachineUpgradeProposal", [
    votingMachineProxy,
    upgradeDelegator,
    votingMachineImplementation,
  ]);

  return {
    votingMachineImplementation,
    changer,
  };
});
