// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { MocV1LendingAndBorrowing, IMoCInrate, IMocSwapperMultihopV3, IDataProvider, ITasksRunner, IOracleManager, ICommissionSplitterTask, TasksRunnerMigration, LiquidationEngineRegistration } from "../changers/mocV1LendingAndBorrowing/MocV1LendingAndBorrowing.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";
import { MocReverseAuction } from "@moc/main/contracts/auxiliary/MocReverseAuction.sol";
import { MocSwapperCoreV1 } from "@moc/lending/contracts/swappers/MocSwapperCoreV1.sol";

// ─── Interfaces ───────────────────────────────────────────────────────────────

interface IGoverned {
  function governor() external view returns (address);
}

interface IOwnableLike {
  function owner() external view returns (address);
}

interface IMoCInrateProbe {
  function getBitProRate() external view returns (uint256);
  function getBitProInterestAddress() external view returns (address payable);
}

/// @notice Minimal interface to inspect BufferCoinbase state (avoids cross-version import)
interface IBufferCoinbaseLike {
  function isLiquidable() external view returns (bool);
  function isFlushable(uint256 i) external view returns (bool);
  function getOutput(uint256 idx) external view returns (address, uint256, uint256, uint256);
  function getToken() external view returns (address);
  function liquidate() external;
  function flush(uint256 i) external;
}

interface IMoCStorageProbe {
  function isBitProInterestEnabled() external view returns (bool);
  function getBitProInterestBlockSpan() external view returns (uint256);
}

interface IMoCBasicOpsProbe {
  function payBitProHoldersInterestPayment() external;
}

interface IERC20Minimal {
  function balanceOf(address account) external view returns (uint256);
}

/// @notice Minimal interface to inspect MocSwapperV3MultiHop paths
interface IMocSwapperV3MultiHopProbe {
  function encodedPaths(address tokenIn, address tokenOut) external view returns (bytes memory);
  function maxAmountToSwapProviders(
    address tokenIn,
    address tokenOut
  ) external view returns (address);
}

interface IMocSwapperProbe {
  function getSafeMaxAmountToSwap(
    address tokenIn,
    address tokenOut
  ) external view returns (uint256);
}

interface IOracleManagerProbe {
  function getContractAddress(bytes32 coinPair) external view returns (address);
}

contract TaskMock {}

/**
 * @title LendingAndBorrowingV1ForkTest
 * @notice Fork test that replicates the LendingAndBorrowingV1 ignition module deploy
 *         and executes the MocV1LendingAndBorrowing changer against RSK mainnet.
 *
 * @dev Parameters are read from the rskMainnet.json parameter file.
 *
 *      Steps replicated from the ignition module:
 *        Step 10  - Deploy BufferCoinbase (impl + TransparentUpgradeableProxy)
 *        Step 12a - Deploy WrbtcToDoc DataProvider
 *        Step 12b - Deploy DocToWrbtc DataProvider
 *        Step 13  - Deploy MocV1LendingAndBorrowing changer
 */
