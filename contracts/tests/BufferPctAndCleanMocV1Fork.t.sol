// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BufferPctAndCleanMocV1, IUpgradeDelegator } from "../changers/bufferPct_cleanMocV1/BufferPctAndCleanMocV1.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

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
  function redeemBPro(uint256 bproAmount) external;
  function mintDoc(uint256 btcToMint) external payable;
  function redeemFreeDoc(uint256 docAmount) external;
}

interface IMoCConnectorProbe {
  function bproToken() external view returns (address);
  function docToken() external view returns (address);
}

interface IERC20Like {
  function balanceOf(address account) external view returns (uint256);
}

contract BufferPctAndCleanMocV1ForkTest {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  uint256 internal constant FORK_BLOCK = 8837400;
  string internal constant MAINNET_PARAMS_PATH =
    "./ignition/modules/BufferPctAndCleanMocV1/parameters/rskMainnet.json";

  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant ZOS_IMPLEMENTATION_SLOT =
    0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;
  bytes32 internal constant UPGRADED_TOPIC = keccak256("Upgraded(address)");

  address internal coinPairProxy;
  address internal mocRewardsBufferProxy;
  address internal mocV1Proxy;
  address internal mocExchangeV1Proxy;
  address internal mocSettlementV1Proxy;
  address internal upgradeDelegatorOracle;
  address internal upgradeDelegatorMoc;

  address internal newCoinPairImpl;
  address internal newMocImpl;
  address internal newMocExchangeImpl;
  address internal newMocSettlementImpl;

  receive() external payable {}

  function setUp() public {
    string memory rpcUrl = vm.envOr("RSK_MAINNET_RPC_URL", "https://public-node.rsk.co");
    vm.createSelectFork(rpcUrl, FORK_BLOCK);

    (
      coinPairProxy,
      mocRewardsBufferProxy,
      mocV1Proxy,
      mocExchangeV1Proxy,
      mocSettlementV1Proxy,
      upgradeDelegatorOracle,
      upgradeDelegatorMoc
    ) = _readMainnetParamsFromJson();

    newCoinPairImpl = _deployFromArtifact(
      "contracts/compat/DeployableCoinPairPrice.sol:DeployableCoinPairPrice"
    );
    newMocImpl = _deployFromArtifact("contracts/compat/DeployableMoC.sol:DeployableMoC");
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
    IBufferTokenLike buffer = IBufferTokenLike(mocRewardsBufferProxy);
    require(buffer.getNumOutputs() == 2, "Buffer must have exactly 2 outputs");

    (address output0Before, uint256 split0Before, , ) = buffer.getOutput(0);
    (address output1Before, uint256 split1Before, , ) = buffer.getOutput(1);

    address coinPairImplBefore = _loadAddress(coinPairProxy, IMPLEMENTATION_SLOT);
    address mocImplBefore = _loadAddress(mocV1Proxy, ZOS_IMPLEMENTATION_SLOT);
    address mocExchangeImplBefore = _loadAddress(mocExchangeV1Proxy, ZOS_IMPLEMENTATION_SLOT);
    address mocSettlementImplBefore = _loadAddress(mocSettlementV1Proxy, ZOS_IMPLEMENTATION_SLOT);

    vm.recordLogs();
    _executeChanger();
    Vm.Log[] memory logs = vm.getRecordedLogs();

    bool coinPairUpgradedEvent = _hasUpgradedEvent(logs, coinPairProxy);
    bool mocUpgradedEvent = _hasUpgradedEvent(logs, mocV1Proxy);
    bool mocExchangeUpgradedEvent = _hasUpgradedEvent(logs, mocExchangeV1Proxy);
    bool mocSettlementUpgradedEvent = _hasUpgradedEvent(logs, mocSettlementV1Proxy);

    require(coinPairUpgradedEvent, "Upgraded event missing for coinPairProxy");
    require(mocUpgradedEvent, "Upgraded event missing for mocV1Proxy");
    require(mocExchangeUpgradedEvent, "Upgraded event missing for mocExchangeV1Proxy");
    require(mocSettlementUpgradedEvent, "Upgraded event missing for mocSettlementV1Proxy");

    address coinPairImplAfter = _loadAddress(coinPairProxy, IMPLEMENTATION_SLOT);
    address mocImplAfter = _loadAddress(mocV1Proxy, ZOS_IMPLEMENTATION_SLOT);
    address mocExchangeImplAfter = _loadAddress(mocExchangeV1Proxy, ZOS_IMPLEMENTATION_SLOT);
    address mocSettlementImplAfter = _loadAddress(mocSettlementV1Proxy, ZOS_IMPLEMENTATION_SLOT);
    require(coinPairImplAfter == newCoinPairImpl, "coinPair implementation mismatch");
    require(mocImplAfter == newMocImpl, "MoC implementation mismatch");
    require(mocExchangeImplAfter == newMocExchangeImpl, "MoCExchange implementation mismatch");
    require(
      mocSettlementImplAfter == newMocSettlementImpl,
      "MoCSettlement implementation mismatch"
    );

    require(coinPairImplAfter != coinPairImplBefore, "coinPair implementation did not change");
    require(mocImplAfter != mocImplBefore, "MoC implementation did not change");
    require(
      mocExchangeImplAfter != mocExchangeImplBefore,
      "MoCExchange implementation did not change"
    );
    require(
      mocSettlementImplAfter != mocSettlementImplBefore,
      "MoCSettlement implementation did not change"
    );

    (address output0After, uint256 split0After, , ) = buffer.getOutput(0);
    (address output1After, uint256 split1After, , ) = buffer.getOutput(1);

    require(output0After == output0Before, "output 0 address changed");
    require(output1After == output1Before, "output 1 address changed");
    require(split0After == 70, "output 0 split must be 70");
    require(split1After == 30, "output 1 split must be 30");

    require(split0Before != split0After || split1Before != split1After, "buffer splits unchanged");
  }

  function testFork_MoCBasicOps_AfterUpgrade() public {
    _executeChanger();

    IMoCBasicOps moc = IMoCBasicOps(mocV1Proxy);
    address connectorAddr = moc.connector();
    require(connectorAddr != address(0), "MoC connector is zero");

    IMoCConnectorProbe connector = IMoCConnectorProbe(connectorAddr);
    address bproTokenAddr = connector.bproToken();
    address docTokenAddr = connector.docToken();
    require(bproTokenAddr != address(0), "BPro token is zero");
    require(docTokenAddr != address(0), "Doc token is zero");

    IERC20Like bproToken = IERC20Like(bproTokenAddr);
    IERC20Like docToken = IERC20Like(docTokenAddr);

    uint256 mintBProBtc = 0.01 ether;
    uint256 mintDocBtc = 0.01 ether;
    uint256 mintBProValue = 0.011 ether;
    uint256 mintDocValue = 0.011 ether;
    vm.deal(address(this), 1 ether);

    uint256 bproBefore = bproToken.balanceOf(address(this));
    moc.mintBPro{ value: mintBProValue }(mintBProBtc);
    uint256 bproAfterMint = bproToken.balanceOf(address(this));
    require(bproAfterMint > bproBefore, "mintBPro did not increase BPro balance");

    uint256 bproToRedeem = (bproAfterMint - bproBefore) / 2;
    require(bproToRedeem > 0, "BPro redeem amount is zero");
    moc.redeemBPro(bproToRedeem);
    uint256 bproAfterRedeem = bproToken.balanceOf(address(this));
    require(bproAfterRedeem < bproAfterMint, "redeemBPro did not decrease BPro balance");

    uint256 docBefore = docToken.balanceOf(address(this));
    moc.mintDoc{ value: mintDocValue }(mintDocBtc);
    uint256 docAfterMint = docToken.balanceOf(address(this));
    require(docAfterMint > docBefore, "mintDoc did not increase Doc balance");

    uint256 docToRedeem = (docAfterMint - docBefore) / 2;
    require(docToRedeem > 0, "Doc redeem amount is zero");
    moc.redeemFreeDoc(docToRedeem);
    uint256 docAfterRedeem = docToken.balanceOf(address(this));
    require(docAfterRedeem < docAfterMint, "redeemFreeDoc did not decrease Doc balance");
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

  function _executeChanger() internal {
    BufferPctAndCleanMocV1 changer = new BufferPctAndCleanMocV1(
      coinPairProxy,
      mocRewardsBufferProxy,
      mocV1Proxy,
      mocExchangeV1Proxy,
      mocSettlementV1Proxy,
      IUpgradeDelegator(upgradeDelegatorOracle),
      IUpgradeDelegator(upgradeDelegatorMoc),
      newCoinPairImpl,
      newMocImpl,
      newMocExchangeImpl,
      newMocSettlementImpl
    );

    IGovernor governor = IGovernor(IGoverned(coinPairProxy).governor());
    address governorOwner = IOwnableLike(address(governor)).owner();
    vm.prank(governorOwner);
    governor.executeChange(IChangeContract(address(changer)));
  }

  function _loadAddress(address target, bytes32 slot) internal view returns (address) {
    return address(uint160(uint256(vm.load(target, slot))));
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
      address mocRewardsBufferProxy_,
      address mocV1Proxy_,
      address mocExchangeV1Proxy_,
      address mocSettlementV1Proxy_,
      address upgradeDelegatorOracle_,
      address upgradeDelegatorMoc_
    )
  {
    string memory json = vm.readFile(MAINNET_PARAMS_PATH);

    coinPairProxy_ = vm.parseJsonAddress(json, ".BufferPctAndCleanMocV1Module.coinPairProxy");
    mocRewardsBufferProxy_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.mocRewardsBufferProxy"
    );
    mocV1Proxy_ = vm.parseJsonAddress(json, ".BufferPctAndCleanMocV1Module.mocV1Proxy");
    mocExchangeV1Proxy_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.mocExchangeV1Proxy"
    );
    mocSettlementV1Proxy_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.mocSettlementV1Proxy"
    );
    upgradeDelegatorOracle_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.upgradeDelegatorOracle"
    );
    upgradeDelegatorMoc_ = vm.parseJsonAddress(
      json,
      ".BufferPctAndCleanMocV1Module.upgradeDelegatorMoc"
    );

    require(coinPairProxy_ != address(0), "coinPairProxy is zero");
    require(mocRewardsBufferProxy_ != address(0), "mocRewardsBufferProxy is zero");
    require(mocV1Proxy_ != address(0), "mocV1Proxy is zero");
    require(mocExchangeV1Proxy_ != address(0), "mocExchangeV1Proxy is zero");
    require(mocSettlementV1Proxy_ != address(0), "mocSettlementV1Proxy is zero");
    require(upgradeDelegatorOracle_ != address(0), "upgradeDelegatorOracle is zero");
    require(upgradeDelegatorMoc_ != address(0), "upgradeDelegatorMoc is zero");
  }
}
