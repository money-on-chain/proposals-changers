// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IMIP264301UpgradeDelegator {
  function upgrade(address proxy, address implementation) external;
}

interface IMIP264301Coiner {
  function setMintDistribution(
    address destination,
    address secondaryDestination,
    uint256 secondaryPercent
  ) external;
}

interface IMIP264301Buffer {
  function getNumOutputs() external view returns (uint256);
  function getOutput(uint256 index) external view returns (address, uint256, uint256, uint256);
  function setThreshold(uint256 threshold) external;
  function removeOutput(uint256 index) external;
  function addOutput(address payable output, uint256 split, uint256 threshold) external;
}

interface IMIP264301BufferTask {
  function buffer() external view returns (address);
}

interface IMIP264301TasksRunner {
  function removeTask(address task) external;
  function addTask(address task) external;
}

interface IMIP264301SplitTask {
  function commissionSplitter() external view returns (address);
  function tokenBalanceThreshold() external view returns (uint256);
  function feeTokenBalanceThreshold() external view returns (uint256);
}

interface IMIP264301TriggerOrderTask {
  function reverseAuction() external view returns (address);
  function BASE_SLEEP_TIME() external view returns (uint256);
  function MAX_REVERT_SLEEP_TIME() external view returns (uint256);
}

interface IMIP264301ReverseAuction {
  function setOrderThreshold(uint256 orderThreshold) external;
}

/**
 * @notice Updates MOC issuance and reward routing, retires intermediate buffer tasks,
 *         lowers RIF auction thresholds, replaces split and trigger-order tasks,
 *         and enables price publications with expiration on both coin pairs.
 */
