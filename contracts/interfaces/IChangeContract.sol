// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title IChangeContract
/// @author Money On Chain
/// @notice Interface for governance change contracts
/// @dev Implement this interface for contracts that execute governance changes.
///      Do not expose state-changing public/external functions.
interface IChangeContract {
    /// @notice Override this function with a recipe of the changes to be done when this ChangeContract is executed
    function execute() external;
}
