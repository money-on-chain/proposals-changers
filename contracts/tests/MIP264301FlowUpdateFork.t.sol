// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { TaskTriggerOrder } from "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol";
import { TaskSplit } from "@moc/oracles/contracts/tasks/mocFlow/commissionSplitter/TaskSplit.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MIP264301FlowUpdate, IMIP264301UpgradeDelegator, IMIP264301Coiner, IMIP264301Buffer, IMIP264301TasksRunner } from "../changers/mip26_4301/MIP264301FlowUpdate.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

interface ICoinerDistributionProbe is IMIP264301Coiner {
  function governor() external view returns (address);
  function getDestination() external view returns (address);
  function getSecondaryDestination() external view returns (address);
  function getSecondaryDestinationPercent() external view returns (uint256);
  function getFirstStagePercent() external view returns (uint256);
  function getSecondStageConstant() external view returns (uint256);
  function getTotalMintTarget() external view returns (uint256);
  function getRemainingToMint() external view returns (uint256);
  function getStage2BeginThreshold() external view returns (uint256);
  function getMintTimestampInterval() external view returns (uint256);
  function getNextMintAt() external view returns (uint256);
  function setStage2BeginThreshold(uint256 threshold) external;
  function mintStep() external;
}

interface IBufferRetirementProbe is IMIP264301Buffer {
  function getLiquidated() external view returns (uint256);
  function liquidate() external;
  function flush(uint256 index) external;
}

interface ITasksRunnerRetirementProbe is IMIP264301TasksRunner {
  function getTasks() external view returns (address[] memory);
  function containsTask(address task) external view returns (bool);
}

interface ITriggerOrderAuctionProbe {
  function reverseAuction() external view returns (address);
}

interface IRifToMocAuctionThresholdProbe {
  function orderThreshold() external view returns (uint256);
}

interface ICoinerGovernorOwner {
  function owner() external view returns (address);
}

/// @dev Exercises stage 2 through real governance without exhausting MOC's supply cap.
contract CoinerStage2TestChanger is IChangeContract {
  ICoinerDistributionProbe internal immutable coiner;

  constructor(ICoinerDistributionProbe coiner_) {
    coiner = coiner_;
  }

  function execute() external {
    coiner.setStage2BeginThreshold(coiner.getRemainingToMint());
  }
}

