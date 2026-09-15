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

interface ISupportersSchedule {
  function setPeriod(uint256 period) external;
}

interface IRoundManagerSchedule {
  function setRoundLockPeriodSecs(uint256 roundLockPeriodSecs) external;
}

interface IMocQueueSchedule {
  function setMaxOperWaitingBlk(uint256 maxOperWaitingBlk) external;
}

interface IMocReverseAuctionThreshold {
  function setOrderThreshold(uint256 orderThreshold) external;
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
 * @notice Converts legacy block schedules through a deployment block/timestamp
 *         anchor, then atomically upgrades and initializes dates-only proxies.
 */
contract MIP263701UseTimestamps is IChangeContract {
  uint256 public constant BLOCK_TIME = 29 seconds;
  uint256 public constant GREGORIAN_AVERAGE_MONTH = 30 days + 10 hours;
  uint256 public constant EMA_CALCULATION_TIME_SPAN = 1 days;
  uint256 public constant BITPRO_INTEREST_TIME_SPAN = 7 days;
  uint256 public constant COINER_MINT_TIME_SPAN = GREGORIAN_AVERAGE_MONTH;
  uint256 public constant SUPPORTERS_ASSUMED_BLOCK_TIME = 30 seconds;
  uint256 public constant SUPPORTERS_PERIOD =
    GREGORIAN_AVERAGE_MONTH / SUPPORTERS_ASSUMED_BLOCK_TIME;
  uint256 public constant RIF_DECAY_TIME_SPAN = 1 days;
  uint256 public constant ROC_QUEUE_MAX_OPER_WAITING_BLOCKS = 6;
  uint256 public constant DOC_TO_MOC_ORDER_THRESHOLD = 300 ether;

  // ===========================================================================
  // Addresses of contracts that need to be changed
  // ===========================================================================
  address public immutable mocProxy; // Updated to remove the obsolete block-span forwarding API.
  address public immutable mocStateProxy; // Updated to schedule legacy EMA calculations by timestamp.
  address public immutable mocInrateProxy; // Updated to schedule weekly interest payments by timestamp.
  address public immutable coinerProxy; // Updated to schedule MOC issuance rounds by timestamp.
  address public immutable supporters; // Updated to add and use a governed Supporters-period setter.
  address public immutable rifOnChain; // Updated to correct its existing second-based schedule periods.
  address public immutable btcUsdCoinPair; // Updated to add and use a governed round-period setter.
  address public immutable rifUsdCoinPair; // Updated to add and use a governed round-period setter.
  address public immutable tasksRunner; // Updated to add and use a governed round-period setter.
  address public immutable rifQueue; // Updated to delay stale-price fallback execution from three blocks to six.
  address public immutable docQueue; // Updated to delay stale-price fallback execution from three blocks to six.
  address public immutable docToMocReverseAuction; // Updated to avoid triggering uneconomic one-DOC swaps.

  // Governance infrastructure authorized to upgrade the contracts listed above.
  IUpgradeDelegator public immutable mocUpgradeDelegator;
  IUpgradeDelegator public immutable flowUpgradeDelegator;

  // New implementations installed in the contracts listed above.
  address public immutable newMocImplementation;
  address public immutable newMocStateImplementation;
  address public immutable newMocInrateImplementation;
  address public immutable newCoinerImplementation;
  address public immutable newSupportersImplementation;
  address public immutable newCoinPairPriceImplementation;
  address public immutable newTasksRunnerImplementation;

  // This is the only configurable time span because oracle rounds intentionally
  // use the average Gregorian month on mainnet and an accelerated period on testnet.
  uint256 public immutable roundLockPeriod;
  uint256 public immutable anchorBlockNumber;
  uint256 public immutable anchorTimestamp;

  /**
   * @param _roundLockPeriod Duration of future CoinPairPrice and TasksRunner rounds.
   * Mainnet uses 30 days and 10 hours; testnet uses 3 hours so governance and
   * task execution can be exercised without waiting for a production-length round.
   */
  constructor(
    address[4] memory _legacyProxies,
    address[8] memory _additionalTargets,
    address[2] memory _upgradeDelegators,
    address[7] memory _newImplementations,
    uint256 _roundLockPeriod
  ) {
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
    rifQueue = _additionalTargets[5];
    docQueue = _additionalTargets[6];
    docToMocReverseAuction = _additionalTargets[7];
    mocUpgradeDelegator = IUpgradeDelegator(_upgradeDelegators[0]);
    flowUpgradeDelegator = IUpgradeDelegator(_upgradeDelegators[1]);
    newMocImplementation = _newImplementations[0];
    newMocStateImplementation = _newImplementations[1];
    newMocInrateImplementation = _newImplementations[2];
    newCoinerImplementation = _newImplementations[3];
    newSupportersImplementation = _newImplementations[4];
    newCoinPairPriceImplementation = _newImplementations[5];
    newTasksRunnerImplementation = _newImplementations[6];
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
    flowUpgradeDelegator.upgrade(supporters, newSupportersImplementation);
    flowUpgradeDelegator.upgrade(btcUsdCoinPair, newCoinPairPriceImplementation);
    flowUpgradeDelegator.upgrade(rifUsdCoinPair, newCoinPairPriceImplementation);
    flowUpgradeDelegator.upgrade(tasksRunner, newTasksRunnerImplementation);

    IMoCStateTimestampSchedule(mocStateProxy).initializeEmaCalculation(
      lastEmaTimestamp,
      EMA_CALCULATION_TIME_SPAN
    );
    IMoCInrateTimestampSchedule(mocInrateProxy).initializeBitProInterestSchedule(
      lastInterestPaymentTimestamp,
      BITPRO_INTEREST_TIME_SPAN
    );
    ICoinerTimestampSchedule(coinerProxy).initializeMintSchedule(
      nextMintTimestamp,
      COINER_MINT_TIME_SPAN
    );

    _updateRifOnChainTimeSpans();
    ISupportersSchedule(supporters).setPeriod(SUPPORTERS_PERIOD);
    IRoundManagerSchedule(btcUsdCoinPair).setRoundLockPeriodSecs(roundLockPeriod);
    IRoundManagerSchedule(rifUsdCoinPair).setRoundLockPeriodSecs(roundLockPeriod);
    IRoundManagerSchedule(tasksRunner).setRoundLockPeriodSecs(roundLockPeriod);

    // Annex: operational adjustments independent from the timestamp migration.
    IMocQueueSchedule(rifQueue).setMaxOperWaitingBlk(ROC_QUEUE_MAX_OPER_WAITING_BLOCKS);
    IMocQueueSchedule(docQueue).setMaxOperWaitingBlk(ROC_QUEUE_MAX_OPER_WAITING_BLOCKS);
    IMocReverseAuctionThreshold(docToMocReverseAuction).setOrderThreshold(
      DOC_TO_MOC_ORDER_THRESHOLD
    );
  }

  function _updateRifOnChainTimeSpans() internal {
    IRifOnChainTimeSpans rif = IRifOnChainTimeSpans(rifOnChain);
    rif.setTCInterestParams(
      rif.tcInterestCollectorAddress(),
      rif.tcInterestRate(),
      BITPRO_INTEREST_TIME_SPAN
    );
    rif.setFluxCapacitorParams(
      rif.maxAbsoluteOpProvider(),
      rif.maxOpDiffProvider(),
      RIF_DECAY_TIME_SPAN
    );
    rif.setEmaCalculationTimeSpan(EMA_CALCULATION_TIME_SPAN);
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
