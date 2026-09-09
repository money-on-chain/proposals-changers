# Use Timestamps Instead of Blocks for Time Periods

> :memo: `MIP#263701`

> :warning: **Status: DRAFT**

## Overview

This proposal removes Rootstock block-number timing from the periodic schedules that produce protocol actions in Money on Chain and MOC Flow:

- the legacy Money on Chain EMA calculation;
- the legacy weekly BitPro/RiskPro interest payment; and
- the MOC Flow Coiner mint round.

The proposal upgrades those implementations and converts their existing schedule state to timestamps in the same governance execution transaction. Thereafter, EMA runs no more than once every 24 hours, the interest payment no more than once every seven days, and Coiner no more than once every 30 days and 10 hours.

The purpose is to make these periods stable in elapsed time instead of changing when Rootstock's block-production rate changes.

---

## Background

The affected schedules were originally expressed as a number of Rootstock blocks. That was a reasonable approximation while block times were stable, but it does not guarantee a calendar-day, week, or month when block production changes.

This has required governance intervention twice:

- In December 2024, after average block time fell below approximately 22 seconds, governance raised the month interval to 119,536 blocks. The same change set the legacy daily and weekly block spans to 3,927 and 27,489 blocks respectively. [Proposal and executed changer](https://forum.moneyonchain.com/t/migration-to-oku-trade-and-adjustments-to-block-duration-parameters/404)
- In March 2025, after average block time rose above approximately 24 seconds, governance reduced the month interval to 106,902 blocks, with daily and weekly spans of 3,512 and 24,585 blocks. Its stated objective was to keep rounds as close to a month as possible. [Proposal and executed changer](https://forum.moneyonchain.com/t/adjustments-to-block-duration-parameters/418)

The faster period also accelerated Coiner issuance temporarily. For example, rounds from 25 October to 17 November 2024 and from 17 November to 11 December 2024 took about 23.35 and 23.55 days. From 30 January 2024 through 13 January 2025, thirteen mint events occurred in roughly 349 days. The total number of events in each calendar year remained twelve, but a rolling twelve-month period did not consistently contain twelve rounds.

Retuning a block span can correct the current observed average, but it cannot preserve a time period if that average changes again. This proposal replaces that recurring operational dependency with elapsed-time schedules.

---

## Proposed Change

### Dates-only implementations

The proposal deploys and upgrades dates-only implementations for the three selected components. The post-upgrade code does not use the old block scheduling fields to decide when an action is due.

| Component                            | Legacy state converted at execution                             | Schedule after upgrade                           |
| ------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------ |
| Legacy EMA (`MoCState`)              | `lastEmaCalculation` becomes `lastEmaCalculationTimestamp`      | `lastEmaCalculationTimestamp + 1 day`            |
| Legacy weekly interest (`MoCInrate`) | `lastBitProInterestBlock` becomes `lastBitProInterestTimestamp` | `lastBitProInterestTimestamp + 7 days`           |
| MOC Flow Coiner                      | `nextMintFromBlock` becomes `_nextMintAt`                       | `_mintTimestampInterval` of 30 days and 10 hours |

Coiner exposes its 30-day 10-hour interval through `getMintTimestampInterval` and uses that stored interval when scheduling each subsequent mint. The value is a simple average month calculated as 365 days divided by twelve. This avoids the roughly five-day annual acceleration that a fixed 30-day interval would accumulate. The interest eligibility comparison remains strictly greater-than, while EMA retains its greater-than-or-equal comparison. Existing block fields remain in storage solely to preserve proxy layout; they are not used by the new scheduling logic. Obsolete block-span getters, setters, and the legacy MoC facade forwarding selector are removed.

### Execution-safe migration

The changer reads the old schedule values **before** upgrading a proxy. It converts them using a fixed, recent block/timestamp anchor and then upgrades and initializes all implementations atomically. It does not rely on the date on which the proposal is submitted, approved, or executed.

For this one-time conversion only, the changer assumes **24 seconds per Rootstock block**. This is not a future block-time assumption: it is only the conversion factor needed to map the legacy block state into an initial timestamp. The current mainnet and testnet anchor pairs are held in the proposal deployment parameters and can be reviewed before deployment.

The first deadline is the translated last-execution timestamp plus the new exact period. If that deadline is already in the past, the corresponding action is immediately eligible. If the legacy last-execution block is zero, the changer uses timestamp 1 so the action is also immediately eligible. This avoids a hard-coded deadline that could be wrong by the time a governance vote completes.

Each initial last-execution timestamp is set exactly once by the approved changer. The scheduling functions revert until initialized, and the initializer is restricted to the governance authorized changer. A standalone implementation cannot establish an arbitrary schedule for the proxy.

### Operational and ABI updates

The proposal also upgrades the legacy MoC facade because it exposed the old weekly block-span getter. Monitoring and interface artifacts are updated to consume the new last-payment timestamp and seven-day time span rather than block-number fields.

---

## Scope Deliberately Excluded

This proposal is intentionally narrow. The following were evaluated and are not changed:

- **Queues and price providers:** their block-based behavior can remain; they are not periodic outbound-payment schedules in scope for this proposal.
- **MoCSettlement and BProx settlement execution:** settlement is not included in this timestamp migration.
- **Legacy daily interest collection:** it is not included because it is not an active, automatically collected outbound payment. This proposal addresses the weekly BitPro/RiskPro payment instead.
- **RIF on Chain:** no RIF on Chain schedule is changed by this proposal. Its queues and price-provider timing remain deliberately out of scope.

Future governance proposals can address any of these components separately if their operational behavior warrants it.

---

## Expected Outcome

After execution:

- EMA eligibility follows elapsed days rather than the number of blocks mined;
- a weekly interest payment cannot become a substantially shorter or longer period just because Rootstock block time changes;
- Coiner rounds occur at least 30 days and 10 hours apart, subject only to the normal requirement that someone submits the mint transaction; and
- no further governance block-span retuning is needed for these three schedules.

The first post-upgrade due time is calculated from a best-effort translation of the legacy last-execution block plus the new exact period. Every later due time is based on the actual execution timestamp.

---

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a governance vote. Before the vote, the community can review:

1. the dates-only implementation source code;
2. the MIP26-3701 changer and its verified-source deployment;
3. the mainnet and testnet anchor parameters; and
4. the generated implementation and changer addresses.

The change takes effect only when the approved changer is executed. Because it derives the initial timestamp state at execution, a voting delay does not require redeploying or reconfiguring the changer.

---

## Changer Contract

The changer address and verified-source URL will be added before the governance vote.

| Changer address and verified source |
| :---------------------------------- |
| `TBD`                               |

Implementation and deployment details are maintained in [`ignition/modules/MIP26-3701`](../../ignition/modules/MIP26-3701).
