// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IChangeContract } from "./IChangeContract.sol";

/// @title IGovernor
/// @author Money On Chain
/// @notice Governor interface for executing and authorizing governance changes
/// @dev This interface **MUST** be compatible with the corresponding Governance instance used on Production.
interface IGovernor {
    /// @notice Function to be called to make the changes described in changeContract
    /// @dev This function should be protected to only execute changes that benefit the system.
    /// @param changeContract_ Address of the contract that will execute the changes
    function executeChange(IChangeContract changeContract_) external;

    /// @notice Returns whether this `changer_` is authorized to execute changes.
    /// @param changer_ Address of the contract that will execute the changes
    /// @return True if the changer is authorized, false otherwise
    function isAuthorizedChanger(address changer_) external view returns (bool);
}
