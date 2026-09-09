// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IUpgradeDelegator, MIP263701UseTimestamps } from "../changers/mip26_3701/MIP263701UseTimestamps.sol";

contract LegacyStateMock {
  uint256 internal immutable lastCalculation;
  uint256 public initializedAt;

  constructor(uint256 _lastCalculation) {
    lastCalculation = _lastCalculation;
  }

  function getLastEmaCalculation() external view returns (uint256) {
    return lastCalculation;
  }

  function initializeEmaCalculation(uint256 lastCalculationTimestamp) external {
    initializedAt = lastCalculationTimestamp;
  }
}

contract LegacyInrateMock {
  uint256 public lastBitProInterestBlock;
  uint256 public initializedAt;

  constructor(uint256 _lastPayment) {
    lastBitProInterestBlock = _lastPayment;
  }

  function initializeBitProInterestSchedule(uint256 lastPaymentTimestamp) external {
    initializedAt = lastPaymentTimestamp;
  }
}

contract LegacyCoinerMock {
  uint256 internal immutable nextMintBlock;
  uint256 public initializedAt;

  constructor(uint256 _nextMintBlock) {
    nextMintBlock = _nextMintBlock;
  }

  function getNextMintFromBlock() external view returns (uint256) {
    return nextMintBlock;
  }

  function initializeMintSchedule(uint256 nextDueTimestamp) external {
    initializedAt = nextDueTimestamp;
  }
}

contract UpgradeDelegatorMock is IUpgradeDelegator {
  uint256 public upgrades;

  function upgrade(address, address) external {
    upgrades++;
  }
}

contract MIP263701UseTimestampsTest is Test {
  uint256 internal constant ANCHOR_BLOCK = 1_000_000;
  uint256 internal constant ANCHOR_TIMESTAMP = 1_700_000_000;

  function testExecuteConvertsLegacySchedulesBeforeUpgrading() public {
    LegacyStateMock state = new LegacyStateMock(999_900);
    LegacyInrateMock inrate = new LegacyInrateMock(1_000_100);
    LegacyCoinerMock coiner = new LegacyCoinerMock(1_000_500);
    UpgradeDelegatorMock mocUpgrader = new UpgradeDelegatorMock();
    UpgradeDelegatorMock flowUpgrader = new UpgradeDelegatorMock();

    MIP263701UseTimestamps changer = new MIP263701UseTimestamps(
      address(0x1),
      address(state),
      address(inrate),
      address(coiner),
      mocUpgrader,
      flowUpgrader,
      address(0x2),
      address(0x3),
      address(0x4),
      address(0x5),
      ANCHOR_BLOCK,
      ANCHOR_TIMESTAMP
    );

    changer.execute();

    assertEq(state.initializedAt(), ANCHOR_TIMESTAMP - 100 * 24);
    assertEq(inrate.initializedAt(), ANCHOR_TIMESTAMP + 100 * 24);
    assertEq(coiner.initializedAt(), ANCHOR_TIMESTAMP + 500 * 24);
    assertEq(mocUpgrader.upgrades(), 3);
    assertEq(flowUpgrader.upgrades(), 1);
  }

  function testUninitializedLegacySchedulesAreImmediatelyDue() public {
    LegacyStateMock state = new LegacyStateMock(0);
    LegacyInrateMock inrate = new LegacyInrateMock(0);
    LegacyCoinerMock coiner = new LegacyCoinerMock(0);
    UpgradeDelegatorMock upgrader = new UpgradeDelegatorMock();
    MIP263701UseTimestamps changer = new MIP263701UseTimestamps(
      address(0x1),
      address(state),
      address(inrate),
      address(coiner),
      upgrader,
      upgrader,
      address(0x2),
      address(0x3),
      address(0x4),
      address(0x5),
      ANCHOR_BLOCK,
      ANCHOR_TIMESTAMP
    );

    vm.warp(1_800_000_000);
    changer.execute();

    // Timestamp 1 represents no prior execution and makes both schedules immediately due.
    assertEq(state.initializedAt(), 1);
    assertEq(inrate.initializedAt(), 1);
    assertEq(coiner.initializedAt(), block.timestamp);
  }
}
