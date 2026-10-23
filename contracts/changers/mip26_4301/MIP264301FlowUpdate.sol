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
}

interface IMIP264301ReverseAuction {
  function setOrderThreshold(uint256 orderThreshold) external;
}

/** @notice Upgrades Coiner, configures mint distribution and retires buffer automation. */
contract MIP264301FlowUpdate is IChangeContract {
  address public immutable destination;
  address public immutable secondaryDestination;
  uint256 public constant SECONDARY_PERCENT = 2500;
  uint256 public constant RIF_TO_MOC_ORDER_THRESHOLD = 5000 ether;

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
  IMIP264301ReverseAuction public immutable reverseAuctionRifToMoc;
  IMIP264301ReverseAuction public immutable reverseAuctionRifToMoc2;
  IMIP264301ReverseAuction public immutable reverseAuctionRifToMoc3;

  constructor(
    address coinerProxy_,
    IMIP264301UpgradeDelegator flowUpgradeDelegator_,
    address newCoinerImplementation_,
    address destination_,
    address secondaryDestination_,
    IMIP264301Buffer coinerBuffer_,
    IMIP264301TasksRunner tasksRunner_,
    address coinerBufferFlushTask_,
    address coinerBufferLiquidateTask_,
    address tasksRunnerBuffer_,
    address tasksRunnerBufferFlushTask_,
    address tasksRunnerBufferLiquidateTask_,
    IMIP264301Buffer mocRewardsBuffer_,
    address btcUsdCoinPair_,
    address[3] memory reverseAuctionsRifToMoc_
  ) {
    require(coinerProxy_ != address(0), "Invalid Coiner proxy");
    require(address(flowUpgradeDelegator_) != address(0), "Invalid UpgradeDelegator");
    require(newCoinerImplementation_ != address(0), "Invalid implementation");
    require(destination_ != address(0), "Invalid destination");
    require(secondaryDestination_ != address(0), "Invalid secondary destination");
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
    destination = destination_;
    secondaryDestination = secondaryDestination_;
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
    reverseAuctionRifToMoc = IMIP264301ReverseAuction(reverseAuctionsRifToMoc_[0]);
    reverseAuctionRifToMoc2 = IMIP264301ReverseAuction(reverseAuctionsRifToMoc_[1]);
    reverseAuctionRifToMoc3 = IMIP264301ReverseAuction(reverseAuctionsRifToMoc_[2]);
  }

  function execute() external override {
    flowUpgradeDelegator.upgrade(coinerProxy, newCoinerImplementation);
    IMIP264301Coiner(coinerProxy).setMintDistribution(
      destination,
      secondaryDestination,
      SECONDARY_PERCENT
    );
    tasksRunner.removeTask(coinerBufferFlushTask);
    tasksRunner.removeTask(coinerBufferLiquidateTask);
    tasksRunner.removeTask(tasksRunnerBufferFlushTask);
    tasksRunner.removeTask(tasksRunnerBufferLiquidateTask);
    _resetBufferThresholds(coinerBuffer);
    _resetBufferThresholds(IMIP264301Buffer(tasksRunnerBuffer));
    _updateMocRewardsBuffer();
    reverseAuctionRifToMoc.setOrderThreshold(RIF_TO_MOC_ORDER_THRESHOLD);
    reverseAuctionRifToMoc2.setOrderThreshold(RIF_TO_MOC_ORDER_THRESHOLD);
    reverseAuctionRifToMoc3.setOrderThreshold(RIF_TO_MOC_ORDER_THRESHOLD);
  }

  function _updateMocRewardsBuffer() internal {
    require(mocRewardsBuffer.getNumOutputs() == 2, "Expected two MOC rewards outputs");
    (, uint256 retainedSplit, , ) = mocRewardsBuffer.getOutput(0);
    (address previousRecipient, uint256 split, , uint256 threshold) = mocRewardsBuffer.getOutput(1);
    require(retainedSplit == 70 && split == 30, "Expected 70/30 MOC rewards split");
    require(previousRecipient == tasksRunnerBuffer, "Unexpected MOC rewards recipient");
    // Preserve the 70% output and inherit the replaced output's flush threshold.
    mocRewardsBuffer.removeOutput(1);
    mocRewardsBuffer.addOutput(payable(address(tasksRunner)), 3, threshold);
    mocRewardsBuffer.addOutput(payable(btcUsdCoinPair), 27, threshold);
  }

  function _resetBufferThresholds(IMIP264301Buffer buffer) internal {
    buffer.setThreshold(0);
    uint256 count = buffer.getNumOutputs();
    address[] memory recipients = new address[](count);
    uint256[] memory splits = new uint256[](count);
    for (uint256 i = 0; i < count; i++) {
      (recipients[i], splits[i], , ) = buffer.getOutput(i);
    }
    // Remove from the end to avoid moving outputs into another index.
    // removeOutput pays each output's pending balance to its existing recipient.
    for (uint256 i = count; i > 0; i--) {
      buffer.removeOutput(i - 1);
    }
    for (uint256 i = 0; i < count; i++) {
      buffer.addOutput(payable(recipients[i]), splits[i], 0);
    }
  }
}
