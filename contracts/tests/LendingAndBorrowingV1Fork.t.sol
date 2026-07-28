// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { MocV1LendingAndBorrowing, IMoCInrate, IMocSwapperMultihopV3, IDataProvider, ITasksRunner } from "../changers/mocV1LendingAndBorrowing/MocV1LendingAndBorrowing.sol";
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

/// @notice Minimal interface to call peek() on a price oracle
interface IPeekable {
  function peek() external view returns (bytes32, bool);
}

/// @notice Minimal interface to inspect MocSwapperV3MultiHop paths
interface IMocSwapperV3MultiHopProbe {
  function encodedPaths(address tokenIn, address tokenOut) external view returns (bytes memory);
  function maxAmountToSwapProviders(
    address tokenIn,
    address tokenOut
  ) external view returns (address);
}

contract TasksRunnerMock is ITasksRunner {
  address[] internal tasks;

  function addTask(address task) external {
    tasks.push(task);
  }

  function removeTask(address task) external {
    for (uint256 i = 0; i < tasks.length; i++) {
      if (tasks[i] == task) {
        tasks[i] = tasks[tasks.length - 1];
        tasks.pop();
        return;
      }
    }
  }

  function getTasks() external view returns (address[] memory) {
    return tasks;
  }

  function containsTask(address task) external view returns (bool) {
    for (uint256 i = 0; i < tasks.length; i++) {
      if (tasks[i] == task) return true;
    }
    return false;
  }
}

