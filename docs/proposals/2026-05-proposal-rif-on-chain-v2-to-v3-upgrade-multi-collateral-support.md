# Proposal: RIF On Chain V2 → V3 Upgrade (Multi-Collateral Support)

## Overview

This proposal introduces an upgrade of the **RIF On Chain (RoC)** protocol from **version V2 to version V3**.

The main objective of this upgrade is to **extend the collateral model** by introducing **multi-collateral support**, allowing the protocol to use both:

- `RIF token` (existing collateral)
- `DOC token` (new collateral)

This enhancement strengthens the robustness and scalability of the system while preserving all existing business logic and protocol guarantees.

A coordinated **dApp update** will also be executed after governance approval.

---

## Problem Statement

**RIF** plays a central role in the protocol as the primary collateral backing **USDRIF**, directly linking the stablecoin’s growth to the expansion of the ecosystem while enabling yield generation for long-term holders.

As adoption increases, demand for **USDRIF** and the availability of **RIF** for collateralisation may diverge. This creates a dependency on a single asset that can limit the protocol’s ability to scale supply efficiently in line with market demand.

Expanding the collateral base with additional assets such as DOC—a rBTC-backed stablecoin—introduces greater flexibility and resilience into the system. This approach reinforces RIF’s role at the core of the protocol while complementing it with external sources of liquidity, enabling more consistent scaling of **USDRIF**, improved market responsiveness, and a more seamless and transparent user experience

---

## Proposed Changes

### 1. Multi-Collateral Support

The protocol will evolve from a **single-collateral model (RIF-only)** to a **dual-collateral model (RIF + DOC)**.

- A new collateral bucket based on `DOC` will be introduced
- Both collateral types will jointly support a single USDRIF supply
- The system will manage collateral through coordinated structures (buckets)

