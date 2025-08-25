/// @notice Error for zero address
error ZeroAddress();
/// @notice Error for already executed changer
error AlreadyExecuted();
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { IMoC } from "../../interfaces/IMoC.sol";

/// @title RemovePanicButtonProposal
/// @author Money On Chain
/// @notice Changer that: (1) removes the panic button (makes MoC unstoppable).
/// @dev Designed for a single execution via governance. Uses a "fuse" pattern to prevent re-execution.
contract RemovePanicButtonProposal is IChangeContract {
    /// @notice MoC contract (minimal interface)
    IMoC public moc;

    /// @notice Emitted after disabling the panic button on MoC
    event PanicButtonRemoved();

    /// @notice Emitted once after the changer finishes and burns its own references
    event ExecutedOnce();

    /// @notice Constructor for RemovePanicButtonProposal
    /// @param _moc MoC contract (minimal interface)
    constructor(IMoC _moc) {
        if (address(_moc) == address(0)) revert ZeroAddress();
        moc = _moc;
    }

    /// @notice Executes the changer exactly once. Callable by governance.
    /// @dev Uses a double guard (moc must be non-zero). After running, reference is zeroed out to prevent re-execution.
    function execute() external override {
        if (address(moc) == address(0)) revert AlreadyExecuted();

        // (1) Remove panic button on MoC
        moc.makeUnstoppable();
        emit PanicButtonRemoved();

        // Burn references to prevent any future execution attempts
        moc = IMoC(address(0));

        emit ExecutedOnce();
    }
}
