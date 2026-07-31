// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { IChangeContract } from "../../interfaces/IChangeContract.sol";

interface ICommissionSplitter {
  function setAcTokenAddressRecipient1(address recipient_) external;
  function setAcTokenAddressRecipient2(address recipient_) external;
  function setAcTokenPctToRecipient1(uint256 percentage_) external;
  function setFeeTokenAddressRecipient1(address recipient_) external;
  function setFeeTokenAddressRecipient2(address recipient_) external;
  function setFeeTokenPctToRecipient1(uint256 percentage_) external;
}

interface IBufferLike {
  function addOutput(address payable output_, uint256 split_, uint256 threshold_) external;
  function removeOutput(uint256 index_) external;
  function getOutput(uint256 index_) external view returns (address, uint256, uint256, uint256);
}

interface IMoCCommissionSplitterV2 {
  function setOutputAddress_1(address payable outputAddress_) external;
  function setOutputAddress_2(address payable outputAddress_) external;
  function setOutputAddress_3(address payable outputAddress_) external;
  function setOutputProportion_1(uint256 proportion_) external;
  function setOutputProportion_2(uint256 proportion_) external;
  function setOutputTokenGovernAddress_1(address payable outputAddress_) external;
  function setOutputTokenGovernAddress_2(address payable outputAddress_) external;
  function setOutputProportionTokenGovern_1(uint256 proportion_) external;
}

interface IMoCCommissionSplitterV3 {
  function setOutputAddress_1(address payable outputAddress_) external;
  function setOutputAddress_2(address payable outputAddress_) external;
  function setOutputProportion_1(uint256 proportion_) external;
}

interface IMocSwapperV3 {
  function setPool(
    address tokenA_,
    address tokenB_,
    uint24 fee_,
    address providerSwappingAtoB_
  ) external;
}

interface IMocSwapperV3MultiHop {
  function setPath(
    address tokenA_,
    address tokenB_,
    address[] calldata intermediateTokens_,
    uint24[] calldata fees_,
    address providerSwappingAtoB_
  ) external;
}

interface IRegistryLike {
  function removeAddressArrayElement(bytes32 key_, address value_) external;
  function pushAddressArray(bytes32 key_, address[] calldata values_) external;
}

/**
 * @title UpdateTestnetFlowChanger
 * @notice Updates the RIF commission splitters used by the testnet flow.
 *
 * Percentages use the commission splitter precision (1e18 = 100%). The
 * splitter computes recipient2's percentage as the remainder.
 */
