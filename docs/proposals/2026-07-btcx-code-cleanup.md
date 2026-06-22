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

#### 2.1 Non-critical Bug Fix: [To be documented]

> :information_source: Info: This bug is not exploitable 

> :information_source: Info: Although non-critical, we will fix it as part of this upgrade to avoid a separate governance proposal and reduce operational overhead.

##### Description

[Detailed description of the bug to be added]

##### Fix

[Explanation of the fix to be added]


## Summary

[Summary to be added]

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

- [add step]
- [add step]


---

## Changer Contract

### The changer contract to vote would be:

| Name | Address (and link to verified code in RSK blockscout explorer) |
| :---- | :---- |
| `GenericChanger` | [`0x00000000000000000000000000000000000FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |

---

## Existing Contracts to be upgraded

The following contracts are already part of the protocol and will be upgraded as part of this proposal:

| Name | Type | Address |
| :---- | :----: | :---- |
| `GenericContract1` | Proxy              | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContract1` | Implementation     | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContract1` | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContract2` | Proxy              | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContract2` | Implementation     | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContract2` | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContractN` | Proxy              | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContractN` | Implementation     | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |
| `GenericContractN` | New implementation | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) |



---

## Existing Contracts to be reconfigured

The following contracts are already part of the protocol and will be reconfigured as part of this proposal:

| Name | Address | Why? |
| :---- | :----: | :---- |
| `GenericContractA` | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) | [Link](#fixme) |
| `GenericContractB` | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) | [Link](#fixme) |
| `GenericContractC` | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) | [Link](#fixme) |


---

## New Contracts

| Name | Address | Why? |
| :---- | :----: | :---- |
| `GenericNewContract1` | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) | [Link](#fixme) |
| `GenericNewContract2` | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) | [Link](#fixme) |
| `GenericNewContract3` | [`0x0000...FIXME`](https://rootstock.blockscout.com/address/0x00000000000000000000000000000000000FIXME?tab=contract) | [Link](#fixme) |

---
