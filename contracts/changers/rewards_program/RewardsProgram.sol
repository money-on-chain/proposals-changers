// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { TaskRewardsStartPeriod } from "@moc/oracles/contracts/tasks/mocFlow/rewards/TaskRewardsStartPeriod.sol";
import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IRewardsProgramCoiner {
  function getDestination() external view returns (address);
  function setMintDistribution(
    address destination,
    address secondaryDestination,
    uint256 secondaryPercent
  ) external;
}

interface IRewardsProgramDistributor {
  function setTask(address newTask) external;
}

interface IRewardsProgramTasksRunner {
  function addTask(address task) external;
}

/**
 * @notice Sets the Rewards Distributor as the Coiner secondary output,
 *         deploys and authorizes TaskRewardsStartPeriod on the Distributor,
 *         and registers the task in TasksRunner.
 */
contract RewardsProgram is IChangeContract {
  uint256 public constant SECONDARY_PERCENT = 2500;

  IRewardsProgramCoiner public immutable coiner;
  IRewardsProgramDistributor public immutable distributor;
  IRewardsProgramTasksRunner public immutable tasksRunner;
  TaskRewardsStartPeriod public taskRewardsStartPeriod;

  constructor(
    IRewardsProgramCoiner coiner_,
    IRewardsProgramDistributor distributor_,
    IRewardsProgramTasksRunner tasksRunner_
  ) {
    require(address(coiner_) != address(0), "Invalid Coiner");
    require(address(distributor_) != address(0), "Invalid Distributor");
    require(address(tasksRunner_) != address(0), "Invalid TasksRunner");

    coiner = coiner_;
    distributor = distributor_;
    tasksRunner = tasksRunner_;
  }

  function execute() external override {
    coiner.setMintDistribution(coiner.getDestination(), address(distributor), SECONDARY_PERCENT);
    TaskRewardsStartPeriod task = new TaskRewardsStartPeriod(address(coiner), address(distributor));
    taskRewardsStartPeriod = task;
    distributor.setTask(address(task));
    tasksRunner.addTask(address(task));
  }
}
