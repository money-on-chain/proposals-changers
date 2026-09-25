// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface IMIP264001Swapper {
  function encodedPaths(address tokenIn, address tokenOut) external view returns (bytes memory);
  function maxAmountToSwapProviders(
    address tokenIn,
    address tokenOut
  ) external view returns (address);

  function setPath(
    address tokenA,
    address tokenB,
    address[] memory intermediates,
    uint24[] memory fees,
    address provider
  ) external;
}

interface IMIP264001Auction {
  function setMocSwapper(address swapper) external;
}

interface IMIP264001Guard {
  function governor() external view returns (address);
  function buckets(uint256 index) external view returns (address);
  function mocSwappers(address bucketA, address bucketB) external view returns (address);
  function coinbaseExecFeeRecipient() external view returns (address);
  function setMocSwapper(address bucketA, address bucketB, address swapper) external;
}

interface IMIP264001Bucket {
  function acToken() external view returns (address);
  function feeToken() external view returns (address);
  function pegContainer(uint256 index) external view returns (uint256, address);
}

interface IMIP264001TasksRunner {
  function addTask(address task) external;
}

/** @notice Configures the RIF/USD subsidy and retires the dedicated RIF/DOC swapper. */
contract MIP264001RifUsdSubsidy is IChangeContract {
  address private constant USDT = 0xAf368c91793CB22739386DFCbBb2F1A9e4bCBeBf;
  address private constant USD0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
  address private constant WRBTC = 0x542fDA317318eBF1d3DEAf76E0b632741A7e677d;

  IMIP264001Swapper public immutable mocSwapperV3Multihop;
  IMIP264001Auction public immutable docToMocAuction;
  IMIP264001Auction public immutable mocToDocAuction;
  IMIP264001Guard public immutable multiCollateralGuard;
  IMIP264001TasksRunner public immutable tasksRunner;
  address public immutable rbtcToMocTask;
  IMIP264001Swapper public immutable deprecatedMocswapperV3Multihop;
  address public immutable rifBucket;
  address public immutable docBucket;
  address public immutable rifToken;
  address public immutable docToken;
  address public immutable mocToken;
  address public immutable docToMocProvider;
  address public immutable mocToDocProvider;
  address public immutable docToRifProvider;
  address public immutable rifToDocProvider;

  constructor(
    IMIP264001Swapper mocSwapperV3Multihop_,
    IMIP264001Auction docToMocAuction_,
    IMIP264001Auction mocToDocAuction_,
    IMIP264001Guard multiCollateralGuard_,
    IMIP264001TasksRunner tasksRunner_,
    address rbtcToMocTask_
  ) {
    mocSwapperV3Multihop = mocSwapperV3Multihop_;
    docToMocAuction = docToMocAuction_;
    mocToDocAuction = mocToDocAuction_;
    multiCollateralGuard = multiCollateralGuard_;
    tasksRunner = tasksRunner_;
    rbtcToMocTask = rbtcToMocTask_;

    address _rifBucket = multiCollateralGuard_.buckets(0);
    address _docBucket = multiCollateralGuard_.buckets(1);
    address _rifToken = IMIP264001Bucket(_rifBucket).acToken();
    address _docToken = IMIP264001Bucket(_docBucket).acToken();
    address _mocToken = IMIP264001Bucket(_rifBucket).feeToken();
    IMIP264001Swapper _deprecatedMocswapperV3Multihop = IMIP264001Swapper(
      multiCollateralGuard_.mocSwappers(_rifBucket, _docBucket)
    );

    address _docToMocProvider = _deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(
      _docToken,
      _mocToken
    );
    address _mocToDocProvider = _deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(
      _mocToken,
      _docToken
    );
    address _docToRifProvider = _deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(
      _docToken,
      _rifToken
    );
    address _rifToDocProvider = _deprecatedMocswapperV3Multihop.maxAmountToSwapProviders(
      _rifToken,
      _docToken
    );
    rifBucket = _rifBucket;
    docBucket = _docBucket;
    rifToken = _rifToken;
    docToken = _docToken;
    mocToken = _mocToken;
    deprecatedMocswapperV3Multihop = _deprecatedMocswapperV3Multihop;
    docToMocProvider = _docToMocProvider;
    mocToDocProvider = _mocToDocProvider;
    docToRifProvider = _docToRifProvider;
    rifToDocProvider = _rifToDocProvider;
  }

  function execute() external {
    // DOC -> USDT -> WRBTC -> MOC
    address[] memory docToMocIntermediates = new address[](2);
    docToMocIntermediates[0] = USDT;
    docToMocIntermediates[1] = WRBTC;
    uint24[] memory docToMocFees = new uint24[](3);
    docToMocFees[0] = 500;
    docToMocFees[1] = 3000;
    docToMocFees[2] = 3000;
    mocSwapperV3Multihop.setPath(
      docToken,
      mocToken,
      docToMocIntermediates,
      docToMocFees,
      docToMocProvider
    );

    // MOC -> WRBTC -> USDT -> DOC
    address[] memory mocToDocIntermediates = new address[](2);
    mocToDocIntermediates[0] = WRBTC;
    mocToDocIntermediates[1] = USDT;
    uint24[] memory mocToDocFees = new uint24[](3);
    mocToDocFees[0] = 3000;
    mocToDocFees[1] = 3000;
    mocToDocFees[2] = 500;
    mocSwapperV3Multihop.setPath(
      mocToken,
      docToken,
      mocToDocIntermediates,
      mocToDocFees,
      mocToDocProvider
    );

    // DOC -> USD0 -> RIF
    address[] memory viaUsd0 = new address[](1);
    viaUsd0[0] = USD0;
    uint24[] memory docToRifFees = new uint24[](2);
    docToRifFees[0] = 3000;
    docToRifFees[1] = 3000;
    mocSwapperV3Multihop.setPath(docToken, rifToken, viaUsd0, docToRifFees, docToRifProvider);

    // RIF -> USD0 -> DOC
    uint24[] memory rifToDocFees = new uint24[](2);
    rifToDocFees[0] = 3000;
    rifToDocFees[1] = 3000;
    mocSwapperV3Multihop.setPath(rifToken, docToken, viaUsd0, rifToDocFees, rifToDocProvider);

    docToMocAuction.setMocSwapper(address(mocSwapperV3Multihop));
    mocToDocAuction.setMocSwapper(address(mocSwapperV3Multihop));
    multiCollateralGuard.setMocSwapper(rifBucket, docBucket, address(mocSwapperV3Multihop));
    tasksRunner.addTask(rbtcToMocTask);
  }
}
