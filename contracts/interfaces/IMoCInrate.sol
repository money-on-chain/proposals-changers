// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title IMoCInrate
/// @author Money On Chain
/// @notice Minimal interface for the MoCInrate contract (only methods used by changers)
interface IMoCInrate {
    /// @notice Sets the BitPro rate
    /// @param newBitProRate The new BitPro rate
    function setBitProRate(uint256 newBitProRate) external;

    /// @notice Sets the commission rate for a transaction type
    /// @param txType The transaction type
    /// @param value The fee value
    function setCommissionRateByTxType(uint8 txType, uint256 value) external;

    /// @notice Gets the BitPro rate
    /// @return The BitPro rate
    function bitProRate() external view returns (uint256);

    /// @notice Gets the commission rate for a transaction type
    /// @param txType The transaction type
    /// @return The fee value
    function commissionRatesByTxType(uint8 txType) external view returns (uint256);

    /// @notice Gets the governor address
    /// @return The governor address
    function governor() external view returns (address);
}
