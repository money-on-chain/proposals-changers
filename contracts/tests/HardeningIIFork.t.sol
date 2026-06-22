// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { HardeningII, IUpgradeDelegator } from "../changers/hardeningII/HardeningII.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";
import { MocMultiCollateralGuard } from "@moc/main/contracts/multiCollateral/MocMultiCollateralGuard.sol";
import { MocQueue } from "@moc/main/contracts/queue/MocQueue.sol";
import { MocQueueExecFees } from "@moc/main/contracts/queue/MocQueueExecFees.sol";
import { MocCARC20 } from "@moc/main/contracts/collateral/rc20/MocCARC20.sol";

interface IGoverned {
  function governor() external view returns (address);
}

interface IOwnableLike {
  function owner() external view returns (address);
}

interface IMoCBasicOps {
  function connector() external view returns (address);
  function mintBPro(uint256 btcToMint) external payable;
  function redeemBPro(uint256 bproAmount) external;
  function mintDoc(uint256 btcToMint) external payable;
  function redeemFreeDoc(uint256 docAmount) external;
}

interface IMoCConnectorProbe {
  function bproToken() external view returns (address);
  function docToken() external view returns (address);
  function mocState() external view returns (address);
  function mocInrate() external view returns (address);
}

interface IMoCStateProbe {
  function bproTecPrice() external view returns (uint256);
  function btcToDoc(uint256 btcAmount) external view returns (uint256);
  function docsToBtc(uint256 docAmount) external view returns (uint256);
  function rbtcInSystem() external view returns (uint256);
}

interface IMoCInrateProbe {
  function MINT_BPRO_FEES_RBTC() external view returns (uint8);
  function MINT_DOC_FEES_RBTC() external view returns (uint8);
  function REDEEM_BPRO_FEES_RBTC() external view returns (uint8);
  function REDEEM_DOC_FEES_RBTC() external view returns (uint8);
  function calcCommissionValue(uint256 rbtcAmount, uint8 txType) external view returns (uint256);
}

interface IMoCStorageProbe {
  function connector() external view returns (address);
  function getBitProRate() external view returns (uint256);
  function getMocPrecision() external view returns (uint256);
  function getReservePrecision() external view returns (uint256);
  function getBitProInterestAddress() external view returns (address payable);
  function getBitProInterestBlockSpan() external view returns (uint256);
  function isDailyEnabled() external view returns (bool);
  function isBitProInterestEnabled() external view returns (bool);
  function isSettlementEnabled() external view returns (bool);
}

interface IMoCExchangeStorageProbe {
  function connector() external view returns (address);
  function getMocPrecision() external view returns (uint256);
  function getReservePrecision() external view returns (uint256);
  function getDayPrecision() external view returns (uint256);
}

interface IMoCBProxManagerStorageProbe {
  function getBucketNBTC(bytes32 bucket) external view returns (uint256);
  function getBucketNBPro(bytes32 bucket) external view returns (uint256);
  function getBucketNDoc(bytes32 bucket) external view returns (uint256);
  function getBucketCobj(bytes32 bucket) external view returns (uint256);
  function getActiveAddressesCount(bytes32 bucket) external view returns (uint256);
}

interface IERC20Like {
  function balanceOf(address account) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transfer(address to, uint256 amount) external returns (bool);
}

interface IERC20Whale {
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
}

