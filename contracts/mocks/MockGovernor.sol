// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockGovernor
/// @author Money On Chain
/// @notice Minimal governor mock for tests. Adapts to common Governed patterns by exposing a few typical selectors.
contract MockGovernor {
    /// @notice Mapping of authorized changers
    mapping(address => bool) public authorized;

    /// @notice Sets the authorization status for a changer
    /// @param changer The address of the changer
    /// @param isAuth Whether the changer is authorized
    function setAuthorized(address changer, bool isAuth) external {
        authorized[changer] = isAuth;
    }

    /// @notice Checks if a changer is authorized (common pattern)
    /// @param changer The address of the changer
    /// @return True if authorized, false otherwise
    function isAuthorizedChanger(address changer) external view returns (bool) {
        return authorized[changer];
    }

    /// @notice Checks if a changer is authorized (alternative name)
    /// @param changer The address of the changer
    /// @return True if authorized, false otherwise
    function isAuthorized(address changer) external view returns (bool) {
        return authorized[changer];
    }
}
