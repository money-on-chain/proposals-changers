# Add RIF/USD and TasksRunner to OMOC; Use RIF/USD0 for Liquidity

> :memo: `MIP#263101`

> :warning: **Status: DRAFT**

## Overview

This proposal prepares the Money on Chain Decentralized Oracle protocol (OMOC) for the upcoming migration of RIF on Chain (RoC) and Money on Chain (MoC) to decentralized RIF/USD price provision and protocol task execution.

The proposed changer will:

- deploy and register the new RIF/USD coin pair in OMOC,
- deploy the TasksRunner infrastructure,
- give OMOC oracle operators time to review, upgrade, and subscribe to the new services before they are used by RoC and MoC,
- change the conversion route used for RIF revenue collected from RoC to use the more liquid USD0/RIF, WBTC/USD0, and MOC/WBTC pools,
- incorporate the OMOC circuit-breaker improvements described in [MIP#262701](MIP262701-omoc-circuit-breaker.md), and
- incorporate the protocol cleanup and fixes described in [MIP#262702](MIP262702-btcx-code-cleanup.md).

These changes are intended to further decentralize price provision and protocol operations while improving the reliability and efficiency of the revenue used to compensate OMOC operators.

---

## Motivation

### Prepare OMOC operators for the RoC and MoC migration

RoC and MoC currently depend on semi-centralized price feeders for the RIF price and on centralized automators for periodic protocol tasks. A separate future governance proposal will migrate those responsibilities to OMOC after the new services are operational and oracle operators have had sufficient time to adopt them.

Before that migration can take place, the RIF/USD coin pair and TasksRunner services must be available in OMOC. Oracle operators also need sufficient time to:

- review the new components,
- upgrade their nodes,
- subscribe to the RIF/USD coin pair,
- subscribe to the TasksRunner consensus, and
- verify that their infrastructure is ready to provide these services.

Deploying the facilities first separates operator onboarding from the later protocol migration and reduces operational risk.

### Improve the conversion of RoC revenue

Part of the revenue collected from RoC is converted from RIF into MOC tokens and used to compensate OMOC nodes. Because there is no direct MOC/RIF liquidity pool, this conversion requires multiple hops.

The existing route uses the WRBTC/RIF pair for one of those hops. That pair frequently lacks sufficient liquidity, which can delay payments and cause unnecessary value loss during conversion.

This proposal changes the conversion route to `RIF → USD0 → WBTC → MOC`, using the USD0/RIF, WBTC/USD0, and MOC/WBTC pools. These pools have substantially more liquidity than the WRBTC/RIF pool used by the existing route. The change is expected to:

- improve the timely payment of OMOC oracle revenue shares,
- reduce slippage and value lost during conversions, and
- make the revenue-conversion process more reliable.

---

## Proposed Changes

### 1. Add the RIF/USD coin pair to OMOC

The changer will deploy and register the contracts and configuration required for RIF/USD price consensus in OMOC.

This proposal only establishes the new coin pair and enables operator subscription. Migrating RoC and MoC to consume the resulting RIF/USD price will require a separate future governance proposal.

### 2. Add TasksRunner to OMOC

The changer will deploy the TasksRunner infrastructure used to coordinate recurring on-chain protocol operations among OMOC operators.

TasksRunner extends the oracle network's consensus-based operating model beyond price publication. Participating operators will be able to subscribe to task-execution consensus, receive execution turns, and execute registered protocol tasks on-chain.

The initial deployment is intended to give operators time to review and adopt the service. Migrating RoC and MoC tasks from centralized automators to TasksRunner will require a separate future governance proposal.

### 3. Use RIF/USD0 liquidity for RoC revenue conversion

The changer will replace the conversion hop that currently depends on WRBTC/RIF liquidity with the multi-hop route `RIF → USD0 → WBTC → MOC`. This route will use the USD0/RIF, WBTC/USD0, and MOC/WBTC pools, which have substantially greater available liquidity.

The conversion will remain multi-hop because no direct MOC/RIF pool exists.

### 4. Incorporate the OMOC circuit-breaker improvements

This proposal incorporates the improvements presented in [MIP#262701 — Implementation of an Oracle Circuit Breaker and some other improvements](MIP262701-omoc-circuit-breaker.md), including:

- the OMOC oracle circuit breaker, and
- automatic unsubscription of oracle operators whose stake falls below the required participation threshold.

### 5. Incorporate the protocol cleanup and fixes

This proposal also incorporates the improvements presented in [MIP#262702 — Code Cleanup for Deprecated BTCX Leveraged Positions (and Bug Fixes)](MIP262702-btcx-code-cleanup.md), including:

- removal of deprecated BTCX daily inrate payment logic, and
- validation preventing unsupported pegged-token addresses from being accepted in RoC queue transactions.

---

## Expected Outcome

After this proposal is executed:

- RIF/USD price consensus will be available in OMOC,
- TasksRunner consensus will be available in OMOC,
- operators will be able to upgrade and subscribe before RoC and MoC depend on the new services,
- RoC revenue conversion will use the more liquid RIF/USD0 route,
- OMOC will include the circuit-breaker and operator-unsubscription improvements from MIP#262701, and
- the cleanup and fixes from MIP#262702 will be incorporated.

The migration of RoC and MoC to these OMOC services will remain subject to a separate future governance proposal and vote.

---

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a governance vote.

The upgrade will be executed only after:

1. proposal approval through governance,
2. deployment and verification of the changer contract, and
3. execution of the approved changer.

---

## Technical Procedure

> :warning: Some technical or coding knowledge is necessary to fully understand this section.

The upgrade will be executed through a changer contract that deploys and configures the RIF/USD coin pair and TasksRunner infrastructure, updates the RoC revenue-conversion route, and incorporates the changes referenced in MIP#262701 and MIP#262702.

The exact contract list, parameters, and verified addresses will be added to this draft before the governance vote.

---

## Changer Contract

| Name  | Address and verified code |
| :---- | :------------------------ |
| `TBD` | `TBD`                     |

---

## Existing Contracts to Be Upgraded or Reconfigured

| Protocol  | Name  | Change                                       | Current Address | New Implementation or Configuration |
| :-------- | :---- | :------------------------------------------- | :-------------- | :---------------------------------- |
| OMOC      | `TBD` | RIF/USD, TasksRunner, and MIP#262701 changes | `TBD`           | `TBD`                               |
| RoC       | `TBD` | RIF revenue-conversion route                 | `TBD`           | `TBD`                               |
| MoC / RoC | `TBD` | MIP#262702 cleanup and fixes                 | `TBD`           | `TBD`                               |

---

## New Contracts

| Protocol | Name  | Purpose                                        | Address |
| :------- | :---- | :--------------------------------------------- | :------ |
| OMOC     | `TBD` | RIF/USD coin-pair infrastructure               | `TBD`   |
| OMOC     | `TBD` | TasksRunner infrastructure                     | `TBD`   |
| Other    | `TBD` | Additional contracts required by this proposal | `TBD`   |
