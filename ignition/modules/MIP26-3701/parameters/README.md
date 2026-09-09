# MIP26-3701 schedule anchors

The changer derives the initial timestamp schedule state during execute, not when the proposal is
deployed or voted on. Each parameter file provides a recent verified block/timestamp pair
and the changer assumes 29 seconds per block for this one-time legacy-state conversion.

- Interest converts `lastBitProInterestBlock` to `lastBitProInterestTimestamp`;
  eligibility remains strictly greater than that timestamp plus seven days.
- Coiner converts its stored `nextMintFromBlock` to `_nextMintAt` and stores
  `_mintTimestampInterval` as `30 days + 10 hours` (2,628,000 seconds), a simple
  average Gregorian month based on a 365-day year.
- EMA converts `lastEmaCalculation` to `lastEmaCalculationTimestamp`; eligibility is
  that timestamp plus 24 hours.
- The proposal also upgrades the legacy MoC facade to remove its block-span forwarding
  selector. Dashboards must read the new last-payment timestamp and time-span fields, not block spans.
- Supporters is recalibrated to 87,600 blocks, representing the 30-day-10-hour average month
  under a 30-second block assumption. Its active earning deadline is not changed.
- RIF on Chain keeps its current implementation and active deadlines, but its settlement,
  TC-interest, decay, and EMA periods are normalized to 30 days 10 hours, 7 days, 1 day,
  and 1 day respectively.
- BTC/USD, RIF/USD, and TasksRunner keep their current implementations and active round deadlines.
  Mainnet next-round periods become 30 days 10 hours; testnet retains its intentional three-hour period.

Anchors recorded on 2026-09-07:

| Network     |     Block | UTC timestamp       | Unix timestamp |
| ----------- | --------: | ------------------- | -------------: |
| RSK mainnet | 9,220,195 | 2026-09-07 21:37:08 |  1,788,817,028 |
| RSK testnet | 8,053,633 | 2026-09-07 21:37:46 |  1,788,817,066 |
