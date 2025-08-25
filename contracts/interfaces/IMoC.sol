// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title IMoC
/// @author Money On Chain
/// @notice Minimal interface for the MoC contract (only methods used by changers)
interface IMoC {
    /// @notice Makes the MoC contract unstoppable (removes panic button)
    function makeUnstoppable() external;
}
