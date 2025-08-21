// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @notice Minimal interface for the MoCInrate contract (only methods used by changers)
interface IMoCInrate {
    function setBitProRate(uint256 newBitProRate) external;
    function setCommissionRateByTxType(uint8 txType, uint256 value) external;
}