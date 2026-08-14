import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("VotingMachineUpgradeChangerModule", (m) => {
  const votingMachineProxy = m.getParameter("votingMachineProxy");
  const upgradeDelegator = m.getParameter("upgradeDelegator");
  const acceptedStepPriorityTimeDelta = m.getParameter(
    "acceptedStepPriorityTimeDelta",
    60 * 60 * 24,
  );

  const votingMachine = m.contractAt("VotingMachine", votingMachineProxy, {
    id: "VotingMachineProxy",
  });
  const registry = m.staticCall(votingMachine, "registry", [], 0, {
    id: "VotingMachineRegistry",
  });

  const newVotingMachineImplementation = m.contract("DeployableVotingMachine", [], {
    id: "VotingMachineImplementation",
  });

  const changer = m.contract("VotingMachineUpgradeProposal", [
    votingMachineProxy,
    registry,
    upgradeDelegator,
    newVotingMachineImplementation,
    acceptedStepPriorityTimeDelta,
  ]);

  return {
    newVotingMachineImplementation,
    changer,
  };
});
