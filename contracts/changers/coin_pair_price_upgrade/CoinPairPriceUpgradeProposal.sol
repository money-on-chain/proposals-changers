// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IUpgradeDelegator {
  function upgrade(address proxy, address newImplementation) external;
}

/**
 * @title CoinPairPriceUpgradeProposal
 * @notice ChangeContract used to upgrade an existing CoinPairPrice proxy
 *         using the Money on Chain UpgradeDelegator pattern.
 */
contract CoinPairPriceUpgradeProposal is IChangeContract {
  address public coinPairProxy;
  address public oracleManagerProxy;
  IUpgradeDelegator public upgradeDelegator;
  address public newCoinPairPriceImplementation;
  address public newOracleManagerImplementation;

  constructor(
    address _coinPairProxy,
    address _oracleManagerProxy,
    IUpgradeDelegator _upgradeDelegator,
    address _newCoinPairPriceImplementation,
    address _newOracleManagerImplementation
  ) {
    coinPairProxy = _coinPairProxy;
    oracleManagerProxy = _oracleManagerProxy;
    upgradeDelegator = _upgradeDelegator;
    newCoinPairPriceImplementation = _newCoinPairPriceImplementation;
    newOracleManagerImplementation = _newOracleManagerImplementation;
  }

  function execute() external {
    _beforeUpgrade();
    _upgrade();
    _afterUpgrade();
  }

  function _upgrade() internal {
    upgradeDelegator.upgrade(oracleManagerProxy, newOracleManagerImplementation);
    upgradeDelegator.upgrade(coinPairProxy, newCoinPairPriceImplementation);
  }

  function _beforeUpgrade() internal virtual {}

  function _afterUpgrade() internal virtual {}
}
