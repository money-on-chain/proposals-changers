// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @notice Minimal interface for the MoC contract (only methods used by changers)
interface IMoC {
    function makeUnstoppable() external;
}