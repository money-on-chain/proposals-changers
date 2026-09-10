import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { batchModule } from "ignition-utils";

const TestnetVotingQuorumChangerModule = buildModule("TestnetVotingQuorumChangerModule", (m) => {
  const votingMachineProxy = m.getParameter("votingMachineProxy");
  const votingMachine = m.contractAt("VotingMachine", votingMachineProxy, {
    id: "VotingMachineProxy",
  });
  const registry = m.staticCall(votingMachine, "registry", [], 0, {
    id: "VotingMachineRegistry",
  });
  const changer = m.contract("TestnetVotingQuorumChanger", [registry]);

  return { changer };
});

export default batchModule(TestnetVotingQuorumChangerModule);
