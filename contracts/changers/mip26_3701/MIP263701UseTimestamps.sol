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
  function initializeEmaCalculation(
    uint256 lastCalculationTimestamp,
    uint256 calculationTimeSpan
  ) external;
}

// Read only before the proxy is upgraded to its dates-only implementation.
interface ILegacyMoCInrateSchedule {
  function lastBitProInterestBlock() external view returns (uint256);
}

interface IMoCInrateTimestampSchedule {
  function initializeBitProInterestSchedule(
    uint256 lastPaymentTimestamp,
    uint256 interestTimeSpan
  ) external;
}

// Read only before the proxy is upgraded to its dates-only implementation.
interface ILegacyCoinerSchedule {
  function getNextMintFromBlock() external view returns (uint256);
  function getMintBlockInterval() external view returns (uint256);
}

interface ICoinerTimestampSchedule {
  function initializeMintSchedule(uint256 nextMintAt, uint256 mintTimestampInterval) external;
}

interface IGovernedDelegateCall {
  function delegateCallToChanger(bytes calldata data) external returns (bytes memory);
}

interface IRifOnChainTimeSpans {
  function tcInterestCollectorAddress() external view returns (address);
  function tcInterestRate() external view returns (uint256);
  function maxAbsoluteOpProvider() external view returns (address);
  function maxOpDiffProvider() external view returns (address);
  function setTCInterestParams(address collector, uint256 rate, uint256 timeSpan) external;
  function setFluxCapacitorParams(
    address maxAbsoluteProvider,
    address maxDiffProvider,
    uint256 timeSpan
  ) external;
  function setEmaCalculationTimeSpan(uint256 timeSpan) external;
}

/**
 * @title MIP263701UseTimestamps
 * @notice Converts legacy block schedules through a fixed block/timestamp
 *         anchor, then atomically upgrades and initializes dates-only proxies.
 */