As described in the [V3 whitepaper](https://github.com/money-on-chain/stable-protocol-roc-v2/blob/master/doc/whitepaper.pdf), this architecture allows:

- RIF to absorb volatility and provide growth potential
- DOC to provide stability and capital efficiency

---

### 2. Improved Stability Model

The addition of DOC introduces a **stable collateral component**, which:

- Reduces reliance on RIF price dynamics
- Allows safer expansion of USDRIF supply
- Improves resilience during market stress

The system introduces mechanisms such as a **Multi-Collateral Guard**, which:

- Coordinates collateral across buckets
- Redistributes risk when one collateral becomes stressed

---

### 3. No Funds Migration Required

This upgrade **does not require users to migrate funds**.

Instead:

- Existing contracts will remain in place
- The upgrade will be executed through **proxy contract upgrades**
- New collateral integrations will be added at the protocol level

This ensures:

- Seamless transition for users
- No disruption of existing positions
- No need for manual interaction

---

### 4. No Changes to Business Logic

This upgrade **does not modify any existing protocol rules**:

- Minting and redemption logic remains unchanged
- Collateralization rules remain unchanged
- Fee structure remains unchanged

The upgrade **only adds new capabilities** by introducing an additional collateral option.

---

### 5. dApp Upgrade

A coordinated **dApp update** will be performed after governance approval.

- The dApp will enter **maintenance mode temporarily**
- The protocol itself will remain fully operational
- Users will not lose access to funds or protocol functionality

---

### 6. Governance Process

As with all protocol-level changes, this proposal will be submitted to a **governance vote**.

The upgrade will be executed only after:

1. Proposal approval through governance
2. Deployment of the changer contract
3. Execution of the upgrade transaction

---

## Technical Procedure

> ⚠️Warning: Some technical knowledge is required to fully understand this section.

The upgrade will be executed through a **changer contract**, which will:

- Configure new collateral structures
- Register new contracts
- Update protocol references

---

## Changer Contract

### The changer contract to vote would be:

|              Name               |                                          Address (and link to verified code in RSK blockscout explorer)                                          |
| :-----------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------: |
| `MultiCollateralUpgradeChanger` | [`0x839228759C6640BB486a05c11b6A81166D8A9DC7`](https://rootstock.blockscout.com/address/0x839228759C6640BB486a05c11b6A81166D8A9DC7?tab=contract) |

---

## Existing Contracts to be Upgraded or Reconfigured

The following contracts are already part of the protocol and will be upgraded or reconfigured as part of this proposal:

| Name                           | Description                                                                 | Address                                                                                                             |
| ------------------------------ | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `MocRif Proxy (RIF Bucket)`    | Main contract handling the RIF collateral bucket (to be upgraded via proxy) | [`0xA270...A36A`](https://rootstock.blockscout.com/address/0xA27024Ed70035E46dba712609fc2Afa1c97aA36A?tab=contract) |
| `USDRIF Proxy`                 | Stablecoin contract implementation (to be upgraded via proxy)               | [`0x3A15...6e37`](https://rootstock.blockscout.com/address/0x3A15461d8aE0F0Fb5Fa2629e9DA7D66A794a6e37?tab=contract) |
| `Legacy MocQueue (RIF Bucket)` | Existing queue contract used by the RIF bucket (state will be migrated)     | [`0x9181...A9E3`](https://rootstock.blockscout.com/address/0x9181E99dceace7dFd5f2E7d5126275D54067A9E3?tab=contract) |

---

## New Contracts and Implementations

The upgrade introduces new implementations and contracts required to support multi-collateral functionality:

| Name                              | Description                                                          | Address                                                                                                             |
| --------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `MocRif Implementation (V3)`      | New implementation for the RIF bucket logic                          | [`0x1a27...eC54`](https://rootstock.blockscout.com/address/0x1a2702d60a8B68B845709155b3d97E1Da85FeC54?tab=contract) |
| `USDRIF Implementation (V3)`      | Updated implementation for the USDRIF token                          | [`0x6D1B...5af9`](https://rootstock.blockscout.com/address/0x6D1BB87856A2b2351D87Ba5772a93dC911325af9?tab=contract) |
| `MocCoreExpansion Implementation` | Extension contract enabling new protocol capabilities                | [`0xd6a1...4207`](https://rootstock.blockscout.com/address/0xd6a161F27C37e94Eb1CA1bCDb67c0Bcd567E4207?tab=contract) |
| `New MocQueue Proxy (RIF Bucket)` | New queue contract using updated time-based logic                    | [`0x47f5...3Bf1`](https://rootstock.blockscout.com/address/0x47f5014115d3bb29B20b5168Ee75050D6f8c3Bf1?tab=contract) |
| `New Price Provider`              | Updated price provider for USDRIF                                    | [`0x6a5b...CC14`](https://rootstock.blockscout.com/address/0x6a5b2C84E63b5C1330bf4CcCff1Ad6F23116CC14?tab=contract) |
| `DOC Bucket (MocCARC20)`          | New bucket contract enabling DOC as collateral                       | [`0x6975...4661`](https://rootstock.blockscout.com/address/0x697535055Aa7AfD2C280523C7B062b1F05284661?tab=contract) |
| `RIF/DOC MocSwapper`              | Swapper contract enabling interaction between RIF and DOC collateral | [`0x0E60...7ba0`](https://rootstock.blockscout.com/address/0x0E60154be285810DFa1d64FaC5acb4804d7A7ba0?tab=contract) |
| `MocMultiCollateralGuard Proxy`   | Core contract coordinating collateral across buckets                 | [`0x0237...F46F`](https://rootstock.blockscout.com/address/0x0237Ad1f0831b479a344E56646BC48B0885cF46F?tab=contract) |
| `MocMultiCollateralGuard Impl.`   | Core contract coordinating collateral across buckets                 | [`0xC36D...3EBd`](https://rootstock.blockscout.com/address/0xC36DA47c94c57FDE23cEF9Fc436B4EdA9A7C3EBd?tab=contract) |

---

## Additional Technical Notes

- The `USDRIF` token will be extended to support minting and redemption from both:

  - `RIF Bucket`
  - `DOC Bucket`

- The `MocMultiCollateralGuard` will be updated to:

  - Register the new `DOC Bucket`
  - Coordinate collateral between both buckets

- The queue mechanism for the RIF bucket will be upgraded:

  - Migrating from block-based logic to timestamp-based logic
  - Preserving existing queue state (operation IDs)

- No contracts are removed as part of this upgrade. Existing infrastructure is extended.

- No user funds are migrated. All changes are executed through proxy upgrades and contract reconfiguration.

## References

- New Whitepaper (V3):  
  https://github.com/money-on-chain/stable-protocol-roc-v2/blob/master/doc/whitepaper.pdf

- Previous Whitepaper (V2):  
  https://github.com/money-on-chain/stable-protocol-roc-v2/blob/master/doc/whitepaper-2023-dec.pdf

- Changer Contract (Block Explorer):  
  https://rootstock.blockscout.com/address/0x839228759C6640BB486a05c11b6A81166D8A9DC7?tab=contract

---

## Summary

This proposal upgrades RIF On Chain to a **multi-collateral protocol**, enabling:

- Increased stability through DOC collateral
- Greater scalability of USDRIF issuance
- Improved resilience under market stress
- Seamless upgrade without fund migration
- No changes to existing protocol rules

The upgrade represents a **natural evolution of the protocol**, expanding its capabilities while preserving its core design principles.

## User Experience Improvements

In addition to the protocol-level enhancements, this upgrade introduces several improvements aimed at enhancing the overall user experience.

### 1. Updated and More Usable dApp

A new version of the dApp will be released alongside this upgrade, providing:

- Improved interface and navigation
- Better visualization of positions and collateral distribution
- Clearer representation of multi-collateral interactions
- Enhanced performance and responsiveness

This update makes the protocol more accessible to both new and existing users.

---

### 2. Support for Multiple Collateral Options

Users will be able to choose between different collateral types (`RIF` and `DOC`) when interacting with the protocol.

This provides:

- Greater flexibility in risk management
- Ability to select between volatile and stable collateral
- More efficient capital allocation depending on market conditions

---

### 3. Joint Operations

The protocol maintains and improves support for **joint operations**, allowing users to perform combined actions in a single transaction.

Examples include:

- Minting `USDRIF` together with collateral tokens when required to maintain coverage
- Redeeming collateral tokens together with `USDRIF` to unlock positions
- Combined operations that simplify user flows under constrained conditions

These operations reduce friction and improve capital efficiency.
