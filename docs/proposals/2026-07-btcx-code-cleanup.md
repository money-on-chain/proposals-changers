# Code Cleanup for Deprecated BTCX Leveraged Positions (and Bug Fixes)


## Overview

The _Money on Chain_ protocol previously supported leveraged positions known as BTCX, which were deactivated in February 2023 through the [Technical proposal for removal of leveraged positions](https://forum.moneyonchain.com/t/technical-proposal-for-removal-of-leveraged-positions/308). However, deprecated code related to the daily inrate payment logic for these leveraged positions remains in the codebase, even though this functionality is no longer being used. This cleanup removes the obsolete code, reducing unnecessary complexity and improving code maintainability.

## Proposed Changes

The deprecated code related to leveraged positions inrate payment logic will be removed from the protocol contracts. This cleanup ensures:

- **Gas & Cost Efficiency**: Reduces gas consumption and eliminates daily operational costs for BPRO holders
- **Improved Code Quality**: Cleaner, more maintainable codebase that is easier to read and understand
- **Enhanced Auditability**: Simplified code analysis for security auditors and reduces the attack surface by eliminating unused logic

#### Technical Implementation

> :warning: Warning: some technical/coding knowledge is necessary to fully understand this document

This code cleanup for _deprecated BTCX leveraged positions_ will be implemented through the changes introduced in the [Remove dailyInratePayment #119](https://github.com/money-on-chain/main-RBTC-contract/pull/119) pull request, which removes unused contract-level code.

### 2. Additional Protocol Improvements

The following changes are independent from the _code cleanup for deprecated BTCX leveraged positions_ and are included in this proposal as protocol maintenance and improvement tasks.

Since a governance upgrade process is already required, these changes can be executed together, reducing operational overhead and avoiding the need for additional governance proposals.

#### 2.1 Non-critical Bug Fix: Unsupported Pegged Token Addresses in ROC Queue Transactions

> :information_source: Info: Although non-critical, we will fix it as part of this upgrade to avoid a separate governance proposal and reduce operational overhead.

##### Description

Some functions that enqueue transactions into the _RIF on Chain_ protocol currently allow unsupported pegged token addresses to be passed as arguments. These transactions are known to fail later when pending queue execution is processed, creating unnecessary gas costs for users and delivering the false impression that the operation was supported.

##### Fix

The _RIF on Chain_ queue-enqueue functions will validate that any token address passed as an argument corresponds to a peg token supported by the protocol before accepting the transaction into the queue. This change prevents unsupported pegged token transactions from being queued and avoids later execution failures and unexpected user expense.


## Summary

This proposal improves the long-term maintainability and reliability of the _Money on Chain_ protocol by:

- removing deprecated BTCX leveraged-position code and obsolete daily inrate payment logic
- reducing protocol complexity and improving auditability
- saving gas and eliminating the marginal daily operational costs for BPRO holders
- preventing unsupported pegged token transactions from being queued in the _RIF on Chain_ queue
- avoiding later queue execution failures and unexpected user expenses

Together, these changes simplify the protocol codebase, reduce operational risk, and support better transaction handling for queued operations.

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a **governance vote**.

The upgrade will be executed only after:

1. Proposal approval through governance
2. Deployment of the changer contract
3. Execution of the upgrade transaction

---

## Technical Procedure

> :warning: Warning: some technical/coding knowledge is necessary to fully understand this document.

The upgrade will be executed through a **changer contract**, which will:

- Remove deprecated BTCX leveraged-position code and obsolete daily inrate payment logic from the relevant contracts
- Add validation to queue-enqueue functions so unsupported pegged token addresses cannot be accepted as transaction arguments


---

## Changer Contract

### The changer contract to vote would be:

| Name | Address (and link to verified code in RSK blockscout explorer) |
| :---- | :---- |
| `HardeningII` | [`0x00000000000000000000000000000000000FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |

---

## Existing Contracts to be upgraded


#### The following contracts are already part of the protocol and will be upgraded for the [code cleanup for deprecated BTCX leveraged positions](#code-cleanup-for-deprecated-btcx-leveraged-positions-and-bug-fixes):

| Name | Type | Address |
| :---- | :----: | :---- |
| `MocV1`             | Proxy              | [`0xf773...68370`](https://rootstock.blockscout.com/address/0xf773B590aF754D597770937Fa8ea7AbDf2668370?tab=contract) |
| `MocV1`             | Implementation     | [`0xa60c...07250`](https://rootstock.blockscout.com/address/0xa60c124c197Ff16162f484A5AAd8691f01c07250?tab=contract) |
| `MocV1`             | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |
| `MocStateV1`        | Proxy              | [`0xb9C4...1e257`](https://rootstock.blockscout.com/address/0xb9C42EFc8ec54490a37cA91c423F7285Fa01e257?tab=contract) |
| `MocStateV1`        | Implementation     | [`0x1D82...06722`](https://rootstock.blockscout.com/address/0x1D827c823D01Acfa4E15959541e310C5FB506722?tab=contract) |
| `MocStateV1`        | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |
| `MocExchangeV1`     | Proxy              | [`0x6aCb...49038`](https://rootstock.blockscout.com/address/0x6aCb83bB0281FB847b43cf7dd5e2766BFDF49038?tab=contract) |
| `MocExchangeV1`     | Implementation     | [`0xFc88...B6FC1`](https://rootstock.blockscout.com/address/0xFc88703c22aeC7E072369D227C063B4D0cAB6FC1?tab=contract) |
| `MocExchangeV1`     | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |
| `MocInrateV1`       | Proxy              | [`0xc0f9...0A3F3`](https://rootstock.blockscout.com/address/0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3?tab=contract) |
| `MocInrateV1`       | Implementation     | [`0xe9B1...ac918`](https://rootstock.blockscout.com/address/0xe9B15bE6E7CD575b15A197de6a536f39b32ac918?tab=contract) |
| `MocInrateV1`       | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |
| `MocBProxManagerV1` | Proxy              | [`0xC4fB...03b6c`](https://rootstock.blockscout.com/address/0xC4fBFa2270Be87FEe5BC38f7a1Bb6A9415103b6c?tab=contract) |
| `MocBProxManagerV1` | Implementation     | [`0xeE35...a4e89`](https://explorer.rootstock.io/address/0xee35b51edf623533a83d3aef8f1518ff67da4e89?tab=contract)    |
| `MocBProxManagerV1` | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |


#### The following contracts are already part of the protocol and will be upgraded for the [2.1 Non-critical Bug Fix: Unsupported Pegged Token Addresses in ROC Queue Transactions](#21-non-critical-bug-fix-unsupported-pegged-token-addresses-in-roc-queue-transactions):

| Name | Type | Address |
| :---- | :----: | :---- |
| `RifBucket` | Proxy              | [`0xA270...aA36A`](https://rootstock.blockscout.com/address/0xA27024Ed70035E46dba712609fc2Afa1c97aA36A?tab=contract) |
| `RifBucket` | Implementation     | [`0x1a27...Fec54`](https://rootstock.blockscout.com/address/0x1a2702D60a8B68b845709155B3d97E1DA85Fec54?tab=contract) |
| `RifBucket` | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |
| `DocBucket` | Proxy              | [`0x6975...84661`](https://rootstock.blockscout.com/address/0x697535055Aa7AfD2C280523C7B062b1F05284661?tab=contract) |
| `DocBucket` | Implementation     | [`0xF920...F5a9B`](https://rootstock.blockscout.com/address/0xF9208cA168FF7ccAFd120edbf39Cf86b625F5a9B?tab=contract) |
| `DocBucket` | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) **(TBD)** |


---
