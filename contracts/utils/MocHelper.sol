// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title MocHelper
/// @author Money On Chain
/// @notice Helper abstract contract for MoC-related math and checks
abstract contract MocHelper {
    /// @notice Error for invalid address
    error InvalidAddress();
    /// @notice Error for invalid value
    error InvalidValue();

    /// @notice Precision constant (1e18)
    uint256 internal constant PRECISION = 10 ** 18;
    /// @notice One constant (1e18)
    uint256 internal constant ONE = 10 ** 18;
    /// @notice Max uint256 value
    uint256 internal constant UINT256_MAX = ~uint256(0);

    /// @notice Saves gas by using unchecked increment
    /// @param i The value to increment
    /// @return The incremented value
    function unchecked_inc(uint256 i) internal pure returns (uint256) {
        unchecked {
            return i + 1;
        }
    }

    /// @notice Add precision and divide two numbers
    /// @param a_ Numerator
    /// @param b_ Denominator
    /// @return Result of (a_ * PRECISION) / b_
    function _divPrec(uint256 a_, uint256 b_) internal pure returns (uint256) {
        return (a_ * PRECISION) / b_;
    }

    /// @notice Multiply two numbers and remove precision
    /// @param a_ Term 1
    /// @param b_ Term 2
    /// @return Result of (a_ * b_) / PRECISION
    function _mulPrec(uint256 a_, uint256 b_) internal pure returns (uint256) {
        return (a_ * b_) / PRECISION;
    }

    /// @notice Reverts if value is greater than or equal to ONE
    /// @param value_ Value to check [PREC]
    function _checkLessThanOne(uint256 value_) internal pure {
        if (!(value_ < ONE)) revert InvalidValue();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */

    // Purposely left unused to save some state space to allow for future upgrades
    // slither-disable-next-line unused-state
    uint256[50] private __gap;
}
