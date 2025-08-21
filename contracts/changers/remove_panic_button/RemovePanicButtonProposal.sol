// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { IMoC } from "../../interfaces/IMoC.sol";

/**
 * @title RemovePanicButtonProposal
 * @notice Changer that: (1) removes the panic button (makes MoC unstoppable).
 * @dev Designed for a single execution via governance. Uses a "fuse" pattern to prevent re-execution.
 */
contract RemovePanicButtonProposal is IChangeContract {
    
    IMoC public moc;
    /// @notice Emitted after disabling the panic button on MoC
    event PanicButtonRemoved();

    /// @notice Emitted once after the changer finishes and burns its own references
    event ExecutedOnce();

    /**     
     * @param _moc MoC contract (minimal interface)     
     */
    constructor(IMoC _moc) {
        // Sanity checks on external targets and inputs        
        require(address(_moc) != address(0), "Wrong MoC address");        
        moc = _moc;
    }

    /**
     * @notice Executes the changer exactly once. Callable by governance.
     * @dev Uses a double guard (moc must be non-zero). After running,
     *      both are zeroed out to burn references and prevent re-execution.
     */
    function execute() external {
        // One-time execution fuse: both references must be intact        
        require(address(moc) != address(0), "This changer was already executed");
        
        // (1) Remove panic button on MoC
        moc.makeUnstoppable();
        emit PanicButtonRemoved();

        // Burn references to prevent any future execution attempts        
        moc = IMoC(address(0));

        emit ExecutedOnce();
    }
    
}
