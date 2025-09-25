# Lithos DEX Guide

## System Overview

- Dual AMM design: stable pools use `x³y + y³x = k` for pegged assets, volatile pools use `xy = k` for non-correlated pairs.
- Router-driven UX sends trades and liquidity adds through `RouterV2`, which delegates to `Pair` contracts deployed by `PairFactory`.
- Gauges sit on top of `Pair` LP tokens; emissions only reach pools that have an active gauge and receive veNFT votes.
- Fees flow from the pair to `PairFees`, then split between LPs, veNFT stakers, and referral handlers according to factory settings.

## Admin Surfaces

### Roles & Addresses

| Control                     | Purpose                                   | How to Update                                                     |
| --------------------------- | ----------------------------------------- | ----------------------------------------------------------------- |
| **Pauser**                  | Pause pair creation and router joins      | `setPauser(address)` → new pauser calls `acceptPauser()`          |
| **Fee Manager**             | Configure trading, staking, referral fees | `setFeeManager(address)` → new manager calls `acceptFeeManager()` |
| **Staking Fee Recipient**   | Receives veNFT staking share              | `setStakingFeeAddress(address)`                                   |
| **Referral Handler (Dibs)** | Processes referral rebates                | `setDibs(address)`                                                |

### Trading & Fee Parameters

| Parameter         | Default                        | Max   | Function               |
| ----------------- | ------------------------------ | ----- | ---------------------- |
| Stable swap fee   | 0.04%                          | 0.25% | `setFee(true, 4)`      |
| Volatile swap fee | 0.18%                          | 0.25% | `setFee(false, 18)`    |
| Referral share    | 12% of total fee               | 12%   | `setReferralFee(1200)` |
| Staking share     | 30% of fees after referral cut | 30%   | `setStakingFees(3000)` |

## Architecture at a Glance

| Component                   | Responsibility                                       | Notes                                       |
| --------------------------- | ---------------------------------------------------- | ------------------------------------------- |
| **PairFactoryUpgradeable**  | Deploys pairs, holds global fee config, pause switch | Emits events consumed by off-chain indexers |
| **Pair**                    | Holds reserves, executes swaps, accrues fees         | Each pair mints ERC20 LP tokens             |
| **PairFees**                | Escrows fee balances until claimed                   | Called by Pair to transfer owed fees        |
| **GaugeV2**                 | Stakes LP tokens and streams emissions               | Created per pair via `VoterV3`              |
| **RouterV2 / GlobalRouter** | Adds/removes liquidity, multi-hop swaps              | Immutable logic once deployed               |

## Pair & Gauge Lifecycle

1. **Create pair**: `PairFactory.createPair(tokenA, tokenB, stable)` deploys the AMM pool.
2. **Whitelist tokens** (if not already): `VoterV3.whitelist(tokens[])` enables future gauges.
3. **Create gauge**: `VoterV3.createGauge(pair, 0)` (type `0` for standard AMM) so LPs can stake and receive emissions.
4. **Vote**: veNFT holders assign weight each epoch; only voted gauges receive weekly emissions from `Minter`.
5. **Distribute fees**: LPs must trigger `Pair.claimFees()`; veNFT voters receive their share through `VoterV3.distribute()` flows.

## Emission Mechanics

See `docs/TOKENOMICS.md` for the full emission curve, bootstrap lock flow, and rebase math; operators only need to ensure `Minter.update_period()` runs weekly so gauges receive the funds they vote for.

## Fee Flow Example

`$10,000` volatile swap at `0.18%` fee → `$18` total:

```
Referral (12%)           $2.16
Staking share (30%)      $4.75
LPs (balance)           $11.09
```

## LP Token Mechanics

### Minting (Add Liquidity)

1. `RouterV2.addLiquidity()` transfers tokens into the pair.
2. Pair mints LP tokens using the constant-product formula (with `MINIMUM_LIQUIDITY` burned on first mint).
3. LP balance is checkpointed against current fee indices before minting to keep earnings accurate.

### Burning (Remove Liquidity)

1. `RouterV2.removeLiquidity()` burns LP tokens.
2. Pair returns proportional reserves using the latest balances.
3. Fees are **not** auto-claimed; LPs must call `Pair.claimFees()` to pull accrued amounts.

### Fee Accounting Model

| Mapping                   | Meaning                                     |
| ------------------------- | ------------------------------------------- |
| `index0/index1`           | Global fee index per LP token (18 decimals) |
| `supplyIndex0/1[account]` | Last index synced for an LP                 |
| `claimable0/1[account]`   | Stored, unclaimed fees owed                 |

An `_updateFor(account)` call (triggered on mint/burn/transfer) applies `delta = index - supplyIndex`, adds `balance * delta / 1e18` to `claimable`, and rewrites the stored index.

## Operational Checklist

- **Weekly**: ensure `Minter.update_period()` ran, then `VoterV3.distributeAll()` so gauges pull emissions and push fee rewards.
- **Liquidity onboarding**: keep anchor assets whitelisted so partners can request pair + gauge creation ahead of launch.
- **Parameter reviews**: compare swap volumes vs. fee levels; adjust `setFee` and `setReferralFee` if routing competitiveness slips.
- **Monitoring**: track per-pair TVL, fee spillage, and gauge health via factory/gauge events.

## Emergency Tooling

- Pause new pair creation and router joins: `PairFactory.setPause(true)`.
- Disable a problematic gauge: `VoterV3.killGauge(gauge)`; revive with `reviveGauge` after remediation.
- Enable withdrawals-only mode on a gauge: `GaugeV2.activateEmergencyMode()` then `stopEmergencyMode()` once safe.
