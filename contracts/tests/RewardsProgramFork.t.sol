// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TaskTriggerOrder } from "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol";
import { TaskSplit } from "@moc/oracles/contracts/tasks/mocFlow/commissionSplitter/TaskSplit.sol";
import { TaskRewardsStartPeriod } from "@moc/oracles/contracts/tasks/mocFlow/rewards/TaskRewardsStartPeriod.sol";
import { MIP264301FlowUpdate, IMIP264301UpgradeDelegator, IMIP264301Buffer, IMIP264301TasksRunner, IMIP264301TriggerOrderTask } from "../changers/mip26_4301/MIP264301FlowUpdate.sol";
import { RewardsProgram, IRewardsProgramCoiner, IRewardsProgramDistributor, IRewardsProgramTasksRunner } from "../changers/rewards_program/RewardsProgram.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

interface ICoinerForkProbe is IRewardsProgramCoiner {
  function governor() external view returns (address);
  function getSecondaryDestination() external view returns (address);
  function getSecondaryDestinationPercent() external view returns (uint256);
  function getFirstStagePercent() external view returns (uint256);
  function getSecondStageConstant() external view returns (uint256);
  function getTotalMintTarget() external view returns (uint256);
  function getRemainingToMint() external view returns (uint256);
  function getStage2BeginThreshold() external view returns (uint256);
  function getMintTimestampInterval() external view returns (uint256);
  function getNextMintAt() external view returns (uint256);
  function mintStep() external;
}

interface ITasksRunnerForkProbe is IRewardsProgramTasksRunner {
  function getTasks() external view returns (address[] memory);
  function containsTask(address task) external view returns (bool);
}

interface IDistributorForkProbe is IRewardsProgramDistributor {
  function task() external view returns (address);
  function canStartDistributionPeriod() external view returns (bool);
  function startDistributionPeriod() external;
}

interface IGovernorOwnerProbe {
  function owner() external view returns (address);
}

contract ForkRewardsDistributor is IDistributorForkProbe {
  IGovernor public immutable governor;
  address public override task;
  bool public canStart = true;
  uint256 public startedPeriods;

  constructor(IGovernor governor_) {
    governor = governor_;
  }

  function setTask(address newTask) external override {
    require(governor.isAuthorizedChanger(msg.sender), "not_authorized_changer");
    task = newTask;
  }

  function canStartDistributionPeriod() external view override returns (bool) {
    return canStart;
  }

  function startDistributionPeriod() external override {
    require(msg.sender == task, "Not authorized task");
    startedPeriods++;
    canStart = false;
  }
}

