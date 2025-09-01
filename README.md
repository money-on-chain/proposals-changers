# Money on Chain – Proposals changers

This repository collects contracts for proposed **changers** of the Money on Chain protocol and the tooling to deploy, validate and test them. Each changer is intended to be executed only once by governance.

## Included proposals

### Proposal 20250826 - 2025/08/26 - Fee reduction

See: [docs/P20250826.md](docs/P20250826.md)

## Project structure

- **contracts/** – changer contracts and minimal interfaces.
- **config/fees_and_bitprorate/** – network parameters in `deployConfig-<network>.json`. After a successful deploy the `changerAddress` is updated.
- **scripts/fees_and_bitprorate/** – `deploy.js`, `validate_prevote.js`, `verify.js` and `validate_aftervote.js` scripts for deployment, pre-vote validation and Blockscout verification.
- **test/** – unit tests (`*.spec.js`).

## Requirements

- Node.js >= 22.10 `nvm use`
- Dependencies: `npm install`
- set .env `cp .env.example .env`
- Compile: `npm run compile`


## Running tests example

```bash
# Local unit tests
npx hardhat test test/fees_and_bitprorate.spec.js
```

```bash
# Hard forks (requires FORK_URL in hardhat.config.js or env)
npm run test
```

## Deployment

1. Fill `config/fees_and_bitprorate/deployConfig-<network>.json` with addresses and parameters.
2. Run the deploy script:
   ```bash
   npx hardhat run scripts/fees_and_bitprorate/deploy.js --network <network>
   ```
   Optionally set `DEPLOY_CONFIG_PATH` to point to an alternate config file.

## Pre-vote validation

```bash
npx hardhat run scripts/fees_and_bitprorate/validate_prevote.js --network <network>
```

Checks on-chain storage of the changer matches the local configuration.

## Contract verification

```bash
npx hardhat run scripts/fees_and_bitprorate/verify.js --network <network>
```

Optionally set `VERIFY_ADDRESS` to explicitly specify the address to verify.

## After-vote validation

```bash
npx hardhat run scripts/fees_and_bitprorate/validate_aftervote.js --network <network>
```

## Forking test

The forking test are part of integral test

```bash
npm run test
```

Checks on-chain storage of the changer matches the local configuration.

## Notes

- Fork tests require `FORK_URL` (and optionally `FORK_BLOCK`) configured in .env
- Scripts use ES Modules and Hardhat v3.
