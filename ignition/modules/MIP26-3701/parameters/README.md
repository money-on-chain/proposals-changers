# MIP26-3701 schedule parameters

The changer records its deployment block and timestamp as the anchor and assumes 29 seconds per block for the one-time conversion of legacy block values. The parameter files configure the stored round-lock period because it intentionally differs between mainnet and testnet. The changer fixes the EMA period at one day, weekly-interest period at seven days, and Coiner period at the average Gregorian month of 30 days and 10 hours.

- Interest converts `lastBitProInterestBlock` to `lastBitProInterestTimestamp`;
  eligibility remains strictly greater than that timestamp plus seven days.
- Coiner converts its stored `nextMintFromBlock` to `_nextMintAt` and stores
  `_mintTimestampInterval` as `30 days + 10 hours` (2,628,000 seconds), a simple
  average Gregorian month based on a 365-day year.
- EMA converts `lastEmaCalculation` to `lastEmaCalculationTimestamp`; eligibility is
  that timestamp plus 24 hours.
- The proposal also upgrades the legacy MoC facade to remove its block-span forwarding
  selector. Dashboards must read the new last-payment timestamp and time-span fields, not block spans.
- Supporters is upgraded to the implementation containing the governed `setPeriod()` setter and
  recalibrated to 87,600 blocks, representing the 30-day-10-hour average month under a 30-second
  block assumption. Its active earning deadline is not changed.
- RIF on Chain keeps its current implementation and active deadlines, but its TC-interest, decay,
  and EMA periods are normalized to 7 days, 1 day, and 1 day respectively.
- BTC/USD, RIF/USD, and TasksRunner are upgraded to implementations containing the governed
  `setRoundLockPeriodSecs()` setter. Their active round deadlines are preserved. Mainnet next-round
  periods become 30 days 10 hours; testnet retains its intentional three-hour period.
- The RIF and DOC queues retain their one-block minimum waiting period and change their stale-price
  fallback maximum from three blocks to six.
- The DOC-to-MOC reverse-auction threshold changes from 1 DOC to 300 DOC.
- CoinPair and TasksRunner publication entry points reject a stale `lastPublicationBlock` before
  expensive validation, while retaining the same check inside shared validation.
