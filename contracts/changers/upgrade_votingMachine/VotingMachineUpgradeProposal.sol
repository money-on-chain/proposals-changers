// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IUpgradeDelegator {
  function upgrade(address proxy, address newImplementation) external;
}

/**
 * @title VotingMachineUpgradeProposal
 * @notice Governance changer used to upgrade the VotingMachine proxy
 *         using the Money on Chain UpgradeDelegator pattern.
 */
contract VotingMachineUpgradeProposal is IChangeContract {
  address public votingMachineProxy;
  IUpgradeDelegator public upgradeDelegator;
  address public newVotingMachineImplementation;

  constructor(
    address _votingMachineProxy,
    IUpgradeDelegator _upgradeDelegator,
    address _newVotingMachineImplementation
  ) {
    votingMachineProxy = _votingMachineProxy;
    upgradeDelegator = _upgradeDelegator;
    newVotingMachineImplementation = _newVotingMachineImplementation;
  }

  function execute() external {
    _beforeUpgrade();
    _upgrade();
    _afterUpgrade();
  }

  function _upgrade() internal {
    upgradeDelegator.upgrade(votingMachineProxy, newVotingMachineImplementation);
  }

  function _beforeUpgrade() internal virtual {}

  function _afterUpgrade() internal virtual {}
}
