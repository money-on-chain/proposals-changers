# MIP26-3701 schedule anchors

The changer derives the initial timestamp schedule state during execute, not when the proposal is
deployed or voted on. Each parameter file provides a recent verified block/timestamp pair
and the changer assumes 24 seconds per block.

- Interest converts `lastBitProInterestBlock` to `lastBitProInterestTimestamp`;
  eligibility remains strictly greater than that timestamp plus seven days.
- Coiner converts its stored `nextMintFromBlock` to `_nextMintAt` and stores
  `_mintTimestampInterval` as `30 days + 10 hours` (2,628,000 seconds), a simple
  average Gregorian month based on a 365-day year.
- EMA converts `lastEmaCalculation` to `lastEmaCalculationTimestamp`; eligibility is
  that timestamp plus 24 hours.
- The proposal also upgrades the legacy MoC facade to remove its block-span forwarding
  selector. Dashboards must read the new last-payment timestamp and time-span fields, not block spans.

Anchors recorded on 2026-09-07:

| Network     |     Block | UTC timestamp       | Unix timestamp |
| ----------- | --------: | ------------------- | -------------: |
| RSK mainnet | 9,220,195 | 2026-09-07 21:37:08 |  1,788,817,028 |
| RSK testnet | 8,053,633 | 2026-09-07 21:37:46 |  1,788,817,066 |
