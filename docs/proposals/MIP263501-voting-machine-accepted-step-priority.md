# Grant Proposal Submitters a Temporary Accepted-Step Priority

> :memo: `MIP#263501`

> :warning: **Status: `Implemented`**

## Overview

This proposal upgrades the Money on Chain Voting Machine so that the person who submitted an accepted proposal has exclusive access to execute its accepted step for a limited period.

Once that period ends, anyone can execute the accepted proposal as they can today.

---

## Motivation

### Proposals that depend on blockchain state

The current voting process does not support proposals that must be executed when the blockchain is in a particular state. Anyone can execute an accepted proposal immediately. If they execute it at the wrong time and its conditions are not met, the changer reverts. The proposal then needs to be voted on again, delaying the application of the intended change.

This is not just a theoretical limitation. Some planned changes require the RIF price to be valid and the RIF queue to be empty when the changer executes.

This proposal gives the original submitter a short, exclusive opportunity to wait for a suitable block and execute the accepted changer when its required state is present.

### Fix to known issue GOV-11: Proposal round counter could wrap after 256 proposals

The current deployed Voting Machine stores its proposal voting-round counter as `uint8`, limiting it to 256 rounds. If the counter wraps, proposal and voter-round tracking can be affected. [GOV-11 — Proposal round counter could wrap after 256 proposals](https://gist.github.com/nubis/9c24c0e2792e4dbb25db74f8f478756f#gov-11--proposal-round-counter-could-wrap-after-256-proposals) records this known issue and its remediation in the Voting Machine implementation. MIP#263501 deploys the upgraded implementation that widens the counter, fixing the issue while also adding the temporary accepted-step priority window.

---

## Proposed Change

The changer will upgrade the Voting Machine and configure a limited accepted-step priority window.

When a proposal is accepted, the Voting Machine records the address that originally submitted it. During the configured priority window, only that address may execute the accepted step.

The accepted-step priority window is configured as 86,400 seconds (24 hours).

After the window expires, execution becomes permissionless again. Any address may execute the accepted proposal.

This gives the proposer time to select an appropriate execution block without permanently restricting community access to accepted proposals.

### Limits

This mechanism does not guarantee that a suitable blockchain state will occur. A proposal that depends on a particular state must still be able to meet its requirements within the configured priority window.

If that state does not occur in time, the changer can still fail and the proposal may need to be submitted and voted on again.

---

## Expected Outcome

After this proposal is executed:

- a proposal's original submitter will have temporary exclusive access to its accepted step;
- changers that depend on a specific blockchain state can be executed at a more appropriate time; and
- accepted proposals remain permissionless to execute once the priority window ends.

---

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a governance vote.

The upgrade will be executed only after:

1. proposal approval through governance;
2. deployment and verification of the changer contract; and
3. execution of the approved changer.

---

## Changer Contract

For implementation-level questions, readers can give their preferred AI assistant the verified contract URL. The verified source code contains the complete implementation and can be used to answer specific technical questions about the change.

### The changer contract to vote would be:

| Name                           | Address (and link to verified code in RSK blockscout explorer)                                                                                   |
| :----------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------- |
| `VotingMachineUpgradeProposal` | [`0x1130acdf30D3c7a550c263152DCd99aCFf7c0d05`](https://rootstock.blockscout.com/address/0x1130acdf30D3c7a550c263152DCd99aCFf7c0d05?tab=contract) |

> :information_source: Info: All changes, upgrades, and reconfigurations to existing contracts, including the exact parameter values, can be audited directly in the changer contract, whose [source code is published and verified in the block explorer](https://rootstock.blockscout.com/address/0x1130acdf30D3c7a550c263152DCd99aCFf7c0d05?tab=contract) linked above.
---

## Status

📣 The voting process is over:
* `29.4%` of the MOC tokens total supply participated in the vote.
* `100%` voted in favor.
* No one vote voted against the proposal.
* The change was successfully implemented.

[TX ID: `0x09cb3f27f3ca9c54a2dadc4ea37f1b941a856d5fa10168e365ff914017b878da`](https://rootstock.blockscout.com/tx/0x09cb3f27f3ca9c54a2dadc4ea37f1b941a856d5fa10168e365ff914017b878da)