contract MIP264301FlowUpdate is IChangeContract {
  address public immutable multisigRewards;
  uint256 public constant SECONDARY_PERCENT = 2500;
  uint256 public constant RIF_TO_MOC_ORDER_THRESHOLD = 5000 ether;
  uint256 public constant TRIGGER_ORDER_BASE_TIME = 5 minutes;
  uint256 public constant TRIGGER_ORDER_MAX_TIME = 10 hours;

  address public immutable coinerProxy;
  IMIP264301UpgradeDelegator public immutable flowUpgradeDelegator;
  address public immutable newCoinerImplementation;
  IMIP264301Buffer public immutable coinerBuffer;
  IMIP264301TasksRunner public immutable tasksRunner;
  address public immutable coinerBufferFlushTask;
  address public immutable coinerBufferLiquidateTask;
  address public immutable tasksRunnerBuffer;
  address public immutable tasksRunnerBufferFlushTask;
  address public immutable tasksRunnerBufferLiquidateTask;
  IMIP264301Buffer public immutable mocRewardsBuffer;
  address public immutable btcUsdCoinPair;
  address public immutable rifUsdCoinPair;
  address public immutable newCoinPairPriceImplementation;
  IMIP264301ReverseAuction public immutable reverseAuctionRifToMoc;
  IMIP264301ReverseAuction public immutable reverseAuctionRifToMoc2;
  IMIP264301ReverseAuction public immutable reverseAuctionRifToMoc3;
  address public immutable deprecatedSplitTask;
  address public immutable newSplitTask;
  address[] public deprecatedTriggerOrderTasks;
  address[] public newTriggerOrderTasks;

  constructor(
    address coinerProxy_,
    IMIP264301UpgradeDelegator flowUpgradeDelegator_,
    address newCoinerImplementation_,
    address multisigRewards_,
    IMIP264301Buffer coinerBuffer_,
    IMIP264301TasksRunner tasksRunner_,
    address coinerBufferFlushTask_,
    address coinerBufferLiquidateTask_,
    address tasksRunnerBuffer_,
    address tasksRunnerBufferFlushTask_,
    address tasksRunnerBufferLiquidateTask_,
    IMIP264301Buffer mocRewardsBuffer_,
    address btcUsdCoinPair_,
    address[3] memory reverseAuctionsRifToMoc_,
    address[2] memory splitTasks_,
    address[2][] memory triggerOrderTasks_,
    address rifUsdCoinPair_,
    address newCoinPairPriceImplementation_
  ) {
    require(coinerProxy_ != address(0), "Invalid Coiner proxy");
    require(address(flowUpgradeDelegator_) != address(0), "Invalid UpgradeDelegator");
    require(newCoinerImplementation_ != address(0), "Invalid implementation");
    require(multisigRewards_ != address(0), "Invalid multisig rewards");
    require(address(coinerBuffer_) != address(0), "Invalid buffer");
    require(address(tasksRunner_) != address(0), "Invalid TasksRunner");
    require(coinerBufferFlushTask_ != coinerBufferLiquidateTask_, "Duplicate buffer task");
    require(
      IMIP264301BufferTask(coinerBufferFlushTask_).buffer() == address(coinerBuffer_),
      "Invalid flush task"
    );
    require(
      IMIP264301BufferTask(coinerBufferLiquidateTask_).buffer() == address(coinerBuffer_),
      "Invalid liquidate task"
    );
    require(tasksRunnerBuffer_ != address(0), "Invalid TasksRunner buffer");
    require(address(mocRewardsBuffer_) != address(0), "Invalid MOC rewards buffer");
    require(btcUsdCoinPair_ != address(0), "Invalid BTC/USD coin pair");
    require(rifUsdCoinPair_ != address(0), "Invalid RIF/USD coin pair");
    require(rifUsdCoinPair_ != btcUsdCoinPair_, "Duplicate coin pair");
    require(
      newCoinPairPriceImplementation_.code.length > 0,
      "Invalid CoinPairPrice implementation"
    );
    require(splitTasks_[0] != address(0) && splitTasks_[1] != address(0), "Invalid split task");
    require(splitTasks_[0] != splitTasks_[1], "Split task must be replaced");
    require(
      IMIP264301SplitTask(splitTasks_[0]).commissionSplitter() ==
        IMIP264301SplitTask(splitTasks_[1]).commissionSplitter(),
      "Unexpected commission splitter"
    );
    // With feeToken disabled, its checked balance is zero. A positive threshold
    // prevents that branch from making the new split task permanently available.
    require(
      IMIP264301SplitTask(splitTasks_[1]).feeTokenBalanceThreshold() > 0,
      "Invalid fee token threshold"
    );
    require(triggerOrderTasks_.length > 0, "Missing trigger order tasks");
    // Bind each old task to a distinct replacement targeting the same auction,
    // with the agreed exponential-backoff configuration.
    for (uint256 i = 0; i < triggerOrderTasks_.length; i++) {
      address deprecatedTask = triggerOrderTasks_[i][0];
      address replacement = triggerOrderTasks_[i][1];
      require(
        deprecatedTask != address(0) && replacement != address(0),
        "Invalid trigger order task"
      );
      require(deprecatedTask != replacement, "Trigger order task must be replaced");
      require(
        IMIP264301TriggerOrderTask(deprecatedTask).reverseAuction() ==
          IMIP264301TriggerOrderTask(replacement).reverseAuction(),
        "Unexpected reverse auction"
      );
      require(
        IMIP264301TriggerOrderTask(replacement).BASE_SLEEP_TIME() == TRIGGER_ORDER_BASE_TIME &&
          IMIP264301TriggerOrderTask(replacement).MAX_REVERT_SLEEP_TIME() == TRIGGER_ORDER_MAX_TIME,
        "Invalid trigger order backoff"
      );
      for (uint256 j = 0; j < i; j++) {
        require(
          deprecatedTriggerOrderTasks[j] != deprecatedTask &&
            newTriggerOrderTasks[j] != replacement,
          "Duplicate trigger order task"
        );
      }
      deprecatedTriggerOrderTasks.push(deprecatedTask);
      newTriggerOrderTasks.push(replacement);
    }
    for (uint256 i = 0; i < reverseAuctionsRifToMoc_.length; i++) {
      require(reverseAuctionsRifToMoc_[i] != address(0), "Invalid RIF to MOC auction");
    }
    require(
      tasksRunnerBufferFlushTask_ != tasksRunnerBufferLiquidateTask_,
      "Duplicate TasksRunner buffer task"
    );
    require(
      IMIP264301BufferTask(tasksRunnerBufferFlushTask_).buffer() == tasksRunnerBuffer_,
      "Invalid TasksRunner buffer flush task"
    );
    require(
      IMIP264301BufferTask(tasksRunnerBufferLiquidateTask_).buffer() == tasksRunnerBuffer_,
      "Invalid TasksRunner buffer liquidate task"
    );
    multisigRewards = multisigRewards_;
    coinerProxy = coinerProxy_;
    flowUpgradeDelegator = flowUpgradeDelegator_;
    newCoinerImplementation = newCoinerImplementation_;
    coinerBuffer = coinerBuffer_;
    tasksRunner = tasksRunner_;
    coinerBufferFlushTask = coinerBufferFlushTask_;
    coinerBufferLiquidateTask = coinerBufferLiquidateTask_;
    tasksRunnerBuffer = tasksRunnerBuffer_;
    tasksRunnerBufferFlushTask = tasksRunnerBufferFlushTask_;
    tasksRunnerBufferLiquidateTask = tasksRunnerBufferLiquidateTask_;
    mocRewardsBuffer = mocRewardsBuffer_;
    btcUsdCoinPair = btcUsdCoinPair_;
    rifUsdCoinPair = rifUsdCoinPair_;
    newCoinPairPriceImplementation = newCoinPairPriceImplementation_;
    reverseAuctionRifToMoc = IMIP264301ReverseAuction(reverseAuctionsRifToMoc_[0]);
    reverseAuctionRifToMoc2 = IMIP264301ReverseAuction(reverseAuctionsRifToMoc_[1]);
    reverseAuctionRifToMoc3 = IMIP264301ReverseAuction(reverseAuctionsRifToMoc_[2]);
    deprecatedSplitTask = splitTasks_[0];
    newSplitTask = splitTasks_[1];
  }

  function execute() external override {
    // 1. Upgrade Coiner to MoC-Flow v3.0.5 while retaining the proxy's issuance state.
    flowUpgradeDelegator.upgrade(coinerProxy, newCoinerImplementation);

    // 2. Send future mint steps directly to the primary (75%) and multisig (25%)
    // recipients, bypassing the old Coiner distribution buffer.
    IMIP264301Coiner(coinerProxy).setMintDistribution(
      address(mocRewardsBuffer),
      multisigRewards,
      SECONDARY_PERCENT
    );

    // 3. Stop automatically flushing and liquidating the two intermediate buffers
    // that are bypassed by the new issuance and rewards routes.
    tasksRunner.removeTask(coinerBufferFlushTask);
    tasksRunner.removeTask(coinerBufferLiquidateTask);
    tasksRunner.removeTask(tasksRunnerBufferFlushTask);
    tasksRunner.removeTask(tasksRunnerBufferLiquidateTask);

    // 4. Clear liquidation and output thresholds so remaining funds can be drained
    // manually. Recreating outputs pays their already-liquidated pending balances.
    _resetBufferThresholds(coinerBuffer);
    _resetBufferThresholds(IMIP264301Buffer(tasksRunnerBuffer));

    // 5. Replace the rewards buffer's indirect 30% route (90/10 downstream) with
    // direct payments of 27% to BTC/USD and 3% to TasksRunner; keep the 70% output.
    _updateMocRewardsBuffer();

    // 6. Allow all three RIF-to-MOC auctions to trigger at 5,000 RIF instead of 20,000.
    reverseAuctionRifToMoc.setOrderThreshold(RIF_TO_MOC_ORDER_THRESHOLD);
    reverseAuctionRifToMoc2.setOrderThreshold(RIF_TO_MOC_ORDER_THRESHOLD);
    reverseAuctionRifToMoc3.setOrderThreshold(RIF_TO_MOC_ORDER_THRESHOLD);

    // 7. Replace the commission-split task with an RBTC-only instance (feeToken = 0),
    // so MOC balances ignored by the splitter cannot keep the task available.
    tasksRunner.removeTask(deprecatedSplitTask);
    tasksRunner.addTask(newSplitTask);

    // 8. Replace every registered trigger-order task with its v3.0.21 counterpart.
    // Failures start a 5-minute retry delay, doubling up to 10 hours; success resets it.
    // Remove all old instances first to free TasksRunner capacity for the replacements.
    for (uint256 i = 0; i < deprecatedTriggerOrderTasks.length; i++) {
      tasksRunner.removeTask(deprecatedTriggerOrderTasks[i]);
    }
    for (uint256 i = 0; i < newTriggerOrderTasks.length; i++) {
      tasksRunner.addTask(newTriggerOrderTasks[i]);
    }

    // 9. Upgrade both registered price feeds to oracles v3.0.21, enabling V4
    // publications with expiration while preserving the legacy V3 publishing API.
    // The proxy state and round schedules are retained; no reinitialization is needed.
    flowUpgradeDelegator.upgrade(btcUsdCoinPair, newCoinPairPriceImplementation);
    flowUpgradeDelegator.upgrade(rifUsdCoinPair, newCoinPairPriceImplementation);
  }

  function _updateMocRewardsBuffer() internal {
    // Require the expected 70/30 layout before changing only the intermediate route.
    require(mocRewardsBuffer.getNumOutputs() == 2, "Expected two MOC rewards outputs");
    (, uint256 retainedSplit, , ) = mocRewardsBuffer.getOutput(0);
    (address previousRecipient, uint256 split, , uint256 threshold) = mocRewardsBuffer.getOutput(1);
    require(retainedSplit == 70 && split == 30, "Expected 70/30 MOC rewards split");
    require(previousRecipient == tasksRunnerBuffer, "Unexpected MOC rewards recipient");
    // Removing the 30% output sends any pending balance to tasksRunnerBuffer,
    // whose zero thresholds allow that final payment to be drained manually.
    mocRewardsBuffer.removeOutput(1);

    // Preserve the 70% output and general liquidation threshold. Both new outputs
    // inherit the removed output's flush threshold, preserving the total split of 100.
    mocRewardsBuffer.addOutput(payable(address(tasksRunner)), 3, threshold);
    mocRewardsBuffer.addOutput(payable(btcUsdCoinPair), 27, threshold);
  }

  function _resetBufferThresholds(IMIP264301Buffer buffer) internal {
    // Permit any positive unallocated balance to be liquidated, however small.
    buffer.setThreshold(0);
    uint256 count = buffer.getNumOutputs();
    address[] memory recipients = new address[](count);
    uint256[] memory splits = new uint256[](count);
    // Snapshot recipients and splits so recreation preserves the existing routing.
    for (uint256 i = 0; i < count; i++) {
      (recipients[i], splits[i], , ) = buffer.getOutput(i);
    }
    // Remove from the end to avoid moving outputs into another index.
    // removeOutput pays each output's pending balance to its existing recipient.
    for (uint256 i = count; i > 0; i--) {
      buffer.removeOutput(i - 1);
    }
    // Restore the original order with zero flush thresholds. Any positive pending
    // balance can then be flushed; historical unassigned rounding dust may remain.
    for (uint256 i = 0; i < count; i++) {
      buffer.addOutput(payable(recipients[i]), splits[i], 0);
    }
  }
}