contract MIP263701UseTimestamps is IChangeContract {
  uint256 public constant BLOCK_TIME = 29 seconds;
  uint256 public constant GREGORIAN_AVERAGE_MONTH = 30 days + 10 hours;
  uint256 public constant SUPPORTERS_ASSUMED_BLOCK_TIME = 30 seconds;
  uint256 public constant SUPPORTERS_PERIOD =
    GREGORIAN_AVERAGE_MONTH / SUPPORTERS_ASSUMED_BLOCK_TIME;
  uint256 public constant RIF_DECAY_TIME_SPAN = 1 days;

  // Compiler-verified against @moneyonchain/oracles 3.0.10. These are the
  // absolute proxy storage slots for SupportersData.period and
  // RoundInfo.roundLockPeriodSecs, respectively.
  uint256 private constant SUPPORTERS_PERIOD_STORAGE_SLOT = 111;
  uint256 private constant ROUND_LOCK_PERIOD_STORAGE_SLOT = 108;

  address public immutable mocProxy;
  address public immutable mocStateProxy;
  address public immutable mocInrateProxy;
  address public immutable coinerProxy;
  address public immutable supporters;
  address public immutable rifOnChain;
  address public immutable btcUsdCoinPair;
  address public immutable rifUsdCoinPair;
  address public immutable tasksRunner;
  IUpgradeDelegator public immutable mocUpgradeDelegator;
  IUpgradeDelegator public immutable flowUpgradeDelegator;
  address public immutable newMocImplementation;
  address public immutable newMocStateImplementation;
  address public immutable newMocInrateImplementation;
  address public immutable newCoinerImplementation;
  uint256 public immutable emaCalculationTimeSpan;
  uint256 public immutable bitProInterestTimeSpan;
  uint256 public immutable coinerMintTimeSpan;
  uint256 public immutable roundLockPeriod;
  uint256 public immutable anchorBlockNumber;
  uint256 public immutable anchorTimestamp;

  constructor(
    address[4] memory _legacyProxies,
    address[5] memory _additionalTargets,
    address[2] memory _upgradeDelegators,
    address[4] memory _newImplementations,
    uint256 _emaCalculationTimeSpan,
    uint256 _bitProInterestTimeSpan,
    uint256 _coinerMintTimeSpan,
    uint256 _roundLockPeriod
  ) {
    require(_emaCalculationTimeSpan > 0, "invalid EMA time span");
    require(_bitProInterestTimeSpan > 0, "invalid interest time span");
    require(_coinerMintTimeSpan > 0, "invalid Coiner time span");
    require(_roundLockPeriod > 0, "invalid round time span");

    mocProxy = _legacyProxies[0];
    mocStateProxy = _legacyProxies[1];
    mocInrateProxy = _legacyProxies[2];
    coinerProxy = _legacyProxies[3];
    supporters = _additionalTargets[0];
    rifOnChain = _additionalTargets[1];
    btcUsdCoinPair = _additionalTargets[2];
    rifUsdCoinPair = _additionalTargets[3];
    tasksRunner = _additionalTargets[4];
    mocUpgradeDelegator = IUpgradeDelegator(_upgradeDelegators[0]);
    flowUpgradeDelegator = IUpgradeDelegator(_upgradeDelegators[1]);
    newMocImplementation = _newImplementations[0];
    newMocStateImplementation = _newImplementations[1];
    newMocInrateImplementation = _newImplementations[2];
    newCoinerImplementation = _newImplementations[3];
    emaCalculationTimeSpan = _emaCalculationTimeSpan;
    bitProInterestTimeSpan = _bitProInterestTimeSpan;
    coinerMintTimeSpan = _coinerMintTimeSpan;
    roundLockPeriod = _roundLockPeriod;
    anchorBlockNumber = block.number;
    anchorTimestamp = block.timestamp;
  }

  function execute() external {
    uint256 lastEmaTimestamp = legacyLastEmaCalculationTimestamp();
    uint256 lastInterestPaymentTimestamp = legacyLastInterestPaymentTimestamp();
    uint256 nextMintTimestamp = nextMintDueTimestamp();

    mocUpgradeDelegator.upgrade(mocProxy, newMocImplementation);
    mocUpgradeDelegator.upgrade(mocStateProxy, newMocStateImplementation);
    mocUpgradeDelegator.upgrade(mocInrateProxy, newMocInrateImplementation);
    flowUpgradeDelegator.upgrade(coinerProxy, newCoinerImplementation);

    IMoCStateTimestampSchedule(mocStateProxy).initializeEmaCalculation(
      lastEmaTimestamp,
      emaCalculationTimeSpan
    );
    IMoCInrateTimestampSchedule(mocInrateProxy).initializeBitProInterestSchedule(
      lastInterestPaymentTimestamp,
      bitProInterestTimeSpan
    );
    ICoinerTimestampSchedule(coinerProxy).initializeMintSchedule(
      nextMintTimestamp,
      coinerMintTimeSpan
    );

    _updateRifOnChainTimeSpans();
    IGovernedDelegateCall(supporters).delegateCallToChanger(abi.encode(SUPPORTERS_PERIOD));
    IGovernedDelegateCall(btcUsdCoinPair).delegateCallToChanger(abi.encode(roundLockPeriod));
    IGovernedDelegateCall(rifUsdCoinPair).delegateCallToChanger(abi.encode(roundLockPeriod));
    IGovernedDelegateCall(tasksRunner).delegateCallToChanger(abi.encode(roundLockPeriod));
  }

  /**
   * @dev Called through Governed.delegateCallToChanger in the target's storage
   *      context. The slots below are verified against the exact storage layout
   *      of the moneyonchain/oracles 3.0.10 package used by the deployed targets.
   */
  function impersonate(bytes calldata data) external {
    uint256 period = abi.decode(data, (uint256));
    address target = address(this);

    if (target == supporters) {
      require(period == SUPPORTERS_PERIOD, "invalid supporters period");
      assembly {
        sstore(SUPPORTERS_PERIOD_STORAGE_SLOT, period)
      }
    } else {
      require(
        target == btcUsdCoinPair || target == rifUsdCoinPair || target == tasksRunner,
        "invalid delegate target"
      );
      require(period == roundLockPeriod, "invalid round period");
      assembly {
        sstore(ROUND_LOCK_PERIOD_STORAGE_SLOT, period)
      }
    }
  }

  function _updateRifOnChainTimeSpans() internal {
    IRifOnChainTimeSpans rif = IRifOnChainTimeSpans(rifOnChain);
    rif.setTCInterestParams(
      rif.tcInterestCollectorAddress(),
      rif.tcInterestRate(),
      bitProInterestTimeSpan
    );
    rif.setFluxCapacitorParams(
      rif.maxAbsoluteOpProvider(),
      rif.maxOpDiffProvider(),
      RIF_DECAY_TIME_SPAN
    );
    rif.setEmaCalculationTimeSpan(emaCalculationTimeSpan);
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
    return timestampAtBlock(lastMintBlock) + coinerMintTimeSpan;
  }

  function timestampAtBlock(uint256 targetBlock) public view returns (uint256) {
    if (targetBlock >= anchorBlockNumber) {
      return anchorTimestamp + ((targetBlock - anchorBlockNumber) * BLOCK_TIME);
    }
    return anchorTimestamp - ((anchorBlockNumber - targetBlock) * BLOCK_TIME);
  }
}
