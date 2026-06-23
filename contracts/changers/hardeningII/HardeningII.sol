// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { MocCARC20 } from "@moc/main/contracts/collateral/rc20/MocCARC20.sol";

interface IUpgradeDelegator {
  function upgrade(address proxy, address newImplementation) external;
}

/**
 * @title HardeningII
 * @notice ChangeContract used to clean MOC V1 BTCx code and do not allow to enqueue RedeemTP operations on RIF with unknown TPS
 */
contract HardeningII is IChangeContract {

  address public immutable mocV1Proxy;
  address public immutable mocStateV1Proxy;
  address public immutable mocExchangeV1Proxy;
  address public immutable mocInrateV1Proxy;
  address public immutable mocBProxManagerV1Proxy;
  MocCARC20 public immutable rifBucketProxy;
  MocCARC20 public immutable docBucketProxy;
  IUpgradeDelegator public immutable upgradeDelegatorMoc;

  address public immutable newMocV1Implementation;
  address public immutable newMocStateV1Implementation;
  address public immutable newMocExchangeV1Implementation;
  address public immutable newMocInrateV1Implementation;
  address public immutable newMocBProxManagerV1Implementation;
  address public immutable newRifBucketImplementation;
  address public immutable newDocBucketImplementation;

  constructor(
    address _mocV1Proxy,
    address _mocStateV1Proxy,
    address _mocExchangeV1Proxy,
    address _mocInrateV1Proxy,
    address _mocBProxManagerV1Proxy,
    address _rifBucketProxy,
    address _docBucketProxy,
    IUpgradeDelegator _upgradeDelegatorMoc,
    address _newMocV1Implementation,
    address _newMocStateV1Implementation,
    address _newMocExchangeV1Implementation,
    address _newMocInrateV1Implementation,
    address _newMocBProxManagerV1Implementation,
    address _newRifBucketImplementation,
    address _newDocBucketImplementation
  ) {
    mocV1Proxy = _mocV1Proxy;
    mocStateV1Proxy = _mocStateV1Proxy;
    mocExchangeV1Proxy = _mocExchangeV1Proxy;
    mocInrateV1Proxy = _mocInrateV1Proxy;
    mocBProxManagerV1Proxy = _mocBProxManagerV1Proxy;
    rifBucketProxy = MocCARC20(_rifBucketProxy);
    docBucketProxy = MocCARC20(_docBucketProxy);
    upgradeDelegatorMoc = _upgradeDelegatorMoc;
    newMocV1Implementation = _newMocV1Implementation;
    newMocStateV1Implementation = _newMocStateV1Implementation;
    newMocExchangeV1Implementation = _newMocExchangeV1Implementation;
    newMocInrateV1Implementation = _newMocInrateV1Implementation;
    newMocBProxManagerV1Implementation = _newMocBProxManagerV1Implementation;
    newRifBucketImplementation = _newRifBucketImplementation;
    newDocBucketImplementation = _newDocBucketImplementation;
  }

  function execute() external {
    _beforeUpgrade();
    _upgrade();
    _afterUpgrade();
  }

  function _upgrade() internal {
    upgradeDelegatorMoc.upgrade(mocV1Proxy, newMocV1Implementation);
    upgradeDelegatorMoc.upgrade(mocStateV1Proxy, newMocStateV1Implementation);
    upgradeDelegatorMoc.upgrade(mocExchangeV1Proxy, newMocExchangeV1Implementation);
    upgradeDelegatorMoc.upgrade(mocInrateV1Proxy, newMocInrateV1Implementation);
    upgradeDelegatorMoc.upgrade(mocBProxManagerV1Proxy, newMocBProxManagerV1Implementation);
    rifBucketProxy.upgradeTo(newRifBucketImplementation);
    docBucketProxy.upgradeTo(newDocBucketImplementation);
  }

  function _beforeUpgrade() internal virtual {}

  function _afterUpgrade() internal virtual {}
}