/** @notice Executes RewardsProgram against the real Coiner, TasksRunner, MOC token, and governance on mainnet. */
contract RewardsProgramForkTest is Test {
  uint256 internal constant FORK_BLOCK = 9_350_345;

  ICoinerForkProbe internal coiner;
  IDistributorForkProbe internal distributor;
  ITasksRunnerForkProbe internal tasksRunner;
  IGovernor internal governor;
  IERC20 internal mocToken;
  RewardsProgram internal changer;

  function setUp() public {
    vm.createSelectFork(
      vm.envOr("RSK_MAINNET_RPC_URL", string("https://public-node.rsk.co")),
      FORK_BLOCK
    );

    string memory params = vm.readFile(
      "./ignition/modules/RewardsProgram/parameters/rskMainnet.json"
    );
    coiner = ICoinerForkProbe(vm.parseJsonAddress(params, ".RewardsProgramModule.coinerProxy"));
    tasksRunner = ITasksRunnerForkProbe(
      vm.parseJsonAddress(params, ".RewardsProgramModule.tasksRunner")
    );
    governor = IGovernor(coiner.governor());

    string memory lendingParams = vm.readFile(
      "./ignition/modules/LendingAndBorrowingV1/parameters/rskMainnet.json"
    );
    mocToken = IERC20(vm.parseJsonAddress(lendingParams, ".LendingAndBorrowingV1Module.mocToken"));

    _ensureMip264301Executed();

    address configuredDistributor = vm.parseJsonAddress(
      params,
      ".RewardsProgramModule.distributor"
    );
    if (configuredDistributor == address(0)) {
      distributor = new ForkRewardsDistributor(governor);
    } else {
      distributor = IDistributorForkProbe(configuredDistributor);
    }

    changer = new RewardsProgram(coiner, distributor, tasksRunner);
  }

  function testForkExecuteConfiguresCoinerDistributorAndTasksRunner() public {
    address primaryBefore = coiner.getDestination();
    assertEq(address(changer.taskRewardsStartPeriod()), address(0));

    _executeChanger(changer);

    TaskRewardsStartPeriod task = changer.taskRewardsStartPeriod();
    assertTrue(address(task) != address(0));
    assertEq(address(task.coiner()), address(coiner));
    assertEq(address(task.distributor()), address(distributor));
    assertEq(task.lastProcessedRemainingToMint(), coiner.getRemainingToMint());
    assertEq(coiner.getDestination(), primaryBefore);
    assertEq(coiner.getSecondaryDestination(), address(distributor));
    assertEq(coiner.getSecondaryDestinationPercent(), changer.SECONDARY_PERCENT());
    assertEq(distributor.task(), address(task));
    assertTrue(tasksRunner.containsTask(address(task)));
  }

  function testForkCoinerMintBeforeExecutionDoesNotMakeTaskAvailablePrematurely() public {
    // Mint occurs after changer deployment but before governance executes the changer.
    vm.warp(block.timestamp > coiner.getNextMintAt() ? block.timestamp : coiner.getNextMintAt());
    coiner.mintStep();

    _executeChanger(changer);

    TaskRewardsStartPeriod task = changer.taskRewardsStartPeriod();
    assertEq(task.lastProcessedRemainingToMint(), coiner.getRemainingToMint());
    assertFalse(task.checkTask());
  }

  function testForkCoinerMintTriggersTaskRewardsStartPeriod() public {
    _executeChanger(changer);

    TaskRewardsStartPeriod task = changer.taskRewardsStartPeriod();
    assertFalse(task.checkTask());

    uint256 remainingBefore = coiner.getRemainingToMint();
    uint256 expectedMint = remainingBefore > coiner.getStage2BeginThreshold()
      ? (remainingBefore * coiner.getFirstStagePercent()) / 10000
      : (
        remainingBefore < coiner.getSecondStageConstant()
          ? remainingBefore
          : coiner.getSecondStageConstant()
      );
    uint256 expectedSecondary = (expectedMint * changer.SECONDARY_PERCENT()) / 10000;
    uint256 primaryBalanceBefore = mocToken.balanceOf(coiner.getDestination());
    uint256 distributorBalanceBefore = mocToken.balanceOf(address(distributor));

    vm.warp(block.timestamp > coiner.getNextMintAt() ? block.timestamp : coiner.getNextMintAt());
    coiner.mintStep();

    assertEq(
      mocToken.balanceOf(coiner.getDestination()) - primaryBalanceBefore,
      expectedMint - expectedSecondary
    );
    assertEq(
      mocToken.balanceOf(address(distributor)) - distributorBalanceBefore,
      expectedSecondary
    );
    assertTrue(task.checkTask());

    task.runTask();

    assertEq(task.lastProcessedRemainingToMint(), coiner.getRemainingToMint());
    assertFalse(task.checkTask());
  }

  function testForkUnauthorizedExecutionReverts() public {
    vm.expectRevert("not_authorized_changer");
    changer.execute();
    assertEq(address(changer.taskRewardsStartPeriod()), address(0));
  }

  function testForkConstructorRejectsInvalidAddresses() public {
    vm.expectRevert("Invalid Coiner");
    new RewardsProgram(IRewardsProgramCoiner(address(0)), distributor, tasksRunner);

    vm.expectRevert("Invalid Distributor");
    new RewardsProgram(coiner, IRewardsProgramDistributor(address(0)), tasksRunner);

    vm.expectRevert("Invalid TasksRunner");
    new RewardsProgram(coiner, distributor, IRewardsProgramTasksRunner(address(0)));
  }

  function _ensureMip264301Executed() internal {
    (bool hasSecondaryGetter, ) = address(coiner).staticcall(
      abi.encodeWithSelector(ICoinerForkProbe.getSecondaryDestination.selector)
    );
    if (hasSecondaryGetter) return;

    string memory mip4301Params = vm.readFile(
      "./ignition/modules/MIP26-4301/parameters/rskMainnet.json"
    );
    TaskSplit deprecatedSplitTask = TaskSplit(
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.deprecatedSplitTask")
    );
    TaskSplit newSplitTask = new TaskSplit(
      address(deprecatedSplitTask.commissionSplitter()),
      address(0),
      address(0),
      deprecatedSplitTask.tokenBalanceThreshold(),
      deprecatedSplitTask.feeTokenBalanceThreshold()
    );
    address[2][] memory triggerOrderTasks = new address[2][](13);
    for (uint256 i = 1; i <= 13; i++) {
      address deprecatedTask = vm.parseJsonAddress(
        mip4301Params,
        string.concat(".MIP264301Module.deprecatedTriggerOrderTask", vm.toString(i))
      );
      TaskTriggerOrder replacement = new TaskTriggerOrder(
        IMIP264301TriggerOrderTask(deprecatedTask).reverseAuction(),
        5 minutes,
        10 hours
      );
      triggerOrderTasks[i - 1] = [deprecatedTask, address(replacement)];
    }

    bytes memory coinerCode = vm.getCode("Coiner");
    address coinerImpl;
    assembly ("memory-safe") {
      coinerImpl := create(0, add(coinerCode, 32), mload(coinerCode))
    }
    require(coinerImpl != address(0), "Coiner implementation deployment failed");

    bytes memory coinPairCode = vm.getCode("CoinPairPrice");
    address coinPairImpl;
    assembly ("memory-safe") {
      coinPairImpl := create(0, add(coinPairCode, 32), mload(coinPairCode))
    }
    require(coinPairImpl != address(0), "CoinPairPrice implementation deployment failed");

    MIP264301FlowUpdate mip264301 = new MIP264301FlowUpdate(
      address(coiner),
      IMIP264301UpgradeDelegator(
        vm.parseJsonAddress(mip4301Params, ".MIP264301Module.flowUpgradeDelegator")
      ),
      coinerImpl,
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.multisigRewards"),
      IMIP264301Buffer(vm.parseJsonAddress(mip4301Params, ".MIP264301Module.coinerBuffer")),
      IMIP264301TasksRunner(address(tasksRunner)),
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.coinerBufferFlushTask"),
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.coinerBufferLiquidateTask"),
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.tasksRunnerBuffer"),
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.tasksRunnerBufferFlushTask"),
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.tasksRunnerBufferLiquidateTask"),
      IMIP264301Buffer(vm.parseJsonAddress(mip4301Params, ".MIP264301Module.mocRewardsBuffer")),
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.btcUsdCoinPair"),
      [
        vm.parseJsonAddress(mip4301Params, ".MIP264301Module.reverseAuctionRifToMoc"),
        vm.parseJsonAddress(mip4301Params, ".MIP264301Module.reverseAuctionRifToMoc2"),
        vm.parseJsonAddress(mip4301Params, ".MIP264301Module.reverseAuctionRifToMoc3")
      ],
      [address(deprecatedSplitTask), address(newSplitTask)],
      triggerOrderTasks,
      vm.parseJsonAddress(mip4301Params, ".MIP264301Module.rifUsdCoinPair"),
      coinPairImpl
    );
    _executeChanger(mip264301);
  }

  function _executeChanger(IChangeContract proposal) internal {
    vm.prank(IGovernorOwnerProbe(address(governor)).owner());
    governor.executeChange(proposal);
  }
}
