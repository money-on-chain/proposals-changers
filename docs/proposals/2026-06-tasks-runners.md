# Tasks runner implementation proposal

## Overview

This proposal defines the implementation of a **Tasks Runner** for the Money on Chain protocol.

The Tasks Runner is a decentralized execution layer that extends the existing oracle coordination model beyond price publication.
It allows the oracle operator network to assign, execute, and earn compensation for periodic on-chain maintenance tasks that are essential for protocol operation.

The core idea is to use a consensus-based scheduling mechanism similar to the oracle price publication flow

This change brings additional autonomy and decentralization to the protocol while creating more revenue opportunities for oracle operators.

---

## Problem Statement

Decentralized oracles already coordinate themselves through a consensus mechanism to assign price publication turns.
In that process, one operator publishes the price and other operators verify that publication by signing it.

Price publication is a periodic task that must be completed for the protocol to function. Without a fresh price, the protocol cannot operate.

However, price publication is not the only periodic task required by the protocol.
Several other on-chain operations are also necessary for correct protocol execution and must run on a predetermined cadence.
These tasks consume gas and are currently executed by a centralized automator service operated by the foundation.

Examples of the current periodic tasks include:
- daily execution of the EMA calculation,
- periodic processing of queued transactions,
- execution of `MocFlow` components and their reverse auctions,
- other protocol maintenance flows that depend on timely on-chain execution.

Relying on a foundation-operated automator creates a central point of operational responsibility.
For the protocol to be more autonomous and decentralized, execution of these tasks should be delegated to oracle node operators using a similar turn-based consensus model to price publication.

---

## Proposed Changes

### 1. Implement the Tasks Runner concept

The Tasks Runner will be an on-chain coordination layer for periodic protocol maintenance tasks.

The same oracle network that already supports price publication will be able to support task execution.

### 2. Decentralized task scheduling and execution

The Tasks Runner will use a consensus-based scheduling mechanism to assign execution turns to oracle operators.
Assigned operators will be responsible for running the task on-chain during their slot.

The system will include fallback rules to ensure the task can still execute if the first assignee is unavailable 
in the same way it does when publishing prices. 
It may also include reward forfeiture if an assigned executor fails to run the task in its window.

### 3. Define the initial set of supported tasks

The proposal focuses on the most critical periodic tasks already required for protocol health:

- Daily EMA calculation,
- Periodic executions of queued transactions,
- `MocFlow` execution tasks, including reverse actions and other related components,

These tasks are necessary for the protocol to behave correctly and safely over time.

### 4. Introduce task execution revenue

Just like price publication, task execution will be economically rewarded.
The proposal introduces a revenue flow dedicated to task execution.
This reward should be sufficient to make task execution attractive to oracle operators and to allocate gas costs transparently.

This revenue model provides several benefits:
- it makes the protocol more autonomous and decentralized,
- it creates more earning opportunities for node operators,
- it increases demand for MOC by assigning economic value to protocol maintenance,
- it reinforces tokenomics through additional utility.

---

## Summary

This proposal implements a **Tasks Runner** to decentralize periodic protocol maintenance tasks.
It will:
- extend the oracle consensus model beyond price publication,
- delegate critical on-chain task execution to oracle node operators,
- reward operators for executing maintenance tasks,
- reduce reliance on the foundation-operated automator,
- strengthen protocol autonomy and decentralization,
- provide additional revenue opportunities for node operators,
- increase the utility of the MOC token through task execution incentives.

---

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
- deploy the Tasks Runner contracts,
- register the initial periodic tasks,
- configure the task reward flow,
- connect the Tasks Runner to existing protocol components.

The Tasks Runner implementation will keep the existing price publication consensus architecture as the basis for scheduling while introducing a parallel task execution layer.

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