contract LendingAndBorrowingV1ForkTest is Test {
  // ─── Constants ────────────────────────────────────────────────────────────
  string internal constant MAINNET_PARAMS_PATH =
    "./ignition/modules/LendingAndBorrowingV1/parameters/rskMainnet.json";

  // ─── Addresses from JSON ──────────────────────────────────────────────────
  address internal governor;
  address internal pauser;
  address internal mocV1;
  address internal mocStateV1;
  address internal mocInrateV1;
  address internal docToken;
  address internal mocToken;
  address internal tasksRunnerAddress;
  address internal oracleManager;
  bytes32 internal liquidationEngineName;
  address internal tokenToCoinbasePriceProvider;
  uint256 internal liquidationPaymentAC;

  // BufferCoinbase params
  address internal bufferProxyAdmin;
  uint256 internal bufferThreshold;
  address internal bufferOutput1;
  address internal bufferOutput2;
  uint256 internal bufferSplit0;
  uint256 internal bufferSplit1;
  uint256 internal bufferSplit2;
  uint256 internal bufferOutputThreshold0;
  uint256 internal bufferOutputThreshold1;
  uint256 internal bufferOutputThreshold2;

  // Lending fee-flow params
  address internal mocFeeFlowProxyAdmin;
  uint256 internal mocFeeFlowThreshold;
  address internal mocFeeFlowMimLabs;
  address internal docToMocReverseAuction;
  uint256 internal mocFeeFlowSplitDocToRbtc;
  uint256 internal mocFeeFlowSplitMimLabs;
  uint256 internal mocFeeFlowSplitDocToMoc;
  uint256 internal mocFeeFlowSplitDocToMocLiquidation;
  uint256 internal mocFeeFlowOutputThresholdDocToRbtc;
  uint256 internal mocFeeFlowOutputThresholdMimLabs;
  uint256 internal mocFeeFlowOutputThresholdDocToMoc;
  uint256 internal mocFeeFlowOutputThresholdDocToMocLiquidation;
  uint256 internal docToRbtcReverseAuctionOrderThreshold;
  uint256 internal docToRbtcReverseAuctionSlippage;
  address internal docToMocLiquidationPriceProvider;
  uint256 internal docToMocLiquidationReverseAuctionOrderThreshold;
  uint256 internal docToMocLiquidationReverseAuctionSlippage;
  uint256 internal rbtcToMocLiquidationReverseAuctionOrderThreshold;
  uint256 internal rbtcToMocLiquidationReverseAuctionSlippage;

  // ReverseAuction params
  // Already deployed DOC/RBTC price provider on mainnet.
  address internal docToRbtcPriceProvider;

  // Changer param
  uint256 internal newBitProRate;

  // Swap path params
  address internal mocSwapperExchange;
  address internal mocSwapperExchangeMultiHop;
  address internal wrbtcToken;
  address internal usdtToken;
  uint256 internal wrbtcToDocMaxAmount;
  uint256 internal docToWrbtcMaxAmount;
  uint24 internal wrbtcUsdtFee;
  uint24 internal usdtDocFee;

  // ─── Deployed contracts ───────────────────────────────────────────────────
  address internal mocSwapperCoreV1;
  address internal tpInjector;
  address internal bufferCoinbaseProxy;
  MocReverseAuction internal docToRbtcReverseAuction;
  MocReverseAuction internal docToMocLiquidationReverseAuction;
  MocReverseAuction internal rbtcToMocLiquidationReverseAuction;
  address internal mocFeeFlowProxy;
  // DataProvider instances deployed via vm.deployCode (avoids moc-main-latest alias issue)
  address internal wrbtcToDocProvider;
  address internal docToWrbtcProvider;
  MocV1LendingAndBorrowing internal changer;
  ITasksRunner internal tasksRunner;
  address internal bufferFlushTask;
  address internal bufferLiquidateTask;
  address internal tpInjectionTask;
  address internal feeFlowBufferFlushTask;
  address internal feeFlowBufferLiquidateTask;
  address internal docToRbtcTask;
  address internal docToMocLiquidationTask;
  address internal rbtcToMocLiquidationTask;
  address internal liquidationEngine;

  receive() external payable {}

  // ─── setUp ────────────────────────────────────────────────────────────────

  function setUp() public {
    string memory defaultRpcUrl = "https://public-node.rsk.co";
    uint256 forkBlock = 9265000;
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", defaultRpcUrl);
    vm.createSelectFork(rpcUrl, forkBlock);

    _readParamsFromJson();
    tpInjector = address(this);

    // ── Step 1: Deploy MocSwapperCoreV1 ────────────────────────────────
    // MocSwapperCoreV1(address governor_, address mocV1_, address mocStateV1_,
    //                  address mocInrateV1_, address tpToken_)
    mocSwapperCoreV1 = address(
      new MocSwapperCoreV1(governor, mocV1, mocStateV1, mocInrateV1, docToken)
    );

    // ── Step 10: Deploy BufferCoinbase impl + TransparentUpgradeableProxy ─
    // BufferCoinbase is =0.6.12, deployed via vm.getCode+assembly to avoid
    // cross-version import errors
    address bufferImpl;
    {
      bytes memory bufferCode = vm.getCode("BufferCoinbase");
      // solhint-disable-next-line no-inline-assembly
      assembly {
        bufferImpl := create(0, add(bufferCode, 0x20), mload(bufferCode))
      }
    }

    address[] memory outputs = new address[](3);
    outputs[0] = tpInjector;
    outputs[1] = bufferOutput1;
    outputs[2] = bufferOutput2;

    uint256[] memory splits = new uint256[](3);
    splits[0] = bufferSplit0;
    splits[1] = bufferSplit1;
    splits[2] = bufferSplit2;

    uint256[] memory outputThresholds = new uint256[](3);
    outputThresholds[0] = bufferOutputThreshold0;
    outputThresholds[1] = bufferOutputThreshold1;
    outputThresholds[2] = bufferOutputThreshold2;

    bytes memory initData = abi.encodeWithSignature(
      "initialize(address,uint256,address[],uint256[],uint256[])",
      governor,
      bufferThreshold,
      outputs,
      splits,
      outputThresholds
    );

    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      bufferImpl,
      bufferProxyAdmin,
      initData
    );
    bufferCoinbaseProxy = address(proxy);

    // The full module deploys the LiquidationEngine before these auctions.
    // A receiver mock is sufficient here to validate their routing.
    liquidationEngine = address(new TaskMock());

    // ── Step 11b: Deploy liquidation-funding reverse auctions ──────────
    docToRbtcReverseAuction = new MocReverseAuction(
      governor,
      mocSwapperCoreV1,
      docToken,
      address(0),
      mocV1,
      docToRbtcReverseAuctionOrderThreshold,
      docToRbtcPriceProvider,
      docToRbtcReverseAuctionSlippage
    );

    address rbtcToMocPriceProvider;
    {
      bytes memory code = abi.encodePacked(
        vm.getCode("PriceProviderInverse"),
        abi.encode(tokenToCoinbasePriceProvider)
      );
      assembly {
        rbtcToMocPriceProvider := create(0, add(code, 0x20), mload(code))
      }
    }

    rbtcToMocLiquidationReverseAuction = new MocReverseAuction(
      governor,
      mocSwapperExchange,
      address(0),
      mocToken,
      liquidationEngine,
      rbtcToMocLiquidationReverseAuctionOrderThreshold,
      rbtcToMocPriceProvider,
      rbtcToMocLiquidationReverseAuctionSlippage
    );

    docToMocLiquidationReverseAuction = new MocReverseAuction(
      governor,
      mocSwapperExchangeMultiHop,
      docToken,
      mocToken,
      liquidationEngine,
      docToMocLiquidationReverseAuctionOrderThreshold,
      docToMocLiquidationPriceProvider,
      docToMocLiquidationReverseAuctionSlippage
    );

    address mocFeeFlowImpl;
    {
      bytes memory feeFlowCode = vm.getCode("BufferToken");
      assembly {
        mocFeeFlowImpl := create(0, add(feeFlowCode, 0x20), mload(feeFlowCode))
      }
    }

    address[] memory feeFlowOutputs = new address[](4);
    feeFlowOutputs[0] = address(docToRbtcReverseAuction);
    feeFlowOutputs[1] = mocFeeFlowMimLabs;
    feeFlowOutputs[2] = docToMocReverseAuction;
    feeFlowOutputs[3] = address(docToMocLiquidationReverseAuction);

    uint256[] memory feeFlowSplits = new uint256[](4);
    feeFlowSplits[0] = mocFeeFlowSplitDocToRbtc;
    feeFlowSplits[1] = mocFeeFlowSplitMimLabs;
    feeFlowSplits[2] = mocFeeFlowSplitDocToMoc;
    feeFlowSplits[3] = mocFeeFlowSplitDocToMocLiquidation;

    uint256[] memory feeFlowOutputThresholds = new uint256[](4);
    feeFlowOutputThresholds[0] = mocFeeFlowOutputThresholdDocToRbtc;
    feeFlowOutputThresholds[1] = mocFeeFlowOutputThresholdMimLabs;
    feeFlowOutputThresholds[2] = mocFeeFlowOutputThresholdDocToMoc;
    feeFlowOutputThresholds[3] = mocFeeFlowOutputThresholdDocToMocLiquidation;

    bytes memory feeFlowInitData = abi.encodeWithSignature(
      "initialize(address,address,uint256,address[],uint256[],uint256[])",
      governor,
      docToken,
      mocFeeFlowThreshold,
      feeFlowOutputs,
      feeFlowSplits,
      feeFlowOutputThresholds
    );
    mocFeeFlowProxy = address(
      new TransparentUpgradeableProxy(mocFeeFlowImpl, mocFeeFlowProxyAdmin, feeFlowInitData)
    );

    // ── Step 12a: Deploy WrbtcToDoc DataProvider ───────────────────────
    // DataProvider(address owner_, uint256 initialData_)
    // owner = pauser, initial max amount = wrbtcToDocMaxAmount
    {
      bytes memory code = abi.encodePacked(
        vm.getCode("DataProvider"),
        abi.encode(pauser, wrbtcToDocMaxAmount)
      );
      address deployed;
      // solhint-disable-next-line no-inline-assembly
      assembly {
        deployed := create(0, add(code, 0x20), mload(code))
      }
      wrbtcToDocProvider = deployed;
    }

    // ── Step 12b: Deploy DocToWrbtc DataProvider ───────────────────────
    // owner = pauser, initial max amount = docToWrbtcMaxAmount
    {
      bytes memory code = abi.encodePacked(
        vm.getCode("DataProvider"),
        abi.encode(pauser, docToWrbtcMaxAmount)
      );
      address deployed;
      // solhint-disable-next-line no-inline-assembly
      assembly {
        deployed := create(0, add(code, 0x20), mload(code))
      }
      docToWrbtcProvider = deployed;
    }

    // ── Step 13: Deploy MocV1LendingAndBorrowing changer ───────────────
    tasksRunner = ITasksRunner(tasksRunnerAddress);
    bufferFlushTask = address(new TaskMock());
    bufferLiquidateTask = address(new TaskMock());
    tpInjectionTask = address(new TaskMock());
    feeFlowBufferFlushTask = address(new TaskMock());
    feeFlowBufferLiquidateTask = address(new TaskMock());
    docToRbtcTask = address(new TaskMock());
    docToMocLiquidationTask = address(new TaskMock());
    rbtcToMocLiquidationTask = address(new TaskMock());
    changer = new MocV1LendingAndBorrowing(
      IMoCInrate(mocInrateV1),
      newBitProRate,
      payable(bufferCoinbaseProxy),
      TasksRunnerMigration({
        tasksRunner: tasksRunner,
        bufferFlushTask: bufferFlushTask,
        bufferLiquidateTask: bufferLiquidateTask,
        tpInjectionTask: tpInjectionTask,
        feeFlowBufferFlushTask: feeFlowBufferFlushTask,
        feeFlowBufferLiquidateTask: feeFlowBufferLiquidateTask,
        docToRbtcTask: docToRbtcTask,
        docToMocLiquidationTask: docToMocLiquidationTask,
        rbtcToMocLiquidationTask: rbtcToMocLiquidationTask
      }),
      LiquidationEngineRegistration({
        oracleManager: IOracleManager(oracleManager),
        name: liquidationEngineName,
        engine: liquidationEngine
      }),
      IMocSwapperMultihopV3(mocSwapperExchangeMultiHop),
      wrbtcToken,
      usdtToken,
      docToken,
      IDataProvider(wrbtcToDocProvider),
      IDataProvider(docToWrbtcProvider),
      wrbtcUsdtFee,
      usdtDocFee
    );
  }

  // ─── Tests ────────────────────────────────────────────────────────────────

  /**
   * @notice Verifies that the changer executes without reverting.
   */
  function testFork_ExecuteChanger_NoRevert() public {
    _executeChanger();
  }

  /**
   * @notice Verifies that after executing the changer:
   *         - mocInrateV1.getBitProRate() equals newBitProRate
   *         - mocInrateV1.getBitProInterestAddress() equals bufferCoinbaseProxy
   */
  function testFork_ChangerSetsCorrectValues() public {
    _executeChanger();

    IMoCInrateProbe inrate = IMoCInrateProbe(mocInrateV1);

    assertEq(
      inrate.getBitProRate(),
      newBitProRate,
      "getBitProRate() should match newBitProRate after changer"
    );
    assertEq(
      inrate.getBitProInterestAddress(),
      bufferCoinbaseProxy,
      "getBitProInterestAddress() should point to bufferCoinbaseProxy after changer"
    );
  }

  function testFork_TasksRunnerRegistersNewTasks() public {
    address deprecatedSplitter = IMoCInrateProbe(mocInrateV1).getBitProInterestAddress();
    assertGt(
      _countSplitterTasks(deprecatedSplitter),
      0,
      "Expected deprecated BitPro interest tasks before migration"
    );

    _executeChanger();

    assertEq(
      _countSplitterTasks(deprecatedSplitter),
      0,
      "Deprecated BitPro interest splitter tasks should be removed"
    );
    assertTrue(_containsTask(bufferFlushTask), "New buffer flush task missing");
    assertTrue(_containsTask(bufferLiquidateTask), "New buffer liquidate task missing");
    assertTrue(_containsTask(tpInjectionTask), "New TP injection task missing");
    assertTrue(_containsTask(feeFlowBufferFlushTask), "Fee flow flush task missing");
    assertTrue(_containsTask(feeFlowBufferLiquidateTask), "Fee flow liquidate task missing");
    assertTrue(_containsTask(docToRbtcTask), "DOC to RBTC task missing");
    assertTrue(_containsTask(docToMocLiquidationTask), "DOC to MOC liquidation task missing");
    assertTrue(_containsTask(rbtcToMocLiquidationTask), "RBTC to MOC liquidation task missing");
  }

  function testFork_ChangerRegistersLiquidationEngine() public {
    _executeChanger();

    assertEq(
      IOracleManagerProbe(oracleManager).getContractAddress(liquidationEngineName),
      liquidationEngine,
      "OracleManager should resolve LENDING to the LiquidationEngine proxy"
    );
  }

  function testFork_ChangerDrainsDeprecatedInterestSplitter() public {
    address deprecatedInterestRecipient = IMoCInrateProbe(mocInrateV1).getBitProInterestAddress();
    vm.deal(deprecatedInterestRecipient, 1 ether);

    _executeChanger();

    assertEq(deprecatedInterestRecipient.balance, 0, "Deprecated splitter was not drained");
  }

  /**
   * @notice Verifies that BufferCoinbase output[0] is the TPInjector,
   *         output[1] is bufferOutput1 and output[2] is bufferOutput2.
   */
  function testFork_BufferCoinbase_OutputsConfiguredCorrectly() public view {
    IBufferCoinbaseLike buffer = IBufferCoinbaseLike(bufferCoinbaseProxy);

    (address out0, , , ) = buffer.getOutput(0);
    assertEq(out0, tpInjector, "BufferCoinbase outputs[0] should be the TPInjector");

    (address out1, , , ) = buffer.getOutput(1);
    assertEq(out1, bufferOutput1, "BufferCoinbase outputs[1] should be bufferOutput1");

    (address out2, , , ) = buffer.getOutput(2);
    assertEq(out2, bufferOutput2, "BufferCoinbase outputs[2] should be bufferOutput2");
  }

  function testFork_MocFeeFlow_ConfiguredCorrectly() public view {
    IBufferCoinbaseLike feeFlow = IBufferCoinbaseLike(mocFeeFlowProxy);

    assertEq(feeFlow.getToken(), docToken, "Fee flow token should be DOC");

    (address output0, uint256 split0, , uint256 threshold0) = feeFlow.getOutput(0);
    assertEq(output0, address(docToRbtcReverseAuction), "Fee flow output[0] should swap to RBTC");
    assertEq(split0, mocFeeFlowSplitDocToRbtc, "Fee flow output[0] split mismatch");
    assertEq(
      threshold0,
      mocFeeFlowOutputThresholdDocToRbtc,
      "Fee flow output[0] threshold mismatch"
    );

    (address output1, uint256 split1, , uint256 threshold1) = feeFlow.getOutput(1);
    assertEq(output1, mocFeeFlowMimLabs, "Fee flow output[1] should be MIM Labs");
    assertEq(split1, mocFeeFlowSplitMimLabs, "Fee flow output[1] split mismatch");
    assertEq(threshold1, mocFeeFlowOutputThresholdMimLabs, "Fee flow output[1] threshold mismatch");

    (address output2, uint256 split2, , uint256 threshold2) = feeFlow.getOutput(2);
    assertEq(output2, docToMocReverseAuction, "Fee flow output[2] should swap to MOC");
    assertEq(split2, mocFeeFlowSplitDocToMoc, "Fee flow output[2] split mismatch");
    assertEq(
      threshold2,
      mocFeeFlowOutputThresholdDocToMoc,
      "Fee flow output[2] threshold mismatch"
    );

    (address output3, uint256 split3, , uint256 threshold3) = feeFlow.getOutput(3);
    assertEq(
      output3,
      address(docToMocLiquidationReverseAuction),
      "Fee flow output[3] should fund LiquidationEngine"
    );
    assertEq(split3, mocFeeFlowSplitDocToMocLiquidation, "Fee flow output[3] split mismatch");
    assertEq(
      threshold3,
      mocFeeFlowOutputThresholdDocToMocLiquidation,
      "Fee flow output[3] threshold mismatch"
    );

    assertEq(
      split0 + split1 + split2 + split3,
      1e18,
      "Fee flow output splits should add up to 100%"
    );
  }

  function testFork_DocToRbtcReverseAuction_ConfiguredCorrectly() public view {
    assertEq(
      address(docToRbtcReverseAuction.mocSwapper()),
      mocSwapperCoreV1,
      "Wrong auction swapper"
    );
    assertEq(docToRbtcReverseAuction.tokenIn(), docToken, "Auction tokenIn should be DOC");
    assertEq(docToRbtcReverseAuction.tokenOut(), address(0), "Auction tokenOut should be RBTC");
    assertEq(docToRbtcReverseAuction.outputAccount(), mocV1, "Auction output should be MoC V1");
    assertEq(
      docToRbtcReverseAuction.orderThreshold(),
      docToRbtcReverseAuctionOrderThreshold,
      "Auction order threshold mismatch"
    );
    assertEq(
      docToRbtcReverseAuction.slippage(),
      docToRbtcReverseAuctionSlippage,
      "Auction slippage mismatch"
    );
  }

  function testFork_DocToRbtcReverseAuction_ExecutesThroughMocSwapperCoreV1() public {
    MocSwapperCoreV1 swapper = MocSwapperCoreV1(payable(mocSwapperCoreV1));
    uint256 maxDocAmount = swapper.getSafeMaxAmountToSwap(docToken, address(0));
    uint256 docAmount = maxDocAmount < 100 ether ? maxDocAmount : 100 ether;
    assertGt(docAmount, 0, "MoC V1 should have redeemable DOC");

    deal(docToken, address(docToRbtcReverseAuction), docAmount);
    docToRbtcReverseAuction.triggerOrders();

    assertEq(
      IERC20Minimal(docToken).balanceOf(address(docToRbtcReverseAuction)),
      0,
      "Reverse auction should redeem its DOC balance"
    );
    assertEq(address(swapper).balance, 0, "MocSwapperCoreV1 should not retain RBTC");
  }

  function testFork_LiquidationFundingReverseAuctions_ConfiguredCorrectly() public view {
    assertEq(
      address(rbtcToMocLiquidationReverseAuction.mocSwapper()),
      mocSwapperExchange,
      "RBTC to MOC auction should use exchange swapper"
    );
    assertEq(rbtcToMocLiquidationReverseAuction.tokenIn(), address(0), "Wrong RBTC tokenIn");
    assertEq(rbtcToMocLiquidationReverseAuction.tokenOut(), mocToken, "Wrong MOC tokenOut");
    assertEq(
      rbtcToMocLiquidationReverseAuction.outputAccount(),
      liquidationEngine,
      "RBTC auction should fund LiquidationEngine"
    );
    assertEq(
      rbtcToMocLiquidationReverseAuction.orderThreshold(),
      rbtcToMocLiquidationReverseAuctionOrderThreshold,
      "RBTC auction threshold mismatch"
    );
    assertEq(
      rbtcToMocLiquidationReverseAuction.slippage(),
      rbtcToMocLiquidationReverseAuctionSlippage,
      "RBTC auction slippage mismatch"
    );

    assertEq(
      address(docToMocLiquidationReverseAuction.mocSwapper()),
      mocSwapperExchangeMultiHop,
      "DOC to MOC auction should use exchange swapper"
    );
    assertEq(docToMocLiquidationReverseAuction.tokenIn(), docToken, "Wrong DOC tokenIn");
    assertEq(docToMocLiquidationReverseAuction.tokenOut(), mocToken, "Wrong MOC tokenOut");
    assertEq(
      docToMocLiquidationReverseAuction.outputAccount(),
      liquidationEngine,
      "DOC auction should fund LiquidationEngine"
    );
    assertEq(
      address(docToMocLiquidationReverseAuction.priceProvider()),
      docToMocLiquidationPriceProvider,
      "DOC auction price provider mismatch"
    );
  }

  function testFork_RbtcToMocExchangeIsAvailable() public view {
    assertGt(
      IMocSwapperProbe(mocSwapperExchange).getSafeMaxAmountToSwap(address(0), mocToken),
      0,
      "RBTC to MOC direct swap is unavailable"
    );
  }

  function testFork_DocToMocMultiHopPathExists() public {
    // TODO: Enable when the upcoming changer configures DOC -> MOC on the new multihop swapper.
    vm.skip(true);

    IMocSwapperV3MultiHopProbe swapper = IMocSwapperV3MultiHopProbe(mocSwapperExchangeMultiHop);
    assertGt(
      swapper.encodedPaths(docToken, mocToken).length,
      0,
      "DOC to MOC exchange path is missing"
    );
    assertTrue(
      swapper.maxAmountToSwapProviders(docToken, mocToken) != address(0),
      "DOC to MOC max amount provider is missing"
    );
  }

  /**
   * @notice Verifies that after executing the changer the WRBTC→DOC and DOC→WRBTC
   *         paths are properly set on the mocSwapperExchange.
   *
   *         WRBTC→USDT→DOC  fees: [3000, 500]
   *         DOC→USDT→WRBTC  fees: [500, 3000]
   */
  function testFork_SwapperExchange_PathSet() public {
    _executeChanger();

    IMocSwapperV3MultiHopProbe swapper = IMocSwapperV3MultiHopProbe(mocSwapperExchangeMultiHop);

    // ── WRBTC→DOC path ────────────────────────────────────────────────
    bytes memory wrbtcToDocPath = swapper.encodedPaths(wrbtcToken, docToken);
    assertTrue(wrbtcToDocPath.length > 0, "WRBTC->DOC path should be non-empty after changer");

    // ── DOC→WRBTC path ────────────────────────────────────────────────
    bytes memory docToWrbtcPath = swapper.encodedPaths(docToken, wrbtcToken);
    assertTrue(docToWrbtcPath.length > 0, "DOC->WRBTC path should be non-empty after changer");

    // ── Provider addresses ────────────────────────────────────────────
    assertEq(
      swapper.maxAmountToSwapProviders(wrbtcToken, docToken),
      wrbtcToDocProvider,
      "maxAmountToSwapProviders[WRBTC][DOC] should be wrbtcToDocProvider"
    );
    assertEq(
      swapper.maxAmountToSwapProviders(docToken, wrbtcToken),
      docToWrbtcProvider,
      "maxAmountToSwapProviders[DOC][WRBTC] should be docToWrbtcProvider"
    );

    // ── Verify path length: WRBTC→DOC ─────────────────────────────────
    // Encoding: wrbtcToken(20B) | fee0=3000(3B) | usdtToken(20B) | fee1=500(3B) | docToken(20B)
    // Total: 20 + 3 + 20 + 3 + 20 = 66 bytes
    assertEq(wrbtcToDocPath.length, 66, "WRBTC->DOC encoded path should be 66 bytes");

    // ── Verify path length: DOC→WRBTC ─────────────────────────────────
    // Encoding: docToken(20B) | fee0=500(3B) | usdtToken(20B) | fee1=3000(3B) | wrbtcToken(20B)
    assertEq(docToWrbtcPath.length, 66, "DOC->WRBTC encoded path should be 66 bytes");
  }

  /**
   * @notice End-to-end flow test:
   *   1. Execute changer → mocInrateV1.getBitProInterestAddress() = bufferCoinbaseProxy
   *   2. Advance blocks until BitPro interest is enabled
   *   3. payBitProHoldersInterestPayment() → RBTC land in bufferCoinbaseProxy
   *   4. BufferCoinbase.liquidate() → distributes RBTC to output internal balances
   *   5. BufferCoinbase.flush(0) → sends RBTC directly to TPInjector
   */
  function testFork_EndToEnd_BitProInterestFlow() public {
    _executeChanger();

    // ── 1. Verify interest address was updated ─────────────────────────
    assertEq(
      IMoCInrateProbe(mocInrateV1).getBitProInterestAddress(),
      bufferCoinbaseProxy,
      "getBitProInterestAddress() should be bufferCoinbaseProxy"
    );

    // ── 2. Advance blocks until BitPro interest payment is enabled ─────
    IMoCStorageProbe mocStorage = IMoCStorageProbe(mocV1);
    uint256 span = mocStorage.getBitProInterestBlockSpan();
    vm.roll(block.number + span + 1);
    assertTrue(mocStorage.isBitProInterestEnabled(), "BitPro interest should be enabled");

    // ── 3. payBitProHoldersInterestPayment() → RBTC to bufferCoinbaseProxy
    uint256 bufferBalanceBefore = address(bufferCoinbaseProxy).balance;
    IMoCBasicOpsProbe(mocV1).payBitProHoldersInterestPayment();
    uint256 bufferBalanceAfter = address(bufferCoinbaseProxy).balance;
    assertGt(
      bufferBalanceAfter,
      bufferBalanceBefore,
      "Buffer should have received RBTC from interest payment"
    );
    uint256 rbtcReceived = bufferBalanceAfter - bufferBalanceBefore;

    // ── 4. BufferCoinbase.liquidate() → splits RBTC to output balances ─
    IBufferCoinbaseLike buffer = IBufferCoinbaseLike(bufferCoinbaseProxy);
    assertTrue(buffer.isLiquidable(), "Buffer should be liquidable after receiving RBTC");
    buffer.liquidate();

    // output[0] = TPInjector, output[1] = bufferOutput1
    (, , uint256 output0Balance, ) = buffer.getOutput(0);
    (, , uint256 output1Balance, ) = buffer.getOutput(1);
    (, , uint256 output2Balance, ) = buffer.getOutput(2);
    assertGt(
      output0Balance,
      0,
      "output[0] (TPInjector) internal balance should be > 0 after liquidate"
    );
    assertGt(
      output1Balance,
      0,
      "output[1] (bufferOutput1) internal balance should be > 0 after liquidate"
    );
    assertApproxEqAbs(
      output0Balance + output1Balance + output2Balance,
      rbtcReceived,
      3,
      "Sum of output balances should approximately equal RBTC received (dust tolerance)"
    );

    // ── 5. BufferCoinbase.flush(0) → RBTC physically sent to TPInjector
    uint256 tpInjectorBalanceBefore = tpInjector.balance;
    assertTrue(buffer.isFlushable(0), "output[0] should be flushable");
    buffer.flush(0);
    uint256 tpInjectorBalanceAfter = tpInjector.balance;
    assertEq(
      tpInjectorBalanceAfter - tpInjectorBalanceBefore,
      output0Balance,
      "TPInjector should have received exactly output0Balance RBTC"
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  function _containsTask(address task_) internal view returns (bool) {
    address[] memory tasks = tasksRunner.getTasks();
    for (uint256 i = 0; i < tasks.length; i++) {
      if (tasks[i] == task_) return true;
    }
    return false;
  }

  function _countSplitterTasks(address splitter_) internal view returns (uint256 count) {
    address[] memory tasks = tasksRunner.getTasks();
    for (uint256 i = 0; i < tasks.length; i++) {
      try ICommissionSplitterTask(tasks[i]).commissionSplitter() returns (address splitter) {
        if (splitter == splitter_) count++;
      } catch {}
    }
  }

  function _executeChanger() internal {
    address governorAddr = IGoverned(mocInrateV1).governor();
    address governorOwner = IOwnableLike(governorAddr).owner();
    vm.prank(governorOwner);
    IGovernor(governorAddr).executeChange(IChangeContract(address(changer)));
  }

  function _readParamsFromJson() internal {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);
    string memory module = "LendingAndBorrowingV1Module";

    governor = vm.parseJsonAddress(json, _key(module, "governor"));
    pauser = vm.parseJsonAddress(json, _key(module, "pauser"));
    mocV1 = vm.parseJsonAddress(json, _key(module, "mocV1"));
    mocStateV1 = vm.parseJsonAddress(json, _key(module, "mocStateV1"));
    mocInrateV1 = vm.parseJsonAddress(json, _key(module, "mocInrateV1"));
    docToken = vm.parseJsonAddress(json, _key(module, "docToken"));
    mocToken = vm.parseJsonAddress(json, _key(module, "mocToken"));
    tasksRunnerAddress = vm.parseJsonAddress(json, _key(module, "tasksRunner"));
    oracleManager = vm.parseJsonAddress(json, _key(module, "oracleManager"));
    liquidationEngineName = vm.parseJsonBytes32(json, _key(module, "liquidationEngineName"));
    tokenToCoinbasePriceProvider = vm.parseJsonAddress(
      json,
      _key(module, "tokenToCoinbasePriceProvider")
    );
    liquidationPaymentAC = vm.parseJsonUint(json, _key(module, "liquidationPaymentAC"));

    bufferProxyAdmin = vm.parseJsonAddress(json, _key(module, "bufferProxyAdmin"));
    bufferThreshold = vm.parseJsonUint(json, _key(module, "bufferThreshold"));
    bufferOutput1 = vm.parseJsonAddress(json, _key(module, "bufferOutput1"));
    bufferOutput2 = vm.parseJsonAddress(json, _key(module, "bufferOutput2"));
    bufferSplit0 = vm.parseJsonUint(json, _key(module, "bufferSplit0"));
    bufferSplit1 = vm.parseJsonUint(json, _key(module, "bufferSplit1"));
    bufferSplit2 = vm.parseJsonUint(json, _key(module, "bufferSplit2"));
    bufferOutputThreshold0 = vm.parseJsonUint(json, _key(module, "bufferOutputThreshold0"));
    bufferOutputThreshold1 = vm.parseJsonUint(json, _key(module, "bufferOutputThreshold1"));
    bufferOutputThreshold2 = vm.parseJsonUint(json, _key(module, "bufferOutputThreshold2"));

    mocFeeFlowProxyAdmin = vm.parseJsonAddress(json, _key(module, "mocFeeFlowProxyAdmin"));
    mocFeeFlowThreshold = vm.parseJsonUint(json, _key(module, "mocFeeFlowThreshold"));
    mocFeeFlowMimLabs = vm.parseJsonAddress(json, _key(module, "mocFeeFlowMimLabs"));
    docToMocReverseAuction = vm.parseJsonAddress(json, _key(module, "docToMocReverseAuction"));
    mocFeeFlowSplitDocToRbtc = vm.parseJsonUint(json, _key(module, "mocFeeFlowSplitDocToRbtc"));
    mocFeeFlowSplitMimLabs = vm.parseJsonUint(json, _key(module, "mocFeeFlowSplitMimLabs"));
    mocFeeFlowSplitDocToMoc = vm.parseJsonUint(json, _key(module, "mocFeeFlowSplitDocToMoc"));
    mocFeeFlowSplitDocToMocLiquidation = vm.parseJsonUint(
      json,
      _key(module, "mocFeeFlowSplitDocToMocLiquidation")
    );
    mocFeeFlowOutputThresholdDocToRbtc = vm.parseJsonUint(
      json,
      _key(module, "mocFeeFlowOutputThresholdDocToRbtc")
    );
    mocFeeFlowOutputThresholdMimLabs = vm.parseJsonUint(
      json,
      _key(module, "mocFeeFlowOutputThresholdMimLabs")
    );
    mocFeeFlowOutputThresholdDocToMoc = vm.parseJsonUint(
      json,
      _key(module, "mocFeeFlowOutputThresholdDocToMoc")
    );
    mocFeeFlowOutputThresholdDocToMocLiquidation = vm.parseJsonUint(
      json,
      _key(module, "mocFeeFlowOutputThresholdDocToMocLiquidation")
    );
    docToRbtcReverseAuctionOrderThreshold = vm.parseJsonUint(
      json,
      _key(module, "docToRbtcReverseAuctionOrderThreshold")
    );
    docToRbtcReverseAuctionSlippage = vm.parseJsonUint(
      json,
      _key(module, "docToRbtcReverseAuctionSlippage")
    );
    docToMocLiquidationPriceProvider = vm.parseJsonAddress(
      json,
      _key(module, "docToMocLiquidationPriceProvider")
    );
    docToMocLiquidationReverseAuctionOrderThreshold = vm.parseJsonUint(
      json,
      _key(module, "docToMocLiquidationReverseAuctionOrderThreshold")
    );
    docToMocLiquidationReverseAuctionSlippage = vm.parseJsonUint(
      json,
      _key(module, "docToMocLiquidationReverseAuctionSlippage")
    );
    rbtcToMocLiquidationReverseAuctionOrderThreshold = vm.parseJsonUint(
      json,
      _key(module, "rbtcToMocLiquidationReverseAuctionOrderThreshold")
    );
    rbtcToMocLiquidationReverseAuctionSlippage = vm.parseJsonUint(
      json,
      _key(module, "rbtcToMocLiquidationReverseAuctionSlippage")
    );

    docToRbtcPriceProvider = vm.parseJsonAddress(json, _key(module, "docToRbtcPriceProvider"));

    newBitProRate = vm.parseJsonUint(json, _key(module, "newBitProRate"));

    mocSwapperExchange = vm.parseJsonAddress(json, _key(module, "mocSwapperExchange"));
    mocSwapperExchangeMultiHop = vm.parseJsonAddress(
      json,
      _key(module, "mocSwapperExchangeMultiHop")
    );
    wrbtcToken = vm.parseJsonAddress(json, _key(module, "wrbtcToken"));
    usdtToken = vm.parseJsonAddress(json, _key(module, "usdtToken"));
    wrbtcToDocMaxAmount = vm.parseJsonUint(json, _key(module, "wrbtcToDocMaxAmount"));
    docToWrbtcMaxAmount = vm.parseJsonUint(json, _key(module, "docToWrbtcMaxAmount"));
    wrbtcUsdtFee = uint24(vm.parseJsonUint(json, _key(module, "wrbtcUsdtFee")));
    usdtDocFee = uint24(vm.parseJsonUint(json, _key(module, "usdtDocFee")));

    require(governor != address(0), "governor is zero");
    require(mocInrateV1 != address(0), "mocInrateV1 is zero");
    require(tasksRunnerAddress != address(0), "tasksRunner is zero");
    require(oracleManager != address(0), "oracleManager is zero");
    require(bufferProxyAdmin != address(0), "bufferProxyAdmin is zero");
    require(mocFeeFlowProxyAdmin != address(0), "mocFeeFlowProxyAdmin is zero");
    require(mocFeeFlowMimLabs != address(0), "mocFeeFlowMimLabs is zero");
    require(docToMocReverseAuction != address(0), "docToMocReverseAuction is zero");
    require(mocToken != address(0), "mocToken is zero");
    require(tokenToCoinbasePriceProvider != address(0), "tokenToCoinbasePriceProvider is zero");
    require(docToMocLiquidationPriceProvider != address(0), "docToMoc price provider is zero");
    require(wrbtcToken != address(0), "wrbtcToken is zero");
    require(usdtToken != address(0), "usdtToken is zero");
    require(mocSwapperExchange != address(0), "mocSwapperExchange is zero");
    require(mocSwapperExchangeMultiHop != address(0), "mocSwapperExchangeMultiHop is zero");
  }

  function _key(string memory module, string memory field) internal pure returns (string memory) {
    return string(abi.encodePacked(".", module, ".", field));
  }
}
