# Use OMOC's TasksRunner and RIF/USD in RoC and MoC

> :memo: `MIP#263102`

> :warning: **Status: DRAFT**

## Overview

This proposal migrates RIF price provision and recurring protocol task execution in RIF on Chain (RoC) and Money on Chain (MoC) to decentralized services operated through the Money on Chain Decentralized Oracle protocol (OMOC).

It is a follow-up to [MIP#263101 — Add RIF/USD and TasksRunner to OMOC; Use RIF/USD0 for Liquidity](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md), which deploys the RIF/USD coin pair and TasksRunner infrastructure and gives OMOC operators time to upgrade and subscribe.

The proposed changer will:

- replace the semi-centralized RIF price feeders used by RoC and MoC with the OMOC RIF/USD price,
- replace centralized automators with OMOC TasksRunner for all supported recurring protocol tasks,
- redirect part of the existing protocol revenue to operators participating in RIF/USD price consensus and TasksRunner consensus,
- route task-execution costs collected from users to TasksRunner operators,
- introduce a price-provision cost on mint and redeem operations, routed directly to the BTC/USD and RIF/USD OMOC oracle services,
- increase RoC's target coverage from 5.5× to 7×, and
- improve the elastic moving average used to calculate the applicable coverage ratio.

Together, these changes further decentralize the protocols and create a more economically self-sustaining model for price provision and protocol operations.

---

## Motivation

### Decentralize RIF price provision

RoC and MoC currently use semi-centralized feeders for the RIF price required by protocol operations. Depending on those feeders creates an operational dependency that can be removed now that RIF/USD price consensus is available through OMOC under MIP#263101.

Migrating the protocols to the OMOC RIF/USD coin pair places RIF price provision under the same decentralized operator model already used for other OMOC price services.

### Decentralize recurring protocol operations

RoC and MoC also depend on centralized automators to execute recurring on-chain tasks. These tasks include protocol maintenance and operational flows that must run on a predetermined cadence, such as:

- daily EMA calculations,
- processing queued transactions,
- executing `MocFlow` components and reverse auctions, and
- other registered maintenance operations required by RoC and MoC.

TasksRunner coordinates these operations among participating OMOC operators through a consensus-based, turn-assignment model. Moving the supported tasks to TasksRunner removes the foundation-operated automators as a central point of operational responsibility.

### Sustain the new decentralized services

RIF/USD price provision and decentralized task execution impose infrastructure and transaction costs on participating operators. This proposal changes revenue distribution and operation-level charges so that the services are funded by the protocols and users that depend on them.

### Improve coverage resilience

RoC's target coverage will be increased to provide a larger collateral buffer. At the same time, the elastic moving average used when calculating the applicable coverage ratio must respond more intelligently to temporary RIF price spikes and drops.

Improving that calculation is intended to prevent short-lived price movements from unnecessarily disrupting the amount of USDRIF that users can mint or causing abrupt changes to RIFPRO leverage.

---

## Proposed Changes

### 1. Use the OMOC RIF/USD price in RoC and MoC

RoC and MoC will be configured to consume the RIF/USD price published through OMOC instead of the current semi-centralized RIF price feeders.

This migration will occur only after the RIF/USD coin pair has been deployed and OMOC operators have had time to subscribe under MIP#263101.

### 2. Use OMOC TasksRunner for protocol tasks

All supported recurring tasks in RoC and MoC will be registered with and executed through OMOC TasksRunner. The centralized automators currently responsible for those tasks will no longer be part of the active execution path.

Operators participating in TasksRunner consensus will coordinate execution turns and receive the associated compensation.

### 3. Protocol-funded rewards

In addition to user-funded execution and price-provision payments, this section shows how the destination of each revenue stream changes after implementing this changer. Each list represents 100% of its revenue source's fee value, and each allocation is shown as **before → after**. The values currently shown on the left match the post-changer allocations and must be replaced with the actual previous allocations before the governance vote.

Values may be converted and paid in a currency different from the one in which they were collected.

#### MoC protocol

**BPRO weekly payments (RBTC)**

- To Mimlabs, in RBTC: 50.00% → 50.00%.
- To MOC stakers, as MOC: 35.00% → 35.00%.
- To the BTC/USD oracle, as MOC: 15.00% → 13.50%.
- To TasksRunner, as MOC: 0.00% → 1.50%.

**Mint/redemption and other fees paid in RBTC — MoC single-collateral bucket**

- To Mimlabs, in RBTC: 50.00% → 50.00%.
- Retained by the MoC bucket, in RBTC, as collateral reimbursement: 10.00% → 10.00%.
- To MOC stakers, as MOC: 28.00% → 28.00%.
- To the BTC/USD oracle, as MOC: 12.00% → 10.80%.
- To TasksRunner, as MOC: 0.00% → 1.20%.

**Fees paid in MOC — MoC single-collateral bucket**

- To Mimlabs, in MOC: 50.00% → 50.00%.
- To the MoC bucket, as RBTC after a MOC-to-RBTC reverse auction: 10.00% → 10.00%.
- To MOC stakers, in MOC: 28.00% → 28.00%.
- To the BTC/USD oracle, in MOC: 12.00% → 10.80%.
- To TasksRunner, in MOC: 0.00% → 1.20%.

#### RoC protocol

**RIF bucket mint/redemption fees paid in RIF**

- Retained in the RIF bucket as RIF collateral: 25.00% → 25.00%.
- To Mimlabs, in RIF: 50.00% → 35.00%.
- To the RIF/USD oracle, as MOC: 0.00% → 15.00%.
- To MOC stakers, as MOC: 17.50% → 17.50%.
- To the BTC/USD oracle, as MOC: 7.50% → 6.75%.
- To TasksRunner, as MOC: 0.00% → 0.75%.

**RIF bucket mint/redemption fees paid in MOC**

- To Mimlabs, in MOC: 50.00% → 35.00%.
- To the RIF bucket, as RIF after a MOC-to-RIF reverse auction: 25.00% → 25.00%.
- To the RIF/USD oracle, in MOC: 0.00% → 15.00%.
- To MOC stakers, in MOC: 17.50% → 17.50%.
- To the BTC/USD oracle, in MOC: 7.50% → 6.75%.
- To TasksRunner, in MOC: 0.00% → 0.75%.

**RIFPRO weekly payments (RIF)**

- To Mimlabs, in RIF: 50.00% → 35.00%.
- To the RIF/USD oracle, as MOC: 0.00% → 15.00%.
- To MOC stakers, as MOC: 35.00% → 35.00%.
- To the BTC/USD oracle, as MOC: 15.00% → 13.50%.
- To TasksRunner, as MOC: 0.00% → 1.50%.

**RIF bucket rebalance fees (tRIF)**

- To TasksRunner, as MOC: 0.00% → 100.00%.
- To centralized automator, as MOC: 100.00% → 0.00%.

**DOC bucket mint/redemption fees paid in DOC**

- Retained in the DOC bucket as DOC collateral: 25.00% → 25.00%.
- To Mimlabs, in DOC: 50.00% → 35.00%.
- To the RIF/USD oracle, as MOC: 0.00% → 15.00%.
- To MOC stakers, as MOC: 17.50% → 17.50%.
- To the BTC/USD oracle, as MOC: 6.75% → 6.75%.
- To TasksRunner, as MOC: 0.75% → 0.75%.

**DOC bucket mint/redemption fees paid in MOC**

- To Mimlabs, in MOC: 50.00% → 35.00%.
- To the DOC bucket, as DOC after a MOC-to-DOC reverse auction: 25.00% → 25.00%.
- To the RIF/USD oracle, in MOC: 0.00% → 15.00%.
- To MOC stakers, in MOC: 17.50% → 17.50%.
- To the BTC/USD oracle, in MOC: 7.50% → 6.75%.
- To TasksRunner, in MOC: 0.00% → 0.75%.

**DOC bucket rebalance fees (DOC)**

- To TasksRunner, as MOC: 0.00% → 100.00%.
- To centralized automator, as MOC: 100.00% → 0.00%.

**MultiCollateralGuard execution and gas-refund fees (RBTC)**

- To TasksRunner, as MOC: 0.00% → 100.00%.
- To centralized automator, as MOC: 100.00% → 0.00%.

**MultiCollateralGuard newly added price-update fees (RBTC)**

- To the BTC/USD oracle, as MOC: 0.00% → 50.00%.
- To the RIF/USD oracle, as MOC: 0.00% → 50.00%.

The 25% DOC and RIF bucket allocations are retained as collateral and are not external payments. The remaining fee value enters the applicable fee-flow splitter. These allocations may be modified through the applicable governance process.

### 4. User-funded execution and price-provision costs

Minting and redemption operations will bear the costs of decentralized task execution and price provision.

OMOC operators participating in TasksRunner consensus will receive the execution payments collected from users when they mint and redeem. This aligns task compensation with the operations that create execution costs and helps decentralized executors recover their on-chain expenses.

Each mint and redeem operation will also include a price-provision charge equivalent to 250,000 gas. At current costs, this is approximately USD 0.20 per operation. The collected amount will be paid to the decentralized price-providing oracles.

The USD estimate is indicative and will vary with gas prices and the RBTC/USD exchange rate.

### 5. Increase target coverage and improve its price calculation

RoC's target coverage will increase from 5.5× to 7×.

Alongside this increase, the elastic moving average governing the applicable coverage-ratio calculation will be improved. The revised calculation will treat temporary RIF price spikes and drops more appropriately, reducing the effect of short-lived market movements on:

- the amount of USDRIF that can be minted, and
- RIFPRO leverage.

RIF has recently moved from approximately USD 0.50 to USD 0.15 and back to approximately USD 0.50 over short periods. Under similar conditions, applying this change could temporarily leave the protocol below its desired coverage target. New USDRIF minting could therefore be unavailable for a few days, until the EMA adjusts or sufficient RIFPRO is minted.

The situation will be monitored closely before execution. If market conditions indicate a material risk to USDRIF minting capacity, submission of this proposal may be delayed.

The exact moving-average logic and parameters will be documented in the technical specification before the governance vote.

---

## Protocol-Funded Reward Summary

| RoC Revenue Source | RIF/USD Providers | TasksRunner Executors | BTC/USD Providers |
| :---- | :----: | :----: | :----: |
| RIF bucket minting and redemption fees | 15% | 0.75% | 6.75% |
| DOC bucket minting and redemption fees | 15% | 0.75% | 6.75% |
| Periodic interest from RIFPRO holders | 15% | 1.5% | 13.5% |

These protocol-funded rewards are additional to the execution and price-provision payments borne by minting and redemption operations.

---

## Expected Outcome

After this proposal is executed:

- RoC and MoC will consume RIF/USD prices from OMOC,
- supported recurring tasks in both protocols will be executed through OMOC TasksRunner,
- centralized RIF price feeders and automators will be removed from the active paths covered by this migration,
- RIF/USD oracle operators and TasksRunner operators will receive dedicated revenue,
- user-paid execution and price-provision costs will flow to the services supporting those operations, and
- RoC's target coverage will increase from 5.5× to 7× while the improved elastic moving average reduces disruption from temporary RIF price spikes and drops, and
- RoC and MoC will operate with fewer centralized dependencies and a more sustainable incentive model.

---

## Dependency on MIP#263101

This proposal depends on the successful execution and operational adoption of [MIP#263101](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md).

Before this changer is executed:

- the OMOC RIF/USD coin pair must be deployed and operational,
- the OMOC TasksRunner infrastructure must be deployed and operational, and
- a sufficient set of OMOC operators must have upgraded and subscribed to the new services.

---

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a governance vote.

The upgrade will be executed only after:

1. MIP#263101 has been executed and the new OMOC services are operational,
2. proposal approval through governance,
3. deployment and verification of the changer contract, and
4. execution of the approved changer.

---

## Technical Procedure

> :warning: Some technical or coding knowledge is necessary to fully understand this section.

The upgrade will be executed through a changer contract that reconfigures RoC and MoC to use the OMOC RIF/USD price and TasksRunner services, updates the applicable revenue-sharing and user-cost parameters, increases RoC's target coverage to 7×, and applies the improved elastic moving-average calculation.

The exact task list, contract list, parameters, and verified addresses will be added to this draft before the governance vote.

---

## Changer Contract

| Name | Address and verified code |
| :---- | :---- |
| `TBD` | `TBD` |

---

## Existing Contracts to Be Upgraded or Reconfigured

| Protocol | Name | Change | Current Address | New Implementation or Configuration |
| :---- | :---- | :---- | :---- | :---- |
| RoC | `TBD` | Use OMOC RIF/USD | `TBD` | `TBD` |
| MoC | `TBD` | Use OMOC RIF/USD | `TBD` | `TBD` |
| RoC | `TBD` | Increase target coverage and improve the elastic moving average | `TBD` | `TBD` |
| RoC | `TBD` | Use TasksRunner and update revenue distribution | `TBD` | `TBD` |
| MoC | `TBD` | Use TasksRunner and update revenue distribution | `TBD` | `TBD` |
| OMOC | `TBD` | Receive and distribute service revenue | `TBD` | `TBD` |

---

## New Contracts

| Protocol | Name | Purpose | Address |
| :---- | :---- | :---- | :---- |
| `TBD` | `TBD` | Additional contracts or implementations required by this proposal | `TBD` |
