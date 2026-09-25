// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { MIP264001RifUsdSubsidy, IMIP264001Swapper, IMIP264001Auction, IMIP264001Guard, IMIP264001Bucket, IMIP264001TasksRunner } from "../changers/mip26_4001/MIP264001RifUsdSubsidy.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";
import { MocReverseAuction } from "@moc/main/contracts/auxiliary/MocReverseAuction.sol";
import { IMocSwapper } from "@moc/main/contracts/interfaces/IMocSwapper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TaskTriggerOrder } from "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol";

interface IMIP264001TasksRunnerProbe {
  function getTasks() external view returns (address[] memory);
}

interface IMIP264001Ownable {
  function owner() external view returns (address);
}

/** @notice Runs the complete proposal against deployed Rootstock mainnet contracts. */
contract MIP264001RifUsdSubsidyForkTest is Test {
  string internal constant PARAMS_PATH = "./ignition/modules/MIP26-4001/parameters/rskMainnet.json";
  string internal constant PARAMS_KEY = ".MIP264001Module.";
  uint256 internal constant FORK_BLOCK = 9_220_195;
  address internal constant USD0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;

  IMIP264001Guard internal guard;
  IMIP264001Swapper internal deprecatedMocswapperV3Multihop;
  IMIP264001Swapper internal mocSwapperV3Multihop;
  IMIP264001Bucket internal rifBucket;
  IMIP264001Bucket internal docBucket;
  MocReverseAuction internal existingAuction;
  MocReverseAuction internal subsidyAuction;
  TaskTriggerOrder internal subsidyTask;
  MIP264001RifUsdSubsidy internal changer;
  address internal docToMocAuction;
  address internal mocToDocAuction;
  address internal tasksRunner;
  address internal rifUsdCoinPair;
  address internal mocToken;
  address internal taskOwner;

  function setUp() public {
    string memory params = vm.readFile(PARAMS_PATH);
    address guardAddress = _address(params, "multiCollateralGuard");
    mocSwapperV3Multihop = IMIP264001Swapper(_address(params, "mocSwapperV3Multihop"));
    docToMocAuction = _address(params, "docToMocAuction");
    mocToDocAuction = _address(params, "mocToDocAuction");
    tasksRunner = _address(params, "tasksRunner");
    taskOwner = _address(params, "taskOwner");

    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", string("https://public-node.rsk.co"));
    vm.createSelectFork(rpcUrl, FORK_BLOCK);

    guard = IMIP264001Guard(guardAddress);
    rifBucket = IMIP264001Bucket(guard.buckets(0));
    docBucket = IMIP264001Bucket(guard.buckets(1));
    deprecatedMocswapperV3Multihop = IMIP264001Swapper(
      guard.mocSwappers(address(rifBucket), address(docBucket))
    );
    (, rifUsdCoinPair) = rifBucket.pegContainer(0);
    mocToken = rifBucket.feeToken();
    existingAuction = MocReverseAuction(payable(guard.coinbaseExecFeeRecipient()));

    subsidyAuction = new MocReverseAuction(
      address(guard.governor()),
      address(existingAuction.mocSwapper()),
      address(0),
      mocToken,
      rifUsdCoinPair,
      existingAuction.orderThreshold(),
      address(existingAuction.priceProvider()),
      existingAuction.slippage()
    );
    subsidyTask = new TaskTriggerOrder(address(subsidyAuction), 36000, taskOwner);
    changer = new MIP264001RifUsdSubsidy(
      mocSwapperV3Multihop,
      IMIP264001Auction(docToMocAuction),
      IMIP264001Auction(mocToDocAuction),
      guard,
      IMIP264001TasksRunner(tasksRunner),
      address(subsidyTask)
    );
  }

  function testForkDerivesAuctionInputsFromLiveContracts() public view {
    assertEq(mocToken, docBucket.feeToken());
    assertEq(address(rifBucket), guard.buckets(0));
    assertEq(address(docBucket), guard.buckets(1));
    assertEq(
      address(deprecatedMocswapperV3Multihop),
      guard.mocSwappers(address(rifBucket), address(docBucket))
    );
    assertEq(
      address(changer.deprecatedMocswapperV3Multihop()),
      address(deprecatedMocswapperV3Multihop)
    );
    assertEq(changer.rifBucket(), address(rifBucket));
    assertEq(changer.docBucket(), address(docBucket));
    assertEq(changer.rifToken(), rifBucket.acToken());
    assertEq(changer.docToken(), docBucket.acToken());
    assertEq(changer.mocToken(), mocToken);
    assertEq(address(changer.tasksRunner()), tasksRunner);
    assertEq(
      changer.docToMocProvider(),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(docBucket.acToken(), mocToken)
    );
    assertEq(
      changer.mocToDocProvider(),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(mocToken, docBucket.acToken())
    );
    assertEq(
      changer.docToRifProvider(),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(
        docBucket.acToken(),
        rifBucket.acToken()
      )
    );
    assertEq(
      changer.rifToDocProvider(),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(
        rifBucket.acToken(),
        docBucket.acToken()
      )
    );
    assertEq(subsidyAuction.tokenIn(), address(0));
    assertEq(subsidyAuction.tokenOut(), rifBucket.feeToken());
    assertEq(subsidyAuction.outputAccount(), rifUsdCoinPair);
    assertEq(address(subsidyAuction.mocSwapper()), address(existingAuction.mocSwapper()));
    assertEq(subsidyAuction.orderThreshold(), existingAuction.orderThreshold());
    assertEq(address(subsidyAuction.priceProvider()), address(existingAuction.priceProvider()));
    assertEq(subsidyAuction.slippage(), existingAuction.slippage());
  }

  function testForkExecutesProposalAgainstDeployedContracts() public {
    address doc = docBucket.acToken();
    address rif = rifBucket.acToken();
    address moc = rifBucket.feeToken();
    bytes memory docToMocPath = deprecatedMocswapperV3Multihop.encodedPaths(doc, moc);
    bytes memory mocToDocPath = deprecatedMocswapperV3Multihop.encodedPaths(moc, doc);
    bytes memory docToRifPath = abi.encodePacked(doc, uint24(3000), USD0, uint24(3000), rif);
    bytes memory rifToDocPath = abi.encodePacked(rif, uint24(3000), USD0, uint24(3000), doc);
    assertGt(docToMocPath.length, 0);
    assertGt(mocToDocPath.length, 0);
    assertGt(docToRifPath.length, 0);
    assertGt(rifToDocPath.length, 0);

    address governor = guard.governor();
    vm.prank(IMIP264001Ownable(governor).owner());
    IGovernor(governor).executeChange(IChangeContract(address(changer)));

    assertEq(mocSwapperV3Multihop.encodedPaths(doc, moc), docToMocPath);
    assertEq(mocSwapperV3Multihop.encodedPaths(moc, doc), mocToDocPath);
    assertEq(mocSwapperV3Multihop.encodedPaths(doc, rif), docToRifPath);
    assertEq(mocSwapperV3Multihop.encodedPaths(rif, doc), rifToDocPath);
    assertEq(
      mocSwapperV3Multihop.maxAmountToSwapProviders(doc, moc),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(doc, moc)
    );
    assertEq(
      mocSwapperV3Multihop.maxAmountToSwapProviders(moc, doc),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(moc, doc)
    );
    assertEq(
      mocSwapperV3Multihop.maxAmountToSwapProviders(doc, rif),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(doc, rif)
    );
    assertEq(
      mocSwapperV3Multihop.maxAmountToSwapProviders(rif, doc),
      deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(rif, doc)
    );
    assertEq(
      address(MocReverseAuction(payable(docToMocAuction)).mocSwapper()),
      address(mocSwapperV3Multihop)
    );
    assertEq(
      address(MocReverseAuction(payable(mocToDocAuction)).mocSwapper()),
      address(mocSwapperV3Multihop)
    );
    assertEq(
      guard.mocSwappers(address(rifBucket), address(docBucket)),
      address(mocSwapperV3Multihop)
    );
    assertEq(
      guard.mocSwappers(address(docBucket), address(rifBucket)),
      address(mocSwapperV3Multihop)
    );

    address[] memory tasks = IMIP264001TasksRunnerProbe(tasksRunner).getTasks();
    bool taskFound;
    for (uint256 i; i < tasks.length; ++i) {
      if (tasks[i] == address(subsidyTask)) taskFound = true;
    }
    assertTrue(taskFound);
    assertEq(address(subsidyTask.reverseAuction()), address(subsidyAuction));
  }

  function testForkSwapsThroughNewPaths() public {
    address governor = guard.governor();
    vm.prank(IMIP264001Ownable(governor).owner());
    IGovernor(governor).executeChange(IChangeContract(address(changer)));

    address doc = docBucket.acToken();
    address rif = rifBucket.acToken();
    address moc = rifBucket.feeToken();

    _assertSwap(doc, moc, 1 ether);
    _assertSwap(moc, doc, 1 ether);
    _assertSwap(doc, rif, 1 ether);
    _assertSwap(rif, doc, 1 ether);
  }

  function testForkSubsidyAuctionSendsMocToRifUsdCoinPair() public {
    address governor = guard.governor();
    vm.prank(IMIP264001Ownable(governor).owner());
    IGovernor(governor).executeChange(IChangeContract(address(changer)));

    uint256 amountIn = subsidyAuction.orderThreshold();
    assertFalse(subsidyTask.checkTask());
    vm.deal(address(this), amountIn);
    (bool funded, ) = payable(address(subsidyAuction)).call{ value: amountIn }("");
    assertTrue(funded);
    assertTrue(subsidyTask.checkTask());

    (uint256 amountToSwap, uint256 amountOutMin) = subsidyAuction.getAmountOutMin();
    assertEq(amountToSwap, amountIn);
    assertGt(amountOutMin, 0);

    uint256 mocBefore = IERC20(mocToken).balanceOf(rifUsdCoinPair);
    subsidyTask.runTask();

    assertEq(subsidyTask.lastRevertTimestamp(), 0);
    assertEq(address(subsidyAuction).balance, 0);
    assertGe(IERC20(mocToken).balanceOf(rifUsdCoinPair) - mocBefore, amountOutMin);
    assertFalse(subsidyTask.checkTask());
  }

  function _assertSwap(address tokenIn, address tokenOut, uint256 amountIn) internal {
    IMocSwapper swapper = IMocSwapper(address(mocSwapperV3Multihop));
    assertGe(swapper.getSafeMaxAmountToSwap(tokenIn, tokenOut), amountIn);
    deal(tokenIn, address(this), amountIn);
    IERC20(tokenIn).approve(address(swapper), amountIn);

    uint256 outputBefore = IERC20(tokenOut).balanceOf(address(this));
    uint256 amountOut = swapper.swapRC20(tokenIn, tokenOut, amountIn, 0, address(this));

    assertGt(amountOut, 0);
    assertEq(IERC20(tokenIn).balanceOf(address(this)), 0);
    assertEq(IERC20(tokenOut).balanceOf(address(this)) - outputBefore, amountOut);
  }

  function _address(string memory params, string memory key) internal returns (address) {
    return vm.parseJsonAddress(params, string.concat(PARAMS_KEY, key));
  }
}
