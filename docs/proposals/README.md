# Proposals for social channels

Collection of proposals in Markdown format.

These documents describe proposed changes to the protocols. They are intended to be published on forums or other social channels to inform the community and encourage public discussion. Markdown was chosen because it is the most compatible and portable format: it makes documents easy to read, version, and share.

## Proposal list

This is a chronological list of proposals (published or pending publication), sorted with the newest entries first.

- `MIP#264001` — [RIF/USD Subsidy](MIP264001-rif-usd-subsidy.md) — **DRAFT**
- `MIP#263701` — [Use Timestamps Instead of Blocks for Time Periods](MIP263701-use-timestamps-instead-of-blocks-for-time-periods.md)
- `MIP#263502` — [Split the RIF on Chain Panic Button and Migrate RIFPRO](MIP263502-split-rif-on-chain-panic-button-and-migrate-rifpro.md) — **DRAFT**
- `MIP#263501` — [Grant Proposal Submitters a Temporary Accepted-Step Priority](MIP263501-voting-machine-accepted-step-priority.md) — **DRAFT**
- `MIP#263102` — [Use OMOC's TasksRunner and RIF/USD in RoC and MoC](MIP263102-use-omoc-tasks-runner-and-rif-usd-in-roc-and-moc.md)
- `MIP#263101` — [Add RIF/USD and TasksRunner to OMOC; Use RIF/USD0 for Liquidity](MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md)
- `MIP#262702` — [Code Cleanup for Deprecated BTCX Leveraged Positions (and Bug Fixes)](MIP262702-btcx-code-cleanup.md)
- `MIP#262701` — [Implementation of an Oracle Circuit Breaker and some other improvements](MIP262701-omoc-circuit-breaker.md)
- `MIP#262301` — [Oracle Incentive Rebalancing and Protocol Cleanup Upgrade](MIP262301-oracle-incentive-rebalancing-and-protocol-cleanup-upgrade.md)
- `MIP#261801` — [Proposal: RIF On Chain V2 → V3 Upgrade (Multi-Collateral Support)](MIP261801-proposal-rif-on-chain-v2-to-v3-upgrade-multi-collateral-support.md)
- `MIP#261401` — [Oracle Reliability Fix and Protocol Unpause Proposal](MIP261401-oracle-reliability-fix-and-protocol-unpause-proposal.md)
- `MIP#260901` — [Proposal: Governance-Controlled Maximum Markup for MocVendors](MIP260901-proposal-governance-controlled-maximum-markup-for-mocvendors.md)
- `MIP#260501` — [Proposal: Reverse Auction Flow Upgrade Using TWAP Pricing](MIP260501-proposal-reverse-auction-flow-upgrade-using-twap-pricing.md)
- `MIP#260502` — [Post-mortem: flash Loan–based price manipulation attack on the MOC FLow Reverse Auction rBTC to MOC contract](MIP260502-post-mortem-flash-loan-based-price-manipulation-attack.md)

## MIP numbering

`MIP` means _Money on Chain Improvement Proposal_.

Each new proposal receives a unique `MIP#` identifier following this rule:

- `YY` = last two digits of the year
- `WW` = ISO week number of the year, zero-padded to 2 digits
- `NN` = sequential proposal number within that week, zero-padded to 2 digits, starting at `01`

The full format is: `MIP#YYWWNN`.

Example: `MIP#262701` = a proposal from 2026, week 27, sequence 01.

## Proposal registry (`proposals.json`)

[`proposals.json`](proposals.json) indexes every proposal in this folder. The dapps and the stable-protocol APIs read it to show, for each proposal voted on-chain, its MIP, title, summary and this markdown document. A changer submitted for voting that is not in the registry is shown as an unlisted proposal.

Add a proposal's entry in the same pull request as its document, and its changer addresses as soon as they are deployed. [AGENTS.md](AGENTS.md) describes where each value comes from (also read by coding agents):

```json
{
  "mip": "MIP#263101",
  "title": "Add RIF/USD and TasksRunner to OMOC; Use RIF/USD₮0 for Liquidity",
  "tags": ["oracles"],
  "status": "Published",
  "date": "2026-08-07",
  "summary": "One or two plain-text sentences for proposal lists.",
  "file": "MIP263101-add-rif-usd-and-tasks-runner-to-omoc.md",
  "forumUrl": "https://forum.moneyonchain.com/t/add-rif-usd-and-tasksrunner-to-omoc-use-rif-usd-0-for-liquidity/468",
  "changers": [
    {
      "network": "rskMainnet",
      "name": "PreTasksRunnerChanger",
      "address": "0x015F2836467Ce43E27D22b0d03929c371Ff1d0f1",
      "submitter": "0x4e9e0E64FF95F9a629d1f756119fa636f30BBacd",
      "executedTx": "0xd7379f99cb56315ce72a301193635223633f2357b543365bc771b4086abd086e"
    }
  ]
}
```

- `tags`: the projects the proposal changes, at least one, in this order: `doc` (Money on Chain), `usdrif` (RIF on Chain), `oracles` (OMOC), `voting` (governance), `staking` (MOC staking and its rewards flow).
- `status`: `Draft`, `Published` (posted to the forum) or `Withdrawn`. Whether it was voted and executed comes from the chain, not from here.
- `date`: forum publication date (`YYYY-MM-DD`), `null` while it is a draft.
- `changers`: every changer contract submitted for this MIP, on `rskMainnet` or `rskTestnet` (a MIP may have several, e.g. a redeploy after a failed vote). `submitter` is the address that submitted the changer for voting (the first `preVote` sender), `null` until it is submitted. `executedTx` is the `acceptedStep` transaction that executed it, `null` until it is executed; the dapps also detect executions from the indexed VotingMachine events where the network emits them (testnet, and mainnet once MIP#263501 is executed), but on mainnet before that it is the only record. Addresses use an [EIP-55](https://eips.ethereum.org/EIPS/eip-55) checksum or Rootstock's [EIP-1191](https://eips.ethereum.org/EIPS/eip-1191) checksum for the network (as Rootstock explorers show them). `[]` when there is none.
- Images in the document must be stored in [`images/`](images) and linked with a relative path; the dapps do not show external images or raw HTML.

`pnpm validate:proposals` checks the registry (CI runs it on every change to this folder or to `ignition/deployments`): unique and well-formed MIPs, every document listed, valid checksums, each mainnet changer present in its document's "Changer Contract" section, and each address on the network its ignition deployment says.
