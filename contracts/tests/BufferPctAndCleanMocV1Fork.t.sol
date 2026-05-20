// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BufferPctAndCleanMocV1, IUpgradeDelegator } from "../changers/bufferPct_cleanMocV1/BufferPctAndCleanMocV1.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";
import { OracleTestHelper, IOracleCheats } from "./helpers/OracleTestHelper.sol";
import { FCMaxAbsoluteOpProvider } from "@moc/roc/contracts/providers/FCMaxAbsoluteOpProvider.sol";
import { FCMaxOpDifferenceProvider } from "@moc/roc/contracts/providers/FCMaxOpDifferenceProvider.sol";

interface Vm {
  struct Log {
    bytes32[] topics;
    bytes data;
    address emitter;
  }

  function createSelectFork(
    string calldata urlOrAlias,
    uint256 blockNumber
  ) external returns (uint256);
  function prank(address msgSender) external;
  function load(address target, bytes32 slot) external view returns (bytes32 data);
  function envOr(
    string calldata name,
    string calldata defaultValue
  ) external returns (string memory value);
  function envOr(string calldata name, address defaultValue) external returns (address value);
  function getCode(string calldata artifactPath) external returns (bytes memory bytecode);
  function readFile(string calldata path) external view returns (string memory);
  function parseJsonAddress(
    string calldata json,
    string calldata key
  ) external pure returns (address);
  function recordLogs() external;
  function getRecordedLogs() external returns (Log[] memory);
  function deal(address account, uint256 newBalance) external;
  function roll(uint256 newHeight) external;
  function mockCall(address callee, bytes calldata data, bytes calldata returnData) external;
  function addr(uint256 privateKey) external returns (address keyAddr);
  function sign(
    uint256 privateKey,
    bytes32 digest
  ) external returns (uint8 v, bytes32 r, bytes32 s);
  function expectRevert() external;
  function expectRevert(bytes calldata) external;
  function txGasPrice(uint256 newGasPrice) external;
}

interface IOwnableLike {
  function owner() external view returns (address);
}

interface IGoverned {
  function governor() external view returns (address);
}

interface IBufferTokenLike {
  function getNumOutputs() external view returns (uint256);
  function getOutput(uint256 idx) external view returns (address, uint256, uint256, uint256);
}

interface IOracleManagerProbe {
  function getOracleOwner(address oracleAddr) external view returns (address);
  function getOracleAddress(address ownerAddr) external view returns (address oracleAddr);
  function getStakingContract() external view returns (address);
  function getRegisteredOraclesLen() external view returns (uint256);
  function getRegisteredOracleAtIndex(
    uint256 idx
  ) external view returns (address ownerAddr, address oracleAddr, string memory url);
}

interface IStakingProbe {
  function setOracleAddress(address oracleAddr) external;
}

