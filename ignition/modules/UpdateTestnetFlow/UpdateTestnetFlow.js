import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const registryAddress = "0xf078375a3dD89dDF4D9dA460352199C6769b5f10";
const oldReverseAuctionBtcToMoc = "0xb908E56e1f386d6F955569a687d5286F7e49A90F";
const oldReverseAuctionRifToBtc = "0x30d4433fF09757D33fFf99Cbe49C6384463bF551";
const oldReverseAuctionMocToBtc = "0x4954737CBbC5f6c31c108011BA3535484b97312A";
const oldReverseAuctionMocToBtc2 = "0xCDeCF0a565ef4a8df1b7109A6fc58C92fdCDB0C2";
const oldReverseAuctionBtcToRif = "0x01e45Ea7a4B90963EA364968f491B5F7F6aCbca4";
export default buildModule("UpdateTestnetFlowModule", (m) => {
  const mocSwapperV3Implementation = m.contract("MocSwapperV3", [], {
    id: "MocSwapperV3Implementation",
  });
  const mocSwapperV3InitData = m.encodeFunctionCall(
    mocSwapperV3Implementation,
    "initialize",
    [
      "0x7b716178771057195bB511f0B1F7198EEE62Bc22", // governor
      "0x5bCdf8A2E61BD238AEe43b99962Ee8BfBda1Beca", // pauser
      "0x1Adac2EA80F7533d0c361E68f09Af9Dd1F22359b", // swapRouter
      "0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab", // coinbaseWrapper
    ],
    { id: "MocSwapperV3InitData" },
  );
  const mocSwapperV3 = m.contract(
    "ERC1967Proxy",
    [mocSwapperV3Implementation, mocSwapperV3InitData],
    { id: "MocSwapperV3" },
  );

  const mocSwapperV3MultiHop = "0xF607f5defD2Bb3C1a95E5fc41343016cCB45fDcA";

  const mocToBtcMaxAmountProvider = m.contract(
    "DataProvider",
    ["0x5bCdf8A2E61BD238AEe43b99962Ee8BfBda1Beca", "20000000000000000000000"],
    { id: "MocToBtcMaxAmountProvider" },
  );
  const btcToMocMaxAmountProvider = m.contract(
    "DataProvider",
    ["0x5bCdf8A2E61BD238AEe43b99962Ee8BfBda1Beca", "10000000000000000"],
    { id: "BtcToMocMaxAmountProvider" },
  );
  const rifToMocMaxAmountProvider = m.contract(
    "DataProvider",
    ["0x5bCdf8A2E61BD238AEe43b99962Ee8BfBda1Beca", "20000000000000000000000"],
    { id: "RifToMocMaxAmountProvider" },
  );
  const mocToRifMaxAmountProvider = m.contract(
    "DataProvider",
    ["0x5bCdf8A2E61BD238AEe43b99962Ee8BfBda1Beca", "20000000000000000000000"],
    { id: "MocToRifMaxAmountProvider" },
  );

  const priceProviderInverse = m.contract(
    "PriceProviderInverse",
    ["0x4f9724e78e7cd521c879b6b9ee7d5b4e7df3cfbc"],
    {
      id: "PriceProviderInverseRifToMoc",
    },
  );
  const uniswapV3Oracle = m.contract(
    "UniswapV3Oracle",
    [
      "0x536af50B25887808C6100343772eDed07C5bC414",
      3600,
      "0x45a97b54021a3F99827641AFe1BFAE574431e6ab",
    ],
    { id: "UniswapV3OracleBtcToMoc" },
  );

  const reverseAuctionRifToMoc = m.contract(
    "MocReverseAuction",
    [
      "0x7b716178771057195bB511f0B1F7198EEE62Bc22", // governor
      mocSwapperV3MultiHop,
      "0x19F64674D8A5B4E652319F5e239eFd3bc969A1fE", // tokenIn RIF
      "0x45a97b54021a3F99827641AFe1BFAE574431e6ab", // tokenOut MOC
      "0x40d86d6ac67059bAe5ae42B6FCaB843c1c6af300", // outputAccount mocRewardsBuffer
      "20000000000000000000000", // orderThreshold
      priceProviderInverse,
      "50000000000000000", // slippage
    ],
    { id: "ReverseAuctionRifToMoc" },
  );
  const reverseAuctionMocToBtc = m.contract(
    "MocReverseAuction",
    [
      "0x7b716178771057195bB511f0B1F7198EEE62Bc22", // governor
      mocSwapperV3,
      "0x45a97b54021a3F99827641AFe1BFAE574431e6ab", // tokenIn MOC
      "0x0000000000000000000000000000000000000000", // tokenOut BTC
      "0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F", // outputAccount MocV1
      "20000000000000000000000", // orderThreshold
      "0x6C3A218AF21b82E17BC684c0B2DB3C799a3c66c1", // priceProvider mocToBtcPriceProvider
      "30000000000000000", // slippage
    ],
    {
      id: "ReverseAuctionMocToBtc",
    },
  );
  const reverseAuctionMocToRif = m.contract(
    "MocReverseAuction",
    [
      "0x7b716178771057195bB511f0B1F7198EEE62Bc22", // governor
      mocSwapperV3MultiHop,
      "0x45a97b54021a3F99827641AFe1BFAE574431e6ab", // tokenIn MOC
      "0x19F64674D8A5B4E652319F5e239eFd3bc969A1fE", // tokenOut RIF
      "0xa416934264515bb381E3b746f10f22D5c6f9431a", // outputAccount RIFBucket
      "20000000000000000000000", // orderThreshold
      "0x4F9724e78e7Cd521c879b6B9eE7D5b4e7df3cfbC", // priceProvider MocToRifPriceProvider
      "50000000000000000", // slippage
    ],
    { id: "ReverseAuctionMocToRif" },
  );
  const reverseAuctionBtcToMoc = m.contract(
    "MocReverseAuction",
    [
      "0x7b716178771057195bB511f0B1F7198EEE62Bc22", // governor
      mocSwapperV3,
      "0x0000000000000000000000000000000000000000", // tokenIn BTC
      "0x45a97b54021a3F99827641AFe1BFAE574431e6ab", // tokenOut MOC
      "0x40d86d6ac67059bAe5ae42B6FCaB843c1c6af300", // outputAccount mocRewardsBuffer
      "10000000000000000", // orderThreshold
      uniswapV3Oracle,
      "30000000000000000", // slippage
    ],
    {
      id: "ReverseAuctionBtcToMoc",
    },
  );

  const changer = m.contract("UpdateTestnetFlowChanger", [
    "0x499072990571C49Ef9369624885581b9C5aF0B11", // rifCommissionSplitterV2
    "0xD1FF3909dCa7C755F38e4FF04ce7170b4940d89B", // rifCommissionSplitterV3
    reverseAuctionRifToMoc,
    "0xf69287F5Ca3cC3C6d3981f2412109110cB8af076", // foundationMultiSig
    "0x1eDaDfd891793a5D1a011fFB82635C2Bbedc2511", // rifProRewardsBuffer
    reverseAuctionMocToRif,
    "0x6e364c96a83B72fe69843E50Fe08D09495AB0100", // docrRewardsBuffer
    "0x40d86d6ac67059bAe5ae42B6FCaB843c1c6af300", // mocRewardsBuffer
    "0xb998C3Da8D24295406d308ea42c85c8acDa880Ba", // bitProRewardsBuffer
    reverseAuctionMocToBtc,
    "0x39192498FcF1dBE11653040bB49308E09A1056AC", // coinPairRBTCUSD
    "0x2Bb08e5DFb88477A88180Fbb7eF8196fbdea4Cd5", // supporters
    "0xFA17f640d0E914B20CDDF985B269D2Dc16e0f767", // mocCommissionSplitterV2
    "0x0dee24D1ffb67fA751a58042F2C7a858FFb3F207", // mocCommissionSplitterV3
    reverseAuctionBtcToMoc,
    "0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F", // mocV1
    mocSwapperV3,
    "0x45a97b54021a3F99827641AFe1BFAE574431e6ab", // mocToken
    "0x0000000000000000000000000000000000000000", // btcToken
    3000, // mocToBtcFee
    mocToBtcMaxAmountProvider,
    3000, // btcToMocFee
    btcToMocMaxAmountProvider,
    mocSwapperV3MultiHop,
    "0x19F64674D8A5B4E652319F5e239eFd3bc969A1fE", // rifToken
    "0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab", // wrbtcToken
    3000, // rifToWrbtcFee
    3000, // wrbtcToMocFee
    3000, // mocToWrbtcFee
    3000, // wrbtcToRifFee
    rifToMocMaxAmountProvider,
    mocToRifMaxAmountProvider,
    registryAddress,
    oldReverseAuctionBtcToMoc,
    oldReverseAuctionRifToBtc,
    oldReverseAuctionMocToBtc,
    oldReverseAuctionMocToBtc2,
    oldReverseAuctionBtcToRif,
  ]);

  return {
    reverseAuctionRifToMoc,
    reverseAuctionMocToBtc,
    reverseAuctionMocToRif,
    reverseAuctionBtcToMoc,
    mocToBtcMaxAmountProvider,
    btcToMocMaxAmountProvider,
    rifToMocMaxAmountProvider,
    mocToRifMaxAmountProvider,
    changer,
  };
});
