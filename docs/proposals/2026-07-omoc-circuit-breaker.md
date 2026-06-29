# Implementation of an Oracle Circuit Breaker and some other improvements


> :warning: Because this is a low-criticality change, the intention is that it may be included as an addendum to a future proposal if the community agrees.

> :information_source: Info: This document is intended to provide a clear introduction and reference so that subsequent proposals can refer to these changes directly. 


## Overview

This proposal introduces an Oracle Circuit Breaker mechanism for the Money on Chain Decentralized Oracle protocol (OMOC), designed to provide immediate protection against potential data integrity issues in the oracle network. The circuit breaker enables the foundation to make all responses to oracle price queries return as invalid when integrity or data quality concerns are detected, signaling that the data cannot be trusted or reverting the transaction. This critical safety mechanism ensures that if future incidents compromise data reliability, the OMOC protocol and dependent third-party protocols can be protected immediately while investigation and remediation occur.

## Problem Statement

The need for an Oracle Circuit Breaker for OMOC emerged from the **[Panic Button Activation Incident Report](https://forum.moneyonchain.com/t/panic-button-activation-incident-report/462)**, which exposed critical vulnerabilities in third-party protocols consuming data from the decentralized oracle network (OMOC). During that incident, many external protocols lacked the capability to pause their operations immediately or could only do so partially, creating cascading risks across the ecosystem.

While the identified issues were successfully resolved in the **[Oracle Reliability Fix and Protocol Unpause Proposal](https://forum.moneyonchain.com/t/oracle-reliability-fix-and-protocol-unpause-proposal/459)** and no further incidents have been detected, we recognize that implementing an oracle circuit breaker for OMOC provides an essential protective mechanism for any unforeseen future incidents. This proposal ensures the OMOC protocol and its ecosystem have a robust tool to mitigate risks immediately, preventing potential damage while investigation and remediation are underway.

## Proposed Changes

### 1. Implementation of an Oracle Circuit Breaker

#### Mechanism

The OMOC Oracle Circuit Breaker is a safety mechanism that can immediately make all responses to price queries indicate invalid data. When activated, all price queries to the OMOC oracle respond with invalid price signals or revert the transaction, preventing any further consumption of potentially compromised data by the OMOC protocol and dependent third-party protocols.

#### Operational Characteristics

- **Immediate Response**: When the circuit breaker is activated, all OMOC oracle price queries immediately respond with invalid prices or transaction reverts, with no delay.
- **No Price Manipulation**: The OMOC circuit breaker mechanism provides no capability to manipulate or influence actual price values—it can only signal that prices are invalid or revert queries when integrity is suspected.
- **Data Integrity Focus**: The circuit breaker is designed exclusively to protect against data integrity and quality concerns in the OMOC network, serving as an emergency response tool rather than a normal operational control.

#### Authority and Governance

- **Delegated Authority**: The capability to activate the circuit breaker will be delegated to the Money on Chain Foundation, which operates as a trusted steward of the protocol.
- **Community Control**: The Money on Chain community retains ultimate authority through governance. If the community determines at any point that the foundation should no longer hold this capability, it can be removed through a governance vote.
- **Transferable Responsibility**: Similarly, the community can transfer this responsibility to another entity through governance if deemed appropriate.

#### Purpose and Scope

This circuit breaker serves as a last-resort protective mechanism against unlikely but potentially severe data integrity incidents in the OMOC network. It ensures that:
- The OMOC protocol can respond immediately to protect the ecosystem if data quality is compromised
- Third-party protocols dependent on OMOC oracle data have a stable data source or clear signal that data cannot be trusted
- Investigation and remediation can proceed without cascading damage across the ecosystem

#### Technical Implementation

> :warning: Warning: some technical/coding knowledge is necessary to fully understand this document

This circuit breaker mechanism will be implemented through the foundational changes introduced in the [Add forced price invalidation and forced revert modes to CoinPairPrice #29](https://github.com/money-on-chain/OMoC-Decentralized-Oracle/pull/29) pull request, which adds the capability to force price invalidation and transaction reverts at the `CoinPairPrice` contract level.

### 2. Additional Enhancements

#### 2.1 Automatic Unsubscription of Oracle Operators Upon Stake Withdrawal

With this enhancement, oracle operators who withdraw their stake below the minimum threshold required for participation will be automatically unsubscribed from active coin pair rounds. Provides the benefits of **Faster Operator Onboarding**: New oracle operators can participate more quickly without waiting for the current round to end and automatically removes inactive operators from rounds when they no longer meet the minimum stake requirements.

> :warning: Warning: some technical/coding knowledge is necessary to fully understand this document

This improvement, implemented through the [Unsuscribe oracles when withdraw their stake #30](https://github.com/money-on-chain/OMoC-Decentralized-Oracle/pull/30) pull request

## Summary

This proposal improves the long-term sustainability and robustness of the Money on Chain Oracle (OMOC) protocol by:

- **Implementing an Oracle Circuit Breaker for OMOC**: A safety mechanism that enables immediate response to potential data integrity incidents in the Money on Chain Oracle network, protecting the OMOC protocol and its ecosystem from cascading failures.
- **Delegating Emergency Authority Responsibly**: Granting the Money on Chain Foundation the capability to activate the OMOC circuit breaker while maintaining community governance control through governance voting.
- **Providing Ecosystem Protection**: Ensuring that dependent protocols and the broader Money on Chain ecosystem have a mechanism to signal and respond to data integrity concerns in OMOC, preventing exposure to potentially compromised price data.
- **Establishing a Complete Incident Response Strategy**: Closing the feedback loop from the Panic Button Activation Incident by demonstrating how the OMOC protocol is prepared to protect itself and the ecosystem against similar situations in the future.

Together, these changes improve OMOC protocol maintainability, strengthen operational resilience, and support the long-term sustainability and trustworthiness of the Money on Chain Oracle network.

## Governance Process

As with all protocol-level changes, this proposal will be submitted to a **governance vote**.
