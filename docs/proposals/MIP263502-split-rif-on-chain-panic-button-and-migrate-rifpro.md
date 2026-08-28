# Split the RIF on Chain Panic Button and Migrate RIFPRO

> :memo: `MIP#263502`

> :warning: **Status: DRAFT**

## Overview

This proposal contains two changes. The main change gives RIF on Chain (RoC) more autonomy by separating its emergency circuit breaker from the one used by Money on Chain (MoC). The secondary change makes RIFPRO easier to understand for current and future holders by migrating it to a denomination in which one new RIFPRO is priced at one RIF at the time of migration.

The changes are executed together by one changer contract.

---

## Motivation

### Give RIF on Chain its own circuit breaker

After [MIP#263102](MIP263102-use-omoc-tasks-runner-and-rif-usd-in-roc-and-moc.md) is accepted, RoC will receive the RIF price through the decentralized OMOC oracle infrastructure. Even with decentralized price provision in place, RoC should retain a circuit breaker that can be activated when an exceptional situation requires immediate protection.

In the current threat environment, including increasingly automated and AI-assisted attacks, governance-delegated circuit breakers have proven to be a useful way to protect protocols and their users while an issue is assessed and addressed.

Today, MoC governance has delegated this responsibility to members of the Mimlabs Foundation. That delegation can activate the circuit breaker for both MoC and RoC. This proposal separates those responsibilities:

- the existing circuit-breaker delegation will continue to apply to MoC only; and
- RoC will have its own circuit breaker, delegated to a group of RootstockLabs and Mimlabs members.

RootstockLabs is a principal proponent of the RIF token and of its use as collateral in RoC. Its close understanding of the RIF ecosystem and attention to RIF markets make its members well suited to share this responsibility with Mimlabs.

This change does not alter governance's ultimate authority over either protocol. It gives RoC a dedicated emergency response path that is better aligned with the people closest to its collateral and market.

### Make RIFPRO easier to reason about

RoC has improved substantially in recent months, and RIFPRO is expected to grow beyond its current niche user base. The current denomination makes the token's price less intuitive than it needs to be for people evaluating the upside they receive when minting RIFPRO.

This proposal migrates RIFPRO to a new denomination so that, at migration, the price of one new RIFPRO is one RIF. The change is a denomination change only: it does not create or remove value for RIFPRO holders.

Holders of the legacy RIFPRO token will be shown a dialog that lets them exchange their tokens for the new token. The exchange preserves the value of each holder's position by issuing fewer new tokens at a correspondingly higher price.

---

## Proposed Changes

### 1. Split the panic button

The changer will update the pauser configuration across the relevant RoC and MoC components so that the existing MoC circuit-breaker delegation remains responsible for MoC, while a new delegated pauser is responsible for RoC.

The RoC pauser will be a group of RootstockLabs and Mimlabs members. It will have the delegated ability to activate RoC's circuit breaker when necessary to protect the protocol and its users.

### 2. Migrate RIFPRO to the new denomination

The changer will upgrade the RIF bucket to use a new RIFPRO token and configure a migrator from the legacy token to the new one.

The migration rate will be calculated from the bucket state at execution so that the new token starts at a one-RIF price while each legacy holder receives the economically equivalent amount of the new token. The migration therefore changes the unit in which RIFPRO is expressed, not the value of a holder's position.

---

## Expected Outcome

After this proposal is executed:

- MoC and RoC will have separate delegated circuit breakers;
- the existing delegation will be limited to MoC;
- a RootstockLabs and Mimlabs group will be able to activate RoC's dedicated circuit breaker;
- RIFPRO holders will be able to exchange legacy RIFPRO for the new denomination; and
- the new RIFPRO token will start with a price of one RIF per token, while the value of each migrated holding is preserved.

---

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a governance vote.

The upgrade will be executed only after:

1. proposal approval through governance;
2. deployment and verification of the changer contract;
3. execution of the approved changer.

---

## Changer Contract

The changer address and its verified-source URL will be added before the governance vote.

For implementation-level questions, readers can give their preferred AI assistant the verified contract URL. The verified source code contains the complete implementation and can be used to answer specific technical questions about the change.

| Changer address and verified source |
| :---- |
| `TBD` |
