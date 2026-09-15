// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { TestnetVotingTimesChanger, IRegistry } from "../changers/testnet-only/TestnetVotingTimesChanger.sol";

contract RegistryMock is IRegistry {
  mapping(bytes32 => uint248) public values;

  function setUint(bytes32 key, uint248 value) external override {
    values[key] = value;
  }
}

contract TestnetVotingTimesChangerTest is Test {
  bytes32 internal constant PRE_VOTE_EXPIRATION_TIME_DELTA_KEY =
    0x62f5dbf0c17b0df83487409f747ad2eeca5fd54c140ca59b32cf39d6f6eaf916;
  bytes32 internal constant VOTING_TIME_DELTA_KEY =
    0xb43ee0a5ee6dcc7115ce824e4e353526ad6e479afa4daeb78451070de942de36;

  RegistryMock internal registry;
  TestnetVotingTimesChanger internal changer;

  function setUp() public {
    registry = new RegistryMock();
    changer = new TestnetVotingTimesChanger(registry);
  }

  function testExecuteSetsTestnetVotingTimes() public {
    changer.execute();

    assertEq(registry.values(PRE_VOTE_EXPIRATION_TIME_DELTA_KEY), 5 minutes);
    assertEq(registry.values(VOTING_TIME_DELTA_KEY), 20 minutes);
  }

  function testConstructorRejectsZeroRegistry() public {
    vm.expectRevert("Invalid registry");
    new TestnetVotingTimesChanger(IRegistry(address(0)));
  }
}
