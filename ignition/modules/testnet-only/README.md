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
