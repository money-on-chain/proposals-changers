// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";
import { IMoCInrate } from "../../interfaces/IMoCInrate.sol";

// Minimal interface for MocSwapperV3MultiHop.setPath
interface IDataProvider {
  function peek() external view returns (bytes32, bool);
}

interface IMocSwapperMultihopV3 {
  function setPath(
    address tokenA_,
    address tokenB_,
    address[] memory intermediateTokens_,
    uint24[] memory fees_,
    IDataProvider providerSwappingAtoB_
  ) external;
}

interface ITasksRunner {
  function addTask(address task) external;
  function removeTask(address task) external;
  function getTasks() external view returns (address[] memory);
}

interface ICommissionSplitterTask {
  function commissionSplitter() external view returns (address);
}

interface ICommissionSplitter {
  function split() external;
}

/**
 * @title MocV1LendingAndBorrowing
 * @notice ChangeContract used to:
 *         1. Set the BitPro interest rate and the BitPro interest address
 *            on MoCInrate V1 (pointing to the newly deployed BufferCoinbase).
 *         2. Configure the WRBTC→USDT→DOC (and reverse DOC→USDT→WRBTC) swap
 *            paths on the mocSwapperExchange (a MocSwapperV3MultiHop instance).
 */
contract MocV1LendingAndBorrowing is IChangeContract {
  IMoCInrate public immutable mocInrateV1;
  uint256 public immutable newBitProRate;
  address payable public immutable newBitProInterestAddress;

  ITasksRunner public immutable tasksRunner;
  address public immutable bufferFlushTask;
  address public immutable bufferLiquidateTask;

  // Swapper exchange (MocSwapperV3MultiHop)
  IMocSwapperMultihopV3 public immutable mocSwapperExchange;

  // Token addresses used in the path
  address public immutable wrbtcToken;
  address public immutable usdtToken;
  address public immutable docToken;

  // DataProviders for max-amount-to-swap limits
  IDataProvider public immutable wrbtcToDocProvider;
  IDataProvider public immutable docToWrbtcProvider;

  // Uniswap V3 pool fees for WRBTC→USDT→DOC path
  // fee0: WRBTC→USDT pool fee (e.g. 3000 = 0.3%)
  // fee1: USDT→DOC  pool fee (e.g.  500 = 0.05%)
  uint24 public immutable wrbtcUsdtFee;
  uint24 public immutable usdtDocFee;

  constructor(
    IMoCInrate _mocInrateV1,
    uint256 _newBitProRate,
    address payable _newBitProInterestAddress,
    ITasksRunner _tasksRunner,
    address _bufferFlushTask,
    address _bufferLiquidateTask,
    IMocSwapperMultihopV3 _mocSwapperExchange,
    address _wrbtcToken,
    address _usdtToken,
    address _docToken,
    IDataProvider _wrbtcToDocProvider,
    IDataProvider _docToWrbtcProvider,
    uint24 _wrbtcUsdtFee,
    uint24 _usdtDocFee
  ) {
    mocInrateV1 = _mocInrateV1;
    newBitProRate = _newBitProRate;
    newBitProInterestAddress = _newBitProInterestAddress;
    tasksRunner = _tasksRunner;
    bufferFlushTask = _bufferFlushTask;
    bufferLiquidateTask = _bufferLiquidateTask;
    mocSwapperExchange = _mocSwapperExchange;
    wrbtcToken = _wrbtcToken;
    usdtToken = _usdtToken;
    docToken = _docToken;
    wrbtcToDocProvider = _wrbtcToDocProvider;
    docToWrbtcProvider = _docToWrbtcProvider;
    wrbtcUsdtFee = _wrbtcUsdtFee;
    usdtDocFee = _usdtDocFee;
  }

  function execute() external {
    address deprecatedInterestRecipient = mocInrateV1.getBitProInterestAddress();
    ICommissionSplitter(deprecatedInterestRecipient).split();
    _removeSplitterTasks(deprecatedInterestRecipient);

    // ── 1. Update BitPro rate and interest address on MoCInrate V1 ──────────
    mocInrateV1.setBitProRate(newBitProRate);
    mocInrateV1.setBitProInterestAddress(newBitProInterestAddress);

    tasksRunner.addTask(bufferFlushTask);
    tasksRunner.addTask(bufferLiquidateTask);

    // ── 2. Configure WRBTC→USDT→DOC path on mocSwapperExchange ─────────────
    address[] memory intermediates = new address[](1);
    intermediates[0] = usdtToken;

    uint24[] memory feesWrbtcToDoc = new uint24[](2);
    feesWrbtcToDoc[0] = wrbtcUsdtFee; // WRBTC → USDT
    feesWrbtcToDoc[1] = usdtDocFee; // USDT  → DOC

    mocSwapperExchange.setPath(
      wrbtcToken,
      docToken,
      intermediates,
      feesWrbtcToDoc,
      wrbtcToDocProvider
    );

    // ── 3. Configure DOC→USDT→WRBTC path (reverse, needed for exactOutput) ──
    uint24[] memory feesDocToWrbtc = new uint24[](2);
    feesDocToWrbtc[0] = usdtDocFee; // DOC  → USDT
    feesDocToWrbtc[1] = wrbtcUsdtFee; // USDT → WRBTC

    mocSwapperExchange.setPath(
      docToken,
      wrbtcToken,
      intermediates,
      feesDocToWrbtc,
      docToWrbtcProvider
    );
  }

  function _removeSplitterTasks(address deprecatedSplitter) internal {
    address[] memory tasks = tasksRunner.getTasks();
    for (uint256 i = 0; i < tasks.length; i++) {
      try ICommissionSplitterTask(tasks[i]).commissionSplitter() returns (
        address commissionSplitter
      ) {
        if (commissionSplitter == deprecatedSplitter) {
          tasksRunner.removeTask(tasks[i]);
        }
      } catch {}
    }
  }
}
