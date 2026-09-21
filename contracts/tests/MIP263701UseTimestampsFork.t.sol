// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IUpgradeDelegator, MIP263701UseTimestamps } from "../changers/mip26_3701/MIP263701UseTimestamps.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

interface IGovernedSchedule {
  function governor() external view returns (address);
}
interface IOwnableGovernor {
  function owner() external view returns (address);
}

interface IMoCStateTimestampScheduleProbe {
  function lastEmaCalculationTimestamp() external view returns (uint256);
  function emaCalculationTimeSpan() external view returns (uint256);
  function getBitcoinMovingAverage() external view returns (uint256);
  function getSmoothingFactor() external view returns (uint256);
}

interface IMoCInrateTimestampScheduleProbe {
  function lastBitProInterestTimestamp() external view returns (uint256);
  function bitProInterestTimeSpan() external view returns (uint256);
}

interface ICoinerTimestampScheduleProbe {
  function getNextMintAt() external view returns (uint256);
  function getMintTimestampInterval() external view returns (uint256);
}

interface ISupportersScheduleProbe {
  function period() external view returns (uint256);
  function getEarningsInfo() external view returns (uint256, uint256, uint256);
}

interface IRoundManagerScheduleProbe {
  function roundLockPeriodSecs() external view returns (uint256);
  function getRoundInfo()
    external
    view
    returns (uint256, uint256, uint256, uint256, address[] memory, address[] memory);
}

interface IRifOnChainTimeSpansProbe {
  function tcInterestCollectorAddress() external view returns (address);
  function tcInterestRate() external view returns (uint256);
  function tcInterestPaymentTimeSpan() external view returns (uint256);
  function nextTCInterestPayment() external view returns (uint256);
  function maxAbsoluteOpProvider() external view returns (address);
  function maxOpDiffProvider() external view returns (address);
  function decayTimeSpan() external view returns (uint256);
  function emaCalculationTimeSpan() external view returns (uint256);
  function nextEmaCalculation() external view returns (uint256);
  function absoluteAccumulator() external view returns (uint256);
  function differentialAccumulator() external view returns (int256);
  function lastOperationTimeStamp() external view returns (uint256);
  function tpEma(uint256 index) external view returns (uint256 ema, uint256 sf);
}

interface IMocQueueScheduleProbe {
  function minOperWaitingBlk() external view returns (uint256);
  function maxOperWaitingBlk() external view returns (uint256);
}

interface IMocReverseAuctionThresholdProbe {
  function orderThreshold() external view returns (uint256);
}

/**
 * @notice Applies MIP26-3701 to the deployed Rootstock mainnet state at the
 *         changer deployment block and reports the timestamps produced by the migration.
 */