contract UpdateTestnetFlowChanger is IChangeContract {
  uint256 private constant V2_AC_RECIPIENT1_PERCENTAGE = 6666 * 1e14;
  uint256 private constant HALF_PERCENTAGE = 500 * 1e15;
  bytes32 private constant MOC_FLOW_REVERSE_AUCTIONS =
    0x0428ec087e0cce276a71d1caf1afe4da32a2d48b3ebe579040612b5bd262ff73;

  ICommissionSplitter public immutable rifCommissionSplitterV2;
  ICommissionSplitter public immutable rifCommissionSplitterV3;
  address public immutable reverseAuctionRifToMoc;
  address public immutable reverseAuctionMocToRif;
  address public immutable foundationMultiSig;
  IBufferLike public immutable rifProRewardsBuffer;
  IBufferLike public immutable docrRewardsBuffer;
  address public immutable mocRewardsBuffer;
  IBufferLike public immutable bitProRewardsBuffer;
  address public immutable reverseAuctionMocToBtc;
  address public immutable coinPairRBTCUSD;
  address public immutable supporters;
  IMoCCommissionSplitterV2 public immutable mocCommissionSplitterV2;
  IMoCCommissionSplitterV3 public immutable mocCommissionSplitterV3;
  address public immutable reverseAuctionBtcToMoc;
  address public immutable mocV1;
  IMocSwapperV3 public immutable mocSwapperV3;
  address public immutable mocToken;
  address public immutable btcToken;
  uint24 public immutable mocToBtcFee;
  address public immutable mocToBtcMaxAmountProvider;
  uint24 public immutable btcToMocFee;
  address public immutable btcToMocMaxAmountProvider;
  IMocSwapperV3MultiHop public immutable mocSwapperV3MultiHop;
  address public immutable rifToken;
  address public immutable wrbtcToken;
  uint24 public immutable rifToWrbtcFee;
  uint24 public immutable wrbtcToMocFee;
  uint24 public immutable mocToWrbtcFee;
  uint24 public immutable wrbtcToRifFee;
  address public immutable rifToMocMaxAmountProvider;
  address public immutable mocToRifMaxAmountProvider;
  IRegistryLike public immutable registry;
  address public immutable oldReverseAuctionBtcToMoc;
  address public immutable oldReverseAuctionRifToBtc;
  address public immutable oldReverseAuctionMocToBtc;
  address public immutable oldReverseAuctionMocToBtc2;
  address public immutable oldReverseAuctionBtcToRif;

  constructor(
    ICommissionSplitter rifCommissionSplitterV2_,
    ICommissionSplitter rifCommissionSplitterV3_,
    address reverseAuctionRifToMoc_,
    address foundationMultiSig_,
    IBufferLike rifProRewardsBuffer_,
    address reverseAuctionMocToRif_,
    IBufferLike docrRewardsBuffer_,
    address mocRewardsBuffer_,
    IBufferLike bitProRewardsBuffer_,
    address reverseAuctionMocToBtc_,
    address coinPairRBTCUSD_,
    address supporters_,
    IMoCCommissionSplitterV2 mocCommissionSplitterV2_,
    IMoCCommissionSplitterV3 mocCommissionSplitterV3_,
    address reverseAuctionBtcToMoc_,
    address mocV1_,
    IMocSwapperV3 mocSwapperV3_,
    address mocToken_,
    address btcToken_,
    uint24 mocToBtcFee_,
    address mocToBtcMaxAmountProvider_,
    uint24 btcToMocFee_,
    address btcToMocMaxAmountProvider_,
    IMocSwapperV3MultiHop mocSwapperV3MultiHop_,
    address rifToken_,
    address wrbtcToken_,
    uint24 rifToWrbtcFee_,
    uint24 wrbtcToMocFee_,
    uint24 mocToWrbtcFee_,
    uint24 wrbtcToRifFee_,
    address rifToMocMaxAmountProvider_,
    address mocToRifMaxAmountProvider_,
    IRegistryLike registry_,
    address oldReverseAuctionBtcToMoc_,
    address oldReverseAuctionRifToBtc_,
    address oldReverseAuctionMocToBtc_,
    address oldReverseAuctionMocToBtc2_,
    address oldReverseAuctionBtcToRif_
  ) {
    rifCommissionSplitterV2 = rifCommissionSplitterV2_;
    rifCommissionSplitterV3 = rifCommissionSplitterV3_;
    reverseAuctionRifToMoc = reverseAuctionRifToMoc_;
    reverseAuctionMocToRif = reverseAuctionMocToRif_;
    foundationMultiSig = foundationMultiSig_;
    rifProRewardsBuffer = rifProRewardsBuffer_;
    docrRewardsBuffer = docrRewardsBuffer_;
    mocRewardsBuffer = mocRewardsBuffer_;
    bitProRewardsBuffer = bitProRewardsBuffer_;
    reverseAuctionMocToBtc = reverseAuctionMocToBtc_;
    coinPairRBTCUSD = coinPairRBTCUSD_;
    supporters = supporters_;
    mocCommissionSplitterV2 = mocCommissionSplitterV2_;
    mocCommissionSplitterV3 = mocCommissionSplitterV3_;
    reverseAuctionBtcToMoc = reverseAuctionBtcToMoc_;
    mocV1 = mocV1_;
    mocSwapperV3 = mocSwapperV3_;
    mocToken = mocToken_;
    btcToken = btcToken_;
    mocToBtcFee = mocToBtcFee_;
    mocToBtcMaxAmountProvider = mocToBtcMaxAmountProvider_;
    btcToMocFee = btcToMocFee_;
    btcToMocMaxAmountProvider = btcToMocMaxAmountProvider_;
    mocSwapperV3MultiHop = mocSwapperV3MultiHop_;
    rifToken = rifToken_;
    wrbtcToken = wrbtcToken_;
    rifToWrbtcFee = rifToWrbtcFee_;
    wrbtcToMocFee = wrbtcToMocFee_;
    mocToWrbtcFee = mocToWrbtcFee_;
    wrbtcToRifFee = wrbtcToRifFee_;
    rifToMocMaxAmountProvider = rifToMocMaxAmountProvider_;
    mocToRifMaxAmountProvider = mocToRifMaxAmountProvider_;
    registry = registry_;
    oldReverseAuctionBtcToMoc = oldReverseAuctionBtcToMoc_;
    oldReverseAuctionRifToBtc = oldReverseAuctionRifToBtc_;
    oldReverseAuctionMocToBtc = oldReverseAuctionMocToBtc_;
    oldReverseAuctionMocToBtc2 = oldReverseAuctionMocToBtc2_;
    oldReverseAuctionBtcToRif = oldReverseAuctionBtcToRif_;
  }

  function execute() external override {
    // V2: 66.66% to Foundation and the 33.34% remainder to the reverse auction.
    rifCommissionSplitterV2.setAcTokenAddressRecipient1(foundationMultiSig);
    rifCommissionSplitterV2.setAcTokenAddressRecipient2(reverseAuctionRifToMoc);
    rifCommissionSplitterV2.setAcTokenPctToRecipient1(V2_AC_RECIPIENT1_PERCENTAGE);

    // V2 fee token: 50% to Foundation and 50% to the RIF Pro rewards buffer.
    rifCommissionSplitterV2.setFeeTokenAddressRecipient1(foundationMultiSig);
    rifCommissionSplitterV2.setFeeTokenAddressRecipient2(address(rifProRewardsBuffer));
    rifCommissionSplitterV2.setFeeTokenPctToRecipient1(HALF_PERCENTAGE);

    // V3: split the AC balance evenly between Foundation and the reverse auction.
    rifCommissionSplitterV3.setAcTokenAddressRecipient1(foundationMultiSig);
    rifCommissionSplitterV3.setAcTokenAddressRecipient2(reverseAuctionRifToMoc);
    rifCommissionSplitterV3.setAcTokenPctToRecipient1(HALF_PERCENTAGE);

    // Replace output0 of DocrRewardsBuffer, preserving its split and threshold.
    (, uint256 split, , uint256 threshold) = docrRewardsBuffer.getOutput(0);
    docrRewardsBuffer.removeOutput(0);
    docrRewardsBuffer.addOutput(payable(mocRewardsBuffer), split, threshold);

    // Replace output0 of BitProRewardsBuffer, preserving its split and threshold.
    (, split, , threshold) = bitProRewardsBuffer.getOutput(0);
    bitProRewardsBuffer.removeOutput(0);
    bitProRewardsBuffer.addOutput(payable(reverseAuctionMocToBtc), split, threshold);

    // Replace output0 of RifProRewardsBuffer, preserving its split and threshold.
    (, split, , threshold) = rifProRewardsBuffer.getOutput(0);
    rifProRewardsBuffer.removeOutput(0);
    rifProRewardsBuffer.addOutput(payable(reverseAuctionMocToRif), split, threshold);

    // Rebuild MocRewardsBuffer with 30% for CoinPairRBTCUSD and 70% for Supporters.
    (, , , threshold) = IBufferLike(mocRewardsBuffer).getOutput(0);
    IBufferLike(mocRewardsBuffer).removeOutput(0);
    IBufferLike(mocRewardsBuffer).addOutput(payable(coinPairRBTCUSD), 30, threshold);
    IBufferLike(mocRewardsBuffer).addOutput(payable(supporters), 70, threshold);

    // MoC V1 commission splitter: 50% Foundation, 40% reverse auction, 10% MoC V1.
    mocCommissionSplitterV2.setOutputAddress_1(payable(foundationMultiSig));
    mocCommissionSplitterV2.setOutputAddress_2(payable(reverseAuctionBtcToMoc));
    mocCommissionSplitterV2.setOutputAddress_3(payable(mocV1));
    mocCommissionSplitterV2.setOutputProportion_1(500 * 1e15); 
    mocCommissionSplitterV2.setOutputProportion_2(400 * 1e15);

    // MoC governance token: 50% Foundation and 50% BitProRewardsBuffer.
    mocCommissionSplitterV2.setOutputTokenGovernAddress_1(payable(foundationMultiSig));
    mocCommissionSplitterV2.setOutputTokenGovernAddress_2(payable(address(bitProRewardsBuffer)));
    mocCommissionSplitterV2.setOutputProportionTokenGovern_1(500 * 1e15);

    // MoC V1 BitPro interest splitter: 50% Foundation and 50% reverse auction.
    mocCommissionSplitterV3.setOutputAddress_1(payable(foundationMultiSig));
    mocCommissionSplitterV3.setOutputAddress_2(payable(reverseAuctionBtcToMoc));
    mocCommissionSplitterV3.setOutputProportion_1(500 * 1e15);

    mocSwapperV3.setPool(mocToken, btcToken, mocToBtcFee, mocToBtcMaxAmountProvider);
    mocSwapperV3.setPool(btcToken, mocToken, btcToMocFee, btcToMocMaxAmountProvider);

    address[] memory rifToMocIntermediateTokens = new address[](1);
    rifToMocIntermediateTokens[0] = wrbtcToken;
    uint24[] memory rifToMocFees = new uint24[](2);
    rifToMocFees[0] = rifToWrbtcFee;
    rifToMocFees[1] = wrbtcToMocFee;
    mocSwapperV3MultiHop.setPath(
      rifToken,
      mocToken,
      rifToMocIntermediateTokens,
      rifToMocFees,
      rifToMocMaxAmountProvider
    );

    address[] memory mocToRifIntermediateTokens = new address[](1);
    mocToRifIntermediateTokens[0] = wrbtcToken;
    uint24[] memory mocToRifFees = new uint24[](2);
    mocToRifFees[0] = mocToWrbtcFee;
    mocToRifFees[1] = wrbtcToRifFee;
    mocSwapperV3MultiHop.setPath(
      mocToken,
      rifToken,
      mocToRifIntermediateTokens,
      mocToRifFees,
      mocToRifMaxAmountProvider
    );

    // Remove only the legacy reverse auctions being replaced. Other reverse
    // auctions registered under this key must remain untouched.
    registry.removeAddressArrayElement(MOC_FLOW_REVERSE_AUCTIONS, oldReverseAuctionBtcToMoc);
    registry.removeAddressArrayElement(MOC_FLOW_REVERSE_AUCTIONS, oldReverseAuctionRifToBtc);
    registry.removeAddressArrayElement(MOC_FLOW_REVERSE_AUCTIONS, oldReverseAuctionMocToBtc);
    registry.removeAddressArrayElement(MOC_FLOW_REVERSE_AUCTIONS, oldReverseAuctionMocToBtc2);
    registry.removeAddressArrayElement(MOC_FLOW_REVERSE_AUCTIONS, oldReverseAuctionBtcToRif);

    address[] memory reverseAuctions = new address[](4);
    reverseAuctions[0] = reverseAuctionBtcToMoc;
    reverseAuctions[1] = reverseAuctionRifToMoc;
    reverseAuctions[2] = reverseAuctionMocToBtc;
    reverseAuctions[3] = reverseAuctionMocToRif;
    registry.pushAddressArray(MOC_FLOW_REVERSE_AUCTIONS, reverseAuctions);
  }
}
