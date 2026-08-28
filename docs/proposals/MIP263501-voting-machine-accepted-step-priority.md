# Grant Proposal Submitters a Temporary Accepted-Step Priority

> :memo: `MIP#263501`

> :warning: **Status: DRAFT**

## Overview

This proposal upgrades the Money on Chain Voting Machine so that the person who submitted an accepted proposal has exclusive access to execute its accepted step for a limited period.

Once that period ends, anyone can execute the accepted proposal as they can today.

---

## Motivation

### Proposals that depend on blockchain state

The current voting process does not support proposals that must be executed when the blockchain is in a particular state. Anyone can execute an accepted proposal immediately. If they execute it at the wrong time and its conditions are not met, the changer reverts. The proposal then needs to be voted on again, delaying the application of the intended change.

This is not just a theoretical limitation. Some planned changes require the RIF price to be valid and the RIF queue to be empty when the changer executes.

This proposal gives the original submitter a short, exclusive opportunity to wait for a suitable block and execute the accepted changer when its required state is present.

---

## Proposed Change

The changer will upgrade the Voting Machine and configure a limited accepted-step priority window.

When a proposal is accepted, the Voting Machine records the address that originally submitted it. During the configured priority window, only that address may execute the accepted step.

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

The changer address and its verified-source URL will be added before the governance vote.

For implementation-level questions, readers can give their preferred AI assistant the verified contract URL. The verified source code contains the complete implementation and can be used to answer specific technical questions about the change.

| Changer address and verified source |
| :---- |
| `TBD` |
