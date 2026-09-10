// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IUpgradeDelegator, MIP263701UseTimestamps } from "../changers/mip26_3701/MIP263701UseTimestamps.sol";

contract LegacyStateMock {
  uint256 internal immutable lastCalculation;
  uint256 public initializedAt;
  uint256 public initializedTimeSpan;

  constructor(uint256 _lastCalculation) {
    lastCalculation = _lastCalculation;
  }

  function getLastEmaCalculation() external view returns (uint256) {
    return lastCalculation;
  }

  function initializeEmaCalculation(
    uint256 lastCalculationTimestamp,
    uint256 calculationTimeSpan
  ) external {
    initializedAt = lastCalculationTimestamp;
    initializedTimeSpan = calculationTimeSpan;
  }
}

contract LegacyInrateMock {
  uint256 public lastBitProInterestBlock;
  uint256 public initializedAt;
  uint256 public initializedTimeSpan;

  constructor(uint256 _lastPayment) {
    lastBitProInterestBlock = _lastPayment;
  }

  function initializeBitProInterestSchedule(
    uint256 lastPaymentTimestamp,
    uint256 interestTimeSpan
  ) external {
    initializedAt = lastPaymentTimestamp;
    initializedTimeSpan = interestTimeSpan;
  }
}

contract LegacyCoinerMock {
  uint256 internal immutable nextMintBlock;
  uint256 internal immutable mintBlockInterval;
  uint256 public initializedAt;
  uint256 public initializedTimeSpan;

  constructor(uint256 _nextMintBlock, uint256 _mintBlockInterval) {
    nextMintBlock = _nextMintBlock;
    mintBlockInterval = _mintBlockInterval;
  }

  function getNextMintFromBlock() external view returns (uint256) {
    return nextMintBlock;
  }

  function getMintBlockInterval() external view returns (uint256) {
    return mintBlockInterval;
  }

  function initializeMintSchedule(uint256 nextDueTimestamp, uint256 mintTimeSpan) external {
    initializedAt = nextDueTimestamp;
    initializedTimeSpan = mintTimeSpan;
  }
}

contract UpgradeDelegatorMock is IUpgradeDelegator {
  uint256 public upgrades;

  function upgrade(address, address) external {
    upgrades++;
  }
}

contract GovernedPeriodMock {
  uint256 public period;

  function delegateCallToChanger(bytes calldata data) external returns (bytes memory) {
    period = abi.decode(data, (uint256));
    return "";
  }
}

contract RifOnChainTimeSpansMock {
  address public tcInterestCollectorAddress = address(0x11);
  uint256 public tcInterestRate = 42;
  address public maxAbsoluteOpProvider = address(0x12);
  address public maxOpDiffProvider = address(0x13);
  uint256 public tcInterestPaymentTimeSpan;
  uint256 public decayTimeSpan;
  uint256 public emaCalculationTimeSpan;

  function setTCInterestParams(address collector, uint256 rate, uint256 timeSpan) external {
    tcInterestCollectorAddress = collector;
    tcInterestRate = rate;
    tcInterestPaymentTimeSpan = timeSpan;
  }

  function setFluxCapacitorParams(
    address absoluteProvider,
    address diffProvider,
    uint256 timeSpan
  ) external {
    maxAbsoluteOpProvider = absoluteProvider;
    maxOpDiffProvider = diffProvider;
    decayTimeSpan = timeSpan;
  }

  function setEmaCalculationTimeSpan(uint256 timeSpan) external {
    emaCalculationTimeSpan = timeSpan;
  }
}