interface ICoinPairPriceProbe {
  function getCoinPair() external view returns (bytes32);
  function getPriceInfo() external view returns (uint256 price, bool isValid, uint256 lastPubBlock);
  function getRoundInfo()
    external
    view
    returns (
      uint256 round,
      uint256 startBlock,
      uint256 lockPeriodTimestamp,
      uint256 totalPoints,
      address[] memory selectedOwners,
      address[] memory selectedOracles
    );
  function publishPrice(
    uint256 version,
    bytes32 coinpair,
    uint256 price,
    address votedOracle,
    uint256 blockNumber,
    uint8[] calldata sigV,
    bytes32[] calldata sigR,
    bytes32[] calldata sigS
  ) external;
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

interface IMoCSettlementStorageProbe {
  function connector() external view returns (address);
  function getBlockSpan() external view returns (uint256);
  function nextSettlementBlock() external view returns (uint256);
  function isSettlementEnabled() external view returns (bool);
}

interface IMoCBasicOps {
  function connector() external view returns (address);
  function mintBPro(uint256 btcToMint) external payable;
  function mintBProVendors(uint256 btcToMint, address payable vendorAccount) external payable;
  function redeemBPro(uint256 bproAmount) external;
  function mintDoc(uint256 btcToMint) external payable;
  function mintDocVendors(uint256 btcToMint, address payable vendorAccount) external payable;
  function redeemFreeDoc(uint256 docAmount) external;
  function runSettlement(uint256 steps) external;
}

interface IMoCConnectorProbe {
  function bproToken() external view returns (address);
  function docToken() external view returns (address);
  function mocState() external view returns (address);
  function mocInrate() external view returns (address);
  function mocExchange() external view returns (address);
  function mocSettlement() external view returns (address);
}

interface IMoCStateProbe {
  function state() external view returns (uint8);
  function bproTecPrice() external view returns (uint256);
  function btcToDoc(uint256 btcAmount) external view returns (uint256);
  function docsToBtc(uint256 docAmount) external view returns (uint256);
  function getBitcoinPrice() external view returns (uint256);
  function getMoCPrice() external view returns (uint256);
  function getMoCVendors() external view returns (address);
  function globalCoverage() external view returns (uint256);
  function cobj() external view returns (uint256);
  function getProtected() external view returns (uint256);
  function liq() external view returns (uint256);
  function getLiquidationEnabled() external view returns (bool);
  function setLiquidationEnabled(bool liquidationEnabled_) external;
  function nextState() external;
}

interface IMoCInrateProbe {
  function MINT_BPRO_FEES_RBTC() external view returns (uint8);
  function MINT_DOC_FEES_RBTC() external view returns (uint8);
  function REDEEM_BPRO_FEES_RBTC() external view returns (uint8);
  function REDEEM_DOC_FEES_RBTC() external view returns (uint8);
  function calcCommissionValue(uint256 rbtcAmount, uint8 txType) external view returns (uint256);
  function calcDocRedInterestValues(
    uint256 docAmount,
    uint256 rbtcAmount
  ) external view returns (uint256);
}

interface IERC20Like {
  function balanceOf(address account) external view returns (uint256);
}

interface IMoCVendorsProbe {
  function updatePaidMarkup(
    address account,
    uint256 mocAmount,
    uint256 rbtcAmount
  ) external returns (bool);
}

interface IRifBucketProbe {
  function maxAbsoluteOpProvider() external view returns (address);
  function maxOpDiffProvider() external view returns (address);
}

interface IDataProviderProbe {
  function peek() external view returns (bytes32, bool);
}

contract ReentrantMoCAttacker {
  IMoCBasicOps internal moc;
  IERC20Like internal bproToken;
  IERC20Like internal docToken;
  bool internal reenterOnReceive;
  bool internal reenterDoc;
  uint8 internal reenterAction;
  bool internal lastReenterCallOk;
  bytes internal lastReenterCallData;

  constructor(address moc_, address bproToken_, address docToken_) {
    moc = IMoCBasicOps(moc_);
    bproToken = IERC20Like(bproToken_);
    docToken = IERC20Like(docToken_);
  }

  receive() external payable {
    if (reenterOnReceive) {
      bytes memory payload;
      uint256 valueToSend = 0;
      if (reenterAction == 1 || reenterDoc) {
        payload = abi.encodeWithSelector(IMoCBasicOps.redeemFreeDoc.selector, uint256(1));
      } else if (reenterAction == 2) {
        payload = abi.encodeWithSelector(IMoCBasicOps.redeemBPro.selector, uint256(1));
      } else if (reenterAction == 3) {
        payload = abi.encodeWithSelector(IMoCBasicOps.mintBPro.selector, uint256(1));
        valueToSend = 1;
      } else if (reenterAction == 4) {
        payload = abi.encodeWithSelector(IMoCBasicOps.mintDoc.selector, uint256(1));
        valueToSend = 1;
      } else {
        return;
      }
      (lastReenterCallOk, lastReenterCallData) = address(moc).call{ value: valueToSend }(payload);
    }
  }

  function attackRedeemBPro(uint256 mintBtcAmount) external payable {
    lastReenterCallOk = true;
    delete lastReenterCallData;
    moc.mintBPro{ value: msg.value }(mintBtcAmount);
    uint256 bproBalance = bproToken.balanceOf(address(this));
    require(bproBalance > 0, "attacker has no BPro");
    reenterOnReceive = true;
    reenterDoc = false;
    reenterAction = 2;
    moc.redeemBPro(bproBalance);
    reenterOnReceive = false;
  }

  function attackRedeemFreeDoc(uint256 mintBtcAmount) external payable {
    lastReenterCallOk = true;
    delete lastReenterCallData;
    moc.mintDoc{ value: msg.value }(mintBtcAmount);
    uint256 docBalance = docToken.balanceOf(address(this));
    require(docBalance > 0, "attacker has no Doc");
    reenterOnReceive = true;
    reenterDoc = true;
    reenterAction = 1;
    moc.redeemFreeDoc(docBalance);
    reenterOnReceive = false;
  }

  function attackMintBProAsVendor(uint256 mintBtcAmount) external payable {
    lastReenterCallOk = true;
    delete lastReenterCallData;
    reenterOnReceive = true;
    reenterDoc = false;
    reenterAction = 3;
    moc.mintBProVendors{ value: msg.value }(mintBtcAmount, payable(address(this)));
    reenterOnReceive = false;
  }

  function attackMintDocAsVendor(uint256 mintBtcAmount) external payable {
    lastReenterCallOk = true;
    delete lastReenterCallData;
    reenterOnReceive = true;
    reenterDoc = false;
    reenterAction = 4;
    moc.mintDocVendors{ value: msg.value }(mintBtcAmount, payable(address(this)));
    reenterOnReceive = false;
  }

  function getLastReenterResult() external view returns (bool ok, bytes memory data) {
    return (lastReenterCallOk, lastReenterCallData);
  }
}

contract LiquidationEnabledTestChanger is IChangeContract {
  IMoCStateProbe internal immutable mocState;
  bool internal immutable liquidationEnabled;

  constructor(address mocState_, bool liquidationEnabled_) {
    mocState = IMoCStateProbe(mocState_);
    liquidationEnabled = liquidationEnabled_;
  }

  function execute() external override {
    mocState.setLiquidationEnabled(liquidationEnabled);
  }
}

contract BufferPctAndCleanMocV1ForkTest is OracleTestHelper {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  uint256 internal constant FORK_BLOCK = 8837400;
  string internal constant MAINNET_PARAMS_PATH =
    "./ignition/modules/BufferPctAndCleanMocV1/parameters/rskMainnet.json";

  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant ZOS_IMPLEMENTATION_SLOT =
    0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;
  bytes32 internal constant UPGRADED_TOPIC = keccak256("Upgraded(address)");
  bytes32 internal constant DATA_UPDATED_TOPIC = keccak256("DataUpdated(uint256)");
  uint256 internal constant PUBLISH_MESSAGE_VERSION = 3;

  address internal coinPairProxy;
  address internal oracleManagerProxy;
  address internal mocRewardsBufferProxy;
  address internal mocV1Proxy;
  address internal mocStateV1Proxy;
  address internal mocExchangeV1Proxy;
  address internal mocSettlementV1Proxy;
  address internal rifBucketProxy;
  address internal upgradeDelegatorOracle;
  address internal upgradeDelegatorMoc;

  address internal newCoinPairImpl;
  address internal newOracleManagerImpl;
  address internal newMocImpl;
  address internal newMocStateImpl;
  address internal newMocExchangeImpl;
  address internal newMocSettlementImpl;

  receive() external payable {}

  function setUp() public {
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", "https://public-node.rsk.co");
    vm.createSelectFork(rpcUrl, FORK_BLOCK);

    (
      coinPairProxy,
      oracleManagerProxy,
      mocRewardsBufferProxy,
      mocV1Proxy,
      rifBucketProxy,
      upgradeDelegatorOracle,
      upgradeDelegatorMoc
    ) = _readMainnetParamsFromJson();
    IMoCConnectorProbe connector = IMoCConnectorProbe(IMoCBasicOps(mocV1Proxy).connector());
    mocStateV1Proxy = connector.mocState();
    mocExchangeV1Proxy = connector.mocExchange();
    mocSettlementV1Proxy = connector.mocSettlement();

    newCoinPairImpl = _deployFromArtifact(
      "contracts/compat/DeployableCoinPairPrice.sol:DeployableCoinPairPrice"
    );
    newOracleManagerImpl = _deployFromArtifact(
      "contracts/compat/DeployableOracleManager.sol:DeployableOracleManager"
    );
    newMocImpl = _deployFromArtifact("contracts/compat/DeployableMoC.sol:DeployableMoC");
    newMocStateImpl = _deployFromArtifact("contracts/compat/DeployableMoCState.sol:DeployableMoCState");
    newMocExchangeImpl = _deployFromArtifact(
      "contracts/compat/DeployableMoCExchange.sol:DeployableMoCExchange"
    );
    newMocSettlementImpl = _deployFromArtifact(
      "contracts/compat/DeployableMoCSettlement.sol:DeployableMoCSettlement"
    );
  }

  function testFork_StorageLayout_NoCollisionOnCriticalPointers() public {
    address coinPairGovernorBefore = IGoverned(coinPairProxy).governor();
    address mocGovernorBefore = IGoverned(mocV1Proxy).governor();
    address mocSettlementGovernorBefore = IGoverned(mocSettlementV1Proxy).governor();
    address mocConnectorBefore = IMoCStorageProbe(mocV1Proxy).connector();
    address mocExchangeConnectorBefore = IMoCExchangeStorageProbe(mocExchangeV1Proxy).connector();
    address mocSettlementConnectorBefore = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .connector();
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
    uint256 mocSettlementBlockSpanBefore = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .getBlockSpan();
    uint256 mocSettlementNextBlockBefore = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .nextSettlementBlock();
    bool mocSettlementEnabledBefore = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .isSettlementEnabled();

    require(coinPairGovernorBefore != address(0), "coinPair governor is zero");
    require(mocGovernorBefore != address(0), "MoC governor is zero");
    require(mocSettlementGovernorBefore != address(0), "MoCSettlement governor is zero");

    _executeChanger();

    address coinPairGovernorAfter = IGoverned(coinPairProxy).governor();
    address mocGovernorAfter = IGoverned(mocV1Proxy).governor();
    address mocSettlementGovernorAfter = IGoverned(mocSettlementV1Proxy).governor();
    address mocConnectorAfter = IMoCStorageProbe(mocV1Proxy).connector();
    address mocExchangeConnectorAfter = IMoCExchangeStorageProbe(mocExchangeV1Proxy).connector();
    address mocSettlementConnectorAfter = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .connector();
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
    uint256 mocSettlementBlockSpanAfter = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .getBlockSpan();
    uint256 mocSettlementNextBlockAfter = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .nextSettlementBlock();
    bool mocSettlementEnabledAfter = IMoCSettlementStorageProbe(mocSettlementV1Proxy)
      .isSettlementEnabled();

    require(coinPairGovernorAfter == coinPairGovernorBefore, "coinPair governor changed");
    require(mocGovernorAfter == mocGovernorBefore, "MoC governor changed");
    require(
      mocSettlementGovernorAfter == mocSettlementGovernorBefore,
      "MoCSettlement governor changed"
    );
    require(mocConnectorAfter == mocConnectorBefore, "MoC connector changed");
    require(
      mocExchangeConnectorAfter == mocExchangeConnectorBefore,
      "MoCExchange connector changed"
    );
    require(
      mocSettlementConnectorAfter == mocSettlementConnectorBefore,
      "MoCSettlement connector changed"
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
      "MoC settlement enabled changed"
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
      mocSettlementBlockSpanAfter == mocSettlementBlockSpanBefore,
      "MoCSettlement blockSpan changed"
    );
    require(
      mocSettlementNextBlockAfter == mocSettlementNextBlockBefore,
      "MoCSettlement next block changed"
    );
    require(
      mocSettlementEnabledAfter == mocSettlementEnabledBefore,
      "MoCSettlement enabled changed"
    );
  }

  function testFork_DeployAndExecuteChanger() public {
    address coinPairImplBefore = _loadAddress(
      IOracleCheats(address(vm)),
      coinPairProxy,
      IMPLEMENTATION_SLOT
    );
    address oracleManagerImplBefore = _loadAddress(
      IOracleCheats(address(vm)),
      oracleManagerProxy,
      IMPLEMENTATION_SLOT
    );
    address mocImplBefore = _loadAddress(
      IOracleCheats(address(vm)),
      mocV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );
    address mocStateImplBefore = _loadAddress(
      IOracleCheats(address(vm)),
      mocStateV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );
    address mocExchangeImplBefore = _loadAddress(
      IOracleCheats(address(vm)),
      mocExchangeV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );
    address mocSettlementImplBefore = _loadAddress(
      IOracleCheats(address(vm)),
      mocSettlementV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );

    vm.recordLogs();
    _executeChanger();
    Vm.Log[] memory logs = vm.getRecordedLogs();

    bool coinPairUpgradedEvent = _hasUpgradedEvent(logs, coinPairProxy);
    bool oracleManagerUpgradedEvent = _hasUpgradedEvent(logs, oracleManagerProxy);
    bool mocUpgradedEvent = _hasUpgradedEvent(logs, mocV1Proxy);
    bool mocStateUpgradedEvent = _hasUpgradedEvent(logs, mocStateV1Proxy);
    bool mocExchangeUpgradedEvent = _hasUpgradedEvent(logs, mocExchangeV1Proxy);
    bool mocSettlementUpgradedEvent = _hasUpgradedEvent(logs, mocSettlementV1Proxy);

    require(coinPairUpgradedEvent, "Upgraded event missing for coinPairProxy");
    require(oracleManagerUpgradedEvent, "Upgraded event missing for oracleManagerProxy");
    require(mocUpgradedEvent, "Upgraded event missing for mocV1Proxy");
    require(mocStateUpgradedEvent, "Upgraded event missing for mocStateV1Proxy");
    require(mocExchangeUpgradedEvent, "Upgraded event missing for mocExchangeV1Proxy");
    require(mocSettlementUpgradedEvent, "Upgraded event missing for mocSettlementV1Proxy");

    address coinPairImplAfter = _loadAddress(
      IOracleCheats(address(vm)),
      coinPairProxy,
      IMPLEMENTATION_SLOT
    );
    address oracleManagerImplAfter = _loadAddress(
      IOracleCheats(address(vm)),
      oracleManagerProxy,
      IMPLEMENTATION_SLOT
    );
    address mocImplAfter = _loadAddress(
      IOracleCheats(address(vm)),
      mocV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );
    address mocStateImplAfter = _loadAddress(
      IOracleCheats(address(vm)),
      mocStateV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );
    address mocExchangeImplAfter = _loadAddress(
      IOracleCheats(address(vm)),
      mocExchangeV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );
    address mocSettlementImplAfter = _loadAddress(
      IOracleCheats(address(vm)),
      mocSettlementV1Proxy,
      ZOS_IMPLEMENTATION_SLOT
    );
    require(coinPairImplAfter == newCoinPairImpl, "coinPair implementation mismatch");
    require(
      oracleManagerImplAfter == newOracleManagerImpl,
      "oracleManager implementation mismatch"
    );
    require(mocImplAfter == newMocImpl, "MoC implementation mismatch");
    require(mocStateImplAfter == newMocStateImpl, "MoCState implementation mismatch");
    require(mocExchangeImplAfter == newMocExchangeImpl, "MoCExchange implementation mismatch");
    require(
      mocSettlementImplAfter == newMocSettlementImpl,
      "MoCSettlement implementation mismatch"
    );

    require(coinPairImplAfter != coinPairImplBefore, "coinPair implementation did not change");
    require(
      oracleManagerImplAfter != oracleManagerImplBefore,
      "oracleManager implementation did not change"
    );
    require(mocImplAfter != mocImplBefore, "MoC implementation did not change");
    require(
      mocStateImplAfter != mocStateImplBefore,
      "MoCState implementation did not change"
    );
    require(
      mocExchangeImplAfter != mocExchangeImplBefore,
      "MoCExchange implementation did not change"
    );
    require(
      mocSettlementImplAfter != mocSettlementImplBefore,
      "MoCSettlement implementation did not change"
    );
  }

  function testFork_BufferSplits_AfterUpgrade() public {
    IBufferTokenLike buffer = IBufferTokenLike(mocRewardsBufferProxy);
    require(buffer.getNumOutputs() == 2, "Buffer must have exactly 2 outputs");

    (address output0Before, uint256 split0Before, , ) = buffer.getOutput(0);
    (address output1Before, uint256 split1Before, , ) = buffer.getOutput(1);

    _executeChanger();

    (address output0After, uint256 split0After, , ) = buffer.getOutput(0);
    (address output1After, uint256 split1After, , ) = buffer.getOutput(1);

    require(output0After == output0Before, "output 0 address changed");
    require(output1After == output1Before, "output 1 address changed");
    require(split0After == 70, "output 0 split must be 70");
    require(split1After == 30, "output 1 split must be 30");
    require(split0Before != split0After || split1Before != split1After, "buffer splits unchanged");
  }

  function testFork_CleansDeprecatedOracles_AfterUpgrade() public {
    address deprecatedOracle0 = 0x4b5E791b0Ef89E954d1212dB598cBd9d3787AAFE;
    address deprecatedOracle1 = 0xe4822F07C1d988A8f2F53D1817f7e8848897b67A;

    IOracleManagerProbe oracleManager = IOracleManagerProbe(oracleManagerProxy);

    address owner0Before = oracleManager.getOracleOwner(deprecatedOracle0);
    address owner1Before = oracleManager.getOracleOwner(deprecatedOracle1);
    require(owner0Before != address(0), "deprecated oracle 0 already clean");
    require(owner1Before != address(0), "deprecated oracle 1 already clean");

    uint256 registeredLen = oracleManager.getRegisteredOraclesLen();
    address[] memory oracleAddressesBefore = new address[](registeredLen);
    address[] memory ownersBefore = new address[](registeredLen);
    for (uint256 i = 0; i < registeredLen; i++) {
      (address ownerAddr, address oracleAddr, ) = oracleManager.getRegisteredOracleAtIndex(i);
      oracleAddressesBefore[i] = oracleAddr;
      ownersBefore[i] = ownerAddr;
    }

    _executeChanger();

    address owner0After = oracleManager.getOracleOwner(deprecatedOracle0);
    address owner1After = oracleManager.getOracleOwner(deprecatedOracle1);
    require(owner0After == address(0), "deprecated oracle 0 not cleared");
    require(owner1After == address(0), "deprecated oracle 1 not cleared");

    for (uint256 i = 0; i < registeredLen; i++) {
      address oracleAddr = oracleAddressesBefore[i];
      address ownerAddr = ownersBefore[i];
      address ownerAfter = oracleManager.getOracleOwner(oracleAddr);
      require(ownerAfter == ownersBefore[i], "non-deprecated oracle owner changed");
      address oracleAddressAfter = oracleManager.getOracleAddress(ownerAddr);
      require(oracleAddressAfter == oracleAddr, "non-deprecated owner oracle changed");
    }
  }

  function testFork_RifBucketProviders_AfterUpgrade_PreservesOwnerAndData() public {
    IRifBucketProbe rifBucket = IRifBucketProbe(rifBucketProxy);

    address maxAbsoluteProviderBefore = rifBucket.maxAbsoluteOpProvider();
    address maxOpDiffProviderBefore = rifBucket.maxOpDiffProvider();

    address ownerAbsBefore = IOwnableLike(maxAbsoluteProviderBefore).owner();
    address ownerDiffBefore = IOwnableLike(maxOpDiffProviderBefore).owner();
    (bytes32 dataAbsBefore, ) = IDataProviderProbe(maxAbsoluteProviderBefore).peek();
    (bytes32 dataDiffBefore, ) = IDataProviderProbe(maxOpDiffProviderBefore).peek();

    _executeChanger();

    address maxAbsoluteProviderAfter = rifBucket.maxAbsoluteOpProvider();
    address maxOpDiffProviderAfter = rifBucket.maxOpDiffProvider();
    require(
      maxAbsoluteProviderAfter != maxAbsoluteProviderBefore,
      "maxAbsolute provider address did not change"
    );
    require(
      maxOpDiffProviderAfter != maxOpDiffProviderBefore,
      "maxOpDiff provider address did not change"
    );

    address ownerAbsAfter = IOwnableLike(maxAbsoluteProviderAfter).owner();
    address ownerDiffAfter = IOwnableLike(maxOpDiffProviderAfter).owner();
    (bytes32 dataAbsAfter, bool validAbsAfter) = IDataProviderProbe(maxAbsoluteProviderAfter)
      .peek();
    (bytes32 dataDiffAfter, bool validDiffAfter) = IDataProviderProbe(maxOpDiffProviderAfter)
      .peek();

    require(validAbsAfter, "maxAbsolute provider after invalid");
    require(validDiffAfter, "maxOpDiff provider after invalid");
    require(ownerAbsAfter == ownerAbsBefore, "maxAbsolute provider owner mismatch");
    require(ownerDiffAfter == ownerDiffBefore, "maxOpDiff provider owner mismatch");
    require(dataAbsAfter == dataAbsBefore, "maxAbsolute provider data mismatch");
    require(dataDiffAfter == dataDiffBefore, "maxOpDiff provider data mismatch");
  }

  function testFork_RifBucketProviders_OwnerCanUpdateAndEmitEvent_AfterUpgrade() public {
    _executeChanger();

    IRifBucketProbe rifBucket = IRifBucketProbe(rifBucketProxy);
    address maxAbsoluteProvider = rifBucket.maxAbsoluteOpProvider();
    address maxOpDiffProvider = rifBucket.maxOpDiffProvider();

    address absOwner = IOwnableLike(maxAbsoluteProvider).owner();
    address diffOwner = IOwnableLike(maxOpDiffProvider).owner();

    uint256 newAbsoluteValue = 123456789;
    uint256 newDifferenceValue = 987654321;

    vm.recordLogs();
    vm.prank(absOwner);
    FCMaxAbsoluteOpProvider(maxAbsoluteProvider).setMaxAbsoluteOperation(newAbsoluteValue);
    Vm.Log[] memory logsAbs = vm.getRecordedLogs();

    vm.recordLogs();
    vm.prank(diffOwner);
    FCMaxOpDifferenceProvider(maxOpDiffProvider).setMaxOperationalDifference(newDifferenceValue);
    Vm.Log[] memory logsDiff = vm.getRecordedLogs();

    (bytes32 absDataAfter, bool absValidAfter) = IDataProviderProbe(maxAbsoluteProvider).peek();
    (bytes32 diffDataAfter, bool diffValidAfter) = IDataProviderProbe(maxOpDiffProvider).peek();
    require(absValidAfter, "maxAbsolute provider invalid after update");
    require(diffValidAfter, "maxOpDiff provider invalid after update");
    require(uint256(absDataAfter) == newAbsoluteValue, "maxAbsolute provider data did not update");
    require(uint256(diffDataAfter) == newDifferenceValue, "maxOpDiff provider data did not update");

    require(
      _hasDataUpdatedEvent(logsAbs, maxAbsoluteProvider, newAbsoluteValue),
      "DataUpdated missing for maxAbsolute provider"
    );
    require(
      _hasDataUpdatedEvent(logsDiff, maxOpDiffProvider, newDifferenceValue),
      "DataUpdated missing for maxOpDiff provider"
    );
  }

  function testFork_OracleHappyPath_CanPublishPrice_AfterUpgrade() public {
    _executeChanger();

    ICoinPairPriceProbe coinPair = ICoinPairPriceProbe(coinPairProxy);
    IOracleManagerProbe oracleManager = IOracleManagerProbe(oracleManagerProxy);
    IStakingProbe staking = IStakingProbe(oracleManager.getStakingContract());

    (, , , , address[] memory selectedOwners, ) = coinPair.getRoundInfo();
    uint256 selectedCount = selectedOwners.length;
    require(selectedCount > 0, "no selected owners");
    uint256 majorityCount = (selectedCount / 2) + 1;

    uint256[] memory privateKeys = new uint256[](majorityCount);
    for (uint256 i = 0; i < majorityCount; i++) {
      privateKeys[i] = 0xA100 + i + 1;
    }

    address[] memory signers = new address[](majorityCount);
    for (uint256 i = 0; i < majorityCount; i++) {
      signers[i] = IOracleCheats(address(vm)).addr(privateKeys[i]);
      vm.prank(selectedOwners[i]);
      staking.setOracleAddress(signers[i]);
      require(
        oracleManager.getOracleAddress(selectedOwners[i]) == signers[i],
        "failed to set signer for selected owner"
      );
      require(
        oracleManager.getOracleOwner(signers[i]) == selectedOwners[i],
        "signer owner mismatch"
      );
    }

    (uint256 currentPrice, bool isValid, uint256 lastPubBlock) = coinPair.getPriceInfo();
    require(isValid, "price invalid before publish");
    bytes32 coinpair = coinPair.getCoinPair();
    uint256 newPrice = currentPrice + 333333;
    address votedOracle = signers[0];

    bytes32 digest = _buildDigest(
      PUBLISH_MESSAGE_VERSION,
      coinpair,
      newPrice,
      votedOracle,
      lastPubBlock
    );
    (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) = _buildSortedSignatures(
      IOracleCheats(address(vm)),
      privateKeys,
      signers,
      digest
    );

    vm.prank(votedOracle);
    coinPair.publishPrice(
      PUBLISH_MESSAGE_VERSION,
      coinpair,
      newPrice,
      votedOracle,
      lastPubBlock,
      sigV,
      sigR,
      sigS
    );

    (uint256 updatedPrice, , uint256 updatedLastPubBlock) = coinPair.getPriceInfo();
    require(updatedPrice == newPrice, "published price not applied");
    require(updatedLastPubBlock == block.number, "publication block not updated");
  }

  function testFork_MoCBasicOps_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    address connectorAddr = moc.connector();

    IMoCConnectorProbe connector = IMoCConnectorProbe(connectorAddr);
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());
    IMoCInrateProbe mocInrate = IMoCInrateProbe(connector.mocInrate());
    address bproTokenAddr = connector.bproToken();
    address docTokenAddr = connector.docToken();

