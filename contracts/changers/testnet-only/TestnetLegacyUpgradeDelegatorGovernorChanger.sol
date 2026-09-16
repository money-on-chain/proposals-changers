// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IGoverned {
  function changeIGovernor(address newIGovernor) external;
}

/**
 * @title TestnetLegacyUpgradeDelegatorGovernorChanger
 * @notice Aligns the legacy VotingMachine UpgradeDelegator with the
 *         VotingMachine's controlled Governor on Rootstock testnet.
 * @dev This changer is intended exclusively for testnet and must never be
 *      executed on mainnet.
 */
contract TestnetLegacyUpgradeDelegatorGovernorChanger is IChangeContract {
  address public constant LEGACY_UPGRADE_DELEGATOR = 0x546AFdf647d0B5c73323366B090Ebe6C0C4D9b2C;
  address public constant VOTING_MACHINE_CONTROLLED_GOVERNOR =
    0x7b716178771057195bB511f0B1F7198EEE62Bc22;

  event UpgradeDelegatorGovernorChanged(address indexed newGovernor);

  function execute() external override {
    IGoverned(LEGACY_UPGRADE_DELEGATOR).changeIGovernor(VOTING_MACHINE_CONTROLLED_GOVERNOR);
    emit UpgradeDelegatorGovernorChanged(VOTING_MACHINE_CONTROLLED_GOVERNOR);
  }
}