contract CommissionSplitterTaskMock {
  address public immutable commissionSplitter;

  constructor(address commissionSplitter_) {
    commissionSplitter = commissionSplitter_;
  }
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
 *        Step 10  - Deploy MocReverseAuction
 *        Step 11  - Deploy BufferCoinbase (impl + TransparentUpgradeableProxy)
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

  // ReverseAuction params
  uint256 internal reverseAuctionOrderThreshold;
  // docToRbtcPriceProvider: already deployed DOC/RBTC price provider on mainnet.
  // Wrapped by PriceProviderInverse at setUp to yield the RBTC/DOC price for the auction.
  address internal docToRbtcPriceProvider;
  uint256 internal reverseAuctionSlippage;

  // Changer param
  uint256 internal newBitProRate;

  // Swap path params
  address internal mocSwapperExchange;
  address internal wrbtcToken;
  address internal usdtToken;
  uint256 internal wrbtcToDocMaxAmount;
  uint256 internal docToWrbtcMaxAmount;
  uint24 internal wrbtcUsdtFee;
  uint24 internal usdtDocFee;

  // ─── Deployed contracts ───────────────────────────────────────────────────
  address internal mocSwapperCoreV1;
  MocReverseAuction internal reverseAuction;
  address internal bufferCoinbaseProxy;
  // DataProvider instances deployed via vm.deployCode (avoids moc-main-latest alias issue)
  address internal wrbtcToDocProvider;
  address internal docToWrbtcProvider;
  MocV1LendingAndBorrowing internal changer;
  TasksRunnerMock internal tasksRunner;
  address internal deprecatedSplitterTask;
  address internal bufferFlushTask;
  address internal bufferLiquidateTask;

  receive() external payable {}

  // ─── setUp ────────────────────────────────────────────────────────────────

  function setUp() public {
    string memory defaultRpcUrl = "https://public-node.rsk.co";
    uint256 forkBlock = 9080600;
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", defaultRpcUrl);
    vm.createSelectFork(rpcUrl, forkBlock);

    _readParamsFromJson();

    // ── Step 1: Deploy MocSwapperCoreV1 ────────────────────────────────
    // MocSwapperCoreV1(address governor_, address mocV1_, address mocStateV1_,
    //                  address mocInrateV1_, address tpToken_)
    mocSwapperCoreV1 = address(
      new MocSwapperCoreV1(governor, mocV1, mocStateV1, mocInrateV1, docToken)
    );

    // ── Step 10a: Deploy PriceProviderInverse ──────────────────────────
    // Wraps the DOC/RBTC price provider to yield the RBTC/DOC price needed by the auction.
    // PriceProviderInverse has pragma >=0.7.6 <0.8.0, deployed via getCode+assembly
    // to avoid cross-version compilation issues in Hardhat.
    address priceProviderInverse;
    {
      bytes memory code = abi.encodePacked(
        vm.getCode("PriceProviderInverse"),
        abi.encode(docToRbtcPriceProvider)
      );
      assembly {
        priceProviderInverse := create(0, add(code, 0x20), mload(code))
      }
    }

    // ── Step 10b: Deploy MocReverseAuction ─────────────────────────────
    // tokenIn  = COINBASE (address(0))
    // tokenOut = DOC
    // outputAccount = bufferOutput1 is used as placeholder for tpInjectorProxy
    reverseAuction = new MocReverseAuction(
      governor,
      mocSwapperCoreV1, // real MocSwapperCoreV1
      address(0), // tokenIn = COINBASE
      docToken, // tokenOut = DOC
      bufferOutput1, // outputAccount placeholder (will be tpInjectorProxy in prod)
      reverseAuctionOrderThreshold,
      priceProviderInverse, // RBTC/DOC = inverse of DOC/RBTC
      reverseAuctionSlippage
    );

    // ── Step 11: Deploy BufferCoinbase impl + TransparentUpgradeableProxy ─
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
    outputs[0] = address(reverseAuction);
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
    tasksRunner = new TasksRunnerMock();
    deprecatedSplitterTask = address(
      new CommissionSplitterTaskMock(IMoCInrateProbe(mocInrateV1).getBitProInterestAddress())
    );
    bufferFlushTask = address(new TaskMock());
    bufferLiquidateTask = address(new TaskMock());
    tasksRunner.addTask(deprecatedSplitterTask);

    changer = new MocV1LendingAndBorrowing(
      IMoCInrate(mocInrateV1),
      newBitProRate,
      payable(bufferCoinbaseProxy),
      tasksRunner,
      bufferFlushTask,
      bufferLiquidateTask,
      IMocSwapperMultihopV3(mocSwapperExchange),
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

  function testFork_TasksRunnerMigratesBitProInterestTasks() public {
    _executeChanger();

    assertFalse(
      tasksRunner.containsTask(deprecatedSplitterTask),
      "Deprecated BitPro interest splitter task should be removed"
    );
    assertTrue(tasksRunner.containsTask(bufferFlushTask), "New buffer flush task missing");
    assertTrue(tasksRunner.containsTask(bufferLiquidateTask), "New buffer liquidate task missing");
  }

  function testFork_ChangerDrainsDeprecatedInterestSplitter() public {
    address deprecatedInterestRecipient = IMoCInrateProbe(mocInrateV1).getBitProInterestAddress();
    vm.deal(deprecatedInterestRecipient, 1 ether);

    _executeChanger();

    assertEq(deprecatedInterestRecipient.balance, 0, "Deprecated splitter was not drained");
  }

  /**
   * @notice Verifies that the ReverseAuction was configured correctly.
   */
  function testFork_ReverseAuction_ConfiguredCorrectly() public view {
    assertEq(reverseAuction.tokenIn(), address(0), "tokenIn should be COINBASE (address(0))");
    assertEq(reverseAuction.tokenOut(), docToken, "tokenOut should be DOC token");
    assertEq(
      address(reverseAuction.governor()),
      governor,
      "reverseAuction.governor() should match governor"
    );
  }

  /**
   * @notice Verifies that BufferCoinbase output[0] is the reverseAuction,
   *         output[1] is bufferOutput1 and output[2] is bufferOutput2.
   */
  function testFork_BufferCoinbase_OutputsConfiguredCorrectly() public view {
    IBufferCoinbaseLike buffer = IBufferCoinbaseLike(bufferCoinbaseProxy);

    (address out0, , , ) = buffer.getOutput(0);
    assertEq(
      out0,
      address(reverseAuction),
      "BufferCoinbase outputs[0] should be the ReverseAuction"
    );

    (address out1, , , ) = buffer.getOutput(1);
    assertEq(out1, bufferOutput1, "BufferCoinbase outputs[1] should be bufferOutput1");

    (address out2, , , ) = buffer.getOutput(2);
    assertEq(out2, bufferOutput2, "BufferCoinbase outputs[2] should be bufferOutput2");
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

    IMocSwapperV3MultiHopProbe swapper = IMocSwapperV3MultiHopProbe(mocSwapperExchange);

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
   *   5. BufferCoinbase.flush(0) → sends RBTC to reverseAuction
   *   6. triggerOrders() → mocked swapper swaps RBTC for DOC, outputAccount receives DOC
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

    // output[0] = reverseAuction, output[1] = bufferOutput1
    (, , uint256 output0Balance, ) = buffer.getOutput(0);
    (, , uint256 output1Balance, ) = buffer.getOutput(1);
    (, , uint256 output2Balance, ) = buffer.getOutput(2);
    assertGt(
      output0Balance,
      0,
      "output[0] (reverseAuction) internal balance should be > 0 after liquidate"
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

    // ── 5. BufferCoinbase.flush(0) → RBTC physically sent to reverseAuction
    uint256 reverseAuctionBalanceBefore = address(reverseAuction).balance;
    assertTrue(buffer.isFlushable(0), "output[0] should be flushable");
    buffer.flush(0);
    uint256 reverseAuctionBalanceAfter = address(reverseAuction).balance;
    assertEq(
      reverseAuctionBalanceAfter - reverseAuctionBalanceBefore,
      output0Balance,
      "reverseAuction should have received exactly output0Balance RBTC"
    );

    // ── 6. triggerOrders() ────────────────────────
    // The priceProvider used by reverseAuction may return isValid=false at the fork block
    // (stale oracle). We read the current price and mock it as valid so triggerOrders() proceeds.
    address priceOracle = 0xe2927A0620b82A66D67F678FC9b826B0E01B1bFD;
    (bytes32 currentPrice, ) = IPeekable(priceOracle).peek();
    vm.mockCall(priceOracle, abi.encodeWithSignature("peek()"), abi.encode(currentPrice, true));

    address outputAccount = reverseAuction.outputAccount();
    uint256 docBefore = IERC20Minimal(docToken).balanceOf(outputAccount);
    reverseAuction.triggerOrders();
    uint256 docAfter = IERC20Minimal(docToken).balanceOf(outputAccount);

    uint256 slippage = reverseAuction.slippage();
    uint256 price = uint256(currentPrice); // DOC/RBTC
    uint256 expectedDocMin = (output0Balance * price) / 1e18;
    expectedDocMin = (expectedDocMin * (1e18 - slippage)) / 1e18;

    assertGe(
      docAfter - docBefore,
      expectedDocMin,
      "DOC received should be >= amountOutMin (price x amountIn x (1 - slippage))"
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

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

    reverseAuctionOrderThreshold = vm.parseJsonUint(
      json,
      _key(module, "reverseAuctionOrderThreshold")
    );
    docToRbtcPriceProvider = vm.parseJsonAddress(json, _key(module, "docToRbtcPriceProvider"));
    reverseAuctionSlippage = vm.parseJsonUint(json, _key(module, "reverseAuctionSlippage"));

    newBitProRate = vm.parseJsonUint(json, _key(module, "newBitProRate"));

    mocSwapperExchange = vm.parseJsonAddress(json, _key(module, "mocSwapperExchange"));
    wrbtcToken = vm.parseJsonAddress(json, _key(module, "wrbtcToken"));
    usdtToken = vm.parseJsonAddress(json, _key(module, "usdtToken"));
    wrbtcToDocMaxAmount = vm.parseJsonUint(json, _key(module, "wrbtcToDocMaxAmount"));
    docToWrbtcMaxAmount = vm.parseJsonUint(json, _key(module, "docToWrbtcMaxAmount"));
    wrbtcUsdtFee = uint24(vm.parseJsonUint(json, _key(module, "wrbtcUsdtFee")));
    usdtDocFee = uint24(vm.parseJsonUint(json, _key(module, "usdtDocFee")));

    require(governor != address(0), "governor is zero");
    require(mocInrateV1 != address(0), "mocInrateV1 is zero");
    require(bufferProxyAdmin != address(0), "bufferProxyAdmin is zero");
    require(wrbtcToken != address(0), "wrbtcToken is zero");
    require(usdtToken != address(0), "usdtToken is zero");
    require(mocSwapperExchange != address(0), "mocSwapperExchange is zero");
  }

  function _key(string memory module, string memory field) internal pure returns (string memory) {
    return string(abi.encodePacked(".", module, ".", field));
  }
}