contract MIP263701UseTimestampsForkTest is Test {
  string internal constant MAINNET_PARAMS_PATH =
    "./ignition/modules/MIP26-3701/parameters/rskMainnet.json";
  string internal constant MAINNET_DEPLOYED_ADDRESSES_PATH =
    "./ignition/deployments/mip26-3701-rsk-mainnet/deployed_addresses.json";
  uint256 internal constant MAINNET_FORK_BLOCK = 9_247_782;

  uint256 internal constant SEPTEMBER_2026_START = 1_788_220_800;
  uint256 internal constant OCTOBER_2026_START = 1_790_812_800;

  address internal mocProxy;
  address internal mocStateProxy;
  address internal mocInrateProxy;
  address internal coinerProxy;
  address internal supporters;
  address internal rifOnChain;
  address internal btcUsdCoinPair;
  address internal rifUsdCoinPair;
  address internal tasksRunner;
  address internal rifQueue;
  address internal docQueue;
  address internal docToMocReverseAuction;
  address internal mocUpgradeDelegator;
  address internal flowUpgradeDelegator;
  uint256 internal roundLockPeriod;
  uint256 internal supportersEarningsBefore;
  uint256 internal supportersDistributedBefore;
  uint256 internal supportersNextBefore;
  uint256 internal btcRoundDeadlineBefore;
  uint256 internal rifRoundDeadlineBefore;
  uint256 internal tasksRoundDeadlineBefore;
  address internal interestCollectorBefore;
  uint256 internal interestRateBefore;
  address internal maxAbsoluteProviderBefore;
  address internal maxDiffProviderBefore;
  uint256 internal nextInterestPaymentBefore;
  uint256 internal nextEmaCalculationBefore;
  uint256 internal absoluteAccumulatorBefore;
  int256 internal differentialAccumulatorBefore;
  uint256 internal lastOperationTimestampBefore;
  uint256 internal rifEmaBefore;
  uint256 internal rifSmoothingFactorBefore;
  uint256 internal legacyBitcoinMovingAverageBefore;
  uint256 internal legacySmoothingFactorBefore;

  MIP263701UseTimestamps internal changer;

  function setUp() public {
    _readMainnetParameters();
    _readMainnetDeployment();

    string memory defaultRpcUrl = "https://public-node.rsk.co";
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", defaultRpcUrl);
    vm.createSelectFork(rpcUrl, MAINNET_FORK_BLOCK);
  }

  function testFork_ExecutionMigratesCurrentMainnetSchedules() public {
    uint256 expectedLastEmaCalculationTimestamp = changer.legacyLastEmaCalculationTimestamp();
    uint256 expectedLastInterestPaymentTimestamp = changer.legacyLastInterestPaymentTimestamp();
    uint256 expectedNextMintTimestamp = changer.nextMintDueTimestamp();
    _captureUnaffectedState();

    _executeChanger();

    uint256 lastEmaCalculationTimestamp = IMoCStateTimestampScheduleProbe(mocStateProxy)
      .lastEmaCalculationTimestamp();
    uint256 lastInterestPaymentTimestamp = IMoCInrateTimestampScheduleProbe(mocInrateProxy)
      .lastBitProInterestTimestamp();
    uint256 nextMintTimestamp = ICoinerTimestampScheduleProbe(coinerProxy).getNextMintAt();

    emit log_named_uint("EMA previous calculation timestamp", lastEmaCalculationTimestamp);
    emit log_named_uint("Weekly interest previous payment timestamp", lastInterestPaymentTimestamp);
    emit log_named_uint("Coiner next round timestamp", nextMintTimestamp);

    assertEq(lastEmaCalculationTimestamp, expectedLastEmaCalculationTimestamp);
    assertEq(lastInterestPaymentTimestamp, expectedLastInterestPaymentTimestamp);
    assertEq(nextMintTimestamp, expectedNextMintTimestamp);
    assertEq(
      IMoCStateTimestampScheduleProbe(mocStateProxy).emaCalculationTimeSpan(),
      changer.EMA_CALCULATION_TIME_SPAN()
    );
    assertEq(
      IMoCInrateTimestampScheduleProbe(mocInrateProxy).bitProInterestTimeSpan(),
      changer.BITPRO_INTEREST_TIME_SPAN()
    );
    assertEq(
      ICoinerTimestampScheduleProbe(coinerProxy).getMintTimestampInterval(),
      changer.COINER_MINT_TIME_SPAN()
    );
    _assertAdditionalSchedulesAndPreservedState();

    assertGe(nextMintTimestamp, SEPTEMBER_2026_START, "Coiner round is before September");
    assertLt(nextMintTimestamp, OCTOBER_2026_START, "Coiner round drifted into October");
  }

  function _captureUnaffectedState() internal {
    (
      supportersEarningsBefore,
      supportersDistributedBefore,
      supportersNextBefore
    ) = ISupportersScheduleProbe(supporters).getEarningsInfo();
    btcRoundDeadlineBefore = _roundDeadline(btcUsdCoinPair);
    rifRoundDeadlineBefore = _roundDeadline(rifUsdCoinPair);
    tasksRoundDeadlineBefore = _roundDeadline(tasksRunner);

    IRifOnChainTimeSpansProbe rif = IRifOnChainTimeSpansProbe(rifOnChain);
    interestCollectorBefore = rif.tcInterestCollectorAddress();
    interestRateBefore = rif.tcInterestRate();
    maxAbsoluteProviderBefore = rif.maxAbsoluteOpProvider();
    maxDiffProviderBefore = rif.maxOpDiffProvider();
    nextInterestPaymentBefore = rif.nextTCInterestPayment();
    nextEmaCalculationBefore = rif.nextEmaCalculation();
    absoluteAccumulatorBefore = rif.absoluteAccumulator();
    differentialAccumulatorBefore = rif.differentialAccumulator();
    lastOperationTimestampBefore = rif.lastOperationTimeStamp();
    (rifEmaBefore, rifSmoothingFactorBefore) = rif.tpEma(0);

    IMoCStateTimestampScheduleProbe legacyState = IMoCStateTimestampScheduleProbe(mocStateProxy);
    legacyBitcoinMovingAverageBefore = legacyState.getBitcoinMovingAverage();
    legacySmoothingFactorBefore = legacyState.getSmoothingFactor();
  }

  function _assertAdditionalSchedulesAndPreservedState() internal view {
    assertEq(ISupportersScheduleProbe(supporters).period(), 87_600);
    assertEq(IRoundManagerScheduleProbe(btcUsdCoinPair).roundLockPeriodSecs(), roundLockPeriod);
    assertEq(IRoundManagerScheduleProbe(rifUsdCoinPair).roundLockPeriodSecs(), roundLockPeriod);
    assertEq(IRoundManagerScheduleProbe(tasksRunner).roundLockPeriodSecs(), roundLockPeriod);
    assertEq(IMocQueueScheduleProbe(rifQueue).minOperWaitingBlk(), 1);
    assertEq(IMocQueueScheduleProbe(rifQueue).maxOperWaitingBlk(), 6);
    assertEq(IMocQueueScheduleProbe(docQueue).minOperWaitingBlk(), 1);
    assertEq(IMocQueueScheduleProbe(docQueue).maxOperWaitingBlk(), 6);
    assertEq(
      IMocReverseAuctionThresholdProbe(docToMocReverseAuction).orderThreshold(),
      300 ether
    );

    IRifOnChainTimeSpansProbe rif = IRifOnChainTimeSpansProbe(rifOnChain);
    assertEq(rif.tcInterestPaymentTimeSpan(), changer.BITPRO_INTEREST_TIME_SPAN());
    assertEq(rif.decayTimeSpan(), 1 days);
    assertEq(rif.emaCalculationTimeSpan(), changer.EMA_CALCULATION_TIME_SPAN());

    (uint256 earningsAfter, uint256 distributedAfter, uint256 nextAfter) = ISupportersScheduleProbe(
      supporters
    ).getEarningsInfo();
    assertEq(earningsAfter, supportersEarningsBefore);
    assertEq(distributedAfter, supportersDistributedBefore);
    assertEq(nextAfter, supportersNextBefore);
    assertEq(_roundDeadline(btcUsdCoinPair), btcRoundDeadlineBefore);
    assertEq(_roundDeadline(rifUsdCoinPair), rifRoundDeadlineBefore);
    assertEq(_roundDeadline(tasksRunner), tasksRoundDeadlineBefore);
    assertEq(rif.tcInterestCollectorAddress(), interestCollectorBefore);
    assertEq(rif.tcInterestRate(), interestRateBefore);
    assertEq(rif.maxAbsoluteOpProvider(), maxAbsoluteProviderBefore);
    assertEq(rif.maxOpDiffProvider(), maxDiffProviderBefore);
    assertEq(rif.nextTCInterestPayment(), nextInterestPaymentBefore);
    assertEq(rif.nextEmaCalculation(), nextEmaCalculationBefore);
    assertEq(rif.absoluteAccumulator(), absoluteAccumulatorBefore);
    assertEq(rif.differentialAccumulator(), differentialAccumulatorBefore);
    assertEq(rif.lastOperationTimeStamp(), lastOperationTimestampBefore);
    (uint256 rifEmaAfter, uint256 rifSmoothingFactorAfter) = rif.tpEma(0);
    assertEq(rifEmaAfter, rifEmaBefore);
    assertEq(rifSmoothingFactorAfter, rifSmoothingFactorBefore);

    IMoCStateTimestampScheduleProbe legacyState = IMoCStateTimestampScheduleProbe(mocStateProxy);
    assertEq(legacyState.getBitcoinMovingAverage(), legacyBitcoinMovingAverageBefore);
    assertEq(legacyState.getSmoothingFactor(), legacySmoothingFactorBefore);
  }

  function _roundDeadline(address target) internal view returns (uint256 deadline) {
    (, , deadline, , , ) = IRoundManagerScheduleProbe(target).getRoundInfo();
  }

  function _executeChanger() internal {
    address governor = IGovernedSchedule(mocStateProxy).governor();
    vm.prank(IOwnableGovernor(governor).owner());
    IGovernor(governor).executeChange(IChangeContract(address(changer)));
  }

  function _readMainnetDeployment() internal {
    string memory json = vm.readFile(MAINNET_DEPLOYED_ADDRESSES_PATH);
    changer = MIP263701UseTimestamps(
      vm.parseJsonAddress(json, ".['MIP263701Module#MIP263701UseTimestamps']")
    );
  }

  function _readMainnetParameters() internal {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);
    string memory module = "MIP263701Module";

    mocProxy = vm.parseJsonAddress(json, _key(module, "mocProxy"));
    mocStateProxy = vm.parseJsonAddress(json, _key(module, "mocStateProxy"));
    mocInrateProxy = vm.parseJsonAddress(json, _key(module, "mocInrateProxy"));
    coinerProxy = vm.parseJsonAddress(json, _key(module, "coinerProxy"));
    supporters = vm.parseJsonAddress(json, _key(module, "supporters"));
    rifOnChain = vm.parseJsonAddress(json, _key(module, "rifOnChain"));
    btcUsdCoinPair = vm.parseJsonAddress(json, _key(module, "btcUsdCoinPair"));
    rifUsdCoinPair = vm.parseJsonAddress(json, _key(module, "rifUsdCoinPair"));
    tasksRunner = vm.parseJsonAddress(json, _key(module, "tasksRunner"));
    rifQueue = vm.parseJsonAddress(json, _key(module, "rifQueue"));
    docQueue = vm.parseJsonAddress(json, _key(module, "docQueue"));
    docToMocReverseAuction = vm.parseJsonAddress(
      json,
      _key(module, "docToMocReverseAuction")
    );
    mocUpgradeDelegator = vm.parseJsonAddress(json, _key(module, "mocUpgradeDelegator"));
    flowUpgradeDelegator = vm.parseJsonAddress(json, _key(module, "flowUpgradeDelegator"));
    roundLockPeriod = vm.parseJsonUint(json, _key(module, "roundLockPeriod"));
  }

  function _key(string memory module, string memory field) internal pure returns (string memory) {
    return string(abi.encodePacked(".", module, ".", field));
  }
}
