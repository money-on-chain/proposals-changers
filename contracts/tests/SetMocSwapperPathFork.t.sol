// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { SetMocSwapperPath } from "../changers/set_moc_swapper_path/SetMocSwapperPath.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

interface IGoverned {
  function governor() external view returns (address);
}

interface IOwnableLike {
  function owner() external view returns (address);
}

interface IERC20Like {
  function balanceOf(address account) external view returns (uint256);
}

interface IReverseAuction {
  function mocSwapper() external view returns (address);
  function tokenIn() external view returns (address);
  function tokenOut() external view returns (address);
  function outputAccount() external view returns (address);
  function orderThreshold() external view returns (uint256);
  function readyToTriggerOrders() external view returns (bool);
  function triggerOrders() external;
  function balanceOfSelf() external view returns (uint256);
}

contract SetMocSwapperPathForkTest is Test {
  // Path to the mainnet parameters JSON
  string internal constant MAINNET_PARAMS_PATH =
    "./ignition/modules/SetMocSwapperPath/parameters/rskMainnet.json";

  // ReverseAuction addresses on RSK mainnet
  address internal constant RIF_TO_MOC_REVERSE_AUCTION = 0x323f6117A256E8f697Ac8d2816eb71e9B7134809;
  address internal constant MOC_TO_RIF_REVERSE_AUCTION = 0xd3D1aFc638cEF2C55D2Ee33e0C355972f11Be065;

  // Price rates with 18 decimals precision:
  //   1 RIF = 2.63 MOC  →  RIF_TO_MOC_RATE = 2.50e18
  //   1 MOC = 0.403 RIF →  MOC_TO_RIF_RATE = 0.40e18
  uint256 internal constant RIF_TO_MOC_RATE = 2.50e18;
  uint256 internal constant MOC_TO_RIF_RATE = 0.40e18;
  // 5% tolerance on price checks
  uint256 internal constant TOLERANCE_BPS = 500; // 5% = 500 / 10000

  // Parameters loaded from JSON
  address internal mocSwapper;
  address internal rifToken;
  address internal mocToken;
  address[] internal rifToMocIntermediateTokens;
  uint24[] internal rifToMocFees;
  address[] internal mocToRifIntermediateTokens;
  uint24[] internal mocToRifFees;

  SetMocSwapperPath internal changer;

  function setUp() public {
    string memory defaultRpcUrl = "https://public-node.rsk.co";
    uint256 forkBlock = 9055200;
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", defaultRpcUrl);
    vm.createSelectFork(rpcUrl, forkBlock);

    _readParamsFromJson();
    _deployChanger();
  }

  // ── Tests ──────────────────────────────────────────────────────────────────

  /**
   * @notice Verifies that the ReverseAuctions have the expected tokenIn/tokenOut
   *         matching the params JSON (RIF->MOC and MOC->RIF respectively)
   */
  function testFork_ReverseAuctions_TokensMatchParams() public view {
    IReverseAuction rifToMoc = IReverseAuction(RIF_TO_MOC_REVERSE_AUCTION);
    IReverseAuction mocToRif = IReverseAuction(MOC_TO_RIF_REVERSE_AUCTION);

    // RIF->MOC auction: tokenIn must be RIF, tokenOut must be MOC
    assertEq(rifToMoc.tokenIn(), rifToken, "RifToMoc: tokenIn is not RIF");
    assertEq(rifToMoc.tokenOut(), mocToken, "RifToMoc: tokenOut is not MOC");

    // MOC->RIF auction: tokenIn must be MOC, tokenOut must be RIF
    assertEq(mocToRif.tokenIn(), mocToken, "MocToRif: tokenIn is not MOC");
    assertEq(mocToRif.tokenOut(), rifToken, "MocToRif: tokenOut is not RIF");

    // Both auctions should use the same swapper
    assertEq(rifToMoc.mocSwapper(), mocSwapper, "RifToMoc: mocSwapper mismatch");
    assertEq(mocToRif.mocSwapper(), mocSwapper, "MocToRif: mocSwapper mismatch");
  }

  /**
   * @notice Verifies that the changer executes without reverting
   */
  function testFork_DeployAndExecuteChanger() public {
    _executeChanger();
  }

  /**
   * @notice After executing the changer, funds the RIF->MOC ReverseAuction
   *         with RIF tokens (via deal) and triggers a swap order.
   *         Verifies MOC is received at ~2.63 MOC per RIF (±5% tolerance).
   */
  function testFork_RifToMoc_TriggerOrders() public {
    _executeChanger();

    IReverseAuction rifToMoc = IReverseAuction(RIF_TO_MOC_REVERSE_AUCTION);
    address outputAccount = rifToMoc.outputAccount();

    // Fund the auction with 2x the orderThreshold using deal (no whale needed)
    uint256 threshold = rifToMoc.orderThreshold();
    uint256 fundAmount = threshold > 0 ? threshold * 2 : 1000 ether;
    deal(rifToken, RIF_TO_MOC_REVERSE_AUCTION, fundAmount);

    require(rifToMoc.readyToTriggerOrders(), "RifToMoc: not ready to trigger after funding");

    uint256 rifInAuctionBefore = IERC20Like(rifToken).balanceOf(RIF_TO_MOC_REVERSE_AUCTION);
    uint256 mocBalanceBefore = IERC20Like(mocToken).balanceOf(outputAccount);

    rifToMoc.triggerOrders();

    uint256 rifInAuctionAfter = IERC20Like(rifToken).balanceOf(RIF_TO_MOC_REVERSE_AUCTION);
    uint256 mocBalanceAfter = IERC20Like(mocToken).balanceOf(outputAccount);

    uint256 rifSpent = rifInAuctionBefore - rifInAuctionAfter;
    uint256 mocReceived = mocBalanceAfter - mocBalanceBefore;

    assertGt(rifSpent, 0, "RifToMoc: no RIF was spent");
    assertGt(mocReceived, 0, "RifToMoc: no MOC was received");

    // Price check: mocReceived should be ~2.63 * rifSpent (±5%)
    uint256 expectedMoc = (rifSpent * RIF_TO_MOC_RATE) / 1e18;
    uint256 minMoc = (expectedMoc * (10000 - TOLERANCE_BPS)) / 10000;
    uint256 maxMoc = (expectedMoc * (10000 + TOLERANCE_BPS)) / 10000;

    assertGe(mocReceived, minMoc, "RifToMoc: received less MOC than expected (price too low)");
    assertLe(mocReceived, maxMoc, "RifToMoc: received more MOC than expected (price too high)");
  }

  /**
   * @notice After executing the changer, funds the MOC->RIF ReverseAuction
   *         with MOC tokens (via deal) and triggers a swap order.
   *         Verifies RIF is received at ~0.403 RIF per MOC (±5% tolerance).
   */
  function testFork_MocToRif_TriggerOrders() public {
    _executeChanger();

    IReverseAuction mocToRif = IReverseAuction(MOC_TO_RIF_REVERSE_AUCTION);
    address outputAccount = mocToRif.outputAccount();

    // Fund the auction with 2x the orderThreshold using deal (no whale needed)
    uint256 threshold = mocToRif.orderThreshold();
    uint256 fundAmount = threshold > 0 ? threshold * 2 : 1000 ether;
    deal(mocToken, MOC_TO_RIF_REVERSE_AUCTION, fundAmount);

    require(mocToRif.readyToTriggerOrders(), "MocToRif: not ready to trigger after funding");

    uint256 mocInAuctionBefore = IERC20Like(mocToken).balanceOf(MOC_TO_RIF_REVERSE_AUCTION);
    uint256 rifBalanceBefore = IERC20Like(rifToken).balanceOf(outputAccount);

    mocToRif.triggerOrders();

    uint256 mocInAuctionAfter = IERC20Like(mocToken).balanceOf(MOC_TO_RIF_REVERSE_AUCTION);
    uint256 rifBalanceAfter = IERC20Like(rifToken).balanceOf(outputAccount);

    uint256 mocSpent = mocInAuctionBefore - mocInAuctionAfter;
    uint256 rifReceived = rifBalanceAfter - rifBalanceBefore;

    assertGt(mocSpent, 0, "MocToRif: no MOC was spent");
    assertGt(rifReceived, 0, "MocToRif: no RIF was received");

    // Price check: rifReceived should be ~0.403 * mocSpent (±5%)
    uint256 expectedRif = (mocSpent * MOC_TO_RIF_RATE) / 1e18;
    uint256 minRif = (expectedRif * (10000 - TOLERANCE_BPS)) / 10000;
    uint256 maxRif = (expectedRif * (10000 + TOLERANCE_BPS)) / 10000;

    assertGe(rifReceived, minRif, "MocToRif: received less RIF than expected (price too low)");
    assertLe(rifReceived, maxRif, "MocToRif: received more RIF than expected (price too high)");
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  function _executeChanger() internal {
    address governor = IGoverned(RIF_TO_MOC_REVERSE_AUCTION).governor();
    address governorOwner = IOwnableLike(governor).owner();
    vm.prank(governorOwner);
    IGovernor(governor).executeChange(IChangeContract(address(changer)));
  }

  function _deployChanger() internal {
    changer = new SetMocSwapperPath(
      mocSwapper,
      rifToken,
      mocToken,
      rifToMocIntermediateTokens,
      rifToMocFees,
      mocToRifIntermediateTokens,
      mocToRifFees
    );
  }

  function _readParamsFromJson() internal {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);

    mocSwapper = vm.parseJsonAddress(json, ".SetMocSwapperPathModule.mocSwapper");
    rifToken = vm.parseJsonAddress(json, ".SetMocSwapperPathModule.rifToken");
    mocToken = vm.parseJsonAddress(json, ".SetMocSwapperPathModule.mocToken");

    // Parse intermediate tokens arrays
    address[] memory rifToMocIntermediate = vm.parseJsonAddressArray(
      json,
      ".SetMocSwapperPathModule.rifToMocIntermediateTokens"
    );
    for (uint256 i = 0; i < rifToMocIntermediate.length; i++) {
      rifToMocIntermediateTokens.push(rifToMocIntermediate[i]);
    }

    address[] memory mocToRifIntermediate = vm.parseJsonAddressArray(
      json,
      ".SetMocSwapperPathModule.mocToRifIntermediateTokens"
    );
    for (uint256 i = 0; i < mocToRifIntermediate.length; i++) {
      mocToRifIntermediateTokens.push(mocToRifIntermediate[i]);
    }

    // Parse fees arrays (stored as uint256 in JSON, cast to uint24)
    uint256[] memory rifToMocFeesRaw = vm.parseJsonUintArray(json, ".SetMocSwapperPathModule.rifToMocFees");
    for (uint256 i = 0; i < rifToMocFeesRaw.length; i++) {
      rifToMocFees.push(uint24(rifToMocFeesRaw[i]));
    }

    uint256[] memory mocToRifFeesRaw = vm.parseJsonUintArray(json, ".SetMocSwapperPathModule.mocToRifFees");
    for (uint256 i = 0; i < mocToRifFeesRaw.length; i++) {
      mocToRifFees.push(uint24(mocToRifFeesRaw[i]));
    }

    require(mocSwapper != address(0), "mocSwapper is zero");
    require(rifToken != address(0), "rifToken is zero");
    require(mocToken != address(0), "mocToken is zero");
  }
}
