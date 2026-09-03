# Testnet-only changers

The changers in this directory are only executed on testnet. They are not
intended for mainnet and must never be deployed or executed there.

These changers are used to maintain the testnet versions of the Money on Chain
protocols. They may use the testnet backdoor mechanism instead of the production
governance flow.

## Testnet voting times

`TestnetVotingTimesChanger` configures the governance voting period to 20
minutes and the pre-voting proposal expiration period to 5 minutes.

Deploy it on Rootstock testnet with:

```bash
pnpm run deploy:testnet:voting-times:ignition
```

## Testnet voting quorum

`TestnetVotingQuorumChanger` configures the minimum voting quorum to 14% of
the total MOC token supply. At a total supply of 100,848,924 MOC, this requires
approximately 14,118,849 MOC to participate.

Deploy it on Rootstock testnet with:

```bash
pnpm run deploy:testnet:voting-quorum:ignition
```

Execute the deployed changer through the testnet backdoor mechanism.

## Legacy UpgradeDelegator governor alignment

`TestnetLegacyUpgradeDelegatorGovernorChanger` changes the governor of the
legacy UpgradeDelegator `0x546afdf647d0b5c73323366b090ebe6c0c4d9b2c` to the
VotingMachine controlled Governor
`0x7b716178771057195bB511f0B1F7198EEE62Bc22`.

Deploy it on Rootstock testnet with:

```bash
pnpm run deploy:testnet:legacy-upgrade-delegator-governor:ignition
```

The legacy UpgradeDelegator is initially governed by
`0x165138C5A2888Fb5230EbF5eC277F0D2E5611d03`. Its multisig owner must call
`executeChange(changer)` on that Governor **directly**. Do not use the normal
`testnet-backdoor` helper for this changer: that helper executes target
changers through the controlled Governor, which is not yet authorized here.
