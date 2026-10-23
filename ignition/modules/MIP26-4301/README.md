# MIP26-4301

Deploys Coiner from `@moc/flow` (`MoC-Flow v3.0.5`) and its governance changer.
The changer upgrades the existing Coiner proxy through the Flow UpgradeDelegator,
then calls `setMintDistribution` in the same transaction. The constructor receives
`destination` and `secondaryDestination` from the Ignition parameter file.
The secondary share is fixed by `SECONDARY_PERCENT = 2500` (25%).
Both network files configure:

- Primary destination: `0xf09006E812BE98c7B18c877Af5C126629acB6cAb` (75%).
- Secondary destination: `0xA088A8FCD247dcB1E99c7f98e2ef3CA7f274B183` (25%, `2500` basis points).

The changer also removes the buffer's flush and liquidate tasks from TasksRunner,
sets its general liquidation threshold to zero, and clears every output's flush
threshold by removing and recreating all outputs in their original order.
Recipients and splits are preserved. Removing each output transfers its pending
balance to its existing recipient; recreated outputs start with zero pending balance.
Unallocated funds remain available for subsequent manual liquidation and flushing.
Historical rounding dust that was never assigned to an output can remain.

The parameter names are `coinerBuffer`, `coinerBufferFlushTask` and
`coinerBufferLiquidateTask`.

Mainnet uses buffer `0x5646c6988d5D3d7F78F15683CE3aca11699BCDBb` with:

- Flush task: `0x23428Ef986A8DcC067152F0a2C46FcC476d2AA9f`.
- Liquidate task: `0x1D994baB150f55332F39aaeE3bC94cb4CA73A659`.

Testnet uses its existing Coiner destination buffer
`0xBBD8aFD5E7D3127D9Ee372D9AD2BC0B0af8af066` and its corresponding tasks.

The changer also removes the flush and liquidate tasks of `tasksRunnerBuffer`.
Mainnet uses `0x5028486837bcF926AD02E935cfFC3D475B39E189` with:

- Flush task: `0xfA56735EB4da217F3a607a43Ed51117c76923ae3`.
- Liquidate task: `0x02643c891Df6b31E2d557be10e654Af1EE007D64`.

The parameter names are `tasksRunnerBuffer`, `tasksRunnerBufferFlushTask` and
`tasksRunnerBufferLiquidateTask`. Testnet uses the corresponding existing buffer
`0x3aE12abBa72256271F8b0d403fC2B7e3A0a3d795`, which distributes 90% to the BTC/USD
coin pair and 10% to TasksRunner. As with `coinerBuffer`, the changer sets its
general threshold to zero and recreates its outputs with the original recipients
and splits and zero thresholds. Pending output balances are paid during removal.

The changer also updates `mocRewardsBuffer`, mainnet
`0xf09006E812BE98c7B18c877Af5C126629acB6cAb`. It keeps the existing 70% output intact,
removes the 30% output pointing to `tasksRunnerBuffer`, and adds:

- 3% to `tasksRunner`.
- 27% to `btcUsdCoinPair` (`0xa288319eCb63301e21963E21EF3Ca8fb720d2672` on mainnet).

Both new outputs inherit the replaced 30% output's threshold. Removing the old
output pays its pending balance to its previous recipient. The rewards buffer's
general threshold and its existing automation remain unchanged.
Testnet uses rewards buffer `0x40d86d6ac67059bAe5ae42B6FCaB843c1c6af300` and the
network's BTC/USD coin pair. Both addresses are supplied as Ignition parameters
`mocRewardsBuffer` and `btcUsdCoinPair`.

The deployed BufferToken has no output threshold setter. The changer snapshots
recipients and splits, removes outputs from the last index to the first, then adds
them back in their original order with zero thresholds using `removeOutput` and
`addOutput`.

The changer lowers `orderThreshold` from 20,000 to 5,000 RIF (`5000 * 10^18`)
for these three mainnet reverse auctions:

- `reverseAuctionRifToMoc`: `0xf674b1e58c791A96735DC0431C3e83c67e6e1609` (RIF/USD coin pair).
- `reverseAuctionRifToMoc2`: `0x437427737A562239a3f1e73cb3A9F87FE258150c` (TasksRunner).
- `reverseAuctionRifToMoc3`: `0x323f6117A256E8f697Ac8d2816eb71e9B7134809` (MOC rewards buffer).

Ignition supplies the three addresses as an array to the constructor. The new
threshold is fixed by `RIF_TO_MOC_ORDER_THRESHOLD = 5000 ether`. Testnet parameters
use the corresponding existing RIF-to-MOC auctions with the same output roles.

The existing Coiner emission amounts and timestamp schedule are preserved. This assumes
MIP26-3701 has already migrated Coiner to timestamp scheduling.
Network proxy and delegator addresses come from the MIP26-3701 parameters.

```bash
pnpm run deploy:testnet:mip26-4301:ignition
pnpm run deploy:mainnet:mip26-4301:ignition
```

These commands deploy the implementation and changer. Governance executes the changer.

The fork test uses the real mainnet Coiner proxy, MOC token and governance at
block `9350345`. It deploys the proposed Coiner implementation and changer.
It checks state preservation, both mint stages, authorization, atomic rollback,
removal of both buffers' flush and liquidate tasks and manual draining of both buffers to the configured
recipients. It also verifies rewards routing at 70/3/27 and the three auction
thresholds changing from 20,000 to 5,000 RIF.
Buffer tests prepare MOC balances directly with `deal`, independently of Coiner
issuance.
The stage-2 test uses an auxiliary changer through real governance to set the
threshold to the remaining issuance, avoiding the token circulation cap while
exercising that branch on the real Coiner and MOC token.

```bash
pnpm exec hardhat test solidity contracts/tests/MIP264301FlowUpdateFork.t.sol
```

Set `RSK_MAINNET_RPC_URL` to override the public mainnet RPC used by the test.
