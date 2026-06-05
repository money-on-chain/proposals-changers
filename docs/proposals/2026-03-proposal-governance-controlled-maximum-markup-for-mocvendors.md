# Proposal: Governance-Controlled Maximum Markup for MocVendors

> :information_source: Info: This does not affect the stablecoin protocol, it only affects the `MocVendors` in _RIF on chain_.

## Summary

This proposal introduces a protocol-level maximum markup (`maxMarkup`) for the MocVendors contract. The goal is to establish a governance-controlled upper bound on vendor markup values without modifying the current operational conditions for vendors.

The maximum markup value will be set exclusively through the MoC governance system by MoC token holders.

This change provides a forward-looking framework of rules where MoC holders can influence vendor behavior while preserving the current vendor ecosystem.

## Motivation

Currently, vendors can set their markup values without a protocol-level upper limit. While this flexibility is useful, it leaves open the possibility of extreme configurations that could negatively affect users and the ecosystem.

This proposal does **not** modify existing vendor markups or operating conditions. Instead, it introduces a governance-controlled safety boundary that can be activated and adjusted over time.

The intention is to:

- Preserve the current vendor model
- Provide a governance-based framework of rules
- Improve predictability for users
- Limit extreme fee extraction scenarios

## Specification

### Maximum Markup

> :warning: Warning: Some technical/coding knowledge is necessary to fully understand this document.

A new parameter `maxMarkup` is introduced in the `MocVendors` contract.

Properties:

- Enforced at the protocol level
- Applies to every markup update
- Cannot be exceeded
- Governed through MoC governance

```
function setMaxMarkup(uint256 newMaxMarkup) external onlyAuthorizedChanger
```

Only governance-authorized changers can update `maxMarkup`.

If a vendor attempts to set a markup higher than `maxMarkup`, the transaction reverts:

```
error MarkupTooHigh();
```

### Governance Control

The value of `maxMarkup` will be determined exclusively through governance voting by MoC token holders.

This ensures that:

- Risk limits are community-defined
- Changes are transparent
- The policy is auditable
- The limits can evolve over time

## Rationale

### Governance-based Vendor Oversight

The proposal establishes a governance framework that allows MoC holders to regulate vendor behavior without interfering with day-to-day operations.

It introduces a mechanism for ecosystem-wide coordination while preserving vendor autonomy.

## Additional Benefits

### 1. Predictable Markup Updates

Markup updates are not applied immediately in the same block they are submitted. Instead, updates are staged and only become effective after a _cooldown_ period.

This creates a protection window where users continue trading under the previously active markup.

Benefits include:

- Improved execution predictability
- Reduced adversarial pricing behavior
- Protection against last-minute markup increases

### 2. Stronger Economic Risk Controls

`maxMarkup` introduces a hard protocol-level ceiling enforced on every update (`MarkupTooHigh` if exceeded).

This prevents outlier configurations and limits worst-case fee extraction, even if a privileged actor attempts to set an abusive value.

Because `maxMarkup` is governed through `setMaxMarkup` (`onlyAuthorizedChanger`), risk policy can evolve over time while remaining explicit and auditable.

### 3. Improved Vendor Autonomy

When a vendor calls `setMarkup`, delegation to the guardian is revoked.

From that point forward, the guardian can no longer change that vendor’s markup. This removes unilateral control paths and gives vendors direct ownership of their fee policy.

This provides a clear autonomy model:

- Vendors may initially rely on delegated operations
- Vendors can later opt into full control
- The decision is permanent

## Backwards Compatibility

This proposal does not modify:

- Existing vendor registrations
- Existing markup values
- Vendor operational flows

All current vendors will continue operating exactly as before, provided their markup remains below `maxMarkup`.

## Security Considerations

### Governance Risk

Since `maxMarkup` is governance-controlled, incorrect parameter selection could negatively affect new vendors.

However:

- Governance decisions are transparent
- Changes are auditable
- Parameters can be updated over time

### Vendor Autonomy

Revoking guardian delegation when vendors set their markup removes centralized intervention capability. This is intentional and aligns incentives toward vendor responsibility.

## Initial Parameter Value

The initial value proposed for `maxMarkup` is **2%**.

This value is intentionally set well above the markup levels currently used by active vendors, ensuring that no existing vendor is affected by this change at the time of activation.

The purpose of setting the initial value at 2% is to introduce the governance-controlled ceiling without disrupting current market dynamics.

In the future, this value may be adjusted through governance voting if ecosystem conditions require it.

## Conclusion

This proposal introduces a minimal but powerful extension to the MocVendors contract.

It preserves the current vendor ecosystem while giving MoC holders the ability to define long-term economic boundaries.

The result is a safer and more predictable marketplace without imposing immediate changes on existing vendors.

## Governance Process

As with all protocol‑level changes, this proposal will be submitted to a **governance vote** within the Money on Chain governance system.

Upon approval, deployment and reconfiguration will be executed following standard upgrade procedures.


## Contracts that will be changed

Only the implementation of the `MocVendors` contract will be replaced.

|             |                                             Address                                                              |
| :---------: | :--------------------------------------------------------------------------------------------------------------: |
| `Proxy`     | [`0x5f69…7012`](https://rootstock.blockscout.com/address/0x5f69Df7e853686a794c13BE029FF228642C07012?tab=contract)|
| `Old impl.` | [`0x7d6E…56BC`](https://rootstock.blockscout.com/address/0x7d6Ed1214289618d64c88EdCaa18F651715856BC?tab=contract)|
| `New impl.` | [`0x4FaA…528c`](https://rootstock.blockscout.com/address/0x4FaA94aF6C936E961218518a8c4535AD14b8528c?tab=contract)|


## Technical procedure

> :warning: Warning: Some technical/coding knowledge is necessary to fully understand this document.

In order to fix these contracts a change contract must be deployed and it will be necessary go through the voting process to make the changes.

### The changer contract to vote would be:

|             Name           |                                          Address (and link to verified code in RSK blockscout explorer)                                          |
| :------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------: |
| `MocVendorsUpgradeChanger` | [`0x47F0704751012f531165FBBDba2FCb3843514935`](https://rootstock.blockscout.com/address/0x47F0704751012f531165FBBDba2FCb3843514935?tab=contract) |
