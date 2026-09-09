# Use Timestamps Instead of Blocks for Time Periods

> :memo: `MIP#263701`

> :warning: **Status: DRAFT**

## Rationale

Rootstock block production changes speed over time. A period expressed as a fixed number of
blocks therefore does not represent a stable number of days: the same configured block span
becomes shorter when blocks accelerate and longer when blocks slow down. This affects schedules
whose intended meaning is a day, a week, or a month.

Governance has already had to compensate for this behavior twice. In December 2024, after
average block time fell below approximately 22 seconds, governance increased the Coiner interval
to 119,536 blocks and changed the legacy daily and weekly spans to 3,927 and 27,489 blocks.
[Proposal and executed changer](https://forum.moneyonchain.com/t/migration-to-oku-trade-and-adjustments-to-block-duration-parameters/404)
In March 2025, after blocks slowed to more than approximately 24 seconds, governance reduced
those values to 106,902, 3,512, and 24,585 blocks respectively.
[Proposal and executed changer](https://forum.moneyonchain.com/t/adjustments-to-block-duration-parameters/418)

The effect was visible in MOC issuance. The rounds from 25 October to 17 November 2024 and from
17 November to 11 December 2024 took approximately 23.35 and 23.55 days. Between 30 January 2024
and 13 January 2025, thirteen mint events occurred in approximately 349 days. Calendar-year
totals remained twelve, but a rolling twelve-month period could contain thirteen rounds.

Changing the block spans again would correct only the current drift. A later change in block
production would require another governance adjustment. MIP26-3701 instead makes the selected
schedules use elapsed timestamps, correcting the current Coiner drift and removing their future
dependence on Rootstock's average block time.

After this proposal, the legacy EMA schedule represents one day, the BitPro/RiskPro interest
schedule represents one week, and the Coiner schedule represents a simple average month of
30 days and 10 hours. Existing RIF on Chain timestamp periods and oracle round periods are also
normalized to those exact calendar durations. Supporters remains block-based, but its lower-impact
reward-streaming period is recalibrated using a 30-second Rootstock block assumption. The principal
payment and issuance schedules will therefore no longer need retuning when block production changes.

---

## Contracts Changed

The changer receives the existing proxy addresses, both upgrade delegators, and the addresses of
four newly deployed implementations. It reads all legacy scheduling state before any upgrade,
upgrades the existing proxies, and initializes their new timestamp fields in the same governance
transaction. The proxies, balances, ownership, and all unrelated protocol state remain in place.

### [Legacy MoC](https://rootstock.blockscout.com/address/0xf773B590aF754D597770937Fa8ea7AbDf2668370)

The legacy MoC proxy is upgraded because its facade exposed
`getBitProInterestBlockSpan()`, an API belonging to the removed block-based schedule. The new
implementation removes that forwarding function. Payment calculation, the interest destination,
the configured rate, bucket accounting, pausing, and all mint and redeem behavior are unchanged.

### [Legacy MoCState and EMA calculator](https://rootstock.blockscout.com/address/0xb9C42EFc8ec54490a37cA91c423F7285Fa01e257)

The EMA schedule stops reading `lastEmaCalculation` and `emaCalculationBlockSpan`. Those
historical storage slots remain in their original positions to preserve proxy storage layout, but
the new implementation does not use them for eligibility.

A new `lastEmaCalculationTimestamp` slot is appended in the reserved storage gap, and the exact
period is exposed as `emaCalculationTimeSpan = 1 days`. EMA calculation is eligible when:

`block.timestamp >= lastEmaCalculationTimestamp + 1 days`

After a calculation, `lastEmaCalculationTimestamp` is set to the actual execution timestamp.
The EMA formula, current EMA value, smoothing factor, price source, and the circumstances that
trigger an attempted calculation are unchanged.

The migration initializes the new field from the legacy last-calculation block using the
proposal anchor. The initializer is restricted to an authorized governance changer, can run only
once, rejects zero, and the scheduling code reverts while the field is uninitialized. There is no
temporary mode in which the upgraded implementation can fall back to block scheduling.

### [Legacy MoCInrate weekly payment](https://rootstock.blockscout.com/address/0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3)

The weekly BitPro/RiskPro payment stops reading `lastBitProInterestBlock` and
`bitProInterestBlockSpan`. Those values remain only as historical storage-layout slots.

A new `lastBitProInterestTimestamp` slot is appended in the reserved storage gap, and the exact
period is exposed as `bitProInterestTimeSpan = 7 days`. Payment is eligible when:

`block.timestamp > lastBitProInterestTimestamp + 7 days`

After payment, `lastBitProInterestTimestamp` is set to the actual execution timestamp. The
interest rate, recipient, amount calculation, RBTC transfer, C0 bucket accounting, and permission
model are unchanged.

The migration initializes the new field from the legacy last-payment block using the proposal
anchor. As with EMA, initialization is governance-only, nonzero, and one-time; the upgraded
schedule cannot operate before initialization and never falls back to block arithmetic.

### [MOC Flow Coiner](https://rootstock.blockscout.com/address/0x661F7d510cdB40638f5Afd9f9dF8877398500593)

The Coiner stops using `_mintBlockInterval` and `_nextMintFromBlock` to determine whether a
round can execute. These fields remain in place solely to preserve the deployed proxy's storage
layout.

The implementation appends `_mintTimestampInterval` and `_nextMintAt`.
`_mintTimestampInterval` is initialized to 30 days and 10 hours, a simple 365-day Gregorian
average divided into twelve equal periods. This avoids the five-day annual acceleration produced
by a 30-day interval. `readyToMint()` uses `_nextMintAt`, and a successful mint sets the next
deadline to the actual execution timestamp plus 30 days and 10 hours.

The two-stage issuance formula, remaining supply, stage threshold, destination, token ownership
requirement, minted amounts, and transfers are unchanged. Only the eligibility clock changes.

The legacy Coiner stores the next eligible block rather than the previous execution block.
Directly translating that block would preserve drift already embedded in the old block interval
and, with the current mainnet state, would push the next round into October. The changer instead
reconstructs the previous execution block by subtracting the deployed
`getMintBlockInterval()` from `getNextMintFromBlock()`, translates that previous block through
the anchor, and adds the new 30-day-10-hour period. At the current mainnet anchor this produces a
first post-migration deadline in September.

Coiner initialization is also governance-only, nonzero, and one-time. Both new timestamp fields
must be initialized before minting can become eligible, and the new implementation contains no
block-scheduling fallback.

### [Supporters](https://rootstock.blockscout.com/address/0xB1fc9817C4ad3C40562DfF1159732d657831558A)

Supporters progressively unlocks each reward allocation between `startEarnings` and `endEarnings`,
both stored as block numbers. Converting that implementation to timestamps is substantially harder
than converting a discrete payment deadline: a migration would have to preserve the exact vested
fraction of an active earning stream, and every balance calculation would have to change from block
progress to elapsed seconds.

Supporters is expected to become economically less significant over time than Coiner issuance,
interest collection, and the actively maintained RIF on Chain schedules. MIP26-3701 therefore does
not add a new Supporters implementation. It recalibrates `period` from 106,902 to 87,600 blocks,
which represents 30 days and 10 hours at an assumed 30 seconds per block. The active
`endEarnings` value is deliberately not changed, preserving rewards already in progress. The new
period takes effect when the next distribution begins.

### [RIF on Chain](https://rootstock.blockscout.com/address/0xA27024Ed70035E46dba712609fc2Afa1c97aA36A)

RIF on Chain already uses timestamps, so it needs no implementation upgrade. Its deployed periods,
however, were obtained by multiplying the March 2025 block values by 24 seconds. This froze the old
block-time estimate into seconds: settlement is 2,565,648 seconds, weekly TC interest is 590,040
seconds, and the daily decay and EMA periods are 84,288 seconds. They no longer vary with block
production, but they are approximately 2.44% shorter than their intended calendar durations.

The changer sets settlement to 2,628,000 seconds, a simple 365-day Gregorian year divided into
twelve equal periods; TC interest to 604,800 seconds; and decay and EMA to 86,400 seconds. It reads
and preserves the deployed TC interest collector, interest rate, and flux-capacitor providers. It
also leaves `nextSettlementTime`, `nextTCInterestPayment`, and `nextEmaCalculation` unchanged, so
no action is duplicated or made immediately eligible merely because its future period changed.

### Oracle and TasksRunner rounds

The [BTC/USD CoinPair](https://rootstock.blockscout.com/address/0xa288319eCb63301e21963E21EF3Ca8fb720d2672),
[RIF/USD CoinPair](https://rootstock.blockscout.com/address/0xaFb1B8C320ACc776c1279bcDB24Ab8F84aB727A4),
and [TasksRunner](https://rootstock.blockscout.com/address/0xd99a43ba443068Ea539CeB623aE24e6C9910b975)
already end their rounds using `lockPeriodTimestamp`. Their existing 2,592,000-second period is
exactly 30 days, which produces an extra round approximately every six years. Since switching these
rounds distributes oracle rewards, the changer normalizes `roundLockPeriodSecs` to 2,628,000 seconds,
the same simple Gregorian average month used for Coiner and RIF on Chain settlement. Current
`lockPeriodTimestamp` values are not changed; the new duration begins with each contract's next round.
The testnet deployment keeps its intentionally accelerated 10,800-second oracle rounds.

## Schedule Conversion at Execution

The proposal cannot know its execution date in advance: deployment, voting, acceptance, and final
execution can be separated by a week or more. Hard-coding the first dates could make them stale
before governance executes the changer. MIP26-3701 therefore calculates the migrated schedule
dynamically when `execute()` runs.

Mainnet and testnet each provide a recent anchor block and its timestamp in the Ignition
parameters. For this one-time historical conversion, the changer uses 29 seconds per block, the
observed Rootstock average over the relevant interval. This value is not used for future
scheduling. It is only used to estimate a timestamp for a legacy block:

`anchor timestamp + (legacy block - anchor block) * 29 seconds`

The calculation works in both directions around the anchor. EMA and weekly interest translate
their last execution block and retain their prior semantics: each stores the estimated previous
execution time, adds its exact period to determine eligibility, and records the actual timestamp
when it next runs. Coiner reconstructs and translates its previous round as described above, then
adds the new average-month period.

If a translated deadline has already passed when the changer executes, that action is immediately
eligible. It is not executed by the changer. The normal task runner or caller executes it, after
which the implementation records the actual timestamp and begins a clean timestamp-based period.
This prevents the changer from duplicating an action while also avoiding a stale hard-coded date.

If an EMA or interest legacy last-execution value is zero, timestamp 1 is used so the action is
immediately eligible. If Coiner has no legacy next block, its first timestamp deadline is the
changer execution time.

Fresh deployments also initialize these timestamp schedules from `block.timestamp` in their
normal initializer. That fresh-deployment path is separate from this proxy migration; existing
proxies receive their translated values exclusively through MIP26-3701.

## Design Decisions and Deliberate Exclusions

The review covered block-dependent components deployed across Money on Chain and RIF on Chain.
The migration was deliberately narrowed to schedules that represent recurring elapsed-time
protocol activity and where block-time drift can materially delay or accelerate an outbound
action.

Queues remain block-based. Their waiting and execution rules are transaction-ordering mechanisms,
not calendar payment schedules, and changing them is unnecessary for this proposal.

Price providers and oracle publication windows remain block-based. Their short block freshness and
emergency-publication windows are intentionally coupled to chain progress. Oracle round endings are
already timestamp-based and are only recalibrated from 30 days to the Gregorian-average month.

`MoCSettlement` remains block-based. Settlement processes legacy queued settlement and BProx
functionality; it is not the recurring Coiner or weekly interest payment. Its behavior and current
operational use were evaluated, but changing it would broaden this migration without solving the
payment drift that motivated the proposal.

Legacy daily inrate collection is not migrated. It is not currently being collected as an active
outbound payment, so migrating its dormant schedule would add contract and operational risk
without a corresponding benefit.

RIF on Chain receives no contract upgrade from MIP26-3701. Its existing timestamp periods are
corrected through governance setters, while its queues and providers remain outside the proposal.

EMA is included even though recalculating it is not an outbound payment. It is frequently reached
through normal protocol operation, has a clear intended daily cadence, and is safe to make due
immediately if its translated deadline has elapsed.

The new implementations are timestamp-only rather than supporting a transition period with both
block and timestamp behavior. A dual-mode implementation would increase complexity and leave two
sources of scheduling truth. The changer instead performs the legacy read, upgrade, and one-time
initialization atomically.

New timestamp values use new storage slots rather than reinterpreting the legacy block slots.
This preserves upgrade layout, gives monitoring an unambiguous timestamp field and period, and
keeps the legacy values available for historical inspection at the storage level. Historical,
single-use changer contracts were not rewritten; they remain as records of previously executed
governance changes and are marked accordingly in their source.

Operational monitoring is updated separately to read
`lastBitProInterestTimestamp` and `bitProInterestTimeSpan`. Removed block-based getters and
setters must not be used after the upgrade.

## Expected Outcome

After execution, EMA eligibility follows elapsed days, weekly payments follow elapsed weeks, and
Coiner issuance, RIF on Chain settlement, and oracle rounds follow twelve equal periods per simple
365-day year. Changes in Rootstock block production no longer shorten or extend these schedules.
Supporters remains the deliberate exception and uses an 87,600-block approximation based on
30-second blocks.

The first Coiner round corrects the drift accumulated under the current block interval and is
expected during September 2026. Every later deadline is based on the timestamp of the actual
previous execution. EMA and weekly interest similarly converge onto exact time periods after
their first post-migration execution.

## Verification

The proposal includes unit tests for anchor conversion and one-time initialization, plus a
Rootstock mainnet-fork test that:

1. forks at the configured mainnet anchor;
2. deploys the four new implementations and the changer;
3. executes the changer through the deployed governor and both upgrade delegators;
4. verifies the migrated timestamp slots and exact periods;
5. verifies Supporters' new period without changing the active earning allocation;
6. verifies the RIF on Chain periods while preserving its active deadlines and economic parameters;
7. verifies the three oracle round periods while preserving their active deadlines;
8. prints the migrated EMA previous-calculation timestamp, weekly-interest previous-payment
   timestamp, and Coiner next-round timestamp; and
9. asserts that the first Coiner deadline is in September 2026 and not October.

## Governance Process

The change takes effect only when the approved changer is executed. Before voting, the community
can review the timestamp-only implementation sources, MIP26-3701, both networks' anchor
parameters, the fork-test output, and the deployed implementation addresses.

## Changer Contract

The changer address and verified-source link will be added here before the governance vote.

`TBD`

Implementation and deployment details are maintained in
[`ignition/modules/MIP26-3701`](../../ignition/modules/MIP26-3701).
