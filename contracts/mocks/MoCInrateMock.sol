// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MoCInrateMock
/// @author Money On Chain
/// @notice Mock contract for MoCInrate, used for testing
contract MoCInrateMock {
    /// @notice BitPro rate
    uint256 public bitProRate;
    /// @notice Mapping of commission by transaction type
    mapping(uint8 => uint256) public commissionByTxType;

    /// @notice Emitted after setting BitPro rate
    /// @param newRate The new BitPro rate set
    event BitProRateSet(uint256 indexed newRate);

    /// @notice Emitted after setting commission rate by tx type
    /// @param txType The transaction type
    /// @param fee The fee set for the transaction type
    event CommissionRateSet(uint8 indexed txType, uint256 indexed fee);

    /// @notice Sets the BitPro rate
    /// @param newBitProRate The new BitPro rate
    function setBitProRate(uint256 newBitProRate) external {
        bitProRate = newBitProRate;
        emit BitProRateSet(newBitProRate);
    }

    /// @notice Sets the commission rate for a transaction type
    /// @param txType The transaction type
    /// @param value The fee value
    function setCommissionRateByTxType(uint8 txType, uint256 value) external {
        commissionByTxType[txType] = value;
        emit CommissionRateSet(txType, value);
    }
}
