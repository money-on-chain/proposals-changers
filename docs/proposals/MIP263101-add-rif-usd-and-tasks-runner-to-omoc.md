# Add RIF/USD and TasksRunner to OMOC; Use RIF/USD0 for Liquidity

> :memo: `MIP#263101`

> :warning: **Status: DRAFT**

## Overview

This proposal prepares the Money on Chain Decentralized Oracle protocol (`OMOC`) for the upcoming migration of RIF on Chain (_RoC_) and Money on Chain (_MoC_) to decentralized RIF/USD price provision and protocol task execution.

The proposed changer will:

- Deploy and register the new `RIF/USD` coin pair in `OMOC`,
- Deploy the TasksRunner infrastructure,
- Give `OMOC` oracle operators time to review, upgrade, and subscribe to the new services before they are used by _RoC_ and _MoC_,
- Change the conversion route used for `RIF` revenue collected from _RoC_ to use the more liquid `USD0/RIF`, `WBTC/USD0`, and `MOC/WBTC` pools,
- Incorporate the OMOC circuit-breaker improvements described in [MIP#262701](MIP262701-omoc-circuit-breaker.md), and
- Incorporate the protocol cleanup and fixes described in [MIP#262702](MIP262702-btcx-code-cleanup.md).

These changes are intended to further decentralize price provision and protocol operations while improving the reliability and efficiency of the revenue used to compensate `OMOC` operators.

---

## Motivation

### Prepare OMOC operators for the _RoC_ and _MoC_ migration

_RoC_ and _MoC_ currently depend on semi-centralized price feeders for the `RIF` price and on centralized automators for periodic protocol tasks. A separate future governance proposal will migrate those responsibilities to `OMOC` after the new services are operational and oracle operators have had sufficient time to adopt them.

Before that migration can take place, the `RIF/USD` coin pair and `TasksRunner` services must be available in `OMOC`. Oracle operators also need sufficient time to:

- Review the new components,
- Upgrade their nodes,
- Subscribe to the `RIF/USD` coin pair,
- Subscribe to the `TasksRunner` consensus, and
- Verify that their infrastructure is ready to provide these services.

Deploying the facilities first separates operator onboarding from the later protocol migration and reduces operational risk.

### Improve the conversion of _RoC_ revenue

Part of the revenue collected from _RoC_ is converted from `RIF` into `MOC` tokens and used to compensate `OMOC` nodes. Because there is no direct `MOC/RIF` liquidity pool, this conversion requires multiple hops.

The existing route uses the `WRBTC/RIF` pair for one of those hops. That pair frequently lacks sufficient liquidity, which can delay payments and cause unnecessary value loss during conversion.

This proposal changes the conversion route to `RIF → USD0 → WBTC → MOC`, using the `USD0/RIF`, `WBTC/USD0`, and `MOC/WBTC` pools. These pools have substantially more liquidity than the `WRBTC/RIF` pool used by the existing route. The change is expected to:

- Improve the timely payment of `OMOC` oracle revenue shares,
- Reduce slippage and value lost during conversions, and
- Make the revenue-conversion process more reliable.

---

## Proposed Changes

### 1. Add the `RIF/USD` coin pair to `OMOC`

The changer will deploy and register the contracts and configuration required for `RIF/USD` price consensus in `OMOC`.

This proposal only establishes the new coin pair and enables operator subscription. Migrating _RoC_ to consume the resulting `RIF/USD` price will require a separate future governance proposal.

### 2. Add `TasksRunner` to `OMOC`

The changer will deploy the `TasksRunner` infrastructure used to coordinate recurring on-chain protocol operations among `OMOC` operators.

`TasksRunner` extends the oracle network's consensus-based operating model beyond price publication. Participating operators will be able to subscribe to task-execution consensus, receive execution turns, and execute registered protocol tasks on-chain.

The initial deployment is intended to give operators time to review and adopt the service. Migrating _RoC_ and _MoC_ tasks from centralized automators to `TasksRunner` will require a separate future governance proposal.

### 3. Use `RIF/USD0` liquidity for _RoC_ revenue conversion

The changer will replace the conversion hop that currently depends on `WRBTC/RIF` liquidity with the multi-hop route `RIF → USD0 → WBTC → MOC`. This route will use the `USD0/RIF, WBTC/USD0`, and `MOC/WBTC` pools, which have substantially greater available liquidity.

The conversion will remain multi-hop because no direct `MOC/RIF` pool exists.

### 4. Incorporate the `OMOC` circuit-breaker improvements

This proposal incorporates the improvements presented in [MIP#262701 — Implementation of an Oracle Circuit Breaker and some other improvements](MIP262701-omoc-circuit-breaker.md), including:

- The `OMOC` oracle circuit breaker, and
- Automatic unsubscription of oracle operators whose stake falls below the required participation threshold.

### 5. Incorporate the protocol cleanup and fixes

This proposal also incorporates the improvements presented in [MIP#262702 — Code Cleanup for Deprecated BTCX Leveraged Positions (and Bug Fixes)](MIP262702-btcx-code-cleanup.md), including:

- Removal of deprecated `BTCX` daily inrate payment logic, and
- Validation preventing unsupported pegged-token addresses from being accepted in _RoC_ queue transactions.

---

## Expected Outcome

After this proposal is executed:

- `RIF/USD` price consensus will be available in `OMOC`,
- `TasksRunner` consensus will be available in `OMOC`,
- Operators will be able to upgrade and subscribe before _RoC_ and _MoC_ depend on the new services,
- _RoC_ revenue conversion will use the more liquid `RIF/USD0` route,
- `OMOC` will include the circuit-breaker and operator-unsubscription improvements from [MIP#262701](MIP262701-omoc-circuit-breaker.md), and
- The cleanup and fixes from [MIP#262702](MIP262702-btcx-code-cleanup.md) will be incorporated.

The migration of _RoC_ and _MoC_ to these `OMOC` services will remain subject to a separate future governance proposal and vote.

---

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a governance vote.

The upgrade will be executed only after:

1. Proposal approval through governance,
2. Deployment and verification of the changer contract, and
3. Execution of the approved changer.

---

## Technical Procedure

> :warning: Some technical or coding knowledge is necessary to fully understand this section.

The upgrade will be executed through a changer contract that deploys and configures the `RIF/USD` coin pair and `TasksRunner` infrastructure, updates the _RoC_ revenue-conversion route, and incorporates the changes referenced in [MIP#262701](MIP262701-omoc-circuit-breaker.md) and [MIP#262702](MIP262702-btcx-code-cleanup.md).

The exact contract list, parameters, and verified addresses will be added to this draft before the governance vote.

---

## Changer Contract

| Name | Address and verified code |
| :---- | :---- |
| `TBD` | `TBD` |

---

## Existing Contracts to Be Upgraded or Reconfigured

| Protocol | Name | Change | Current Address | New Implementation or Configuration |
| :---- | :---- | :---- | :---- | :---- |
| OMOC | `TBD` | RIF/USD, TasksRunner, and MIP#262701 changes | `TBD` | `TBD` |
| RoC | `TBD` | RIF revenue-conversion route | `TBD` | `TBD` |
| MoC / RoC | `TBD` | MIP#262702 cleanup and fixes | `TBD` | `TBD` |

---

## New Contracts

| Protocol | Name | Purpose | Address |
| :---- | :---- | :---- | :---- |
| OMOC | `TBD` | RIF/USD coin-pair infrastructure | `TBD` |
| OMOC | `TBD` | TasksRunner infrastructure | `TBD` |
| Other | `TBD` | Additional contracts required by this proposal | `TBD` |
