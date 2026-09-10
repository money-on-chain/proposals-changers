// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IQuorumRegistry {
  function setUint(bytes32 key, uint248 value) external;
}

/**
 * @title TestnetVotingQuorumChanger
 * @notice Sets the voting quorum threshold to 14% for testnet maintenance.
 * @dev This changer is intended exclusively for testnet and must never be
 *      executed on mainnet.
 */
contract TestnetVotingQuorumChanger is IChangeContract {
  bytes32 public constant MOC_VOTING_MACHINE_VOTE_MIN_PCT_FOR_QUORUM =
    0xde1ede48948567c43c504b761af8cd6af5363fafeceb1239b3083955d809714f;

  uint248 public constant QUORUM_PERCENTAGE = 14;

  IQuorumRegistry public immutable registry;

  event VotingQuorumPercentageSet(uint248 value);

  constructor(IQuorumRegistry registry_) {
    require(address(registry_) != address(0), "Invalid registry");
    registry = registry_;
  }

  function execute() external override {
    registry.setUint(MOC_VOTING_MACHINE_VOTE_MIN_PCT_FOR_QUORUM, QUORUM_PERCENTAGE);
    emit VotingQuorumPercentageSet(QUORUM_PERCENTAGE);
  }
}
