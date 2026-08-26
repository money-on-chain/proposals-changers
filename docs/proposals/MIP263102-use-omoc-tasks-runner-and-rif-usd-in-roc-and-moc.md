# Use OMOC's TasksRunner and RIF/USD in RoC and MoC

> :memo: `MIP#263102`

> :warning: **Under review**

## Overview

This proposal migrates `RIF` price provision and recurring protocol task execution in _RIF on Chain (RoC)_ and _Money on Chain (MoC)_ to decentralized services operated through the _Money on Chain Decentralized Oracle protocol (OMOC)_.

It is a follow-up to [MIP#263101 — Add RIF/USD and TasksRunner to OMOC; Use RIF/USD0 for Liquidity](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md), which deploys the `RIF/USD` coinpair and `TasksRunner` infrastructure and gives _OMOC_ operators time to upgrade and subscribe.

The proposed changer will:

- Replace the semi-centralized `RIF` price feeders used by _RoC_ and _MoC_ with the _OMOC_ `RIF/USD` price,
- Replace centralized automators with _OMOC_ `TasksRunner` for all supported recurring protocol tasks,
- Redirect part of the existing protocol revenue to operators participating in `RIF/USD` price consensus and `TasksRunner` consensus,
- Route task-execution costs collected from users to `TasksRunner` operators,
- Introduce a price-provision cost on mint and redeem operations, routed directly to the `BTC/USD` and `RIF/USD` _OMOC_ oracle services,
- Increase _RoC's_ target coverage from 5.5× to 7×, and
- Improve the elastic moving average used to calculate the applicable coverage ratio.

Together, these changes further decentralize the protocols and create a more economically self-sustaining model for price provision and protocol operations.

---

## Motivation

### Decentralize RIF price provision

_RoC_ currently use semi-centralized feeders for the RIF price required by protocol operations. Depending on those feeders creates an operational dependency that can be removed now that `RIF/USD` price consensus is available through _OMOC_ under [MIP#263101](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md).

Migrating the protocols to the _OMOC_ `RIF/USD` coinpair places `RIF` price provision under the same decentralized operator model already used for other _OMOC_ price services.

### Decentralize recurring protocol operations

_RoC_ and _MoC_ also depend on centralized automators to execute recurring on-chain tasks. These tasks include protocol maintenance and operational flows that must run on a predetermined cadence, such as:

- Daily `EMA` calculations,
- Processing queued transactions,
- Executing `MocFlow` components and reverse auctions, and
- Other registered maintenance operations required by _RoC_ and _MoC_.

`TasksRunner` coordinates these operations among participating _OMOC_ operators through a consensus-based, turn-assignment model. Moving the supported tasks to `TasksRunner` removes the foundation-operated automators as a central point of operational responsibility.

### Sustain the new decentralized services

`RIF/USD` price provision and decentralized task execution impose infrastructure and transaction costs on participating operators. This proposal changes revenue distribution and operation-level charges so that the services are funded by the protocols and users that depend on them.

### Improve coverage resilience

_RoC's_ target coverage will be increased to provide a larger collateral buffer. At the same time, the elastic moving average used when calculating the applicable coverage ratio must respond more intelligently to temporary `RIF` price spikes and drops.

Improving that calculation is intended to prevent short-lived price movements from unnecessarily disrupting the amount of `USDRIF` that users can mint or causing abrupt changes to `RIFPRO` leverage.

---

## Proposed Changes

### 1. Use the _OMOC_ `RIF/USD` price in _RoC_

_RoC_ will be configured to consume the `RIF/USD` price published through _OMOC_ instead of the current semi-centralized `RIF` price feeders.

This migration will occur only after the `RIF/USD` coinpair has been deployed and _OMOC_ operators have had time to subscribe under [MIP#263101](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md).

### 2. Use _OMOC_ `TasksRunner` for protocol tasks

All supported recurring tasks in _RoC_ and _MoC_ will be registered with and executed through _OMOC_ `TasksRunner`. The centralized automators currently responsible for those tasks will no longer be part of the active execution path.

Operators participating in `TasksRunner` consensus will coordinate execution turns and receive the associated compensation.

### 3. Protocol-funded rewards

In addition to user-funded execution and price-provision payments, this section shows how the destination of each revenue stream changes after implementing this changer. Each list represents 100% of its revenue source's fee value, and each allocation is shown as **before → after**. Values may be converted and paid in a currency different from the one in which they were collected.

#### MoC protocol

**BPRO weekly payments (RBTC)**

- To Mimlabs, in `RBTC`: 50.00% → 50.00%.
- To `MOC` stakers, as `MOC`: 35.00% → 35.00%.
- To the `BTC/USD` oracle, as `MOC`: 15.00% → 13.50%.
- To `TasksRunner`, as `MOC`: 0.00% → 1.50%.

**Mint/redemption and other fees paid in RBTC — MoC single-collateral bucket**

- To Mimlabs, in `RBTC`: 50.00% → 50.00%.
- Retained by the _MoC_ bucket, in `RBTC`, as collateral reimbursement: 10.00% → 10.00%.
- To `MOC` stakers, as `MOC`: 28.00% → 28.00%.
- To the `BTC/USD` oracle, as `MOC`: 12.00% → 10.80%.
- To `TasksRunner`, as `MOC`: 0.00% → 1.20%.

**Fees paid in MOC — MoC single-collateral bucket**

- To Mimlabs, in `MOC`: 50.00% → 50.00%.
- To the _MoC_ bucket, as `RBTC` after a MOC-to-RBTC reverse auction: 10.00% → 10.00%.
- To `MOC` stakers, in `MOC`: 28.00% → 28.00%.
- To the `BTC/USD` oracle, in `MOC`: 12.00% → 10.80%.
- To `TasksRunner`, in `MOC`: 0.00% → 1.20%.

#### RoC protocol

**RIF bucket mint/redemption fees paid in RIF**

- Retained in the `RIF` bucket as `RIF` collateral: 25.00% → 25.00%.
- To Mimlabs, in `RIF`: 50.00% → 35.00%.
- To the `RIF/USD` oracle, as `MOC`: 0.00% → 15.00%.
- To `MOC` stakers, as `MOC`: 17.50% → 17.50%.
- To the `BTC/USD` oracle, as `MOC`: 7.50% → 6.75%.
- To `TasksRunner`, as `MOC`: 0.00% → 0.75%.

**RIF bucket mint/redemption fees paid in MOC**

- To Mimlabs, in `MOC`: 50.00% → 35.00%.
- To the `RIF` bucket, as `RIF` after a MOC-to-RIF reverse auction: 25.00% → 25.00%.
- To the `RIF/USD` oracle, in `MOC`: 0.00% → 15.00%.
- To `MOC` stakers, in `MOC`: 17.50% → 17.50%.
- To the `BTC/USD` oracle, in `MOC`: 7.50% → 6.75%.
- To `TasksRunner`, in `MOC`: 0.00% → 0.75%.

**RIFPRO weekly payments (RIF)**

- To Mimlabs, in `RIF`: 50.00% → 35.00%.
- To the `RIF/USD` oracle, as `MOC`: 0.00% → 15.00%.
- To `MOC` stakers, as `MOC`: 35.00% → 35.00%.
- To the `BTC/USD` oracle, as `MOC`: 15.00% → 13.50%.
- To `TasksRunner`, as `MOC`: 0.00% → 1.50%.

**RIF bucket rebalance fees (RIF)**

- To `TasksRunner`, as `MOC`: 0.00% → 100.00%.
- To centralized automator, as `MOC`: 100.00% → 0.00%.

**DOC bucket mint/redemption fees paid in DOC**

- Retained in the `DOC` bucket as `DOC` collateral: 25.00% → 25.00%.
- To Mimlabs, in `DOC`: 50.00% → 35.00%.
- To the `RIF/USD` oracle, as `MOC`: 0.00% → 15.00%.
- To `MOC` stakers, as `MOC`: 17.50% → 17.50%.
- To the `BTC/USD` oracle, as `MOC`: 6.75% → 6.75%.
- To TasksRunner, as `MOC`: 0.75% → 0.75%.

**DOC bucket mint/redemption fees paid in MOC**

- To Mimlabs, in `MOC`: 50.00% → 35.00%.
- To the `DOC` bucket, as `DO`C after a MOC-to-DOC reverse auction: 25.00% → 25.00%.
- To the `RIF/USD` oracle, in `MOC`: 0.00% → 15.00%.
- To `MOC` stakers, in `MOC`: 17.50% → 17.50%.
- To the `BTC/USD` oracle, in `MOC`: 7.50% → 6.75%.
- To `TasksRunner`, in `MOC`: 0.00% → 0.75%.

**DOC bucket rebalance fees (DOC)**

- To `TasksRunner`, as `MOC`: 0.00% → 100.00%.
- To _centralized automator_, as `MOC`: 100.00% → 0.00%.

**MultiCollateralGuard execution and gas-refund fees (RBTC)**

- To `TasksRunner`, as MOC: 0.00% → 100.00%.
- To _centralized automator_, as `MOC`: 100.00% → 0.00%.

**MultiCollateralGuard newly added price-update fees (RBTC)**

- To the `BTC/USD` oracle, as `MOC`: 0.00% → 50.00%.
- To the `RIF/USD` oracle, as `MOC`: 0.00% → 50.00%.

The 25% `DOC` and `RIF` bucket allocations are retained as collateral and are not external payments. The remaining fee value enters the applicable fee-flow splitter. These allocations may be modified through the applicable governance process.

### 4. User-funded execution and price-provision costs

Minting and redemption operations will bear the costs of decentralized task execution and price provision.

_OMOC_ operators participating in TasksRunner consensus will receive the execution payments collected from users when they mint and redeem. This aligns task compensation with the operations that create execution costs and helps decentralized executors recover their on-chain expenses.

Each mint and redeem operation will also include a price-provision charge equivalent to 250,000 gas. At current costs, this is approximately USD 0.20 per operation. The collected amount will be paid to the decentralized price-providing oracles.

The USD estimate is indicative and will vary with gas prices and the `RBTC/USD` exchange rate.

### 5. Increase target coverage and improve its price calculation

_RoC's_ target coverage will increase from 5.5× to 7×.

Alongside this increase, the elastic moving average governing the applicable coverage-ratio calculation will be improved. The revised calculation will treat temporary `RIF` price spikes and drops more appropriately, reducing the effect of short-lived market movements on:

- The amount of `USDRIF` that can be minted, and
- `RIFPRO` leverage.

`RIF` has recently moved from approximately USD 0.50 to USD 0.15 and back to approximately USD 0.50 over short periods. Under similar conditions, applying this change could temporarily leave the protocol below its desired coverage target. New `USDRIF` minting could therefore be unavailable for a few days, until the `EMA` adjusts or sufficient `RIFPRO` is minted.

The situation will be monitored closely before execution. If market conditions indicate a material risk to `USDRIF` minting capacity, submission of this proposal may be delayed.

The exact moving-average logic and parameters will be documented in the technical specification before the governance vote.

---

## Protocol-Funded Reward Summary

| _RoC_ Revenue Source                     | `RIF/USD` Providers | `TasksRunner` Executors | `BTC/USD` Providers |
| :--------------------------------------- | :-----------------: | :---------------------: | :-----------------: |
| `RIF` bucket minting and redemption fees |          15%        |           0.75%         |        6.75%        |
| `DOC` bucket minting and redemption fees |          15%        |           0.75%         |        6.75%        |
| Periodic interest from `RIFPRO` holders  |          15%        |            1.5%         |        13.5%        |

These protocol-funded rewards are additional to the execution and price-provision payments borne by minting and redemption operations.

---

## Expected Outcome

After this proposal is executed:

- _RoC_ will consume `RIF/USD` prices from _OMOC_,
- Supported recurring tasks in both protocols will be executed through _OMOC_ `TasksRunner`,
- Centralized `RIF` price feeders and automators will be removed from the active paths covered by this migration,
- `RIF/USD` oracle operators and TasksRunner operators will receive dedicated revenue,
- User-paid execution and price-provision costs will flow to the services supporting those operations, and
- _RoC's_ target coverage will increase from 5.5× to 7× while the improved elastic moving average reduces disruption from temporary `RIF` price spikes and drops, and
- _RoC_ and MoC will operate with fewer centralized dependencies and a more sustainable incentive model.

---

## Dependency on MIP#263101

This proposal depends on the successful execution and operational adoption of [MIP#263101](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md).

Before this changer is executed:

- The _OMOC_ `RIF/USD` coinpair must be deployed and operational,
- The _OMOC_ `TasksRunner` infrastructure must be deployed and operational, and
- A sufficient set of _OMOC_ operators must have upgraded and subscribed to the new services.

---

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a governance vote.

The upgrade will be executed only after:

1. [MIP#263101](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md) has been executed and the new _OMOC_ services are operational,
2. Proposal approval through governance,
3. Deployment and verification of the changer contract, and
4. Execution of the approved changer.

---

## Technical Procedure

> :warning: Some technical or coding knowledge is necessary to fully understand this section.

The upgrade will be executed through a changer contract that reconfigures _RoC_ and _MoC_ to use the _OMOC_ `RIF/USD` price and `TasksRunner` services, updates the applicable revenue-sharing and user-cost parameters, increases _RoC's_ target coverage to 7×, and applies the improved elastic moving-average calculation.

---

## Changer Contract

### The changer contract to vote would be:

| Name                    | Address (and link to verified code in RSK blockscout explorer)                                                                                   |
| :---------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| `AddTasksRunnerChanger` | [`0xA20737eCBd96bFAf9CA670b6f9EbbD5F77c9D3EA`](https://rootstock.blockscout.com/address/0xA20737eCBd96bFAf9CA670b6f9EbbD5F77c9D3EA?tab=contract) |

> :information_source: Info: All changes, upgrades, and reconfigurations to existing contracts, including the exact parameter values, can be audited directly in the changer contract, whose [source code is published and verified in the block explorer](https://rootstock.blockscout.com/address/0xA20737eCBd96bFAf9CA670b6f9EbbD5F77c9D3EA?tab=contract) linked above.