    IERC20Like bproToken = IERC20Like(bproTokenAddr);
    IERC20Like docToken = IERC20Like(docTokenAddr);

    uint256 mintBProBtc = 0.01 ether;
    uint256 mintDocBtc = 0.01 ether;
    uint256 mintBProValue = 0.011 ether;
    uint256 mintDocValue = 0.011 ether;
    vm.deal(address(this), 1 ether);

    uint256 bproBefore = bproToken.balanceOf(address(this));
    uint8 mocStateBeforeMint = mocState.state();
    require(mocStateBeforeMint != 1, "BProDiscount state not supported in exact assertion");
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

    uint256 docToRedeem = (docAfterMint - docBefore) / 2;
    require(docToRedeem > 0, "Doc redeem amount is zero");
    uint256 expectedGrossRbtcFromDocRedeem = mocState.docsToBtc(docToRedeem);
    uint256 docRedeemInterest = mocInrate.calcDocRedInterestValues(
      docToRedeem,
      expectedGrossRbtcFromDocRedeem
    );
    uint256 expectedPreFeeRbtcFromDocRedeem = expectedGrossRbtcFromDocRedeem - docRedeemInterest;
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

  function testFork_RunSettlement_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    address mocStateAddr = connector.mocState();
    IMoCSettlementStorageProbe settlement = IMoCSettlementStorageProbe(mocSettlementV1Proxy);

