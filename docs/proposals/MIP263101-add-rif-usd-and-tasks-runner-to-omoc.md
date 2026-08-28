# Add RIF/USD and TasksRunner to OMOC; Use RIF/USD₮0 for Liquidity

> :memo: `MIP#263101`

> :warning: **Status: Implemented**

## Overview

This proposal prepares the Money on Chain Decentralized Oracle protocol (`OMOC`) for the upcoming migration of RIF on Chain (_RoC_) and Money on Chain (_MoC_) to decentralized RIF/USD price provision and protocol task execution.

The proposed changer will:

- Deploy and register the new `RIF/USD` coin pair in `OMOC`,
- Deploy the TasksRunner infrastructure,
- Give `OMOC` oracle operators time to review, upgrade, and subscribe to the new services before they are used by _RoC_ and _MoC_,
- Change the conversion route used for `RIF` revenue collected from _RoC_ to use the more liquid `USD₮0/RIF`, `WBTC/USD₮0`, and `MOC/WBTC` pools,
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

This proposal changes the conversion route to `RIF → USD₮0 → WBTC → MOC`, using the `USD₮0/RIF`, `WBTC/USD₮0`, and `MOC/WBTC` pools. These pools have substantially more liquidity than the `WRBTC/RIF` pool used by the existing route. The change is expected to:

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

### 3. Use `RIF/USD₮0` liquidity for _RoC_ revenue conversion

The changer will replace the conversion hop that currently depends on `WRBTC/RIF` liquidity with the multi-hop route `RIF → USD₮0 → WBTC → MOC`. This route will use the `USD₮0/RIF, WBTC/USD₮0`, and `MOC/WBTC` pools, which have substantially greater available liquidity.

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
- _RoC_ revenue conversion will use the more liquid `RIF/USD₮0` route,
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

### The changer contract to vote would be:

| Name                    | Address (and link to verified code in RSK blockscout explorer)                                                                                   |
| :---------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| `PreTasksRunnerChanger` | [`0x015F2836467Ce43E27D22b0d03929c371Ff1d0f1`](https://rootstock.blockscout.com/address/0x015F2836467Ce43E27D22b0d03929c371Ff1d0f1?tab=contract) |

---

## Existing Contracts to be upgraded

The following contracts are already part of the protocol and will be upgraded as part of this proposal:

| Name             |        Type        | Address                                                                                                             |
| :--------------- | :----------------: | :------------------------------------------------------------------------------------------------------------------ |
| `OracleManager`  |       Proxy        | [`0x64A5...712C`](https://rootstock.blockscout.com/address/0x64A5634b2D1F17DC7c4765aaCd222F8E9eB7712C?tab=contract) |
| `OracleManager`  |   Implementation   | [`0x2ea6...F6A9`](https://rootstock.blockscout.com/address/0x2ea69e6e91040c57a0AeaE0B0E3424Aaf740F6A9?tab=contract) |
| `OracleManager`  | New implementation | [`0xDa61...5c54`](https://rootstock.blockscout.com/address/0xDa61bA24E64d508E27f699F6F41E46C6246f5c54?tab=contract) |
| `CoinPairBTCUSD` |       Proxy        | [`0xa288...2672`](https://rootstock.blockscout.com/address/0xa288319eCb63301e21963E21EF3Ca8fb720d2672?tab=contract) |
| `CoinPairBTCUSD` |   Implementation   | [`0x37ff...e03F`](https://rootstock.blockscout.com/address/0x37ff40ec727349d478d2715aE58097f218F7e03F?tab=contract) |
| `CoinPairBTCUSD` | New implementation | [`0xb9F7...8b9A`](https://rootstock.blockscout.com/address/0xb9F7B2996123BDd1157fd7549d90573240fB8b9A?tab=contract) |
| `CoinPairRIFBTC` |       Proxy        | [`0x4D58...98d0`](https://rootstock.blockscout.com/address/0x4D582deE1B405A45CD0c6801f0575560ad3f98d0?tab=contract) |
| `CoinPairRIFBTC` |   Implementation   | [`0x37ff...e03F`](https://rootstock.blockscout.com/address/0x37ff40ec727349d478d2715aE58097f218F7e03F?tab=contract) |
| `CoinPairRIFBTC` | New implementation | [`0xb9F7...8b9A`](https://rootstock.blockscout.com/address/0xb9F7B2996123BDd1157fd7549d90573240fB8b9A?tab=contract) |
| `CoinPairUSDARS` |       Proxy        | [`0x44E1...4393`](https://rootstock.blockscout.com/address/0x44E100CC6B4b89EfFF71e0c88048166732F04393?tab=contract) |
| `CoinPairUSDARS` |   Implementation   | [`0x37ff...e03F`](https://rootstock.blockscout.com/address/0x37ff40ec727349d478d2715aE58097f218F7e03F?tab=contract) |
| `CoinPairUSDARS` | New implementation | [`0xb9F7...8b9A`](https://rootstock.blockscout.com/address/0xb9F7B2996123BDd1157fd7549d90573240fB8b9A?tab=contract) |
| `CoinpairUSDCOP` |       Proxy        | [`0xdD71...166b`](https://rootstock.blockscout.com/address/0xdD711A0EB1CbdF7F5287C5CA67E0E9d0288f166b?tab=contract) |
| `CoinpairUSDCOP` |   Implementation   | [`0x37ff...e03F`](https://rootstock.blockscout.com/address/0x37ff40ec727349d478d2715aE58097f218F7e03F?tab=contract) |
| `CoinpairUSDCOP` | New implementation | [`0xb9F7...8b9A`](https://rootstock.blockscout.com/address/0xb9F7B2996123BDd1157fd7549d90573240fB8b9A?tab=contract) |

---

## Existing Contracts to be reconfigured

The following contracts are already part of the protocol and will be reconfigured as part of this proposal:

| Name         |                                                       Address                                                       |
| :----------- | :-----------------------------------------------------------------------------------------------------------------: |
| `mocSwapper` | [`0x2412...3C73`](https://rootstock.blockscout.com/address/0x24122D7Ff0eF57c18e5c333e2C7BD863e4F23C73?tab=contract) |

---

## New Contracts

| Name                        |                                                       Address                                                       |
| :-------------------------- | :-----------------------------------------------------------------------------------------------------------------: |
| `TasksRunnerProxy`          | [`0xD99a...b975`](https://rootstock.blockscout.com/address/0xD99a43Ba443068ea539CeB623AE24e6c9910b975?tab=contract) |
| `TasksRunnerImplementation` | [`0xA3eA...69D3`](https://rootstock.blockscout.com/address/0xA3eA7a013F11f71AD5D2139dDBBD385d559469D3?tab=contract) |
| `BasefeeProvider`           | [`0xA9Aa...915C`](https://rootstock.blockscout.com/address/0xA9Aa3df27E832360D631C22BB4f2592A8574915C?tab=contract) |

---

## Status

📣 The voting process is over:
* `29.0%` of the MOC tokens total supply participated in the vote.
* `100%` voted in favor.
* No one vote voted against the proposal.
* The change was successfully implemented.

[TX ID: `0xd7379f99cb56315ce72a301193635223633f2357b543365bc771b4086abd086e`](https://rootstock.blockscout.com/tx/0xd7379f99cb56315ce72a301193635223633f2357b543365bc771b4086abd086e)