contract MIP263701UseTimestampsTest is Test {
  uint256 internal constant ANCHOR_BLOCK = 1_000_000;
  uint256 internal constant ANCHOR_TIMESTAMP = 1_700_000_000;

  function testExecuteConvertsLegacySchedulesBeforeUpgrading() public {
    vm.roll(ANCHOR_BLOCK);
    vm.warp(ANCHOR_TIMESTAMP);
    LegacyStateMock state = new LegacyStateMock(999_900);
    LegacyInrateMock inrate = new LegacyInrateMock(1_000_100);
    LegacyCoinerMock coiner = new LegacyCoinerMock(1_000_500, 100);
    GovernedPeriodMock supporters = new GovernedPeriodMock();
    GovernedPeriodMock btcUsdCoinPair = new GovernedPeriodMock();
    GovernedPeriodMock rifUsdCoinPair = new GovernedPeriodMock();
    GovernedPeriodMock tasksRunner = new GovernedPeriodMock();
    RifOnChainTimeSpansMock rifOnChain = new RifOnChainTimeSpansMock();
    UpgradeDelegatorMock mocUpgrader = new UpgradeDelegatorMock();
    UpgradeDelegatorMock flowUpgrader = new UpgradeDelegatorMock();

    MIP263701UseTimestamps changer = new MIP263701UseTimestamps(
      [address(0x1), address(state), address(inrate), address(coiner)],
      [
        address(supporters),
        address(rifOnChain),
        address(btcUsdCoinPair),
        address(rifUsdCoinPair),
        address(tasksRunner)
      ],
      [address(mocUpgrader), address(flowUpgrader)],
      [address(0x2), address(0x3), address(0x4), address(0x5)],
      1 days,
      7 days,
      30 days + 10 hours,
      30 days + 10 hours
    );

    changer.execute();

    assertEq(state.initializedAt(), ANCHOR_TIMESTAMP - 100 * 29);
    assertEq(inrate.initializedAt(), ANCHOR_TIMESTAMP + 100 * 29);
    assertEq(coiner.initializedAt(), ANCHOR_TIMESTAMP + 400 * 29 + changer.coinerMintTimeSpan());
    assertEq(state.initializedTimeSpan(), 1 days);
    assertEq(inrate.initializedTimeSpan(), 7 days);
    assertEq(coiner.initializedTimeSpan(), 30 days + 10 hours);
    assertEq(mocUpgrader.upgrades(), 3);
    assertEq(flowUpgrader.upgrades(), 1);
    assertEq(supporters.period(), 87_600);
    assertEq(btcUsdCoinPair.period(), 30 days + 10 hours);
    assertEq(rifUsdCoinPair.period(), 30 days + 10 hours);
    assertEq(tasksRunner.period(), 30 days + 10 hours);
    assertEq(rifOnChain.tcInterestCollectorAddress(), address(0x11));
    assertEq(rifOnChain.tcInterestRate(), 42);
    assertEq(rifOnChain.maxAbsoluteOpProvider(), address(0x12));
    assertEq(rifOnChain.maxOpDiffProvider(), address(0x13));
    assertEq(rifOnChain.tcInterestPaymentTimeSpan(), 7 days);
    assertEq(rifOnChain.decayTimeSpan(), 1 days);
    assertEq(rifOnChain.emaCalculationTimeSpan(), 1 days);
  }

  function testUninitializedLegacySchedulesAreImmediatelyDue() public {
    vm.roll(ANCHOR_BLOCK);
    vm.warp(1_800_000_000);
    LegacyStateMock state = new LegacyStateMock(0);
    LegacyInrateMock inrate = new LegacyInrateMock(0);
    LegacyCoinerMock coiner = new LegacyCoinerMock(0, 100);
    GovernedPeriodMock periodTarget = new GovernedPeriodMock();
    RifOnChainTimeSpansMock rifOnChain = new RifOnChainTimeSpansMock();
    UpgradeDelegatorMock upgrader = new UpgradeDelegatorMock();
    MIP263701UseTimestamps changer = new MIP263701UseTimestamps(
      [address(0x1), address(state), address(inrate), address(coiner)],
      [
        address(periodTarget),
        address(rifOnChain),
        address(periodTarget),
        address(periodTarget),
        address(periodTarget)
      ],
      [address(upgrader), address(upgrader)],
      [address(0x2), address(0x3), address(0x4), address(0x5)],
      1 days,
      7 days,
      30 days + 10 hours,
      30 days + 10 hours
    );

    changer.execute();

    // Timestamp 1 represents no prior execution and makes both schedules immediately due.
    assertEq(state.initializedAt(), 1);
    assertEq(inrate.initializedAt(), 1);
    assertEq(coiner.initializedAt(), block.timestamp);
  }
}
