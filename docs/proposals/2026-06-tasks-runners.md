# Tasks runners

## Overview

...

The proposal has two primary objectives:

...

## Problem Statement

...

## Proposed Changes

### 1. ...

...

### 2. ...

...

### 3. ...

...

### 4. Additional Protocol Improvements

The following changes are independent from ... and are included in this proposal as protocol maintenance and improvement tasks.

Since a governance upgrade process is already required, these changes can be executed together, reducing operational overhead and avoiding the need for additional governance proposals.

#### 4.1 ...

...

#### 4.2 ...
...


#### 4.3 Non-critical Bug Fix: ..

> :information_source: Info: This bug is not exploitable.

> :information_source: Info: Although non-critical, we will fix it as part of this upgrade to avoid a separate governance proposal and reduce operational overhead.

##### Description

...

##### Fix

...


## Summary

This proposal improves the long-term sustainability and robustness of the Money on Chain protocol by:

- ...
- ...
- ...

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

- ...
- ...
- ...

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
