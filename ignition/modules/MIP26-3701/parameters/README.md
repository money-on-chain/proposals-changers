# MIP26-3701 schedule parameters

The changer records its deployment block and timestamp as the anchor and assumes 29 seconds per
block for the one-time conversion of legacy block values. The parameter files configure the stored
EMA, weekly-interest, and Coiner spans passed to the upgraded implementations.

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
- RIF on Chain keeps its current implementation and active deadlines, but its TC-interest, decay,
  and EMA periods are normalized to 7 days, 1 day, and 1 day respectively.
- BTC/USD, RIF/USD, and TasksRunner keep their current implementations and active round deadlines.
  Mainnet next-round periods become 30 days 10 hours; testnet retains its intentional three-hour period.
