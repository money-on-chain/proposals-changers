// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IRegistry {
  function setUint(bytes32 key, uint248 value) external;
}

/**
 * @title TestnetVotingTimesChanger
 * @notice Sets short voting periods for testnet protocol maintenance.
 * @dev This changer is intended exclusively for testnet and must never be
 *      executed on mainnet.
 */
contract TestnetVotingTimesChanger is IChangeContract {
  bytes32 public constant MOC_VOTING_MACHINE_PRE_VOTE_EXPIRATION_TIME_DELTA =
    0x62f5dbf0c17b0df83487409f747ad2eeca5fd54c140ca59b32cf39d6f6eaf916;
  bytes32 public constant MOC_VOTING_MACHINE_VOTING_TIME_DELTA =
    0xb43ee0a5ee6dcc7115ce824e4e353526ad6e479afa4daeb78451070de942de36;

  uint248 public constant PRE_VOTE_EXPIRATION_TIME_DELTA = 5 minutes;
  uint248 public constant VOTING_TIME_DELTA = 20 minutes;

  IRegistry public immutable registry;

  event PreVoteExpirationTimeDeltaSet(uint248 value);
  event VotingTimeDeltaSet(uint248 value);

  constructor(IRegistry registry_) {
    require(address(registry_) != address(0), "Invalid registry");
    registry = registry_;
  }

  function execute() external override {
    registry.setUint(
      MOC_VOTING_MACHINE_PRE_VOTE_EXPIRATION_TIME_DELTA,
      PRE_VOTE_EXPIRATION_TIME_DELTA
    );
    emit PreVoteExpirationTimeDeltaSet(PRE_VOTE_EXPIRATION_TIME_DELTA);

    registry.setUint(MOC_VOTING_MACHINE_VOTING_TIME_DELTA, VOTING_TIME_DELTA);
    emit VotingTimeDeltaSet(VOTING_TIME_DELTA);
  }
}