/** @notice Executes MIP26-4301 against the real Coiner, token and governance on mainnet. */
contract MIP264301FlowUpdateForkTest is Test {
  uint256 internal constant FORK_BLOCK = 9_350_345;
  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  ICoinerDistributionProbe internal coiner;
  IERC20 internal token;
  IGovernor internal governor;
  IMIP264301UpgradeDelegator internal upgradeDelegator;
  MIP264301FlowUpdate internal changer;
  IBufferRetirementProbe internal coinerBuffer;
  ITasksRunnerRetirementProbe internal tasksRunner;
  address internal coinerBufferFlushTask;
  address internal coinerBufferLiquidateTask;
  address internal tasksRunnerBuffer;
  address internal tasksRunnerBufferFlushTask;
  address internal tasksRunnerBufferLiquidateTask;
  address internal previousImplementation;
  address internal implementation;
  IBufferRetirementProbe internal mocRewardsBuffer;
  address internal btcUsdCoinPair;
  address[3] internal reverseAuctionsRifToMoc;
  TaskSplit internal deprecatedSplitTask;
  TaskSplit internal newSplitTask;
  address[2][] internal triggerOrderTaskReplacements;

  function setUp() public {
    vm.createSelectFork(
      vm.envOr("RSK_MAINNET_RPC_URL", string("https://public-node.rsk.co")),
      FORK_BLOCK
    );
    string memory params = vm.readFile("./ignition/modules/MIP26-4301/parameters/rskMainnet.json");
    coiner = ICoinerDistributionProbe(vm.parseJsonAddress(params, ".MIP264301Module.coinerProxy"));
    upgradeDelegator = IMIP264301UpgradeDelegator(
      vm.parseJsonAddress(params, ".MIP264301Module.flowUpgradeDelegator")
    );
    string memory lendingParams = vm.readFile(
      "./ignition/modules/LendingAndBorrowingV1/parameters/rskMainnet.json"
    );
    token = IERC20(vm.parseJsonAddress(lendingParams, ".LendingAndBorrowingV1Module.mocToken"));
    coinerBuffer = IBufferRetirementProbe(
      vm.parseJsonAddress(params, ".MIP264301Module.coinerBuffer")
    );
    tasksRunner = ITasksRunnerRetirementProbe(
      vm.parseJsonAddress(params, ".MIP264301Module.tasksRunner")
    );
    coinerBufferFlushTask = vm.parseJsonAddress(params, ".MIP264301Module.coinerBufferFlushTask");
    coinerBufferLiquidateTask = vm.parseJsonAddress(
      params,
      ".MIP264301Module.coinerBufferLiquidateTask"
    );
    tasksRunnerBuffer = vm.parseJsonAddress(params, ".MIP264301Module.tasksRunnerBuffer");
    tasksRunnerBufferFlushTask = vm.parseJsonAddress(
      params,
      ".MIP264301Module.tasksRunnerBufferFlushTask"
    );
    tasksRunnerBufferLiquidateTask = vm.parseJsonAddress(
      params,
      ".MIP264301Module.tasksRunnerBufferLiquidateTask"
    );
    mocRewardsBuffer = IBufferRetirementProbe(
      vm.parseJsonAddress(params, ".MIP264301Module.mocRewardsBuffer")
    );
    btcUsdCoinPair = vm.parseJsonAddress(params, ".MIP264301Module.btcUsdCoinPair");
    reverseAuctionsRifToMoc = [
      vm.parseJsonAddress(params, ".MIP264301Module.reverseAuctionRifToMoc"),
      vm.parseJsonAddress(params, ".MIP264301Module.reverseAuctionRifToMoc2"),
      vm.parseJsonAddress(params, ".MIP264301Module.reverseAuctionRifToMoc3")
    ];
    deprecatedSplitTask = TaskSplit(
      vm.parseJsonAddress(params, ".MIP264301Module.deprecatedSplitTask")
    );
    newSplitTask = new TaskSplit(
      address(deprecatedSplitTask.commissionSplitter()),
      address(0),
      address(0),
      deprecatedSplitTask.tokenBalanceThreshold(),
      deprecatedSplitTask.feeTokenBalanceThreshold()
    );
    for (uint256 i = 1; i <= 13; i++) {
      address deprecatedTask = vm.parseJsonAddress(
        params,
        string.concat(".MIP264301Module.deprecatedTriggerOrderTask", vm.toString(i))
      );
      TaskTriggerOrder replacement = new TaskTriggerOrder(
        ITriggerOrderAuctionProbe(deprecatedTask).reverseAuction(),
        5 minutes,
        10 hours
      );
      triggerOrderTaskReplacements.push([deprecatedTask, address(replacement)]);
    }
    governor = IGovernor(coiner.governor());
    previousImplementation = _implementation();
    // Only deploy the proposed implementation; retain the existing mainnet proxy and state.
    bytes memory code = vm.getCode("Coiner");
    address deployed;
    assembly ("memory-safe") {
      deployed := create(0, add(code, 32), mload(code))
    }
    require(deployed != address(0), "Coiner implementation deployment failed");
    implementation = deployed;
    changer = _deployChanger(
      implementation,
      tasksRunner,
      vm.parseJsonAddress(params, ".MIP264301Module.destination"),
      vm.parseJsonAddress(params, ".MIP264301Module.secondaryDestination")
    );
    assertGt(address(coiner).code.length, 0);
    assertGt(address(token).code.length, 0);
    assertTrue(previousImplementation != implementation);
  }

  function testForkUpgradePreservesMainnetState() public {
    bytes32 stateBefore = _emissionState();
    address governorBefore = coiner.governor();
    uint256 supplyBefore = token.totalSupply();
    _executeChanger(changer);
    assertEq(_implementation(), implementation);
    assertEq(_emissionState(), stateBefore, "Emission state changed during upgrade");
    assertEq(coiner.governor(), governorBefore);
    assertEq(token.totalSupply(), supplyBefore);
    assertEq(coiner.getDestination(), changer.destination());
    assertEq(coiner.getSecondaryDestination(), changer.secondaryDestination());
    assertEq(coiner.getSecondaryDestinationPercent(), 2500);
  }

  function testForkMintDistributes75And25Percent() public {
    _executeChanger(changer);
    assertGt(coiner.getRemainingToMint(), coiner.getStage2BeginThreshold());
    _mintAndAssertSplit();
  }

  function testForkStage2MintDistribution() public {
    _executeChanger(changer);
    // Real governance selects stage 2 without minting past MOC's circulation cap.
    CoinerStage2TestChanger stage2 = new CoinerStage2TestChanger(coiner);
    vm.prank(ICoinerGovernorOwner(address(governor)).owner());
    governor.executeChange(IChangeContract(address(stage2)));
    assertEq(coiner.getRemainingToMint(), coiner.getStage2BeginThreshold());
    assertGt(coiner.getRemainingToMint(), 0);
    _mintAndAssertSplit();
  }

  function testForkUnauthorizedExecutionReverts() public {
    vm.expectRevert();
    changer.execute();
    assertEq(_implementation(), previousImplementation);
  }

  function testForkDistributionRemainsGovernanceProtected() public {
    _executeChanger(changer);
    vm.expectRevert("not_authorized_changer");
    coiner.setMintDistribution(address(this), address(this), 10000);
  }

  function testForkDistributionFailureRollsBackUpgrade() public {
    bytes32 stateBefore = _emissionState();
    // Changer bytecode has no distribution setter, so configuration must revert.
    MIP264301FlowUpdate invalid = _deployChanger(
      address(changer),
      tasksRunner,
      changer.destination(),
      changer.secondaryDestination()
    );
    address governorOwner = ICoinerGovernorOwner(address(governor)).owner();
    vm.prank(governorOwner);
    vm.expectRevert();
    governor.executeChange(IChangeContract(address(invalid)));
    assertEq(_implementation(), previousImplementation);
    assertEq(_emissionState(), stateBefore);
  }

  function testForkRemovesCoinerBufferTasks() public {
    assertTrue(tasksRunner.containsTask(coinerBufferFlushTask));
    assertTrue(tasksRunner.containsTask(coinerBufferLiquidateTask));
    _executeChanger(changer);
    assertFalse(tasksRunner.containsTask(coinerBufferFlushTask));
    assertFalse(tasksRunner.containsTask(coinerBufferLiquidateTask));
  }

  function testForkRemovesTasksRunnerBufferTasks() public {
    assertTrue(tasksRunner.containsTask(tasksRunnerBufferFlushTask));
    assertTrue(tasksRunner.containsTask(tasksRunnerBufferLiquidateTask));
    _executeChanger(changer);
    assertFalse(tasksRunner.containsTask(tasksRunnerBufferFlushTask));
    assertFalse(tasksRunner.containsTask(tasksRunnerBufferLiquidateTask));
  }

  function testForkBufferCanBeDrainedToRecipients() public {
    _executeChanger(changer);
    // Keep historical rounding dust and add 100 units to distribute 75/25.
    uint256 historicalDust = coinerBuffer.getLiquidated();
    deal(address(token), address(coinerBuffer), historicalDust + 100);
    uint256 primaryBefore = token.balanceOf(changer.destination());
    uint256 secondaryBefore = token.balanceOf(changer.secondaryDestination());

    coinerBuffer.liquidate();
    for (uint256 i = 0; i < coinerBuffer.getNumOutputs(); i++) {
      coinerBuffer.flush(i);
    }

    assertEq(token.balanceOf(changer.destination()), primaryBefore + 75);
    assertEq(token.balanceOf(changer.secondaryDestination()), secondaryBefore + 25);
    assertEq(token.balanceOf(address(coinerBuffer)), historicalDust);
  }

  function testForkTasksRunnerBufferCanBeDrainedToRecipients() public {
    IBufferRetirementProbe buffer = IBufferRetirementProbe(tasksRunnerBuffer);
    (address oracleRecipient, , , ) = buffer.getOutput(0);
    (address runnerRecipient, , , ) = buffer.getOutput(1);
    _executeChanger(changer);
    uint256 historicalDust = buffer.getLiquidated();
    deal(address(token), tasksRunnerBuffer, historicalDust + 100);
    uint256 oracleBefore = token.balanceOf(oracleRecipient);
    uint256 runnerBefore = token.balanceOf(runnerRecipient);

    buffer.liquidate();
    for (uint256 i = 0; i < buffer.getNumOutputs(); i++) {
      buffer.flush(i);
    }

    assertEq(token.balanceOf(oracleRecipient), oracleBefore + 90);
    assertEq(token.balanceOf(runnerRecipient), runnerBefore + 10);
    assertEq(token.balanceOf(tasksRunnerBuffer), historicalDust);
  }

  function testForkMocRewardsBufferDistributes70And3And27Percent() public {
    (
      address retainedRecipient,
      uint256 retainedSplit,
      uint256 retainedBalance,
      uint256 retainedThreshold
    ) = mocRewardsBuffer.getOutput(0);
    (, , , uint256 replacedThreshold) = mocRewardsBuffer.getOutput(1);
    _executeChanger(changer);
    assertEq(mocRewardsBuffer.getNumOutputs(), 3);
    (address recipient, uint256 split, uint256 balance, uint256 threshold) = mocRewardsBuffer
      .getOutput(0);
    assertEq(recipient, retainedRecipient);
    assertEq(split, retainedSplit);
    assertEq(balance, retainedBalance);
    assertEq(threshold, retainedThreshold);
    (recipient, split, balance, threshold) = mocRewardsBuffer.getOutput(1);
    assertEq(recipient, address(tasksRunner));
    assertEq(split, 3);
    assertEq(balance, 0);
    assertEq(threshold, replacedThreshold);
    (recipient, split, balance, threshold) = mocRewardsBuffer.getOutput(2);
    assertEq(recipient, btcUsdCoinPair);
    assertEq(split, 27);
    assertEq(balance, 0);
    assertEq(threshold, replacedThreshold);

    // Exceed the original flush thresholds without minting from Coiner.
    uint256 amount = (retainedThreshold + replacedThreshold + 1) * 100;
    deal(address(token), address(mocRewardsBuffer), mocRewardsBuffer.getLiquidated() + amount);
    uint256 retainedBefore = token.balanceOf(retainedRecipient);
    uint256 runnerBefore = token.balanceOf(address(tasksRunner));
    uint256 oracleBefore = token.balanceOf(btcUsdCoinPair);
    mocRewardsBuffer.liquidate();
    mocRewardsBuffer.flush(0);
    mocRewardsBuffer.flush(1);
    mocRewardsBuffer.flush(2);
    assertEq(
      token.balanceOf(retainedRecipient),
      retainedBefore + retainedBalance + (amount * 70) / 100
    );
    assertEq(token.balanceOf(address(tasksRunner)), runnerBefore + (amount * 3) / 100);
    assertEq(token.balanceOf(btcUsdCoinPair), oracleBefore + (amount * 27) / 100);
  }

  function testForkLowersRifToMocOrderThresholds() public {
    for (uint256 i = 0; i < reverseAuctionsRifToMoc.length; i++) {
      assertEq(
        IRifToMocAuctionThresholdProbe(reverseAuctionsRifToMoc[i]).orderThreshold(),
        20000 ether
      );
    }
    _executeChanger(changer);
    for (uint256 i = 0; i < reverseAuctionsRifToMoc.length; i++) {
      assertEq(
        IRifToMocAuctionThresholdProbe(reverseAuctionsRifToMoc[i]).orderThreshold(),
        5000 ether
      );
    }
  }

  function testForkReplacesCommissionSplitTask() public {
    assertTrue(tasksRunner.containsTask(address(deprecatedSplitTask)));
    assertFalse(tasksRunner.containsTask(address(newSplitTask)));
    _executeChanger(changer);
    assertFalse(tasksRunner.containsTask(address(deprecatedSplitTask)));
    assertTrue(tasksRunner.containsTask(address(newSplitTask)));
    assertEq(
      address(newSplitTask.commissionSplitter()),
      address(deprecatedSplitTask.commissionSplitter())
    );
    assertEq(newSplitTask.tokenBalanceThreshold(), deprecatedSplitTask.tokenBalanceThreshold());
    assertEq(
      newSplitTask.feeTokenBalanceThreshold(),
      deprecatedSplitTask.feeTokenBalanceThreshold()
    );
  }

  function testForkSplitTaskIgnoresFeeTokensAndRunsOnlyForRBTC() public {
    _executeChanger(changer);
    address splitter = address(newSplitTask.commissionSplitter());
    uint256 nativeThreshold = newSplitTask.tokenBalanceThreshold();
    uint256 feeThreshold = newSplitTask.feeTokenBalanceThreshold();
    vm.deal(splitter, 0);
    deal(address(token), splitter, feeThreshold);
    assertTrue(deprecatedSplitTask.checkTask());
    deprecatedSplitTask.runTask();
    assertTrue(deprecatedSplitTask.checkTask(), "Old task stays available after splitting");
    assertFalse(newSplitTask.checkTask(), "Fee tokens must not make replacement available");
    vm.deal(splitter, nativeThreshold - 1);
    assertFalse(newSplitTask.checkTask());
    vm.deal(splitter, nativeThreshold);
    assertTrue(newSplitTask.checkTask());
    newSplitTask.runTask();
    assertFalse(newSplitTask.checkTask(), "Task must stop being available after splitting RBTC");
    assertEq(splitter.balance, 0);
    assertEq(token.balanceOf(splitter), feeThreshold);
  }

  function testForkReplacesAllTriggerOrderTasksWithFiveMinuteBaseAndTenHourMax() public {
    assertEq(triggerOrderTaskReplacements.length, 13);
    address[] memory beforeTasks = tasksRunner.getTasks();
    uint256 auctionTasks;
    for (uint256 i = 0; i < beforeTasks.length; i++) {
      try ITriggerOrderAuctionProbe(beforeTasks[i]).reverseAuction() returns (address) {
        auctionTasks++;
      } catch {}
    }
    assertEq(auctionTasks, 13, "Task inventory must cover every reverse auction");
    for (uint256 i = 0; i < triggerOrderTaskReplacements.length; i++) {
      assertTrue(tasksRunner.containsTask(triggerOrderTaskReplacements[i][0]));
      assertFalse(tasksRunner.containsTask(triggerOrderTaskReplacements[i][1]));
    }
    _executeChanger(changer);
    // The four retired buffer tasks are the only net removals.
    assertEq(tasksRunner.getTasks().length, beforeTasks.length - 4);
    for (uint256 i = 0; i < triggerOrderTaskReplacements.length; i++) {
      address oldTask = triggerOrderTaskReplacements[i][0];
      TaskTriggerOrder replacement = TaskTriggerOrder(triggerOrderTaskReplacements[i][1]);
      assertFalse(tasksRunner.containsTask(oldTask));
      assertTrue(tasksRunner.containsTask(address(replacement)));
      assertEq(
        address(replacement.reverseAuction()),
        ITriggerOrderAuctionProbe(oldTask).reverseAuction()
      );
      assertEq(replacement.BASE_SLEEP_TIME(), 5 minutes);
      assertEq(replacement.MAX_REVERT_SLEEP_TIME(), 10 hours);
      assertEq(replacement.errorCount(), 0);
      assertEq(replacement.currentRevertSleepTime(), 0);
    }
  }

  function testForkTriggerOrderBackoffGrowsFromFiveMinutesToTenHours() public {
    _executeChanger(changer);
    TaskTriggerOrder task = TaskTriggerOrder(triggerOrderTaskReplacements[0][1]);
    // The real RBTC auction cannot swap without funds, producing real trigger failures.
    vm.deal(address(task.reverseAuction()), 0);
    task.runTask();
    assertEq(task.errorCount(), 1);
    assertEq(task.currentRevertSleepTime(), 5 minutes);
    uint256 firstFailureAt = task.lastRevertTimestamp();
    vm.warp(block.timestamp + 1);
    task.runTask();
    assertEq(task.errorCount(), 1, "Calls during backoff must not increase errors");
    assertEq(task.lastRevertTimestamp(), firstFailureAt);
    for (uint256 attempt = 2; attempt <= 9; attempt++) {
      vm.warp(task.lastRevertTimestamp() + task.currentRevertSleepTime());
      task.runTask();
      uint256 expected = (5 minutes) * (2 ** (attempt - 1));
      if (expected > 10 hours) expected = 10 hours;
      assertEq(task.errorCount(), attempt);
      assertEq(task.currentRevertSleepTime(), expected);
    }
  }

  function testForkTaskRemovalFailureRollsBackCoinerChanges() public {
    address destinationBefore = coiner.getDestination();
    bytes32 stateBefore = _emissionState();
    MIP264301FlowUpdate invalid = _deployChanger(
      implementation,
      IMIP264301TasksRunner(address(token)),
      changer.destination(),
      changer.secondaryDestination()
    );
    address governorOwner = ICoinerGovernorOwner(address(governor)).owner();
    vm.prank(governorOwner);
    vm.expectRevert();
    governor.executeChange(IChangeContract(address(invalid)));
    assertEq(_implementation(), previousImplementation);
    assertEq(coiner.getDestination(), destinationBefore);
    assertEq(_emissionState(), stateBefore);
    assertTrue(tasksRunner.containsTask(coinerBufferFlushTask));
    assertTrue(tasksRunner.containsTask(coinerBufferLiquidateTask));
  }

  function testForkOutputChangesRemainGovernanceProtected() public {
    (address recipient, uint256 split, , ) = coinerBuffer.getOutput(0);
    vm.expectRevert("not_authorized_changer");
    coinerBuffer.removeOutput(0);
    vm.expectRevert("not_authorized_changer");
    coinerBuffer.addOutput(payable(recipient), split, 0);
  }

  function _mintAndAssertSplit() internal {
    uint256 remaining = coiner.getRemainingToMint();
    uint256 amount = remaining > coiner.getStage2BeginThreshold()
      ? (remaining * coiner.getFirstStagePercent()) / 10000
      : (remaining < coiner.getSecondStageConstant() ? remaining : coiner.getSecondStageConstant());
    assertGt(amount, 0);
    uint256 primaryBefore = token.balanceOf(changer.destination());
    uint256 secondaryBefore = token.balanceOf(changer.secondaryDestination());
    uint256 coinerBalanceBefore = token.balanceOf(address(coiner));
    uint256 supplyBefore = token.totalSupply();
    vm.warp(block.timestamp > coiner.getNextMintAt() ? block.timestamp : coiner.getNextMintAt());
    coiner.mintStep();
    uint256 secondaryAmount = (amount * 2500) / 10000;
    assertEq(token.balanceOf(changer.destination()) - primaryBefore, amount - secondaryAmount);
    assertEq(token.balanceOf(changer.secondaryDestination()) - secondaryBefore, secondaryAmount);
    assertEq(token.balanceOf(address(coiner)), coinerBalanceBefore);
    assertEq(token.totalSupply() - supplyBefore, amount);
    assertEq(coiner.getRemainingToMint(), remaining - amount);
    assertEq(coiner.getNextMintAt(), block.timestamp + coiner.getMintTimestampInterval());
  }

  function _deployChanger(
    address implementation_,
    IMIP264301TasksRunner runner_,
    address destination_,
    address secondaryDestination_
  ) internal returns (MIP264301FlowUpdate) {
    address[3] memory auctions = reverseAuctionsRifToMoc;
    address[2] memory splitTasks = [address(deprecatedSplitTask), address(newSplitTask)];
    address[2][] memory triggerOrderTasks = triggerOrderTaskReplacements;
    return
      new MIP264301FlowUpdate(
        address(coiner),
        upgradeDelegator,
        implementation_,
        destination_,
        secondaryDestination_,
        coinerBuffer,
        runner_,
        coinerBufferFlushTask,
        coinerBufferLiquidateTask,
        tasksRunnerBuffer,
        tasksRunnerBufferFlushTask,
        tasksRunnerBufferLiquidateTask,
        mocRewardsBuffer,
        btcUsdCoinPair,
        auctions,
        splitTasks,
        triggerOrderTasks
      );
  }

  function _executeChanger(MIP264301FlowUpdate proposal) internal {
    vm.prank(ICoinerGovernorOwner(address(governor)).owner());
    governor.executeChange(IChangeContract(address(proposal)));
  }

  function _implementation() internal view returns (address) {
    return address(uint160(uint256(vm.load(address(coiner), IMPLEMENTATION_SLOT))));
  }

  function _emissionState() internal view returns (bytes32) {
    return
      keccak256(
        abi.encode(
          coiner.getFirstStagePercent(),
          coiner.getSecondStageConstant(),
          coiner.getTotalMintTarget(),
          coiner.getRemainingToMint(),
          coiner.getStage2BeginThreshold(),
          coiner.getMintTimestampInterval(),
          coiner.getNextMintAt()
        )
      );
  }
}
