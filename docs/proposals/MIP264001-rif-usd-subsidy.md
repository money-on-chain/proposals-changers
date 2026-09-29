# RIF/USD Subsidy

> :memo: `MIP#264001`

> :warning: **Status: DRAFT**

## Overview

This proposal completes the operational funding path for the `RIF/USD` oracle service introduced in [MIP#263101](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md) and used by RoC and MoC in [MIP#263102](MIP263102-use-omoc-tasks-runner-and-rif-usd-in-roc-and-moc.md).

It deploys an `RBTC → MOC` reverse auction whose MOC output goes directly to the `RIF/USD` CoinPair. The proposal registers a `TaskTriggerOrder` for this auction in OMOC's `TasksRunner`, allowing participating operators to execute it when its RBTC balance reaches the configured threshold.

The proposal also retires the dedicated RIF/DOC multi-hop swapper from active use. It configures the shared `MocSwapperV3Multihop` with the paths needed by the RIF and DOC buckets, switches the two existing DOC/MOC reverse auctions to that swapper, and makes it the guard's swapper for both bucket directions.

---

## Motivation

The `RIF/USD` CoinPair needs MOC to compensate its oracle operators. The protocol already uses reverse auctions to convert accumulated assets into MOC for equivalent operational destinations. This proposal gives the `RIF/USD` CoinPair the same mechanism: it accumulates RBTC, converts it to MOC through the established `RBTC → MOC` swapper, and sends the output to the CoinPair.

The RIF and DOC buckets currently depend on a dedicated `MocSwapperV3Multihop` for their cross-bucket conversions. The shared swapper is already deployed and used by the protocol. Configuring the required paths there consolidates swap execution in that component while retaining the existing maximum-swap providers.

---

## Proposed Changes

### 1. Create the RIF/USD subsidy reverse auction

The proposal deploys a `MocReverseAuction` with:

| Parameter                                     | Value                                                                         |
| :-------------------------------------------- | :---------------------------------------------------------------------------- |
| Input token                                   | RBTC                                                                          |
| Output token                                  | MOC, read from the RIF bucket's `feeToken`                                    |
| Output account                                | `RIF/USD` CoinPair, read from the RIF bucket's peg container                  |
| Swapper                                       | The existing `RBTC → MOC` swapper used by the guard's execution-fee recipient |
| Order threshold, price provider, and slippage | The values used by that existing RBTC-to-MOC reverse auction                  |

Reading these values at deployment keeps the new auction aligned with the active protocol configuration without duplicating addresses or economic parameters in the deployment inputs.

### 2. Register its task in OMOC `TasksRunner`

The proposal deploys a `TaskTriggerOrder` for the new reverse auction and adds it to OMOC's `TasksRunner` at [`0xd99a43ba443068Ea539CeB623aE24e6C9910b975`](https://rootstock.blockscout.com/address/0xd99a43ba443068Ea539CeB623AE24e6C9910b975?tab=contract).

The task becomes eligible when the reverse auction has accumulated at least its order threshold in RBTC. The task's revert backoff is 36,000 seconds. On execution, it triggers the auction and the resulting MOC is transferred directly to the `RIF/USD` CoinPair.

### 3. Move RIF/DOC paths to the shared multi-hop swapper

The proposal configures [`MocSwapperV3Multihop`](https://rootstock.blockscout.com/address/0x24122d7FF0EF57C18e5C333E2c7bD863e4F23c73?tab=contract) at `0x24122d7FF0EF57C18e5C333E2c7bD863e4F23c73` with these paths:

| Conversion | Path                     | Fees             |
| :--------- | :----------------------- | :--------------- |
| DOC → MOC  | DOC → USD0 → WRBTC → MOC | 3000, 3000, 3000 |
| MOC → DOC  | MOC → WRBTC → USD0 → DOC | 3000, 3000, 3000 |
| DOC → RIF  | DOC → USD0 → RIF         | 3000, 3000       |
| RIF → DOC  | RIF → USD0 → DOC         | 3000, 3000       |

All routes configured by this proposal use USD0 where a USD-denominated intermediate asset is needed. They no longer use pools with USD₮, including the DOC-to-MOC and MOC-to-DOC routes.

The changer reads the RIF and DOC token addresses, the MOC fee token, and the existing maximum-swap providers from the deployed guard, buckets, and deprecated swapper. It preserves those providers when it configures the shared swapper.

### 4. Reconfigure the auctions and guard

The following existing reverse auctions will use the shared multi-hop swapper:

| Contract                              | Address                                                                                                                                          | Conversion |
| :------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------- | :--------- |
| `RevAuctionDOCtoMOC_rocRewardsBuffer` | [`0x883e3433c236Abd3c301FFc9B59EA478C0C21c9a`](https://rootstock.blockscout.com/address/0x883e3433c236Abd3c301FFc9B59EA478C0C21c9a?tab=contract) | DOC → MOC  |
| `RevAuctionMOCtoDOC_docBucket`        | [`0x3EB689a01c4e8ccaC7c72097104FF37Ccf907bBE`](https://rootstock.blockscout.com/address/0x3EB689a01c4e8ccaC7c72097104FF37Ccf907bBE?tab=contract) | MOC → DOC  |

The `MocMultiCollateralGuard` at [`0x0237Ad1f0831b479a344E56646BC48B0885cF46F`](https://rootstock.blockscout.com/address/0x0237Ad1f0831b479a344E56646BC48B0885cF46F?tab=contract) will also use the shared swapper for both RIF-to-DOC and DOC-to-RIF bucket conversions.

This removes the dedicated swapper at [`0x0E60154be285810DFa1d64FaC5acb4804d7A7ba0`](https://rootstock.blockscout.com/address/0x0E60154be285810DFa1d64FaC5acb4804d7A7ba0?tab=contract) from the active paths covered by this proposal.

---

## Expected Outcome

After execution:

- the `RIF/USD` CoinPair can receive MOC from a dedicated RBTC-to-MOC subsidy auction;
- OMOC `TasksRunner` operators can trigger that auction once its RBTC threshold is met;
- DOC/MOC and RIF/DOC conversions use the shared `MocSwapperV3Multihop` with the specified routes;
- the two existing DOC/MOC reverse auctions use the shared swapper; and
- the RIF/DOC dedicated swapper is no longer used by the guard or those reverse-auction flows.

---

## Verification

The implementation includes a Rootstock mainnet-fork test. It deploys and executes the changer against the deployed contracts, verifies the configured paths and maximum-swap providers, executes swaps through each of the four paths, and funds and triggers the new reverse auction. The test verifies that the `RIF/USD` CoinPair receives MOC and that the task does not enter its revert backoff.

---

## Governance Process

The change takes effect only when the approved changer is executed through MoC governance.

Before the vote, the deployed changer, reverse auction, and task addresses will be added to this document with links to their verified source code.

---

## Changer Contract

| Name                     | Address and verified source |
| :----------------------- | :-------------------------- |
| `MIP264001RifUsdSubsidy` | `TBD`                       |

## New Contracts

| Name                                      | Address |
| :---------------------------------------- | :------ |
| `RevAuctionRBTCtoMOC_rifUsdSubsidy`       | `TBD`   |
| `TaskTriggerOrderRBTCtoMOC_rifUsdSubsidy` | `TBD`   |
