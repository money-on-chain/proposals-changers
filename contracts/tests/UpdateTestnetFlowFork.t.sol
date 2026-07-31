// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DataProvider } from "@moc/roc/contracts/providers/DataProvider.sol";
import { MocReverseAuction } from "@moc/main/contracts/auxiliary/MocReverseAuction.sol";
import { MocSwapperV3 } from "@moc/main/contracts/multiCollateral/swapper/MocSwapperV3.sol";
import { IBufferLike, ICommissionSplitter, IChangeContract, IMoCCommissionSplitterV2, IMoCCommissionSplitterV3, IMocSwapperV3, IMocSwapperV3MultiHop, IRegistryLike, UpdateTestnetFlowChanger } from "../changers/updateTestnetFlow/UpdateTestnetFlowChanger.sol";

interface IOwnableLike {
  function owner() external view returns (address);
}

interface IGovernorLike {
  function executeChange(IChangeContract changeContract_) external;
}

interface IRegistryProbe is IRegistryLike {
  function addressArrayContains(bytes32 key_, address value_) external view returns (bool);
}

contract UpdateTestnetFlowForkTest is Test {
  string private constant DEFAULT_RPC_URL = "https://public-node.testnet.rsk.co";
  address private constant GOVERNOR = 0x7b716178771057195bB511f0B1F7198EEE62Bc22;
  address private constant PAUSER = 0x5bCdf8A2E61BD238AEe43b99962Ee8BfBda1Beca;
  address private constant SWAP_ROUTER = 0x1Adac2EA80F7533d0c361E68f09Af9Dd1F22359b;
  address private constant COINBASE_WRAPPER = 0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab;
  address private constant MULTIHOP_SWAPPER = 0xF607f5defD2Bb3C1a95E5fc41343016cCB45fDcA;
  address private constant MOC_TOKEN = 0x45a97b54021a3F99827641AFe1BFAE574431e6ab;
  address private constant RIF_TOKEN = 0x19F64674D8A5B4E652319F5e239eFd3bc969A1fE;
  address private constant WRBTC_TOKEN = 0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab;
  address private constant REGISTRY = 0xf078375a3dD89dDF4D9dA460352199C6769b5f10;
  address private constant MOC_TO_BTC_PROVIDER = 0x6C3A218AF21b82E17BC684c0B2DB3C799a3c66c1;
  address private constant MOC_TO_RIF_PROVIDER = 0x4F9724e78e7Cd521c879b6B9eE7D5b4e7df3cfbC;
  address private constant UNISWAP_V3_POOL = 0x536af50B25887808C6100343772eDed07C5bC414;
  address private constant MOC_REWARDS_BUFFER = 0x40d86d6ac67059bAe5ae42B6FCaB843c1c6af300;
  address private constant BTC_TO_MOC_OUTPUT_ACCOUNT = 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F;
  address private constant MOC_TO_RIF_OUTPUT_ACCOUNT = 0xa416934264515bb381E3b746f10f22D5c6f9431a;

  address private constant RIF_COMMISSION_SPLITTER_V2 = 0x499072990571C49Ef9369624885581b9C5aF0B11;
  address private constant RIF_COMMISSION_SPLITTER_V3 = 0xD1FF3909dCa7C755F38e4FF04ce7170b4940d89B;
  address private constant FOUNDATION_MULTISIG = 0xf69287F5Ca3cC3C6d3981f2412109110cB8af076;
  address private constant RIF_PRO_REWARDS_BUFFER = 0x1eDaDfd891793a5D1a011fFB82635C2Bbedc2511;
  address private constant DOCR_REWARDS_BUFFER = 0x6e364c96a83B72fe69843E50Fe08D09495AB0100;
  address private constant BITPRO_REWARDS_BUFFER = 0xb998C3Da8D24295406d308ea42c85c8acDa880Ba;
  address private constant COIN_PAIR_RBTC_USD = 0x39192498FcF1dBE11653040bB49308E09A1056AC;
  address private constant SUPPORTERS = 0x2Bb08e5DFb88477A88180Fbb7eF8196fbdea4Cd5;
  address private constant MOC_COMMISSION_SPLITTER_V2 = 0xFA17f640d0E914B20CDDF985B269D2Dc16e0f767;
  address private constant MOC_COMMISSION_SPLITTER_V3 = 0x0dee24D1ffb67fA751a58042F2C7a858FFb3F207;
  address private constant MOC_V1 = 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F;

  address private constant OLD_BTC_TO_MOC = 0xb908E56e1f386d6F955569a687d5286F7e49A90F;
  address private constant OLD_RIF_TO_BTC = 0x30d4433fF09757D33fFf99Cbe49C6384463bF551;
  address private constant OLD_MOC_TO_BTC = 0x4954737CBbC5f6c31c108011BA3535484b97312A;
  address private constant OLD_BTC_TO_MOC_2 = 0xCDeCF0a565ef4a8df1b7109A6fc58C92fdCDB0C2;
  address private constant OLD_BTC_TO_RIF = 0x01e45Ea7a4B90963EA364968f491B5F7F6aCbca4;

  bytes32 private constant MOC_FLOW_REVERSE_AUCTIONS =
    0x0428ec087e0cce276a71d1caf1afe4da32a2d48b3ebe579040612b5bd262ff73;

  function testFork_DeployModuleAndExecuteChangerThroughGovernor() public {
    string memory rpcUrl = vm.envOr("RSK_TESTNET_RPC_URL", DEFAULT_RPC_URL);
    uint256 forkBlockNumber = 7930000;
    vm.createSelectFork(rpcUrl, forkBlockNumber);

    address mocSwapper = _deployMocSwapper();
    address mocToBtcMaxProvider = address(new DataProvider(PAUSER, 20_000 ether));
    address btcToMocMaxProvider = address(new DataProvider(PAUSER, 0.01 ether));
    address rifToMocMaxProvider = address(new DataProvider(PAUSER, 20_000 ether));
    address mocToRifMaxProvider = address(new DataProvider(PAUSER, 20_000 ether));
    address priceProviderInverse = _deployLegacy(
      "DeployablePriceProviderInverse.sol:DeployablePriceProviderInverse",
      abi.encode(MOC_TO_RIF_PROVIDER)
    );
    address uniswapV3Oracle = _deployLegacy(
      "DeployableUniswapV3Oracle.sol:DeployableUniswapV3Oracle",
      abi.encode(UNISWAP_V3_POOL, uint32(3600), MOC_TOKEN)
    );

    address reverseAuctionRifToMoc = address(
      new MocReverseAuction(
        GOVERNOR,
        MULTIHOP_SWAPPER,
        RIF_TOKEN,
        MOC_TOKEN,
        MOC_REWARDS_BUFFER,
        20_000 ether,
        priceProviderInverse,
        0.05 ether
      )
    );
    address reverseAuctionMocToBtc = address(
      new MocReverseAuction(
        GOVERNOR,
        mocSwapper,
        MOC_TOKEN,
        address(0),
        BTC_TO_MOC_OUTPUT_ACCOUNT,
        20_000 ether,
        MOC_TO_BTC_PROVIDER,
        0.03 ether
      )
    );
    address reverseAuctionMocToRif = address(
      new MocReverseAuction(
        GOVERNOR,
        MULTIHOP_SWAPPER,
        MOC_TOKEN,
        RIF_TOKEN,
        MOC_TO_RIF_OUTPUT_ACCOUNT,
        20_000 ether,
        MOC_TO_RIF_PROVIDER,
        0.05 ether
      )
    );
    address reverseAuctionBtcToMoc = address(
      new MocReverseAuction(
        GOVERNOR,
        mocSwapper,
        address(0),
        MOC_TOKEN,
        MOC_REWARDS_BUFFER,
        0.01 ether,
        uniswapV3Oracle,
        0.03 ether
      )
    );

    UpdateTestnetFlowChanger changer = new UpdateTestnetFlowChanger(
      ICommissionSplitter(RIF_COMMISSION_SPLITTER_V2),
      ICommissionSplitter(RIF_COMMISSION_SPLITTER_V3),
      reverseAuctionRifToMoc,
      FOUNDATION_MULTISIG,
      IBufferLike(RIF_PRO_REWARDS_BUFFER),
      reverseAuctionMocToRif,
      IBufferLike(DOCR_REWARDS_BUFFER),
      MOC_REWARDS_BUFFER,
      IBufferLike(BITPRO_REWARDS_BUFFER),
      reverseAuctionMocToBtc,
      COIN_PAIR_RBTC_USD,
      SUPPORTERS,
      IMoCCommissionSplitterV2(MOC_COMMISSION_SPLITTER_V2),
      IMoCCommissionSplitterV3(MOC_COMMISSION_SPLITTER_V3),
      reverseAuctionBtcToMoc,
      MOC_V1,
      IMocSwapperV3(mocSwapper),
      MOC_TOKEN,
      address(0),
      3000,
      mocToBtcMaxProvider,
      3000,
      btcToMocMaxProvider,
      IMocSwapperV3MultiHop(MULTIHOP_SWAPPER),
      RIF_TOKEN,
      WRBTC_TOKEN,
      3000,
      3000,
      3000,
      3000,
      rifToMocMaxProvider,
      mocToRifMaxProvider,
      IRegistryLike(REGISTRY),
      OLD_BTC_TO_MOC,
      OLD_RIF_TO_BTC,
      OLD_MOC_TO_BTC,
      OLD_BTC_TO_MOC_2,
      OLD_BTC_TO_RIF
    );

    address governorOwner = IOwnableLike(GOVERNOR).owner();
    vm.prank(governorOwner);
    IGovernorLike(GOVERNOR).executeChange(IChangeContract(address(changer)));

    IRegistryProbe registry = IRegistryProbe(REGISTRY);
    assertTrue(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, reverseAuctionBtcToMoc));
    assertTrue(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, reverseAuctionRifToMoc));
    assertTrue(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, reverseAuctionMocToBtc));
    assertTrue(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, reverseAuctionMocToRif));
    assertFalse(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, OLD_BTC_TO_MOC));
    assertFalse(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, OLD_RIF_TO_BTC));
    assertFalse(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, OLD_MOC_TO_BTC));
    assertFalse(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, OLD_BTC_TO_MOC_2));
    assertFalse(registry.addressArrayContains(MOC_FLOW_REVERSE_AUCTIONS, OLD_BTC_TO_RIF));
  }

  function _deployMocSwapper() internal returns (address) {
    MocSwapperV3 implementation = new MocSwapperV3();
    bytes memory initData = abi.encodeCall(
      MocSwapperV3.initialize,
      (GOVERNOR, PAUSER, SWAP_ROUTER, COINBASE_WRAPPER)
    );
    return address(new ERC1967Proxy(address(implementation), initData));
  }

  function _deployLegacy(string memory artifact_, bytes memory constructorArgs_) internal returns (address deployed_) {
    bytes memory creationCode = vm.getCode(artifact_);
    bytes memory initCode = bytes.concat(creationCode, constructorArgs_);

    assembly ("memory-safe") {
      deployed_ := create(0, add(initCode, 0x20), mload(initCode))
    }
    require(deployed_ != address(0), "legacy deployment failed");
  }
}
