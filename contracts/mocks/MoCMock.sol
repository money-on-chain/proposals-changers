// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MoCMock
/// @author Money On Chain
/// @notice Mock contract for MoC, used for testing
contract MoCMock {
    /// @notice Whether the contract is unstoppable
    bool public unstoppable;

    /// @notice Emitted when the contract is made unstoppable
    event MadeUnstoppable();

    /// @notice Makes the contract unstoppable (removes panic button)
    function makeUnstoppable() external {
        unstoppable = true;
        emit MadeUnstoppable();
    }
}
