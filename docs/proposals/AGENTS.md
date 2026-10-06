# Agent guide: maintaining `proposals.json`

`proposals.json` is the proposal registry. The dapps and the stable-protocol APIs read it to match each changer contract voted on-chain to its MIP, and show that MIP's title, summary and document as the **official** description of the proposal. A changer that is not listed is shown to voters as an unlisted proposal.

Treat every edit as security-sensitive: a wrong address attaches a MIP's description to a contract that does something else, and a missing one makes an official proposal look suspicious. **Never guess or invent a value. When a value is not in the sources below, leave it as described (`null` / `[]`) and ask the maintainer.**

The field format is described in [README.md](README.md#proposal-registry-proposalsjson). This guide is how to fill it.

## When to update the registry

| Event                                                                                                                    | Change                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| A new `MIPYYWWNN-*.md` document is added                                                                                 | Add its entry (`status: "Draft"`, `date: null`, `forumUrl: null`, `changers: []` unless already deployed) and its line in the README list. |
| A changer is deployed (new `ignition/deployments/<id>/`, or an address added to a document's "Changer Contract" section) | Add it to that MIP's `changers`.                                                                                                           |
| The proposal is posted on the forum                                                                                      | `status: "Published"`, `date`, `forumUrl`.                                                                                                 |
| The proposal is abandoned                                                                                                | `status: "Withdrawn"`. Keep its changers.                                                                                                  |
| A changer is redeployed (e.g. after a failed vote)                                                                       | **Add** the new changer; never remove or edit the old one, it may already have votes on-chain.                                             |

Do not record voting results or execution (`Accepted`, `Executed`, ...): the APIs read those from the chain.

## Where each field comes from

| Field      | Source                                                                                | Rule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mip`      | The `> :memo: \`MIP#YYWWNN\`` line at the top of the document                         | Same value as the document's file name prefix (`MIP263101-...md` → `MIP#263101`). New MIPs follow the numbering in the README: `YY` year, `WW` ISO week, `NN` sequence in that week from `01`.                                                                                                                                                                                                                                                                                                                 |
| `title`    | The document's first heading                                                          | Copy it verbatim, without the `#` and without markdown (`**`, `_`, backticks).                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `tags`     | The document: which projects its changes apply to                                     | At least one of `doc` (Money on Chain: DOC, BPRO, MoC contracts), `usdrif` (RIF on Chain: USDRIF, RIFPRO), `oracles` (OMOC: CoinPairs, OracleManager, TasksRunner), `voting` (governance: VotingMachine, Governor), `staking` (MOC staking and its rewards flow), in that order. Tag every project whose contracts the changer modifies; the document's "Changer Contract" and upgraded-contracts sections list them. Ask when unsure. A new tag needs the maintainer and a change to `TAGS` in the validator. |
| `status`   | Maintainer / forum                                                                    | `Draft` until posted on the forum, then `Published`; `Withdrawn` if abandoned.                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `date`     | The forum topic's creation date                                                       | `YYYY-MM-DD`. `null` while `Draft`. Required for `Published`.                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `summary`  | The document's opening paragraphs (Overview)                                          | See [Writing the summary](#writing-the-summary).                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `file`     | The document's file name                                                              | Name only, no folder.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `forumUrl` | The forum topic, given by the maintainer or found on <https://forum.moneyonchain.com> | Full `https://forum.moneyonchain.com/t/<slug>/<id>` link. Only use a topic whose content is this MIP (search the forum for `MIP#YYWWNN`). `null` while `Draft`.                                                                                                                                                                                                                                                                                                                                                |
| `changers` | See [Finding changer addresses](#finding-changer-addresses)                           | `[]` when the MIP has no changer (reports, addenda executed by another MIP's changer).                                                                                                                                                                                                                                                                                                                                                                                                                         |

## Finding changer addresses

A changer is the contract voted on-chain: the one the Governor executes. Each entry is `{ "network", "name", "address", "submitter", "executedTx" }`, with `network` `rskMainnet` or `rskTestnet`.

Use only these two sources:

1. **The document's "Changer Contract" section** (the table under `## Changer Contract`). This is the authority for mainnet: every `rskMainnet` changer must appear there, and the validator enforces it. `name` is the contract name in the first column.
2. **Ignition deployments**: `ignition/deployments/<deployment-id>/deployed_addresses.json`.
   - The network comes from the deployment id: `*-rsk-mainnet` or `chain-30` → `rskMainnet`, `*-rsk-testnet` or `chain-31` → `rskTestnet`. Ids under `testnet-only` modules are not MIPs: do not add them.
   - The file maps `<Module>#<Contract>` to an address. The changer is the contract the module builds to be voted, usually named after the MIP or ending in `Changer` / `Proposal` (e.g. `MIP263701Module#MIP263701UseTimestamps`, `HardeningIIModule#HardeningII`). The `*Implementation`, `*Proxy`, library and helper entries of the same module are **not** changers.
   - `name` is the part after `#`.
   - Match the deployment to the MIP through the document (it names the changer contract), the module name, or `package.json`'s `deploy:*` scripts. If it is not unambiguous, ask.

Never take changer addresses from block explorers, chat messages or other repositories without the maintainer confirming them.

### Finding the submitter

`submitter` is the address that submitted the changer for voting: the sender of the first successful `preVote(<changer>)` call to that network's VotingMachine (the contract stores it as the proposal's proposer). It is read from the chain, never assumed:

- VotingMachine: mainnet `0x65a5681be95d212f0c90ead40170d8277de81169`, testnet `0x7D124cC0f59aDA5793AD8edA9eD1836cB7e797a3`. Their transactions are listed on <https://rootstock.blockscout.com> and <https://rootstock-testnet.blockscout.com>.
- Look at both the **transactions** and the **internal transactions** of the VotingMachine: proposals submitted from a multisig or a vesting contract arrive as internal calls, and then the submitter is that contract (the caller of `preVote`), not the account that signed the transaction.
- Take the earliest call whose argument is the changer address. If the changer was never pre-voted on that network, `submitter` is `null`.

### Finding the execution

`executedTx` is the hash of the transaction that executed the changer: a successful `acceptedStep()` call to the network's VotingMachine (see the addresses above) during which the Governor calls the changer. Find it in the changer's **internal transactions** on Blockscout: the incoming call whose parent transaction is that `acceptedStep()`. Proposal documents usually also cite it as "TX ID" once executed. Write it in lowercase. It stays `null` until the changer is executed; a changer that was executed must have a `submitter`.

Fill it at least for mainnet: until MIP#263501 is executed there, the mainnet VotingMachine emits no events, so this field is the only record of the execution. On testnet the dapps read executions from the indexed events, so it is optional there.

### Address format

Addresses must carry a valid checksum: [EIP-55](https://eips.ethereum.org/EIPS/eip-55), which ignition's `deployed_addresses.json` uses, or [EIP-1191](https://eips.ethereum.org/EIPS/eip-1191) for the entry's network (chain 30 mainnet, 31 testnet), which Rootstock explorers and the documents' "Changer Contract" tables use. Both are accepted, so copy addresses exactly as the source shows them. Never retype or re-case them by hand; if the validator reports a checksum error, the address is wrong and the printed `expected` values show the valid casings.

An address may appear only once in the whole registry.

## Writing the summary

- One or two sentences, plain text, at most 500 characters. No markdown, links or line breaks.
- Say what the changer does and why, using only facts stated in the document. No opinions, no promises, no calls to vote.
- Name protocols and contracts as the document does (MoC, RoC, OMOC, RIF/USD, TasksRunner, ...).
- For a MIP without a changer, say what it is (e.g. "Post-mortem of ...", "... Executed as part of MIP#263101.").

## Order and formatting

- Keep `proposals` sorted by `mip`, newest first, the same order as the README list.
- Every MIP must also be in the README list, in its existing format:
  `` - `MIP#YYWWNN` — [Title](MIPYYWWNN-file-name.md) `` followed by ` — **DRAFT**` while it is a draft.
- Only the fields listed above are allowed; the validator rejects any other.
- Keep the file formatted with the repository's Prettier config (`pnpm exec prettier --write docs/proposals/proposals.json`, when dependencies are installed).

## Validate before finishing

```sh
node scripts/proposals/validate-proposals.mjs
```

It needs no installed dependencies. Fix every `error` line; CI fails on them. Report `warning` lines to the maintainer instead of fixing them by editing the documents, unless asked to: the documents are the published text.

## Checklist

- [ ] Every value comes from the document, an ignition deployment, the forum topic or the maintainer, never from a guess.
- [ ] Mainnet changers are in the document's "Changer Contract" section, testnet ones in an ignition deployment of the right network.
- [ ] Addresses are checksummed and not used by another entry.
- [ ] `tags` lists every project the changer modifies, and each `submitter` is the first `preVote` sender read from the chain (or `null`).
- [ ] Each executed mainnet changer has its `acceptedStep` transaction in `executedTx`.
- [ ] Existing changers were not modified or removed.
- [ ] Entry order and README list are in sync.
- [ ] `node scripts/proposals/validate-proposals.mjs` reports `0 error(s)`.
- [ ] Anything ambiguous was asked, not assumed, and is mentioned in the pull request.
