import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("LendingAndBorrowingV1Module", (m) => {
  // ─── Shared addresses ───────────────────────────────────────────────────────
  const governor = m.getParameter("governor");
  const pauser = m.getParameter("pauser");

  // MoC V1 contract addresses
  const mocV1 = m.getParameter("mocV1"); // MoC V1 proxy (the bucket)
  const mocStateV1 = m.getParameter("mocStateV1"); // MoCState V1 proxy
  const mocInrateV1 = m.getParameter("mocInrateV1"); // MoCInrate V1 proxy

  // ─── BufferCoinbase parameters ───────────────────────────────────────────────
  const bufferProxyAdmin = m.getParameter("bufferProxyAdmin");
  const bufferThreshold = m.getParameter("bufferThreshold", "0");
  // bufferOutput0 is the MocReverseAuction deployed below
  const bufferOutput1 = m.getParameter("bufferOutput1");
  const bufferOutput2 = m.getParameter("bufferOutput2");
  const bufferSplit0 = m.getParameter("bufferSplit0", "0");
  const bufferSplit1 = m.getParameter("bufferSplit1", "0");
  const bufferSplit2 = m.getParameter("bufferSplit2", "0");
  const bufferOutputThreshold0 = m.getParameter("bufferOutputThreshold0", "0");
  const bufferOutputThreshold1 = m.getParameter("bufferOutputThreshold1", "0");
  const bufferOutputThreshold2 = m.getParameter("bufferOutputThreshold2", "0");

  // ─── MocReverseAuction parameters ────────────────────────────────────────────
  // tokenIn = COINBASE (address(0)), tokenOut = docToken, outputAccount = tpInjectorProxy
  const reverseAuctionOrderThreshold = m.getParameter("reverseAuctionOrderThreshold", "0");
  // docToRbtcPriceProvider: already-deployed DOC/RBTC price provider (e.g. PriceProviderDocRbtc)
  // The module wraps it in PriceProviderInverse to obtain the RBTC/DOC price needed by the auction.
  const docToRbtcPriceProvider = m.getParameter("docToRbtcPriceProvider");
  const reverseAuctionSlippage = m.getParameter("reverseAuctionSlippage", "0");

  // ─── MocV1LendingAndBorrowing changer parameter ──────────────────────────────
  const newBitProRate = m.getParameter("newBitProRate", "0");

  // DOC token (TP token used in this deployment)
  const docToken = m.getParameter("docToken");

  // ─── LendingManager parameters ──────────────────────────────────────────────
  const maxSlippage = m.getParameter("maxSlippage", "30000000000000000"); // 3%

  // Queue is disabled for this deployment
  const useQueue = m.getParameter("useQueue", false);
  const minOperWaitingBlk = m.getParameter("minOperWaitingBlk", 1);
  const maxOperWaitingBlk = m.getParameter("maxOperWaitingBlk", 100);
  const maxOperationPerBatch = m.getParameter("maxOperationPerBatch", 50);
  const borrowExecCost = m.getParameter("borrowExecCost", 200000);
  const removeACExecCost = m.getParameter("removeACExecCost", 150000);
  const repayWithACExecCost = m.getParameter("repayWithACExecCost", 300000);

  // ─── Pool initialization parameters (DOC pool) ──────────────────────────────
  const minCoverage = m.getParameter("minCoverage"); // e.g. "1200000000000000000" (1.2e18)
  const liquidationCoverage = m.getParameter("liquidationCoverage"); // e.g. "1070000000000000000"
  const borrowFee = m.getParameter("borrowFee"); // e.g. "100000000000000000" (10%)
  const uKinkPoint = m.getParameter("uKinkPoint"); // e.g. "800000000000000000" (80%)
  const uSoftSlope = m.getParameter("uSoftSlope"); // e.g. "3170979198"
  const uMaxSlope = m.getParameter("uMaxSlope"); // e.g. "63419583967"
  const injectionTimeSpan = m.getParameter("injectionTimeSpan"); // e.g. "86400" (1 day)
  const injectionBaseFactor = m.getParameter("injectionBaseFactor"); // e.g. "10000000000000000"
  const brakeFirstKink = m.getParameter("brakeFirstKink"); // e.g. "700000000000000000"
  const brakeSecondKink = m.getParameter("brakeSecondKink"); // e.g. "900000000000000000"

  // ─── Swapper & fee flow addresses ───────────────────────────────────────────
  // mocSwapperExchange is already deployed; set to address(0) if not available yet
  const mocSwapperExchange = m.getParameter(
    "mocSwapperExchange",
    "0x0000000000000000000000000000000000000000",
  );
  // feeFlow address — set to address(0) if not available yet
  const mocFeeFlow = m.getParameter("mocFeeFlow", "0x0000000000000000000000000000000000000000");

  // ─── Swap path parameters (WRBTC→USDT→DOC) ──────────────────────────────────
  // WRBTC token address (coinbase wrapper on RSK)
  const wrbtcToken = m.getParameter("wrbtcToken");
  // USDT token address (intermediate hop)
  const usdtToken = m.getParameter("usdtToken");
  // Max amount DataProvider initial values (owner = pauser); set to "0" as placeholder
  const wrbtcToDocMaxAmount = m.getParameter("wrbtcToDocMaxAmount", "0");
  const docToWrbtcMaxAmount = m.getParameter("docToWrbtcMaxAmount", "0");
  // Uniswap V3 pool fees for the multihop path WRBTC→USDT→DOC
  // wrbtcUsdtFee: fee of the WRBTC/USDT pool (e.g. 3000 = 0.3%)
  // usdtDocFee:  fee of the USDT/DOC  pool (e.g.  500 = 0.05%)
  const wrbtcUsdtFee = m.getParameter("wrbtcUsdtFee", 3000);
  const usdtDocFee = m.getParameter("usdtDocFee", 500);

  // ─── 1. Deploy MocAdapterV1 (no proxy needed) ───────────────────────────────
  const mocAdapterV1 = m.contract("MocAdapterV1", [mocV1, mocStateV1, docToken], {
    id: "MocAdapterV1",
  });

  // ─── 2. Deploy MocSwapperCoreV1 (no proxy needed) ───────────────────────────
  const mocSwapperCoreV1 = m.contract(
    "MocSwapperCoreV1",
    [governor, mocV1, mocStateV1, mocInrateV1, docToken],
    { id: "MocSwapperCoreV1" },
  );

  // ─── 3. Deploy MocLendingManager implementation ──────────────────────────────
  const lendingManagerImpl = m.contract("MocLendingManager", [], {
    id: "MocLendingManagerImplementation",
  });

  // Build initialize calldata for the proxy
  const queueParams = [
    useQueue,
    minOperWaitingBlk,
    maxOperWaitingBlk,
    maxOperationPerBatch,
    borrowExecCost,
    removeACExecCost,
    repayWithACExecCost,
  ];

  const lendingManagerInitData = m.encodeFunctionCall(lendingManagerImpl, "initialize", [
    governor,
    pauser,
    mocAdapterV1,
    maxSlippage,
    queueParams,
  ]);

  // Deploy MocLendingManager via ERC1967Proxy
  const lendingManagerProxy = m.contract(
    "ERC1967Proxy",
    [lendingManagerImpl, lendingManagerInitData],
    { id: "MocLendingManagerProxy" },
  );

  // Wrap proxy as MocLendingManager for subsequent calls
  const lendingManager = m.contractAt("MocLendingManager", lendingManagerProxy, {
    id: "MocLendingManagerProxyInstance",
  });

  // ─── 4. Deploy MocLendingReader (no proxy needed) ────────────────────────────
  const lendingReader = m.contract("MocLendingReader", [lendingManagerProxy], {
    id: "MocLendingReader",
  });

  // ─── 5. Deploy TPInjector implementation ────────────────────────────────────
  const tpInjectorImpl = m.contract("TPInjector", [], {
    id: "TPInjectorImplementation",
  });

  // Build initialize calldata for the TPInjector proxy
  const tpInjectorInitData = m.encodeFunctionCall(tpInjectorImpl, "initialize", [
    governor,
    pauser,
    docToken,
    lendingManagerProxy,
  ]);

  // Deploy TPInjector via ERC1967Proxy
  const tpInjectorProxy = m.contract("ERC1967Proxy", [tpInjectorImpl, tpInjectorInitData], {
    id: "TPInjectorProxy",
  });

  // Wrap proxy as TPInjector for reference
  const tpInjector = m.contractAt("TPInjector", tpInjectorProxy, {
    id: "TPInjectorProxyInstance",
  });

  // ─── 6. Initialize the DOC lending pool ─────────────────────────────────────
  m.call(
    lendingManager,
    "initializePool",
    [
      docToken,
      tpInjectorProxy,
      minCoverage,
      liquidationCoverage,
      borrowFee,
      uKinkPoint,
      uSoftSlope,
      uMaxSlope,
      injectionTimeSpan,
      injectionBaseFactor,
      brakeFirstKink,
      brakeSecondKink,
    ],
    { id: "InitializeDocPool" },
  );

  // ─── 7. Configure swapper core (MoC V1 bucket, DOC token) ───────────────────
  m.call(lendingManager, "setMocSwapperCore", [mocV1, docToken, mocSwapperCoreV1], {
    id: "SetMocSwapperCore",
  });

  // ─── 8. Configure swapper exchange (already deployed externally) ─────────────
  m.call(lendingManager, "setMocSwapperExchange", [mocV1, docToken, mocSwapperExchange], {
    id: "SetMocSwapperExchange",
  });

  // ─── 9. Configure fee flow ───────────────────────────────────────────────────
  m.call(lendingManager, "setMocFeeFlow", [mocV1, docToken, mocFeeFlow], {
    id: "SetMocFeeFlow",
  });

  // ─── 10a. Deploy PriceProviderInverse ────────────────────────────────────────
  // Wraps the DOC/RBTC price provider to obtain the RBTC/DOC price required by
  // MocReverseAuction (inverse = 1e36 / docToRbtcPrice).
  const reverseAuctionPriceProvider = m.contract("PriceProviderInverse", [docToRbtcPriceProvider], {
    id: "ReverseAuctionPriceProvider",
  });

  // ─── 10b. Deploy MocReverseAuction ───────────────────────────────────────────
  // Accumulates COINBASE (address(0)), swaps it to DOC via mocSwapperCoreV1,
  // and sends the result to the TPInjector.
  // This contract will be bufferOutput0 in the BufferCoinbase.
  const reverseAuction = m.contract(
    "MocReverseAuction",
    [
      governor,
      mocSwapperCoreV1,
      "0x0000000000000000000000000000000000000000", // tokenIn = COINBASE
      docToken, // tokenOut = DOC
      tpInjectorProxy, // outputAccount = TPInjector
      reverseAuctionOrderThreshold,
      reverseAuctionPriceProvider,
      reverseAuctionSlippage,
    ],
    { id: "MocReverseAuction" },
  );

  // ─── 11. Deploy BufferCoinbase via TransparentUpgradeableProxy ───────────────
  // The BufferCoinbase (from @moc/flow) uses an initializer pattern.
  // We deploy the implementation first, then wrap it in a TransparentUpgradeableProxy.
  // bufferOutput0 = reverseAuction (deployed above), bufferOutput1 = external param
  const bufferCoinbaseImpl = m.contract("BufferCoinbase", [], {
    id: "BufferCoinbaseImplementation",
  });

  const bufferCoinbaseInitData = m.encodeFunctionCall(bufferCoinbaseImpl, "initialize", [
    governor,
    bufferThreshold,
    [reverseAuction, bufferOutput1, bufferOutput2],
    [bufferSplit0, bufferSplit1, bufferSplit2],
    [bufferOutputThreshold0, bufferOutputThreshold1, bufferOutputThreshold2],
  ]);

  // TransparentUpgradeableProxy(logic, admin, data)
  const bufferCoinbaseProxy = m.contract(
    "TransparentUpgradeableProxy",
    [bufferCoinbaseImpl, bufferProxyAdmin, bufferCoinbaseInitData],
    { id: "BufferCoinbaseProxy" },
  );

  // ─── 12a. Deploy DataProvider for WRBTC→DOC max amount ───────────────────────
  // owner = pauser, initial value = wrbtcToDocMaxAmount (placeholder "0")
  const wrbtcToDocProvider = m.contract("DataProvider", [pauser, wrbtcToDocMaxAmount], {
    id: "WrbtcToDocDataProvider",
  });

  // ─── 12b. Deploy DataProvider for DOC→WRBTC max amount ───────────────────────
  // owner = pauser, initial value = docToWrbtcMaxAmount (placeholder "0")
  const docToWrbtcProvider = m.contract("DataProvider", [pauser, docToWrbtcMaxAmount], {
    id: "DocToWrbtcDataProvider",
  });

  // ─── 13. Deploy MocV1LendingAndBorrowing changer ─────────────────────────────
  // This changer:
  //   a) Sets the new BitPro rate and points the BitPro interest address
  //      to the newly deployed BufferCoinbase proxy on MoCInrate V1.
  //   b) Configures the WRBTC→USDT→DOC (and reverse) swap paths on
  //      mocSwapperExchange (a MocSwapperV3MultiHop).
  const changer = m.contract(
    "MocV1LendingAndBorrowing",
    [
      mocInrateV1,
      newBitProRate,
      bufferCoinbaseProxy,
      mocSwapperExchange,
      wrbtcToken,
      usdtToken,
      docToken,
      wrbtcToDocProvider,
      docToWrbtcProvider,
      wrbtcUsdtFee,
      usdtDocFee,
    ],
    { id: "MocV1LendingAndBorrowingChanger" },
  );

  return {
    mocAdapterV1,
    mocSwapperCoreV1,
    lendingManagerImpl,
    lendingManagerProxy,
    lendingManager,
    lendingReader,
    tpInjectorImpl,
    tpInjectorProxy,
    tpInjector,
    reverseAuction,
    bufferCoinbaseImpl,
    bufferCoinbaseProxy,
    wrbtcToDocProvider,
    docToWrbtcProvider,
    changer,
  };
});
