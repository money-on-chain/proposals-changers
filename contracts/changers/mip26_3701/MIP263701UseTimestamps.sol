// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IUpgradeDelegator {
  function upgrade(address proxy, address newImplementation) external;
}

// Read only before the proxy is upgraded to its dates-only implementation.
interface ILegacyMoCStateSchedule {
  function getLastEmaCalculation() external view returns (uint256);
}

interface IMoCStateTimestampSchedule {
  function initializeEmaCalculation(uint256 lastCalculationTimestamp) external;
}

// Read only before the proxy is upgraded to its dates-only implementation.
interface ILegacyMoCInrateSchedule {
  function lastBitProInterestBlock() external view returns (uint256);
}

interface IMoCInrateTimestampSchedule {
  function initializeBitProInterestSchedule(uint256 lastPaymentTimestamp) external;
}

// Read only before the proxy is upgraded to its dates-only implementation.
interface ILegacyCoinerSchedule {
  function getNextMintFromBlock() external view returns (uint256);
  function getMintBlockInterval() external view returns (uint256);
}

interface ICoinerTimestampSchedule {
  function initializeMintSchedule(uint256 nextMintAt) external;
}

/**
 * @title MIP263701UseTimestamps
 * @notice Converts legacy block schedules through a fixed block/timestamp
 *         anchor, then atomically upgrades and initializes dates-only proxies.
 */
contract MIP263701UseTimestamps is IChangeContract {
  uint256 public constant BLOCK_TIME = 29 seconds;
  uint256 public constant COINER_MINT_TIME_SPAN = 30 days + 10 hours;

  address public immutable mocProxy;
  address public immutable mocStateProxy;
  address public immutable mocInrateProxy;
  address public immutable coinerProxy;
  IUpgradeDelegator public immutable mocUpgradeDelegator;
  IUpgradeDelegator public immutable flowUpgradeDelegator;
  address public immutable newMocImplementation;
  address public immutable newMocStateImplementation;
  address public immutable newMocInrateImplementation;
  address public immutable newCoinerImplementation;
  uint256 public immutable anchorBlockNumber;
  uint256 public immutable anchorTimestamp;

  constructor(
    address _mocProxy,
    address _mocStateProxy,
    address _mocInrateProxy,
    address _coinerProxy,
    IUpgradeDelegator _mocUpgradeDelegator,
    IUpgradeDelegator _flowUpgradeDelegator,
    address _newMocImplementation,
    address _newMocStateImplementation,
    address _newMocInrateImplementation,
    address _newCoinerImplementation,
    uint256 _anchorBlockNumber,
    uint256 _anchorTimestamp
  ) {
    require(_anchorTimestamp > 0, "invalid anchor timestamp");

    mocProxy = _mocProxy;
    mocStateProxy = _mocStateProxy;
    mocInrateProxy = _mocInrateProxy;
    coinerProxy = _coinerProxy;
    mocUpgradeDelegator = _mocUpgradeDelegator;
    flowUpgradeDelegator = _flowUpgradeDelegator;
    newMocImplementation = _newMocImplementation;
    newMocStateImplementation = _newMocStateImplementation;
    newMocInrateImplementation = _newMocInrateImplementation;
    newCoinerImplementation = _newCoinerImplementation;
    anchorBlockNumber = _anchorBlockNumber;
    anchorTimestamp = _anchorTimestamp;
  }

  function execute() external {
    uint256 lastEmaTimestamp = legacyLastEmaCalculationTimestamp();
    uint256 lastInterestPaymentTimestamp = legacyLastInterestPaymentTimestamp();
    uint256 nextMintTimestamp = nextMintDueTimestamp();

    mocUpgradeDelegator.upgrade(mocProxy, newMocImplementation);
    mocUpgradeDelegator.upgrade(mocStateProxy, newMocStateImplementation);
    mocUpgradeDelegator.upgrade(mocInrateProxy, newMocInrateImplementation);
    flowUpgradeDelegator.upgrade(coinerProxy, newCoinerImplementation);

    IMoCStateTimestampSchedule(mocStateProxy).initializeEmaCalculation(lastEmaTimestamp);
    IMoCInrateTimestampSchedule(mocInrateProxy).initializeBitProInterestSchedule(
      lastInterestPaymentTimestamp
    );
    ICoinerTimestampSchedule(coinerProxy).initializeMintSchedule(nextMintTimestamp);
  }

  function legacyLastEmaCalculationTimestamp() public view returns (uint256) {
    uint256 lastCalculationBlock = ILegacyMoCStateSchedule(mocStateProxy).getLastEmaCalculation();
    if (lastCalculationBlock == 0) return 1;
    return timestampAtBlock(lastCalculationBlock);
  }

  function legacyLastInterestPaymentTimestamp() public view returns (uint256) {
    uint256 lastPaymentBlock = ILegacyMoCInrateSchedule(mocInrateProxy).lastBitProInterestBlock();
    if (lastPaymentBlock == 0) return 1;
    return timestampAtBlock(lastPaymentBlock);
  }

  function nextMintDueTimestamp() public view returns (uint256) {
    uint256 nextMintBlock = ILegacyCoinerSchedule(coinerProxy).getNextMintFromBlock();
    if (nextMintBlock == 0) return block.timestamp;

    uint256 mintBlockInterval = ILegacyCoinerSchedule(coinerProxy).getMintBlockInterval();
    if (mintBlockInterval == 0 || nextMintBlock < mintBlockInterval) {
      return timestampAtBlock(nextMintBlock);
    }

    uint256 lastMintBlock = nextMintBlock - mintBlockInterval;
    return timestampAtBlock(lastMintBlock) + COINER_MINT_TIME_SPAN;
  }

  function timestampAtBlock(uint256 targetBlock) public view returns (uint256) {
    if (targetBlock >= anchorBlockNumber) {
      return anchorTimestamp + ((targetBlock - anchorBlockNumber) * BLOCK_TIME);
    }
    return anchorTimestamp - ((anchorBlockNumber - targetBlock) * BLOCK_TIME);
  }
}
