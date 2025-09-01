// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MoCInrateMock {
  uint256 public bitProRate;
  mapping(uint8 => uint256) public commissionByTxType;

  event BitProRateSet(uint256 newRate);
  event CommissionRateSet(uint8 indexed txType, uint256 fee);

  function setBitProRate(uint256 newBitProRate) external {
    bitProRate = newBitProRate;
    emit BitProRateSet(newBitProRate);
  }

  function setCommissionRateByTxType(uint8 txType, uint256 value) external {
    commissionByTxType[txType] = value;
    emit CommissionRateSet(txType, value);
  }
}
