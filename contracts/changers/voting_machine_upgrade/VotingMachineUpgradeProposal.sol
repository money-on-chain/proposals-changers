// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IUpgradeDelegator {
  function upgrade(address proxy, address newImplementation) external;
}

interface IRegistry {
  function setUint(bytes32 key, uint248 value) external;
}

/**
 * @title VotingMachineUpgradeProposal
 * @notice Upgrades the VotingMachine proxy and configures its accepted-step
 *         proposer priority window.
 */
contract VotingMachineUpgradeProposal is IChangeContract {
  bytes32 public constant MOC_VOTING_MACHINE_ACCEPTED_STEP_PRIORITY_TIME_DELTA =
    0x966841a4b245a1fdec6244a638f8c320312779e88c67bc05fde78d6c98c5a9aa;

  address public immutable votingMachineProxy;
  IRegistry public immutable registry;
  IUpgradeDelegator public immutable upgradeDelegator;
  address public immutable newVotingMachineImplementation;
  uint248 public immutable acceptedStepPriorityTimeDelta;

  event VotingMachineUpgraded(address indexed implementation);
  event AcceptedStepPriorityTimeDeltaSet(uint248 value);

  constructor(
    address _votingMachineProxy,
    IRegistry _registry,
    IUpgradeDelegator _upgradeDelegator,
    address _newVotingMachineImplementation,
    uint248 _acceptedStepPriorityTimeDelta
  ) {
    require(_votingMachineProxy != address(0), "Invalid VotingMachine proxy");
    require(address(_registry) != address(0), "Invalid registry");
    require(address(_upgradeDelegator) != address(0), "Invalid UpgradeDelegator");
    require(_newVotingMachineImplementation != address(0), "Invalid implementation");

    votingMachineProxy = _votingMachineProxy;
    registry = _registry;
    upgradeDelegator = _upgradeDelegator;
    newVotingMachineImplementation = _newVotingMachineImplementation;
    acceptedStepPriorityTimeDelta = _acceptedStepPriorityTimeDelta;
  }

  function execute() external override {
    upgradeDelegator.upgrade(votingMachineProxy, newVotingMachineImplementation);
    emit VotingMachineUpgraded(newVotingMachineImplementation);

    registry.setUint(
      MOC_VOTING_MACHINE_ACCEPTED_STEP_PRIORITY_TIME_DELTA,
      acceptedStepPriorityTimeDelta
    );
    emit AcceptedStepPriorityTimeDeltaSet(acceptedStepPriorityTimeDelta);
  }
}
