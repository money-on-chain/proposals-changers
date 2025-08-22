# Money on Chain – Changers

This repository collects contracts for proposed **changers** of the Money on Chain protocol and the tooling to deploy, validate and test them. Each changer is intended to be executed only once by governance.

## Included changers

### FeesAndBitProRateProposal
Sets a new BitPro rate and loads a complete fee table by transaction type into the `MoCInrate` contract. After execution it burns its own references to prevent re-running.

### RemovePanicButtonProposal
Calls `makeUnstoppable` on the `MoC` contract to remove the panic button. It also burns a fuse after its first run.

## Project structure

- **contracts/** – changer contracts and minimal interfaces.
- **config/<changer>/** – network parameters in `deployConfig-<network>.json`. After a successful deploy the `changerAddress` is updated.
- **scripts/<changer>/** – `deploy.js`, `validate_prevote.js` and `verify.js` scripts for deployment, pre-vote validation and Blockscout verification.
- **test/** – unit tests (`*.spec.js`) and fork tests (`test/fork/*.fork.spec.js`).

## Requirements

- Node.js >= 18
- Dependencies: `npm install`

## Running tests

```bash
# Local unit tests
npx hardhat test test/fees_and_bitprorate.spec.js

# Fork tests (requires an RPC in FORK_URL)
FORK_URL=https://... npx hardhat test test/fork/fees_and_bitprorate.fork.spec.js
FORK_URL=https://... npx hardhat test test/fork/remove_panic_button.fork.spec.js
```

## Deployment

1. Fill `config/<changer>/deployConfig-<network>.json` with addresses and parameters.
2. Run the deploy script:
   ```bash
   npx hardhat run scripts/<changer>/deploy.js --network <network>
   ```
   `DEPLOY_CONFIG_PATH` can point to an alternate config file.

## Pre-vote validation

```bash
npx hardhat run scripts/<changer>/validate_prevote.js --network <network>
```
Checks on-chain storage of the changer matches the local configuration.

## Contract verification

```bash
npx hardhat run scripts/<changer>/verify.js --network <network>
```
Optionally set `VERIFY_ADDRESS` to explicitly specify the address to verify.

## Notes

- Fork tests require `FORK_URL` (and optionally `FORK_BLOCK`) configured in `hardhat.config.js`.
- Scripts use ES Modules and Hardhat v3.