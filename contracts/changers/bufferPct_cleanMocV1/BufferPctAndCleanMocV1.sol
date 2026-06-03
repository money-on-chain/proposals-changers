// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { MocBaseBucket } from "moc-main-latest/contracts/core/MocBaseBucket.sol";

interface IUpgradeDelegator {
  function upgrade(address proxy, address newImplementation) external;
}

interface IBufferToken {
  function getOutput(uint256 idx) external view returns (address, uint256, uint256, uint256);
  function removeOutput(uint256 idx) external;
  function addOutput(address payable output, uint256 split, uint256 threshold) external;
  function getNumOutputs() external view returns (uint256);
}

interface IOracleManager {
  function clearRegisteredOwner(address oracleAddr) external;
}

/**
 * @title BufferPctAndCleanMocV1
 * @notice ChangeContract used to set new Buffer pcts and clean MOC V1
 */
contract BufferPctAndCleanMocV1 is IChangeContract {
  address public immutable oracleManagerProxy;
  address public immutable coinPairProxy;
  address public immutable mocRewardsBufferProxy;
  address public immutable mocV1Proxy;
  address public immutable mocStateV1Proxy;
  address public immutable mocExchangeV1Proxy;
  address public immutable mocSettlementV1Proxy;
  address public immutable rifBucketProxy;
  IUpgradeDelegator public immutable upgradeDelegatorOracle;
  IUpgradeDelegator public immutable upgradeDelegatorMoc;
  address public immutable newCoinPairPriceImplementation;
  address public immutable newOracleManagerImplementation;
  address public immutable newMocV1Implementation;
  address public immutable newMocStateV1Implementation;
  address public immutable newMocExchangeV1Implementation;
  address public immutable newMocSettlementV1Implementation;
  address public immutable newMaxAbsoluteOpProvider;
  address public immutable newMaxOpDifferenceProvider;
  address[] public deprecatedOracles;

  constructor(
    address _oracleManagerProxy,
    address _coinPairProxy,
    address _mocRewardsBufferProxy,
    address _mocV1Proxy,
    address _mocStateV1Proxy,
    address _mocExchangeV1Proxy,
    address _mocSettlementV1Proxy,
    address _rifBucketProxy,
    IUpgradeDelegator _upgradeDelegatorOracle,
    IUpgradeDelegator _upgradeDelegatorMoc,
    address _newCoinPairPriceImplementation,
    address _newOracleManagerImplementation,
    address _newMocV1Implementation,
    address _newMocStateV1Implementation,
    address _newMocExchangeV1Implementation,
    address _newMocSettlementV1Implementation,
    address _newMaxAbsoluteOpProvider,
    address _newMaxOpDifferenceProvider,
    address[] memory _deprecatedOracles
  ) {
    oracleManagerProxy = _oracleManagerProxy;
    coinPairProxy = _coinPairProxy;
    mocRewardsBufferProxy = _mocRewardsBufferProxy;
    mocV1Proxy = _mocV1Proxy;
    mocStateV1Proxy = _mocStateV1Proxy;
    mocExchangeV1Proxy = _mocExchangeV1Proxy;
    mocSettlementV1Proxy = _mocSettlementV1Proxy;
    rifBucketProxy = _rifBucketProxy;
    upgradeDelegatorOracle = _upgradeDelegatorOracle;
    upgradeDelegatorMoc = _upgradeDelegatorMoc;
    newCoinPairPriceImplementation = _newCoinPairPriceImplementation;
    newOracleManagerImplementation = _newOracleManagerImplementation;
    newMocV1Implementation = _newMocV1Implementation;
    newMocStateV1Implementation = _newMocStateV1Implementation;
    newMocExchangeV1Implementation = _newMocExchangeV1Implementation;
    newMocSettlementV1Implementation = _newMocSettlementV1Implementation;
    newMaxAbsoluteOpProvider = _newMaxAbsoluteOpProvider;
    newMaxOpDifferenceProvider = _newMaxOpDifferenceProvider;
    deprecatedOracles = _deprecatedOracles;
  }

  function execute() external {
    _beforeUpgrade();
    _upgrade();
    _afterUpgrade();
  }

  function _upgrade() internal {
    upgradeDelegatorOracle.upgrade(coinPairProxy, newCoinPairPriceImplementation);
    upgradeDelegatorOracle.upgrade(oracleManagerProxy, newOracleManagerImplementation);
    upgradeDelegatorMoc.upgrade(mocV1Proxy, newMocV1Implementation);
    upgradeDelegatorMoc.upgrade(mocStateV1Proxy, newMocStateV1Implementation);
    upgradeDelegatorMoc.upgrade(mocExchangeV1Proxy, newMocExchangeV1Implementation);
    upgradeDelegatorMoc.upgrade(mocSettlementV1Proxy, newMocSettlementV1Implementation);
  }

  function _beforeUpgrade() internal virtual {}

  function _afterUpgrade() internal virtual {
    // skipped for testnet, rewards are collected to the multisig and not distributed with the Buffer
    if (mocRewardsBufferProxy != address(0)) {
      setBufferSplits();
    }
    setRifBucketFluxCapacitorProviders();
    removeOldOracleOwners();
  }

  function setRifBucketFluxCapacitorProviders() internal {
    MocBaseBucket rifBucket = MocBaseBucket(rifBucketProxy);
    rifBucket.setFluxCapacitorParams(
      newMaxAbsoluteOpProvider,
      newMaxOpDifferenceProvider,
      rifBucket.decayTimeSpan()
    );
  }

  function setBufferSplits() internal {
    IBufferToken buffer = IBufferToken(mocRewardsBufferProxy);
    require(buffer.getNumOutputs() == 2, "Buffer must have exactly 2 outputs");

    (address output0, , , uint256 threshold0) = buffer.getOutput(0);
    (address output1, , , uint256 threshold1) = buffer.getOutput(1);

    buffer.removeOutput(1);
    buffer.removeOutput(0);

    buffer.addOutput(payable(output0), 70, threshold0);
    buffer.addOutput(payable(output1), 30, threshold1);
  }

  function removeOldOracleOwners() internal {
    IOracleManager oracleManager = IOracleManager(oracleManagerProxy);
    for (uint256 i = 0; i < deprecatedOracles.length; i++) {
      oracleManager.clearRegisteredOwner(deprecatedOracles[i]);
    }
  }
}
