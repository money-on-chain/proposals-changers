# Oracle Reliability Fix and Protocol Unpause Proposal

## Overview

This document proposes a fix to the Money on Chain Decentralized Oracles (OMoC) protocol for a bug that has been identified.

> :information_source: Info: This change affects oracle operation and does not modify the economic model of the protocol.

This bug affects the reliability of the price provided by the oracle, which is a critical component of the protocol. For this reason, it has been decided to pause the protocol until a proper fix can be implemented. Once this proposal is approved and the patch is applied, the protocol will be safely unpaused.

## Proposed Changes

### Apply Fixes from PR #21

The protocol will incorporate the fixes introduced in:

https://github.com/money-on-chain/OMoC-Decentralized-Oracle/pull/21

## Technical procedure

> :warning: Warning: Some technical/coding knowledge is necessary to fully understand this document.

In order to fix OMoC a change contract must be deployed and it will be necessary go through the voting process to make the changes.

### The changer contract to vote would be:

|              Name              |                                          Address (and link to verified code in RSK blockscout explorer)                                          |
| :----------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------: |
| `CoinPairPriceUpgradeProposal` | [`0x8168488d431Ab46A9aBF905A9578F53BecC08F59`](https://rootstock.blockscout.com/address/0x8168488d431Ab46A9aBF905A9578F53BecC08F59?tab=contract) |
