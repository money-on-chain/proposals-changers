import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("LendingAndBorrowingV1Module", (m) => {
  // ─── Shared addresses ───────────────────────────────────────────────────────
  const governor = m.getParameter("governor");
  const pauser = m.getParameter("pauser");
  const tasksRunner = m.getParameter("tasksRunner");

  // MoC V1 contract addresses
  const mocV1 = m.getParameter("mocV1"); // MoC V1 proxy (the bucket)
  const mocStateV1 = m.getParameter("mocStateV1"); // MoCState V1 proxy
  const mocInrateV1 = m.getParameter("mocInrateV1"); // MoCInrate V1 proxy

  // ─── BufferCoinbase parameters ───────────────────────────────────────────────
  const bufferProxyAdmin = m.getParameter("bufferProxyAdmin");
  const bufferThreshold = m.getParameter("bufferThreshold", "0");
  // bufferOutput0 is the TPInjector deployed below
  const bufferOutput1 = m.getParameter("bufferOutput1");
  const bufferOutput2 = m.getParameter("bufferOutput2");
  const bufferSplit0 = m.getParameter("bufferSplit0", "0");
  const bufferSplit1 = m.getParameter("bufferSplit1", "0");
  const bufferSplit2 = m.getParameter("bufferSplit2", "0");
  const bufferOutputThreshold0 = m.getParameter("bufferOutputThreshold0", "0");
  const bufferOutputThreshold1 = m.getParameter("bufferOutputThreshold1", "0");
  const bufferOutputThreshold2 = m.getParameter("bufferOutputThreshold2", "0");

  // ─── Lending fee-flow BufferToken parameters ───────────────────────────────
  const mocFeeFlowProxyAdmin = m.getParameter("mocFeeFlowProxyAdmin");
  const mocFeeFlowThreshold = m.getParameter("mocFeeFlowThreshold", "0");
  const mocFeeFlowMimLabs = m.getParameter("mocFeeFlowMimLabs");
  const docToMocReverseAuction = m.getParameter("docToMocReverseAuction");
  const mocFeeFlowSplitDocToRbtc = m.getParameter("mocFeeFlowSplitDocToRbtc");
  const mocFeeFlowSplitMimLabs = m.getParameter("mocFeeFlowSplitMimLabs");
  const mocFeeFlowSplitDocToMoc = m.getParameter("mocFeeFlowSplitDocToMoc");
  const mocFeeFlowSplitDocToMocLiquidation = m.getParameter("mocFeeFlowSplitDocToMocLiquidation");
  const mocFeeFlowOutputThresholdDocToRbtc = m.getParameter(
    "mocFeeFlowOutputThresholdDocToRbtc",
    "0",
  );
  const mocFeeFlowOutputThresholdMimLabs = m.getParameter("mocFeeFlowOutputThresholdMimLabs", "0");
  const mocFeeFlowOutputThresholdDocToMoc = m.getParameter(
    "mocFeeFlowOutputThresholdDocToMoc",
    "0",
  );
  const mocFeeFlowOutputThresholdDocToMocLiquidation = m.getParameter(
    "mocFeeFlowOutputThresholdDocToMocLiquidation",
    "0",
  );

  // ─── MocReverseAuction parameters ────────────────────────────────────────────
  // tokenIn = COINBASE (address(0)), tokenOut = docToken, outputAccount = tpInjectorProxy
  // docToRbtcPriceProvider: already-deployed DOC/RBTC price provider (e.g. PriceProviderDocRbtc)
  // The module wraps it in PriceProviderInverse to obtain the RBTC/DOC price needed by the auction.
  const docToRbtcPriceProvider = m.getParameter("docToRbtcPriceProvider");
  const docToRbtcReverseAuctionOrderThreshold = m.getParameter(
    "docToRbtcReverseAuctionOrderThreshold",
    "0",
  );
  const docToRbtcReverseAuctionSlippage = m.getParameter("docToRbtcReverseAuctionSlippage", "0");
  const docToMocLiquidationPriceProvider = m.getParameter("docToMocLiquidationPriceProvider");
  const docToMocLiquidationReverseAuctionOrderThreshold = m.getParameter(
    "docToMocLiquidationReverseAuctionOrderThreshold",
    "0",
  );
  const docToMocLiquidationReverseAuctionSlippage = m.getParameter(
    "docToMocLiquidationReverseAuctionSlippage",
    "0",
  );
  const rbtcToMocLiquidationReverseAuctionOrderThreshold = m.getParameter(
    "rbtcToMocLiquidationReverseAuctionOrderThreshold",
    "0",
  );
  const rbtcToMocLiquidationReverseAuctionSlippage = m.getParameter(
    "rbtcToMocLiquidationReverseAuctionSlippage",
    "0",
  );
  const reverseAuctionTaskRevertSleepTime = m.getParameter(
    "reverseAuctionTaskRevertSleepTime",
    3600,
  );

  // ─── MocV1LendingAndBorrowing changer parameter ──────────────────────────────
  const newBitProRate = m.getParameter("newBitProRate", "0");

  // DOC token (TP token used in this deployment)
  const docToken = m.getParameter("docToken");

  // ─── LendingManager parameters ──────────────────────────────────────────────
  const maxSlippage = m.getParameter("maxSlippage", "30000000000000000"); // 3%
  const liquidationPaymentAC = m.getParameter("liquidationPaymentAC");

  // ─── LiquidationEngine parameters ──────────────────────────
  const liquidationEngineProxyAdmin = m.getParameter("liquidationEngineProxyAdmin");
  const liquidationEngineName = m.getParameter(
    "liquidationEngineName",
    "0x4c454e44494e4700000000000000000000000000000000000000000000000000", // LENDING
  );
  const mocToken = m.getParameter("mocToken");
  const oracleManager = m.getParameter("oracleManager");
  const oracleRegistry = m.getParameter("oracleRegistry");
  const tokenToCoinbasePriceProvider = m.getParameter("tokenToCoinbasePriceProvider");
  const baseFeeProvider = m.getParameter("baseFeeProvider");
  const maxOraclesPerRound = m.getParameter("liquidationMaxOraclesPerRound", 5);
  const maxSubscribedOraclesPerRound = m.getParameter(
    "liquidationMaxSubscribedOraclesPerRound",
    10,
  );
  const roundLockPeriod = m.getParameter("liquidationRoundLockPeriod", 60);
  const maxMissedSigRounds = m.getParameter("liquidationMaxMissedSigRounds", 0);
  const minOraclesPerRound = m.getParameter("liquidationMinOraclesPerRound", 1);
  const sharesCapMultiplier = m.getParameter(
    "liquidationSharesCapMultiplier",
    "1500000000000000000", // 1.5
  );
  const maxLiquidationsPerBatch = m.getParameter("maxLiquidationsPerBatch", 10);

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
  const mocSwapperExchangeMultiHop = m.getParameter(
    "mocSwapperExchangeMultiHop",
    "0x0000000000000000000000000000000000000000",
  );
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

  // ─── 0. Deploy InterimGovernor ───────────────────────────────────────────────
  // Used as the governor during deployment so that the deployer (owner) can call
  // onlyAuthorizedChanger functions directly (initializePool, setMocSwapperCore, etc.).
  // At the end, governance is transferred to the real governor via changeGovernor().
  const interimGovernor = m.contract("InterimGovernor", [], {
    id: "InterimGovernor",
  });

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
    interimGovernor,
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
  // Use interimGovernor so the deployer can call onlyAuthorizedChanger during setup.
  const tpInjectorInitData = m.encodeFunctionCall(tpInjectorImpl, "initialize", [
    interimGovernor,
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
  const initializeDocPool = m.call(
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

  // ─── 6b. Deploy and initialize the LiquidationEngine ───────────────
  const liquidationEngineImpl = m.contract(
    "@moc/oracles/contracts/LiquidationEngine.sol:LiquidationEngine",
    [],
    { id: "LiquidationEngineImplementation" },
  );

  const liquidationRoundConfig = [
    maxOraclesPerRound,
    maxSubscribedOraclesPerRound,
    roundLockPeriod,
    maxMissedSigRounds,
  ];
  const liquidationEngineParams = [
    tokenToCoinbasePriceProvider,
    baseFeeProvider,
    sharesCapMultiplier,
    maxLiquidationsPerBatch,
  ];
  const liquidationEngineInitData = m.encodeFunctionCall(liquidationEngineImpl, "initialize", [
    governor,
    liquidationEngineName,
    lendingManagerProxy,
    [[docToken, mocV1]],
    mocToken,
    liquidationRoundConfig,
    oracleManager,
    oracleRegistry,
    minOraclesPerRound,
    liquidationEngineParams,
  ]);

  const liquidationEngineProxy = m.contract(
    "TransparentUpgradeableProxy",
    [liquidationEngineImpl, liquidationEngineProxyAdmin, liquidationEngineInitData],
    { id: "LiquidationEngineProxy", after: [initializeDocPool] },
  );

  const liquidationEngine = m.contractAt(
    "@moc/oracles/contracts/LiquidationEngine.sol:LiquidationEngine",
    liquidationEngineProxy,
    { id: "LiquidationEngineProxyInstance" },
  );

  // ─── 7. Configure swapper core (MoC V1 bucket, DOC token) ───────────────────
  // Must run after initializePool so the pool mapping entry exists.
  const setMocSwapperCore = m.call(
    lendingManager,
    "setMocSwapperCore",
    [mocV1, docToken, mocSwapperCoreV1],
    { id: "SetMocSwapperCore", after: [initializeDocPool] },
  );

  // ─── 8. Configure swapper exchange (already deployed externally) ─────────────
  // Must run after initializePool so the pool mapping entry exists.
  const setMocSwapperExchangeMultiHop = m.call(
    lendingManager,
    "setMocSwapperExchange",
    [mocV1, docToken, mocSwapperExchangeMultiHop],
    { id: "SetMocSwapperExchangeMultiHop", after: [initializeDocPool] },
  );

  // ─── 9a. Deploy the DOC→RBTC reverse auction used by lending fee flow ────────
  const docToRbtcReverseAuction = m.contract(
    "MocReverseAuction",
    [
      governor,
      mocSwapperCoreV1,
      docToken,
      "0x0000000000000000000000000000000000000000", // tokenOut = RBTC
      mocV1,
      docToRbtcReverseAuctionOrderThreshold,
      docToRbtcPriceProvider,
      docToRbtcReverseAuctionSlippage,
    ],
    { id: "DocToRbtcReverseAuction" },
  );

  // ─── 9b. Deploy auctions that fund LiquidationEngine with MOC ──────────────
  const rbtcToMocLiquidationPriceProvider = m.contract(
    "PriceProviderInverse",
    [tokenToCoinbasePriceProvider],
    { id: "RbtcToMocLiquidationPriceProvider" },
  );

  const rbtcToMocLiquidationReverseAuction = m.contract(
    "MocReverseAuction",
    [
      governor,
      mocSwapperExchange,
      "0x0000000000000000000000000000000000000000", // tokenIn = RBTC
      mocToken,
      liquidationEngineProxy,
      rbtcToMocLiquidationReverseAuctionOrderThreshold,
      rbtcToMocLiquidationPriceProvider,
      rbtcToMocLiquidationReverseAuctionSlippage,
    ],
    { id: "RbtcToMocLiquidationReverseAuction" },
  );

  const docToMocLiquidationReverseAuction = m.contract(
    "MocReverseAuction",
    [
      governor,
      mocSwapperExchangeMultiHop,
      docToken,
      mocToken,
      liquidationEngineProxy,
      docToMocLiquidationReverseAuctionOrderThreshold,
      docToMocLiquidationPriceProvider,
      docToMocLiquidationReverseAuctionSlippage,
    ],
    { id: "DocToMocLiquidationReverseAuction" },
  );

  // ─── 9c. Deploy the lending fee-flow BufferToken ───────────────────────────
  const mocFeeFlowImpl = m.contract("BufferToken", [], {
    id: "MocFeeFlowImplementation",
  });

  const mocFeeFlowInitData = m.encodeFunctionCall(mocFeeFlowImpl, "initialize", [
    governor,
    docToken,
    mocFeeFlowThreshold,
    [
      docToRbtcReverseAuction,
      mocFeeFlowMimLabs,
      docToMocReverseAuction,
      docToMocLiquidationReverseAuction,
    ],
    [
      mocFeeFlowSplitDocToRbtc,
      mocFeeFlowSplitMimLabs,
      mocFeeFlowSplitDocToMoc,
      mocFeeFlowSplitDocToMocLiquidation,
    ],
    [
      mocFeeFlowOutputThresholdDocToRbtc,
      mocFeeFlowOutputThresholdMimLabs,
      mocFeeFlowOutputThresholdDocToMoc,
      mocFeeFlowOutputThresholdDocToMocLiquidation,
    ],
  ]);

  const mocFeeFlowProxy = m.contract(
    "TransparentUpgradeableProxy",
    [mocFeeFlowImpl, mocFeeFlowProxyAdmin, mocFeeFlowInitData],
    { id: "MocFeeFlowProxy" },
  );

  const mocFeeFlow = m.contractAt("BufferToken", mocFeeFlowProxy, {
    id: "MocFeeFlowProxyInstance",
  });

  // ─── 9d. Configure fee flow and liquidation payment routing ────────────────
  // Must run after initializePool so the pool mapping entry exists.
  const setMocFeeFlow = m.call(
    lendingManager,
    "setMocFeeFlow",
    [mocV1, docToken, mocFeeFlowProxy],
    {
      id: "SetMocFeeFlow",
      after: [initializeDocPool],
    },
  );

  const setLiquidationEngine = m.call(
    lendingManager,
    "setLiquidationEngine",
    [mocV1, docToken, rbtcToMocLiquidationReverseAuction],
    { id: "SetLiquidationEngine", after: [initializeDocPool] },
  );

  const setLiquidationPaymentAC = m.call(
    lendingManager,
    "setLiquidationPaymentAC",
    [mocV1, docToken, liquidationPaymentAC],
    { id: "SetLiquidationPaymentAC", after: [initializeDocPool] },
  );

  // ─── 9e. Transfer governance to the real governor ───────────────────────────
  // Now that all pool configuration is done, hand over governance of both
  // MocLendingManager and TPInjector from InterimGovernor to the real governor.
  m.call(lendingManager, "changeGovernor", [governor], {
    id: "TransferLendingManagerGovernance",
    after: [
      setMocSwapperCore,
      setMocSwapperExchangeMultiHop,
      setMocFeeFlow,
      setLiquidationEngine,
      setLiquidationPaymentAC,
    ],
  });

  m.call(tpInjector, "changeGovernor", [governor], {
    id: "TransferTpInjectorGovernance",
    after: [setMocSwapperCore, setMocSwapperExchangeMultiHop, setMocFeeFlow],
  });

  // ─── 10. Deploy BufferCoinbase via TransparentUpgradeableProxy ──────────────
  // The BufferCoinbase (from @moc/flow) uses an initializer pattern.
  // We deploy the implementation first, then wrap it in a TransparentUpgradeableProxy.
  // bufferOutput0 = TPInjector, bufferOutput1 and bufferOutput2 = external params
  const bufferCoinbaseImpl = m.contract("BufferCoinbase", [], {
    id: "BufferCoinbaseImplementation",
  });

  const bufferCoinbaseInitData = m.encodeFunctionCall(bufferCoinbaseImpl, "initialize", [
    governor,
    bufferThreshold,
    [tpInjectorProxy, bufferOutput1, bufferOutput2],
    [bufferSplit0, bufferSplit1, bufferSplit2],
    [bufferOutputThreshold0, bufferOutputThreshold1, bufferOutputThreshold2],
  ]);

  // TransparentUpgradeableProxy(logic, admin, data)
  const bufferCoinbaseProxy = m.contract(
    "TransparentUpgradeableProxy",
    [bufferCoinbaseImpl, bufferProxyAdmin, bufferCoinbaseInitData],
    { id: "BufferCoinbaseProxy" },
  );

  const bufferFlushTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/buffer/TaskFlush.sol:TaskFlush",
    [bufferCoinbaseProxy],
    { id: "TaskFlushBitProInterestBuffer" },
  );

  const bufferLiquidateTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/buffer/TaskLiquidate.sol:TaskLiquidate",
    [bufferCoinbaseProxy],
    { id: "TaskLiquidateBitProInterestBuffer" },
  );

  const tpInjectionTask = m.contract(
    "@moc/oracles/contracts/tasks/lending/TaskTPInjection.sol:TaskTPInjection",
    [lendingManagerProxy, docToken],
    { id: "TaskTPInjection" },
  );

  const mocFeeFlowFlushTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/buffer/TaskFlush.sol:TaskFlush",
    [mocFeeFlowProxy],
    { id: "TaskFlushMocFeeFlow" },
  );

  const mocFeeFlowLiquidateTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/buffer/TaskLiquidate.sol:TaskLiquidate",
    [mocFeeFlowProxy],
    { id: "TaskLiquidateMocFeeFlow" },
  );

  const docToRbtcReverseAuctionTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol:TaskTriggerOrder",
    [docToRbtcReverseAuction, reverseAuctionTaskRevertSleepTime, pauser],
    { id: "TaskTriggerOrderDocToRbtc" },
  );

  const docToMocLiquidationReverseAuctionTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol:TaskTriggerOrder",
    [docToMocLiquidationReverseAuction, reverseAuctionTaskRevertSleepTime, pauser],
    { id: "TaskTriggerOrderDocToMocLiquidation" },
  );

  const rbtcToMocLiquidationReverseAuctionTask = m.contract(
    "@moc/oracles/contracts/tasks/mocFlow/reverseAuction/TaskTriggerOrder.sol:TaskTriggerOrder",
    [rbtcToMocLiquidationReverseAuction, reverseAuctionTaskRevertSleepTime, pauser],
    { id: "TaskTriggerOrderRbtcToMocLiquidation" },
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
  //   c) Registers the LiquidationEngine proxy in OracleManager under its
  //      bytes32 service name so oracle operators can subscribe to it.
  //   d) Registers the buffer, TP injection, and reverse-auction tasks in TasksRunner.
  const changer = m.contract(
    "MocV1LendingAndBorrowing",
    [
      mocInrateV1,
      newBitProRate,
      bufferCoinbaseProxy,
      [
        tasksRunner,
        bufferFlushTask,
        bufferLiquidateTask,
        tpInjectionTask,
        mocFeeFlowFlushTask,
        mocFeeFlowLiquidateTask,
        docToRbtcReverseAuctionTask,
        docToMocLiquidationReverseAuctionTask,
        rbtcToMocLiquidationReverseAuctionTask,
      ],
      [oracleManager, liquidationEngineName, liquidationEngineProxy],
      mocSwapperExchangeMultiHop,
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
    interimGovernor,
    mocAdapterV1,
    mocSwapperCoreV1,
    lendingManagerImpl,
    lendingManagerProxy,
    lendingManager,
    lendingReader,
    liquidationEngineImpl,
    liquidationEngineProxy,
    liquidationEngine,
    tpInjectorImpl,
    tpInjectorProxy,
    tpInjector,
    docToRbtcReverseAuction,
    docToMocLiquidationReverseAuction,
    rbtcToMocLiquidationReverseAuction,
    rbtcToMocLiquidationPriceProvider,
    mocFeeFlowImpl,
    mocFeeFlowProxy,
    mocFeeFlow,
    bufferCoinbaseImpl,
    bufferCoinbaseProxy,
    bufferFlushTask,
    bufferLiquidateTask,
    tpInjectionTask,
    mocFeeFlowFlushTask,
    mocFeeFlowLiquidateTask,
    docToRbtcReverseAuctionTask,
    docToMocLiquidationReverseAuctionTask,
    rbtcToMocLiquidationReverseAuctionTask,
    wrbtcToDocProvider,
    docToWrbtcProvider,
    changer,
  };
});