    // Stabilize settlement path on fork: ensure non-zero oracle prices.
    vm.mockCall(
      mocStateAddr,
      abi.encodeWithSelector(IMoCStateProbe.getBitcoinPrice.selector),
      abi.encode(uint256(1e18))
    );
    vm.mockCall(
      mocStateAddr,
      abi.encodeWithSelector(IMoCStateProbe.getMoCPrice.selector),
      abi.encode(uint256(1e18))
    );
    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("peek()"))),
      abi.encode(bytes32(uint256(1e18)), true)
    );
    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("read()"))),
      abi.encode(bytes32(uint256(1e18)))
    );

    uint256 nextSettlementBlockBefore = settlement.nextSettlementBlock();
    if (block.number < nextSettlementBlockBefore) {
      vm.roll(nextSettlementBlockBefore);
    }

    require(settlement.isSettlementEnabled(), "settlement not enabled");
    moc.runSettlement(1);

    uint256 nextSettlementBlockAfter = settlement.nextSettlementBlock();
    require(
      nextSettlementBlockAfter > nextSettlementBlockBefore,
      "next settlement block did not advance"
    );
    require(!settlement.isSettlementEnabled(), "settlement should be disabled right after run");
  }

  function testFork_MoCBasicOps_BelowCoverage_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());
    IERC20Like bproToken = IERC20Like(connector.bproToken());
    IERC20Like docToken = IERC20Like(connector.docToken());

    uint256 mintBProBtc = 0.01 ether;
    uint256 mintDocBtc = 0.01 ether;
    uint256 operationValue = 0.011 ether;
    vm.deal(address(this), 2 ether);

    // Seed balances while system is healthy so we can test both redeem paths below coverage.
    moc.mintBPro{ value: operationValue }(mintBProBtc);
    moc.mintDoc{ value: operationValue }(mintDocBtc);

    uint256 bproBalance = bproToken.balanceOf(address(this));
    uint256 docBalance = docToken.balanceOf(address(this));

    uint256 currentBtcPrice = mocState.getBitcoinPrice();
    uint256 currentCoverage = mocState.globalCoverage();
    uint256 cobj = mocState.cobj();
    uint256 protected = mocState.getProtected();
    require(currentCoverage > cobj, "test precondition: coverage must start above cobj");
    require(cobj > protected, "test precondition: cobj must be above protected");

    // Target BelowCobj but outside protection mode: protected < coverage < cobj.
    uint256 targetCoverage = (cobj + protected) / 2;
    uint256 targetBtcPrice = (currentBtcPrice * targetCoverage) / currentCoverage;

    // Force BTC price through oracle reads to place protocol in BelowCobj.
    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("peek()"))),
      abi.encode(bytes32(targetBtcPrice), true)
    );
    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("read()"))),
      abi.encode(bytes32(targetBtcPrice))
    );

    bytes memory stateRevertData = abi.encodeWithSignature(
      "Error(string)",
      "Function cannot be called at this state."
    );

    vm.expectRevert(stateRevertData);
    moc.mintDoc{ value: operationValue }(mintDocBtc);

    vm.expectRevert(stateRevertData);
    moc.redeemBPro(bproBalance / 2);

    moc.mintBPro{ value: operationValue }(mintBProBtc);
    moc.redeemFreeDoc(docBalance / 2);
  }

  function testFork_MoCBasicOps_BelowProtected_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());
    IERC20Like bproToken = IERC20Like(connector.bproToken());
    IERC20Like docToken = IERC20Like(connector.docToken());

    uint256 mintBProBtc = 0.01 ether;
    uint256 mintDocBtc = 0.01 ether;
    uint256 operationValue = 0.011 ether;
    vm.deal(address(this), 2 ether);

    // Seed balances while system is healthy so we can attempt both redeem operations later.
    moc.mintBPro{ value: operationValue }(mintBProBtc);
    moc.mintDoc{ value: operationValue }(mintDocBtc);

    uint256 bproBalance = bproToken.balanceOf(address(this));
    uint256 docBalance = docToken.balanceOf(address(this));

    uint256 currentBtcPrice = mocState.getBitcoinPrice();
    uint256 currentCoverage = mocState.globalCoverage();
    uint256 cobj = mocState.cobj();
    uint256 protected = mocState.getProtected();
    require(currentCoverage > cobj, "test precondition: coverage must start above cobj");

    // Target protection mode: coverage < protected.
    uint256 targetCoverage = protected - 1;
    uint256 targetBtcPrice = (currentBtcPrice * targetCoverage) / currentCoverage;

    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("peek()"))),
      abi.encode(bytes32(targetBtcPrice), true)
    );
    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("read()"))),
      abi.encode(bytes32(targetBtcPrice))
    );

    bytes memory stateRevertData = abi.encodeWithSignature(
      "Error(string)",
      "Function cannot be called at this state."
    );
    bytes memory protectionRevertData = abi.encodeWithSignature(
      "Error(string)",
      "Function cannot be called at protection mode."
    );

    vm.expectRevert(stateRevertData);
    moc.mintDoc{ value: operationValue }(mintDocBtc);

    vm.expectRevert(stateRevertData);
    moc.redeemBPro(bproBalance / 2);

    vm.expectRevert(protectionRevertData);
    moc.mintBPro{ value: operationValue }(mintBProBtc);

    vm.expectRevert(protectionRevertData);
    moc.redeemFreeDoc(docBalance / 2);
  }

  function testFork_MoCBasicOps_LiquidationRefundsMints_AfterUpgrade() public {
    _executeChanger();
    vm.txGasPrice(0);

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());
    IERC20Like bproToken = IERC20Like(connector.bproToken());
    IERC20Like docToken = IERC20Like(connector.docToken());

    uint256 mintBProBtc = 0.01 ether;
    uint256 mintDocBtc = 0.01 ether;
    uint256 operationValue = 0.011 ether;
    vm.deal(address(this), 2 ether);

    // Seed balances while system is healthy so we can validate redeem failures under protection mode.
    moc.mintBPro{ value: operationValue }(mintBProBtc);
    moc.mintDoc{ value: operationValue }(mintDocBtc);

    uint256 bproBalance = bproToken.balanceOf(address(this));
    uint256 docBalance = docToken.balanceOf(address(this));

    uint256 currentBtcPrice = mocState.getBitcoinPrice();
    uint256 currentCoverage = mocState.globalCoverage();
    uint256 cobj = mocState.cobj();
    uint256 protected = mocState.getProtected();
    require(currentCoverage > cobj, "test precondition: coverage must start above cobj");

    uint256 liq = mocState.liq();
    uint256 liquidationCoverage = liq - 1;
    uint256 liquidationBtcPrice = (currentBtcPrice * liquidationCoverage) / currentCoverage;

    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("peek()"))),
      abi.encode(bytes32(liquidationBtcPrice), true)
    );
    vm.mockCall(
      coinPairProxy,
      abi.encodeWithSelector(bytes4(keccak256("read()"))),
      abi.encode(bytes32(liquidationBtcPrice))
    );

    uint256 coverageBeforeOps = mocState.globalCoverage();
    require(coverageBeforeOps <= mocState.getProtected(), "not in protection mode");
    require(coverageBeforeOps <= mocState.liq(), "not below liq");
    require(!mocState.getLiquidationEnabled(), "liquidation enabled unexpectedly");
    mocState.nextState();
    require(mocState.state() == 2, "state should be BelowCobj when liquidation is disabled");

    bytes memory stateRevertData = abi.encodeWithSignature(
      "Error(string)",
      "Function cannot be called at this state."
    );
    bytes memory protectionRevertData = abi.encodeWithSignature(
      "Error(string)",
      "Function cannot be called at protection mode."
    );

    vm.expectRevert(stateRevertData);
    moc.mintDoc{ value: operationValue }(mintDocBtc);
    vm.expectRevert(stateRevertData);
    moc.redeemBPro(bproBalance / 2);
    vm.expectRevert(protectionRevertData);
    moc.mintBPro{ value: operationValue }(mintBProBtc);
    vm.expectRevert(protectionRevertData);
    moc.redeemFreeDoc(docBalance / 2);

    // Enable liquidation through governance.
    if (!mocState.getLiquidationEnabled()) {
      LiquidationEnabledTestChanger liquidationEnabledChanger = new LiquidationEnabledTestChanger(
        address(mocState),
        true
      );
      IGovernor governor = IGovernor(IGoverned(address(mocState)).governor());
      address governorOwner = IOwnableLike(address(governor)).owner();
      vm.prank(governorOwner);
      governor.executeChange(IChangeContract(address(liquidationEnabledChanger)));
      require(mocState.getLiquidationEnabled(), "liquidationEnabled was not set");
    }

    uint256 rbtcBeforeTrigger = address(this).balance;
    uint256 bproBeforeTrigger = bproToken.balanceOf(address(this));
    moc.mintBPro{ value: operationValue }(mintBProBtc);
    require(address(this).balance == rbtcBeforeTrigger, "mintBPro value was not refunded");
    require(
      bproToken.balanceOf(address(this)) == bproBeforeTrigger,
      "mintBPro should not mint in liquidation"
    );

    uint256 rbtcBeforeMintDoc = address(this).balance;
    uint256 docBeforeMintDoc = docToken.balanceOf(address(this));
    moc.mintDoc{ value: operationValue }(mintDocBtc);
    require(address(this).balance == rbtcBeforeMintDoc, "mintDoc value was not refunded");
    require(
      docToken.balanceOf(address(this)) == docBeforeMintDoc,
      "mintDoc should not mint in liquidation"
    );
  }

  function testFork_NonReentrant_RedeemBPro_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    address bproTokenAddr = connector.bproToken();

    ReentrantMoCAttacker attacker = new ReentrantMoCAttacker(
      mocV1Proxy,
      bproTokenAddr,
      connector.docToken()
    );
    vm.deal(address(attacker), 1 ether);

    (bool ok, ) = address(attacker).call{ value: 0.011 ether }(
      abi.encodeWithSelector(ReentrantMoCAttacker.attackRedeemBPro.selector, 0.01 ether)
    );
    require(ok, "attack transaction should complete");
    (bool reenterOk, bytes memory reenterData) = attacker.getLastReenterResult();
    require(
      !reenterOk && _isErrorString(reenterData, "reentrancy not allowed"),
      "redeemBPro should revert by nonReentrant modifier"
    );
  }

  function testFork_NonReentrant_RedeemFreeDoc_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    address bproTokenAddr = connector.bproToken();
    address docTokenAddr = connector.docToken();

    ReentrantMoCAttacker attacker = new ReentrantMoCAttacker(
      mocV1Proxy,
      bproTokenAddr,
      docTokenAddr
    );
    vm.deal(address(attacker), 1 ether);

    (bool ok, ) = address(attacker).call{ value: 0.011 ether }(
      abi.encodeWithSelector(ReentrantMoCAttacker.attackRedeemFreeDoc.selector, 0.01 ether)
    );
    require(ok, "attack transaction should complete");
    (bool reenterOk, bytes memory reenterData) = attacker.getLastReenterResult();
    require(
      !reenterOk && _isErrorString(reenterData, "reentrancy not allowed"),
      "redeemFreeDoc should revert by nonReentrant modifier"
    );
  }

  function testFork_NonReentrant_MintBProVendors_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());
    address bproTokenAddr = connector.bproToken();
    address docTokenAddr = connector.docToken();

    // Force vendor path to perform vendor transfer (callback target for reentrancy attempt).
    vm.mockCall(
      mocState.getMoCVendors(),
      abi.encodeWithSelector(IMoCVendorsProbe.updatePaidMarkup.selector),
      abi.encode(true)
    );

    ReentrantMoCAttacker attacker = new ReentrantMoCAttacker(
      mocV1Proxy,
      bproTokenAddr,
      docTokenAddr
    );
    vm.deal(address(attacker), 1 ether);

    (bool ok, ) = address(attacker).call{ value: 0.011 ether }(
      abi.encodeWithSelector(ReentrantMoCAttacker.attackMintBProAsVendor.selector, 0.01 ether)
    );
    require(ok, "attack transaction should complete");
    (bool reenterOk, bytes memory reenterData) = attacker.getLastReenterResult();
    require(
      !reenterOk && _isErrorString(reenterData, "reentrancy not allowed"),
      "mintBProVendors should revert by nonReentrant modifier"
    );
  }

  function testFork_NonReentrant_MintDocVendors_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    IMoCConnectorProbe connector = IMoCConnectorProbe(moc.connector());
    IMoCStateProbe mocState = IMoCStateProbe(connector.mocState());
    address bproTokenAddr = connector.bproToken();
    address docTokenAddr = connector.docToken();

    // Force vendor path to perform vendor transfer (callback target for reentrancy attempt).
    vm.mockCall(
      mocState.getMoCVendors(),
      abi.encodeWithSelector(IMoCVendorsProbe.updatePaidMarkup.selector),
      abi.encode(true)
    );

    ReentrantMoCAttacker attacker = new ReentrantMoCAttacker(
      mocV1Proxy,
      bproTokenAddr,
      docTokenAddr
    );
    vm.deal(address(attacker), 1 ether);

    (bool ok, ) = address(attacker).call{ value: 0.011 ether }(
      abi.encodeWithSelector(ReentrantMoCAttacker.attackMintDocAsVendor.selector, 0.01 ether)
    );
    require(ok, "attack transaction should complete");
    (bool reenterOk, bytes memory reenterData) = attacker.getLastReenterResult();
    require(
      !reenterOk && _isErrorString(reenterData, "reentrancy not allowed"),
      "mintDocVendors should revert by nonReentrant modifier"
    );
  }

  function _isErrorString(
    bytes memory revertData,
    string memory expected
  ) internal pure returns (bool) {
    if (revertData.length < 68) return false;
    bytes4 selector;
    assembly ("memory-safe") {
      selector := mload(add(revertData, 0x20))
    }
    if (selector != 0x08c379a0) return false; // Error(string)

    bytes memory payload = new bytes(revertData.length - 4);
    for (uint256 i = 0; i < payload.length; i++) {
      payload[i] = revertData[i + 4];
    }
    string memory reason = abi.decode(payload, (string));
    return keccak256(bytes(reason)) == keccak256(bytes(expected));
  }

  function _hasUpgradedEvent(Vm.Log[] memory logs, address emitter) internal pure returns (bool) {
    for (uint256 i = 0; i < logs.length; i++) {
      if (
        logs[i].emitter == emitter &&
        logs[i].topics.length > 0 &&
        logs[i].topics[0] == UPGRADED_TOPIC
      ) {
        return true;
      }
    }
    return false;
  }

  function _hasDataUpdatedEvent(
    Vm.Log[] memory logs,
    address emitter,
    uint256 expectedData
  ) internal pure returns (bool) {
    for (uint256 i = 0; i < logs.length; i++) {
      if (
        logs[i].emitter == emitter &&
        logs[i].topics.length > 0 &&
        logs[i].topics[0] == DATA_UPDATED_TOPIC
      ) {
        if (abi.decode(logs[i].data, (uint256)) == expectedData) {
          return true;
        }
      }
    }
    return false;
  }

  function _executeChanger() internal {
    address[] memory deprecatedOracles = new address[](2);
    deprecatedOracles[0] = 0x4b5E791b0Ef89E954d1212dB598cBd9d3787AAFE;
    deprecatedOracles[1] = 0xe4822F07C1d988A8f2F53D1817f7e8848897b67A;

    IRifBucketProbe rifBucket = IRifBucketProbe(rifBucketProxy);
    address maxAbsoluteProviderBefore = rifBucket.maxAbsoluteOpProvider();
    address maxOpDiffProviderBefore = rifBucket.maxOpDiffProvider();
    (bytes32 dataAbsBefore, ) = IDataProviderProbe(maxAbsoluteProviderBefore).peek();
    (bytes32 dataDiffBefore, ) = IDataProviderProbe(maxOpDiffProviderBefore).peek();

    address newMaxAbsoluteOpProvider = address(
      new FCMaxAbsoluteOpProvider(
        IOwnableLike(maxAbsoluteProviderBefore).owner(),
        uint256(dataAbsBefore)
      )
    );
    address newMaxOpDifferenceProvider = address(
      new FCMaxOpDifferenceProvider(
        IOwnableLike(maxOpDiffProviderBefore).owner(),
        uint256(dataDiffBefore)
      )
    );

    BufferPctAndCleanMocV1 changer = new BufferPctAndCleanMocV1(
      oracleManagerProxy,
      coinPairProxy,
      mocRewardsBufferProxy,
      mocV1Proxy,
      mocStateV1Proxy,
      mocExchangeV1Proxy,
      mocSettlementV1Proxy,
      rifBucketProxy,
      IUpgradeDelegator(upgradeDelegatorOracle),
      IUpgradeDelegator(upgradeDelegatorMoc),
      newCoinPairImpl,
      newOracleManagerImpl,
      newMocImpl,
      newMocStateImpl,
      newMocExchangeImpl,
      newMocSettlementImpl,
      newMaxAbsoluteOpProvider,
      newMaxOpDifferenceProvider,
      deprecatedOracles
    );

    IGovernor governor = IGovernor(IGoverned(coinPairProxy).governor());
    address governorOwner = IOwnableLike(address(governor)).owner();
    vm.prank(governorOwner);
    governor.executeChange(IChangeContract(address(changer)));
  }

  function _deployFromArtifact(string memory artifactPath) internal returns (address deployed) {
    bytes memory bytecode = vm.getCode(artifactPath);
    require(bytecode.length != 0, "artifact bytecode is empty");
    assembly ("memory-safe") {
      deployed := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    require(deployed != address(0), "deployment failed");
  }

  function _readMainnetParamsFromJson()
    internal
    view
    returns (
      address coinPairProxy_,
      address oracleManagerProxy_,
      address mocRewardsBufferProxy_,
      address mocV1Proxy_,
      address rifBucketProxy_,
      address upgradeDelegatorOracle_,
      address upgradeDelegatorMoc_
    )
  {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);

    oracleManagerProxy_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.oracleManagerProxy"
    );
    coinPairProxy_ = vm.parseJsonAddress(json, ".BufferPctAndCleanMocV1Module.coinPairProxy");
    mocRewardsBufferProxy_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.mocRewardsBufferProxy"
    );
    mocV1Proxy_ = vm.parseJsonAddress(json, ".BufferPctAndCleanMocV1Module.mocV1Proxy");
    rifBucketProxy_ = vm.parseJsonAddress(json, ".BufferPctAndCleanMocV1Module.rifBucketProxy");
    upgradeDelegatorOracle_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.upgradeDelegatorOracle"
    );
    upgradeDelegatorMoc_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.upgradeDelegatorMoc"
    );

    require(oracleManagerProxy_ != address(0), "oracleManagerProxy is zero");
    require(coinPairProxy_ != address(0), "coinPairProxy is zero");
    require(mocRewardsBufferProxy_ != address(0), "mocRewardsBufferProxy is zero");
    require(mocV1Proxy_ != address(0), "mocV1Proxy is zero");
    require(upgradeDelegatorOracle_ != address(0), "upgradeDelegatorOracle is zero");
    require(upgradeDelegatorMoc_ != address(0), "upgradeDelegatorMoc is zero");
  }
}
