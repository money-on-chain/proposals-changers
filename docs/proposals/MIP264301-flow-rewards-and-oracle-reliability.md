# Flow Rewards and Oracle Reliability Improvements

> :memo: `MIP#264301`

> :warning: **Status: `Draft`**

## Overview

This proposal improves how MOC issuance reaches its recipients, how OMOC's TasksRunner handles several recurring operations, and how the BTC/USD and RIF/USD oracles publish prices. It also corrects the price used when RIF on Chain (RoC) users pay RIF bucket fees in MOC.

The issuance change is a step toward a decentralized rewards program for BPRO holders. It establishes a direct route for the existing rewards share, but **does not launch a new BPRO rewards program or change the amount or schedule of MOC issuance**. Further governance and implementation work would be needed for that program.

## Motivation

MOC issuance and oracle rewards currently pass through intermediate buffers that are no longer needed for their intended destinations. These extra steps add maintenance work and can leave balances waiting for a task to move them. Direct routing makes the flow easier to follow and reduces operational dependencies.

Some TasksRunner tasks can remain eligible when there is no useful work to perform, or retry a failing auction too frequently. Adjusting these tasks should help operators spend their turns on work that can succeed and avoid repeated failed transactions.

An oracle signature should only authorize a price publication for a short window. If a signed price can be held and published much later, the publisher has more opportunity to choose a favorable moment to use it. Giving new signatures an expiration timestamp lets oracle operators limit that price optionality. The oracle upgrade also prepares the price feeds to support publications requested by the protocol when an operation needs a fresh price.

## Proposed Changes

### 1. Route MOC issuance directly to its recipients

The Coiner will send each future MOC mint directly to the existing rewards buffer (75%) and the configured rewards multisig (25%). This bypasses the intermediate Coiner buffer. The current issuance amounts, two-stage issuance rules, and timestamp schedule remain in place.

The direct route makes the 75% rewards share available at its intended destination without depending on another automated transfer. It also creates a simpler starting point for a future decentralized BPRO-holder rewards program. This proposal does not define eligibility, distribution rules, or activation for that future program.

### 2. Simplify oracle and task rewards routing

The MOC rewards buffer currently sends 30% of its receipts through a second buffer, which then divides that share between the BTC/USD oracle and TasksRunner. The proposal sends those amounts directly: 27% of the rewards buffer's receipts to the BTC/USD oracle and 3% to TasksRunner. Its existing 70% destination remains in place.

The two intermediate buffers will no longer have automatic flush and liquidation tasks. Their existing recipients and proportions are retained for any balances already there, and their thresholds are cleared so remaining funds can be moved through the normal buffer functions. The migration pays out balances already assigned to outputs; very small unassigned rounding balances may remain.

### 3. Let smaller RIF-to-MOC balances reach their destinations

Three existing RIF-to-MOC reverse auctions fund the RIF/USD oracle, TasksRunner, and the MOC rewards buffer. Their order thresholds will fall from 20,000 RIF to 5,000 RIF. This allows accumulated RIF to be converted and delivered sooner, instead of waiting for a larger balance.

### 4. Correct TasksRunner eligibility and retries

The commission-splitting task will be replaced with one that checks the RBTC balance relevant to its splitter. MOC balances that the splitter does not use will no longer keep this task perpetually eligible after it has run.

The 13 registered reverse-auction trigger tasks will also be replaced. Each replacement retains its auction, but after a failed attempt it waits before retrying. The delay starts at five minutes, doubles after consecutive failures, and is capped at ten hours; a successful execution resets it. This reduces repeated failed calls while leaving the auctions available for later attempts.

### 5. Give oracle signatures an expiration timestamp

The BTC/USD and RIF/USD price feeds will gain a publication method in which new V4 oracle signatures include an expiration timestamp. A publication using a V4 signature must occur no later than that time. Oracle nodes can therefore choose a short validity window, reducing the opportunity to hold a signed price and choose when to publish it. The contract checks the signed expiration but does not impose a maximum window; its length depends on the timestamp the signers choose.

The current V3 publication method remains available during the transition, and the new method can also accept legacy V3 signatures. Those signatures do not themselves carry an expiration timestamp. The upgrade preserves each feed's current price, state, and round schedule. It also supplies the price-feed capability needed for future conditional publications when a protocol operation calls for a fresh price; this changer does not turn on conditional publication by itself.

### 6. Correct the MOC fee price in RoC's RIF bucket

When a user pays RIF bucket fees in MOC, the bucket needs a RIF-per-MOC price to calculate the MOC amount. Its current price provider can return an invalid price, leaving users to pay in RIF instead. The proposal switches the bucket to the existing MOC-to-RIF auction price provider, which supplies the required price. The fee token itself stays the same.

## Expected Outcome

MOC issuance and rewards reach their existing destinations through fewer steps, and the unused buffer tasks are retired. Smaller RIF balances can reach reward recipients sooner. TasksRunner avoids a permanently eligible split task and spaces out retries of failing auctions. The oracle feeds can accept short-lived signed prices and are prepared for a later move toward publication on protocol demand. RoC users should be able to pay RIF bucket fees in MOC when the replacement provider has a valid price.

## Changer Contract

The `MIP264301FlowUpdate` changer has not yet been assigned a mainnet address in this draft. Its address and verified code link will be added here before the proposal is submitted for voting.