contract HardeningIIForkTest is Test {
  // ZOS (OpenZeppelin v2) implementation slot — used by MoC V1 proxies
  bytes32 internal constant ZOS_IMPLEMENTATION_SLOT =
    0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;

  // ERC1967 implementation slot — used by MoC V2 bucket proxies (rif/doc)
  bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  uint256 internal constant FORK_BLOCK = 8962309;

  // Path to the mainnet parameters JSON
  string internal constant MAINNET_PARAMS_PATH =
    "./ignition/modules/HardeningII/parameters/rskMainnet.json";

  // Addresses loaded from JSON
  address internal mocV1Proxy;
  address internal mocStateV1Proxy;
  address internal mocExchangeV1Proxy;
  address internal mocInrateV1Proxy;
  address internal mocBProxManagerV1Proxy;
  address internal rifBucketProxy;
  address internal docBucketProxy;
  address internal upgradeDelegatorMoc;

  // New implementations (freshly deployed in test)
  address internal newMocV1Implementation;
  address internal newMocStateV1Implementation;
  address internal newMocExchangeV1Implementation;
  address internal newMocInrateV1Implementation;
  address internal newMocBProxManagerV1Implementation;
  address internal newRifBucketImplementation;
  address internal newDocBucketImplementation;

  HardeningII internal changer;

  receive() external payable {}

  function setUp() public {
    string memory defaultRpcUrl = "https://public-node.rsk.co";
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", defaultRpcUrl);
    vm.createSelectFork(rpcUrl, FORK_BLOCK);

    // Read addresses from the parameters JSON
    _readParamsFromJson();

    // Deploy new implementations
    newMocV1Implementation = _deployFromArtifact(
      "contracts/compat/DeployableMoC.sol:DeployableMoC"
    );
    newMocStateV1Implementation = _deployFromArtifact(
      "contracts/compat/DeployableMoCState.sol:DeployableMoCState"
    );
    newMocExchangeV1Implementation = _deployFromArtifact(
      "contracts/compat/DeployableMoCExchange.sol:DeployableMoCExchange"
    );
    newMocInrateV1Implementation = _deployFromArtifact(
      "contracts/compat/DeployableMoCInrate.sol:DeployableMoCInrate"
    );
    newMocBProxManagerV1Implementation = _deployFromArtifact(
      "contracts/compat/DeployableMoCBProxManager.sol:DeployableMoCBProxManager"
    );
    newRifBucketImplementation = _deployFromArtifact(
      "contracts/compat/DeployableMocCARC20.sol:DeployableMocCARC20"
    );
    newDocBucketImplementation = _deployFromArtifact(
      "contracts/compat/DeployableMocCARC20.sol:DeployableMocCARC20"
    );

    // Deploy the changer
    changer = new HardeningII(
      mocV1Proxy,
      mocStateV1Proxy,
      mocExchangeV1Proxy,
      mocInrateV1Proxy,
      mocBProxManagerV1Proxy,
      rifBucketProxy,
      docBucketProxy,
      IUpgradeDelegator(upgradeDelegatorMoc),
      newMocV1Implementation,
      newMocStateV1Implementation,
      newMocExchangeV1Implementation,
      newMocInrateV1Implementation,
      newMocBProxManagerV1Implementation,
      newRifBucketImplementation,
      newDocBucketImplementation
    );
  }

  // ── Tests ──────────────────────────────────────────────────────────────────

  function testFork_DeployAndExecuteChanger() public {
    _executeChanger();
    // If no revert occurred, the changer executed successfully
  }

  function testFork_ImplementationSlotsUpdated_AfterExecute() public {
    // V1 proxies use the ZOS slot; V2 bucket proxies use ERC1967
    address mocV1ImplBefore = _getZosImplementation(mocV1Proxy);
    address mocStateImplBefore = _getZosImplementation(mocStateV1Proxy);
    address mocExchangeImplBefore = _getZosImplementation(mocExchangeV1Proxy);
    address mocInrateImplBefore = _getZosImplementation(mocInrateV1Proxy);
    address mocBProxManagerImplBefore = _getZosImplementation(mocBProxManagerV1Proxy);
    address rifBucketImplBefore = _getErc1967Implementation(rifBucketProxy);
    address docBucketImplBefore = _getErc1967Implementation(docBucketProxy);

    _executeChanger();

    address mocV1ImplAfter = _getZosImplementation(mocV1Proxy);
    address mocStateImplAfter = _getZosImplementation(mocStateV1Proxy);
    address mocExchangeImplAfter = _getZosImplementation(mocExchangeV1Proxy);
    address mocInrateImplAfter = _getZosImplementation(mocInrateV1Proxy);
    address mocBProxManagerImplAfter = _getZosImplementation(mocBProxManagerV1Proxy);
    address rifBucketImplAfter = _getErc1967Implementation(rifBucketProxy);
    address docBucketImplAfter = _getErc1967Implementation(docBucketProxy);

    require(
      mocV1ImplAfter == newMocV1Implementation,
      "mocV1 implementation not updated"
    );
    require(mocV1ImplAfter != mocV1ImplBefore, "mocV1 implementation did not change");

    require(
      mocStateImplAfter == newMocStateV1Implementation,
      "mocState implementation not updated"
    );
    require(mocStateImplAfter != mocStateImplBefore, "mocState implementation did not change");

    require(
      mocExchangeImplAfter == newMocExchangeV1Implementation,
      "mocExchange implementation not updated"
    );
    require(
      mocExchangeImplAfter != mocExchangeImplBefore,
      "mocExchange implementation did not change"
    );

    require(
      mocInrateImplAfter == newMocInrateV1Implementation,
      "mocInrate implementation not updated"
    );
    require(mocInrateImplAfter != mocInrateImplBefore, "mocInrate implementation did not change");

    require(
      mocBProxManagerImplAfter == newMocBProxManagerV1Implementation,
      "mocBProxManager implementation not updated"
    );
    require(
      mocBProxManagerImplAfter != mocBProxManagerImplBefore,
      "mocBProxManager implementation did not change"
    );

    require(
      rifBucketImplAfter == newRifBucketImplementation,
      "rifBucket implementation not updated"
    );
    require(rifBucketImplAfter != rifBucketImplBefore, "rifBucket implementation did not change");

    require(
      docBucketImplAfter == newDocBucketImplementation,
      "docBucket implementation not updated"
    );
    require(docBucketImplAfter != docBucketImplBefore, "docBucket implementation did not change");
  }

  function testFork_StorageLayout_NoCollisionOnCriticalPointers() public {
    // Only the contracts that HardeningII upgrades are verified:
    // MoC, MoCState, MoCExchange, MoCInrate, MoCBProxManager + V2 buckets.
    // MoCSettlement is NOT upgraded in this proposal.
    address mocGovernorBefore = IGoverned(mocV1Proxy).governor();
    address mocConnectorBefore = IMoCStorageProbe(mocV1Proxy).connector();
    address mocExchangeConnectorBefore = IMoCExchangeStorageProbe(mocExchangeV1Proxy).connector();
    uint256 mocBitProRateBefore = IMoCStorageProbe(mocV1Proxy).getBitProRate();
    uint256 mocPrecisionBefore = IMoCStorageProbe(mocV1Proxy).getMocPrecision();
    uint256 mocReservePrecisionBefore = IMoCStorageProbe(mocV1Proxy).getReservePrecision();
    address mocBitProInterestAddressBefore = IMoCStorageProbe(mocV1Proxy)
      .getBitProInterestAddress();
    uint256 mocBitProInterestBlockSpanBefore = IMoCStorageProbe(mocV1Proxy)
      .getBitProInterestBlockSpan();
    bool mocDailyEnabledBefore = IMoCStorageProbe(mocV1Proxy).isDailyEnabled();
    bool mocBitProInterestEnabledBefore = IMoCStorageProbe(mocV1Proxy).isBitProInterestEnabled();
    bool mocSettlementEnabledBeforeFromMoC = IMoCStorageProbe(mocV1Proxy).isSettlementEnabled();
    uint256 mocExchangePrecisionBefore = IMoCExchangeStorageProbe(mocExchangeV1Proxy)
      .getMocPrecision();
    uint256 mocExchangeReservePrecisionBefore = IMoCExchangeStorageProbe(mocExchangeV1Proxy)
      .getReservePrecision();
    uint256 mocExchangeDayPrecisionBefore = IMoCExchangeStorageProbe(mocExchangeV1Proxy)
      .getDayPrecision();
    bytes32 BUCKET_C0 = "C0";
    bytes32 BUCKET_X2 = "X2";
    uint256 mocBProxNBTCC0Before = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketNBTC(BUCKET_C0);
    uint256 mocBProxNBProC0Before = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketNBPro(BUCKET_C0);
    uint256 mocBProxNDocC0Before = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketNDoc(BUCKET_C0);
    uint256 mocBProxCobjC0Before = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketCobj(BUCKET_C0);
    uint256 mocBProxActiveC0Before = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getActiveAddressesCount(BUCKET_C0);
    uint256 mocBProxCobjX2Before = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketCobj(BUCKET_X2);

    require(mocGovernorBefore != address(0), "MoC governor is zero");

    _executeChanger();

    address mocGovernorAfter = IGoverned(mocV1Proxy).governor();
    address mocConnectorAfter = IMoCStorageProbe(mocV1Proxy).connector();
    address mocExchangeConnectorAfter = IMoCExchangeStorageProbe(mocExchangeV1Proxy).connector();
    uint256 mocBitProRateAfter = IMoCStorageProbe(mocV1Proxy).getBitProRate();
    uint256 mocPrecisionAfter = IMoCStorageProbe(mocV1Proxy).getMocPrecision();
    uint256 mocReservePrecisionAfter = IMoCStorageProbe(mocV1Proxy).getReservePrecision();
    address mocBitProInterestAddressAfter = IMoCStorageProbe(mocV1Proxy).getBitProInterestAddress();
    uint256 mocBitProInterestBlockSpanAfter = IMoCStorageProbe(mocV1Proxy)
      .getBitProInterestBlockSpan();
    bool mocDailyEnabledAfter = IMoCStorageProbe(mocV1Proxy).isDailyEnabled();
    bool mocBitProInterestEnabledAfter = IMoCStorageProbe(mocV1Proxy).isBitProInterestEnabled();
    bool mocSettlementEnabledAfterFromMoC = IMoCStorageProbe(mocV1Proxy).isSettlementEnabled();
    uint256 mocExchangePrecisionAfter = IMoCExchangeStorageProbe(mocExchangeV1Proxy)
      .getMocPrecision();
    uint256 mocExchangeReservePrecisionAfter = IMoCExchangeStorageProbe(mocExchangeV1Proxy)
      .getReservePrecision();
    uint256 mocExchangeDayPrecisionAfter = IMoCExchangeStorageProbe(mocExchangeV1Proxy)
      .getDayPrecision();
    uint256 mocBProxNBTCC0After = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketNBTC(BUCKET_C0);
    uint256 mocBProxNBProC0After = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketNBPro(BUCKET_C0);
    uint256 mocBProxNDocC0After = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketNDoc(BUCKET_C0);
    uint256 mocBProxCobjC0After = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketCobj(BUCKET_C0);
    uint256 mocBProxActiveC0After = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getActiveAddressesCount(BUCKET_C0);
    uint256 mocBProxCobjX2After = IMoCBProxManagerStorageProbe(mocBProxManagerV1Proxy)
      .getBucketCobj(BUCKET_X2);

    require(mocGovernorAfter == mocGovernorBefore, "MoC governor changed");
    require(mocConnectorAfter == mocConnectorBefore, "MoC connector changed");
    require(
      mocExchangeConnectorAfter == mocExchangeConnectorBefore,
      "MoCExchange connector changed"
    );
    require(mocBitProRateAfter == mocBitProRateBefore, "MoC bitProRate changed");
    require(mocPrecisionAfter == mocPrecisionBefore, "MoC precision changed");
    require(mocReservePrecisionAfter == mocReservePrecisionBefore, "MoC reserve precision changed");
    require(
      mocBitProInterestAddressAfter == mocBitProInterestAddressBefore,
      "MoC bitPro interest address changed"
    );
    require(
      mocBitProInterestBlockSpanAfter == mocBitProInterestBlockSpanBefore,
      "MoC bitPro interest block span changed"
    );
    require(mocDailyEnabledAfter == mocDailyEnabledBefore, "MoC daily enabled changed");
    require(
      mocBitProInterestEnabledAfter == mocBitProInterestEnabledBefore,
      "MoC bitPro interest enabled changed"
    );
    require(
      mocSettlementEnabledAfterFromMoC == mocSettlementEnabledBeforeFromMoC,
      "MoC settlement enabled (read from MoC) changed"
    );
    require(
      mocExchangePrecisionAfter == mocExchangePrecisionBefore,
      "MoCExchange precision changed"
    );
    require(
      mocExchangeReservePrecisionAfter == mocExchangeReservePrecisionBefore,
      "MoCExchange reserve precision changed"
    );
    require(
      mocExchangeDayPrecisionAfter == mocExchangeDayPrecisionBefore,
      "MoCExchange day precision changed"
    );
    require(
      mocBProxNBTCC0After == mocBProxNBTCC0Before,
      "MoCBProxManager C0 NBTC changed"
    );
    require(
      mocBProxNBProC0After == mocBProxNBProC0Before,
      "MoCBProxManager C0 NBPro changed"
    );
    require(
      mocBProxNDocC0After == mocBProxNDocC0Before,
      "MoCBProxManager C0 NDoc changed"
    );
    require(
      mocBProxCobjC0After == mocBProxCobjC0Before,
      "MoCBProxManager C0 cobj changed"
    );
    require(
      mocBProxActiveC0After == mocBProxActiveC0Before,
      "MoCBProxManager C0 active addresses count changed"
    );
    require(
      mocBProxCobjX2After == mocBProxCobjX2Before,
      "MoCBProxManager X2 cobj changed"
    );
  }

  function testFork_MoCBasicOps_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());
    IMoCInrateProbe mocInrate = IMoCInrateProbe(connector.mocInrate());

    IERC20Like bproToken = IERC20Like(connector.bproToken());
    IERC20Like docToken = IERC20Like(connector.docToken());

    uint256 mintBProBtc = 0.01 ether;
    uint256 mintDocBtc = 0.01 ether;
    uint256 mintBProValue = 0.011 ether;
    uint256 mintDocValue = 0.011 ether;
    vm.deal(address(this), 1 ether);

    // --- mintBPro ---
    uint256 bproBefore = bproToken.balanceOf(address(this));
    uint256 bproTecPrice = mocState.bproTecPrice();
    uint256 mocPrecision = IMoCStorageProbe(mocV1Proxy).getMocPrecision();
    uint256 expectedBproMinted = (mintBProBtc * mocPrecision) / bproTecPrice;
    uint256 bproMintCommission = mocInrate.calcCommissionValue(
      mintBProBtc,
      mocInrate.MINT_BPRO_FEES_RBTC()
    );
    uint256 expectedRbtcSpentOnMintBpro = mintBProBtc + bproMintCommission;
    uint256 rbtcBeforeMintBpro = address(this).balance;
    moc.mintBPro{ value: mintBProValue }(mintBProBtc);
    uint256 rbtcAfterMintBpro = address(this).balance;
    uint256 bproAfterMint = bproToken.balanceOf(address(this));
    require(bproAfterMint - bproBefore == expectedBproMinted, "mintBPro unexpected BPro amount");
    require(
      rbtcBeforeMintBpro - rbtcAfterMintBpro == expectedRbtcSpentOnMintBpro,
      "mintBPro unexpected RBTC spent"
    );

    // --- redeemBPro ---
    uint256 bproToRedeem = (bproAfterMint - bproBefore) / 2;
    require(bproToRedeem > 0, "BPro redeem amount is zero");
    uint256 bproTecPriceRedeem = mocState.bproTecPrice();
    uint256 expectedGrossRbtcFromBproRedeem = (bproToRedeem * bproTecPriceRedeem) / mocPrecision;
    uint256 bproRedeemCommission = mocInrate.calcCommissionValue(
      expectedGrossRbtcFromBproRedeem,
      mocInrate.REDEEM_BPRO_FEES_RBTC()
    );
    uint256 expectedRbtcFromBproRedeem = expectedGrossRbtcFromBproRedeem - bproRedeemCommission;
    uint256 rbtcBeforeRedeemBpro = address(this).balance;
    moc.redeemBPro(bproToRedeem);
    uint256 rbtcAfterRedeemBpro = address(this).balance;
    uint256 bproAfterRedeem = bproToken.balanceOf(address(this));
    require(
      bproAfterMint - bproAfterRedeem == bproToRedeem,
      "redeemBPro unexpected BPro burned amount"
    );
    require(
      rbtcAfterRedeemBpro - rbtcBeforeRedeemBpro == expectedRbtcFromBproRedeem,
      "redeemBPro unexpected RBTC received"
    );

    // --- mintDoc ---
    uint256 docBefore = docToken.balanceOf(address(this));
    uint256 expectedDocMinted = mocState.btcToDoc(mintDocBtc);
    uint256 docMintCommission = mocInrate.calcCommissionValue(
      mintDocBtc,
      mocInrate.MINT_DOC_FEES_RBTC()
    );
    uint256 expectedRbtcSpentOnMintDoc = mintDocBtc + docMintCommission;
    uint256 rbtcBeforeMintDoc = address(this).balance;
    moc.mintDoc{ value: mintDocValue }(mintDocBtc);
    uint256 rbtcAfterMintDoc = address(this).balance;
    uint256 docAfterMint = docToken.balanceOf(address(this));
    require(docAfterMint - docBefore == expectedDocMinted, "mintDoc unexpected Doc amount");
    require(
      rbtcBeforeMintDoc - rbtcAfterMintDoc == expectedRbtcSpentOnMintDoc,
      "mintDoc unexpected RBTC spent"
    );

    // --- redeemFreeDoc ---
    uint256 docToRedeem = (docAfterMint - docBefore) / 2;
    require(docToRedeem > 0, "Doc redeem amount is zero");
    uint256 expectedGrossRbtcFromDocRedeem = mocState.docsToBtc(docToRedeem);
    uint256 expectedPreFeeRbtcFromDocRedeem = expectedGrossRbtcFromDocRedeem;
    uint256 docRedeemCommission = mocInrate.calcCommissionValue(
      expectedPreFeeRbtcFromDocRedeem,
      mocInrate.REDEEM_DOC_FEES_RBTC()
    );
    uint256 expectedRbtcFromDocRedeem = expectedPreFeeRbtcFromDocRedeem - docRedeemCommission;
    uint256 rbtcBeforeRedeemDoc = address(this).balance;
    moc.redeemFreeDoc(docToRedeem);
    uint256 rbtcAfterRedeemDoc = address(this).balance;
    uint256 docAfterRedeem = docToken.balanceOf(address(this));
    require(
      docAfterMint - docAfterRedeem == docToRedeem,
      "redeemFreeDoc unexpected Doc burned amount"
    );
    require(
      rbtcAfterRedeemDoc - rbtcBeforeRedeemDoc == expectedRbtcFromDocRedeem,
      "redeemFreeDoc unexpected RBTC received"
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  function _executeChanger() internal {
    address governor = IGoverned(rifBucketProxy).governor();
    address governorOwner = IOwnableLike(governor).owner();
    vm.prank(governorOwner);
    IGovernor(governor).executeChange(IChangeContract(address(changer)));
  }

  function _getZosImplementation(address proxy) internal view returns (address impl) {
    bytes32 raw = vm.load(proxy, ZOS_IMPLEMENTATION_SLOT);
    impl = address(uint160(uint256(raw)));
  }

  function _getErc1967Implementation(address proxy) internal view returns (address impl) {
    bytes32 raw = vm.load(proxy, ERC1967_IMPLEMENTATION_SLOT);
    impl = address(uint160(uint256(raw)));
  }

  function _deployFromArtifact(string memory artifactPath) internal returns (address deployed) {
    bytes memory bytecode = vm.getCode(artifactPath);
    require(
      bytecode.length != 0,
      string(abi.encodePacked("artifact bytecode is empty: ", artifactPath))
    );
    assembly ("memory-safe") {
      deployed := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    require(
      deployed != address(0),
      string(abi.encodePacked("deployment failed: ", artifactPath))
    );
  }

  function _readParamsFromJson() internal {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);

    mocV1Proxy = vm.parseJsonAddress(json, ".HardeningIIModule.mocV1Proxy");
    mocStateV1Proxy = vm.parseJsonAddress(json, ".HardeningIIModule.mocStateV1Proxy");
    mocExchangeV1Proxy = vm.parseJsonAddress(json, ".HardeningIIModule.mocExchangeV1Proxy");
    mocInrateV1Proxy = vm.parseJsonAddress(json, ".HardeningIIModule.mocInrateV1Proxy");
    mocBProxManagerV1Proxy = vm.parseJsonAddress(json, ".HardeningIIModule.mocBProxManagerV1Proxy");
    rifBucketProxy = vm.parseJsonAddress(json, ".HardeningIIModule.rifBucketProxy");
    docBucketProxy = vm.parseJsonAddress(json, ".HardeningIIModule.docBucketProxy");
    upgradeDelegatorMoc = vm.parseJsonAddress(json, ".HardeningIIModule.upgradeDelegatorMoc");

    require(mocV1Proxy != address(0), "mocV1Proxy is zero");
    require(mocStateV1Proxy != address(0), "mocStateV1Proxy is zero");
    require(mocExchangeV1Proxy != address(0), "mocExchangeV1Proxy is zero");
    require(mocInrateV1Proxy != address(0), "mocInrateV1Proxy is zero");
    require(mocBProxManagerV1Proxy != address(0), "mocBProxManagerV1Proxy is zero");
    require(rifBucketProxy != address(0), "rifBucketProxy is zero");
    require(docBucketProxy != address(0), "docBucketProxy is zero");
    require(upgradeDelegatorMoc != address(0), "upgradeDelegatorMoc is zero");
  }

  function testFork_MoCState_BproTecPriceAndRbtcInSystem_UnchangedAfterUpgrade() public {
    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());

    uint256 bproTecPriceBefore = mocState.bproTecPrice();
    uint256 rbtcInSystemBefore = mocState.rbtcInSystem();

    require(bproTecPriceBefore > 0, "bproTecPrice is zero before upgrade");
    require(rbtcInSystemBefore > 0, "rbtcInSystem is zero before upgrade");

    _executeChanger();

    uint256 bproTecPriceAfter = mocState.bproTecPrice();
    uint256 rbtcInSystemAfter = mocState.rbtcInSystem();

    assertEq(bproTecPriceAfter, bproTecPriceBefore, "bproTecPrice changed after upgrade");
    assertEq(rbtcInSystemAfter, rbtcInSystemBefore, "rbtcInSystem changed after upgrade");
  }

  function testFork_RifBucket_RedeemTP_InvalidAddress_Reverts() public {
    _executeChanger();

    MocCARC20 rif = MocCARC20(rifBucketProxy);
    address fakeTP = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
    uint256 execFee = _execFee(MocQueueExecFees.OperType.redeemTP);
    vm.deal(address(this), execFee);

    vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
    rif.redeemTP{ value: execFee }(fakeTP, 1 ether, 0, address(this), address(0));
  }

  function testFork_DocBucket_RedeemTP_InvalidAddress_Reverts() public {
    _executeChanger();

    MocCARC20 doc = MocCARC20(docBucketProxy);
    address fakeTP = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
    uint256 execFee = MocQueueExecFees(doc.mocQueue()).getExecFee(
      MocQueueExecFees.OperType.redeemTP
    );
    vm.deal(address(this), execFee);

    vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
    doc.redeemTP{ value: execFee }(fakeTP, 1 ether, 0, address(this), address(0));
  }

  function testFork_RifBucket_MintAndRedeemTP_AfterUpgrade() public {
    _executeChanger();

    MocCARC20 rif = MocCARC20(rifBucketProxy);
    address acToken = address(rif.acToken());
    address tpToken = address(rif.tpTokens(0));

    // Known RIF whale on RSK mainnet (MoC reserve / treasury)
    address knownRifHolder = 0xe4822F07C1d988A8f2F53D1817f7e8848897b67A;
    uint256 rifBalance = IERC20Whale(acToken).balanceOf(knownRifHolder);
    uint256 rifAmount = 100 ether; // 100 RIF

    require(rifBalance >= rifAmount, "RIF whale has insufficient balance");

    vm.prank(knownRifHolder);
    IERC20Whale(acToken).transfer(address(this), rifAmount);

    uint256 execFee = _execFee(MocQueueExecFees.OperType.mintTP);
    vm.deal(address(this), execFee * 10);

    // Approve rif bucket to spend RIF
    IERC20Like(acToken).approve(rifBucketProxy, rifAmount);

    uint256 tpBefore = IERC20Like(tpToken).balanceOf(address(this));
    uint256 rifBefore = IERC20Like(acToken).balanceOf(address(this));

    // Enqueue mintTP
    uint256 qTP = 1 ether; // 1 TP token
    uint256 qACmax = rifAmount;
    rif.mintTP{ value: execFee }(tpToken, qTP, qACmax, address(this), address(0));

    _mineUntilQueueCanExecute();
    _executeRifQueue();

    uint256 tpAfterMint = IERC20Like(tpToken).balanceOf(address(this));
    require(tpAfterMint > tpBefore, "mintTP: no TP minted after queue execution");

    // Enqueue redeemTP
    uint256 tpToRedeem = tpAfterMint - tpBefore;
    uint256 execFeeRedeem = _execFee(MocQueueExecFees.OperType.redeemTP);
    IERC20Like(tpToken).approve(rifBucketProxy, tpToRedeem);
    rif.redeemTP{ value: execFeeRedeem }(tpToken, tpToRedeem, 0, address(this), address(0));

    _mineUntilQueueCanExecute();
    _executeRifQueue();

    uint256 tpAfterRedeem = IERC20Like(tpToken).balanceOf(address(this));
    uint256 rifAfterRedeem = IERC20Like(acToken).balanceOf(address(this));
    require(tpAfterRedeem < tpAfterMint, "redeemTP: TP not burned after queue execution");
    require(rifAfterRedeem > rifBefore - qACmax, "redeemTP: no RIF received after queue execution");
  }

  function _execFee(MocQueueExecFees.OperType operType_) internal view returns (uint256) {
        return MocQueueExecFees(MocCARC20(rifBucketProxy).mocQueue()).getExecFee(operType_);
    }

    function _mocMultiCollateralGuard() internal view returns (MocMultiCollateralGuard) {
        return MocMultiCollateralGuard(payable(MocQueueExecFees(MocCARC20(rifBucketProxy).mocQueue()).mocMultiCollateralGuard()));
    }

    function _mineUntilQueueCanExecute() internal {
        uint256 minOperWaitingBlk = MocQueue(payable(MocCARC20(rifBucketProxy).mocQueue())).minOperWaitingBlk();
        vm.roll(block.number + minOperWaitingBlk + 1);
    }

    function _executeRifQueue() internal {
        _mocMultiCollateralGuard().execute();
    }
}
