# Use Timestamps Instead of Blocks for Time Periods

> :memo: `MIP#263701`

> :warning: **Status: DRAFT**

## Rationale

Rootstock block production changes speed over time. A fixed number of blocks therefore does not
represent a stable number of days: schedules accelerate when blocks become faster and slow down
when blocks become slower.

Governance has already adjusted these periods twice. In December 2024, after average block time
fell below approximately 22 seconds, the Coiner interval was increased to 119,536 blocks and the
legacy daily and weekly periods were changed to 3,927 and 27,489 blocks.
[December 2024 proposal](https://forum.moneyonchain.com/t/migration-to-oku-trade-and-adjustments-to-block-duration-parameters/404)
In March 2025, after blocks slowed to more than approximately 24 seconds, those values were changed
to 106,902, 3,512, and 24,585 blocks.
[March 2025 proposal](https://forum.moneyonchain.com/t/adjustments-to-block-duration-parameters/418)

The changing cadence was visible in MOC issuance. The rounds from 25 October to 17 November 2024
and from 17 November to 11 December 2024 lasted approximately 23.35 and 23.55 days. From
30 January 2024 through 13 January 2025, thirteen mint events occurred in approximately 349 days.

MIP26-3701 migrates the legacy EMA calculation, weekly BitPro/RiskPro interest payment, and MOC
Coiner from block-based periods to timestamp-based periods. It also corrects related deployed
periods that already use seconds but do not currently match their intended day, week, or average
month. This gives these operations a stable calendar cadence regardless of future Rootstock block
speed.

---

## Contracts Changed

The proposal upgrades the existing legacy MoC, MoCState, MoCInrate, and Coiner proxies. Their
addresses and state remain unchanged. The changer reads the legacy scheduling state, upgrades the
proxies, and initializes the new timestamp schedules in the same governance transaction.

### [Legacy MoC](https://rootstock.blockscout.com/address/0xf773B590aF754D597770937Fa8ea7AbDf2668370)

The MoC facade is upgraded to remove the obsolete `getBitProInterestBlockSpan()` forwarding
function. Minting, redemption, accounting, fees, pausing, and payment calculations are unchanged.

### [Legacy MoCState and EMA calculator](https://rootstock.blockscout.com/address/0xb9C42EFc8ec54490a37cA91c423F7285Fa01e257)

EMA eligibility changes from `lastEmaCalculation + emaCalculationBlockSpan` to:

`lastEmaCalculationTimestamp + emaCalculationTimeSpan`

The changer converts the stored last-calculation block to a timestamp and initializes
`emaCalculationTimeSpan` to 86,400 seconds. After each calculation,
`lastEmaCalculationTimestamp` records the actual execution time. The span is stored in proxy
storage and can be changed later by governance through `setEmaCalculationTimeSpan()`.

The EMA value, formula, smoothing factor, and price source are unchanged.

### [Legacy MoCInrate weekly payment](https://rootstock.blockscout.com/address/0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3)

Weekly BitPro/RiskPro interest eligibility changes from
`lastBitProInterestBlock + bitProInterestBlockSpan` to:

`lastBitProInterestTimestamp + bitProInterestTimeSpan`

The changer converts the stored last-payment block to a timestamp and initializes
`bitProInterestTimeSpan` to 604,800 seconds. After each payment,
`lastBitProInterestTimestamp` records the actual execution time. The span is stored in proxy
storage and can be changed later by governance through `setBitProInterestTimeSpan()`.

The interest rate, recipient, amount calculation, RBTC transfer, and C0 bucket accounting are
unchanged.

### [MOC Flow Coiner](https://rootstock.blockscout.com/address/0x661F7d510cdB40638f5Afd9f9dF8877398500593)

Coiner eligibility changes from `_nextMintFromBlock` to the timestamp `_nextMintAt`. Its stored
`_mintTimestampInterval` is initialized to 2,628,000 seconds, equal to 30 days and 10 hours. This
is a simple average Gregorian month calculated as 365 days divided by twelve. Governance can
change the stored interval later through `setMintTimestampInterval()`.

The legacy Coiner stores the next eligible block. To correct the drift already accumulated in that
value, the changer reconstructs the previous mint block by subtracting `_mintBlockInterval`,
converts that block to a timestamp, and adds the new average-month interval. Later mints schedule
the next round from their actual execution timestamp.

The two-stage issuance formula, remaining supply, thresholds, destination, ownership requirements,
minted amounts, and transfers are unchanged.

### [Supporters](https://rootstock.blockscout.com/address/0xB1fc9817C4ad3C40562DfF1159732d657831558A)

Supporters continues to stream rewards over blocks. Its `period` is recalibrated from 106,902 to
87,600 blocks, representing 30 days and 10 hours at an assumed 30-second block time.

The active `endEarnings` value is preserved, so rewards already being streamed are unaffected.
The new period applies to the next distribution.

### [RIF on Chain](https://rootstock.blockscout.com/address/0xA27024Ed70035E46dba712609fc2Afa1c97aA36A)

RIF on Chain already schedules these operations with timestamps, so its implementation is not
upgraded. The changer corrects the deployed periods that were derived from the previous block
values using a 24-second conversion:

- TC interest changes from 590,040 to 604,800 seconds, exactly seven days.
- Flux-capacitor decay changes from 84,288 to 86,400 seconds, exactly one day.
- EMA calculation changes from 84,288 to 86,400 seconds, exactly one day.

The current TC interest and EMA deadlines are preserved. The TC interest collector, interest rate,
and flux-capacitor providers are also preserved.

### Oracle and TasksRunner rounds

The [BTC/USD CoinPair](https://rootstock.blockscout.com/address/0xa288319eCb63301e21963E21EF3Ca8fb720d2672),
[RIF/USD CoinPair](https://rootstock.blockscout.com/address/0xaFb1B8C320ACc776c1279bcDB24Ab8F84aB727A4),
and [TasksRunner](https://rootstock.blockscout.com/address/0xd99a43ba443068Ea539CeB623aE24e6C9910b975)
already use timestamp deadlines. Their mainnet `roundLockPeriodSecs` changes from 2,592,000
seconds, exactly 30 days, to the 2,628,000-second average Gregorian month used by Coiner.

Current round deadlines are preserved, and the new duration applies when each next round begins.
Testnet retains its intentionally accelerated 10,800-second round period.

## Migration

The changer records its deployment block number and timestamp. It uses this pair and an estimated
29-second historical block time to convert the legacy EMA, interest-payment, and Coiner block
values:

`anchor timestamp + (legacy block - anchor block) * 29 seconds`

EMA and weekly interest retain the meaning of their existing state: the previous execution is
converted to a timestamp, and eligibility is determined by adding the configured period. Coiner
reconstructs its previous execution block before conversion and adds 2,628,000 seconds to obtain
the first timestamp deadline.

The changer does not execute an EMA calculation, interest payment, or Coiner mint. If an operation
is already due after conversion, its normal caller can execute it once. That execution records the
actual timestamp and begins the new time-based cadence.

Fresh deployments initialize the stored timestamp periods to one day for EMA, one week for
BitPro/RiskPro interest, and 30 days 10 hours for Coiner.

## Components Evaluated and Left Unchanged

Queues remain block-based because their delays enforce transaction ordering and chain progress,
not a calendar payment cadence.

Price-provider freshness and emergency-publication windows remain block-based because they measure
how many blocks have passed without a price publication. Their behavior is intentionally tied to
chain progress.

Legacy daily inrate collection is not migrated because it is not currently collected as an active
outbound payment.

Supporters remains block-based because reward balances vest continuously between two block
boundaries. Its active stream must preserve the exact already-vested fraction. This proposal only
recalibrates the period used by future distributions; Supporters is expected to become
economically less significant than Coiner issuance and the active interest schedules.

RIF on Chain and the oracle round managers are not upgraded because they already use timestamp
deadlines. Only their configured durations are corrected.

## Expected Outcome

After execution:

- Legacy EMA calculations follow an exact one-day period.
- Legacy BitPro/RiskPro interest payments follow an exact seven-day period.
- Coiner issuance follows a 30-day-10-hour average Gregorian month.
- RIF on Chain TC interest, decay, and EMA use exact weekly and daily periods.
- Mainnet oracle rounds use the same average Gregorian month as Coiner.
- Supporters uses an 87,600-block approximation based on 30-second blocks.

The first Coiner deadline is expected during September 2026 rather than drifting into October.
Subsequent EMA calculations, interest payments, and Coiner rounds are scheduled from their actual
execution timestamps.

## Verification

The proposal includes unit tests and a Rootstock mainnet-fork test that deploys and executes the
changer against deployed protocol state. The tests verify the upgraded implementations, converted
timestamps, configured periods, preserved active deadlines and economic parameters, and the first
Coiner deadline.

## Governance Process

The change takes effect only when the approved changer is executed.

## Changer Contract

The changer address and verified-source link will be added here before the governance vote.

`TBD`

Implementation and deployment details are maintained in
[`ignition/modules/MIP26-3701`](../../ignition/modules/MIP26-3701).
