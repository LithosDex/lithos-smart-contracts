# Lithos Tokenomics Guide

## System Flywheel

1. **Lock**: Stake LITHOS into `VotingEscrow` to mint veNFT voting power (max lock 104 weeks).
2. **Vote**: veNFT holders direct emissions toward gauges attached to liquidity pools.
3. **Emit**: `MinterUpgradeable.update_period()` mints weekly LITHOS, allocates to team, rebases, then pushes the rest to `VoterV3`.
4. **Distribute**: `VoterV3.distribute()` streams emissions to gauges; LPs stake to capture rewards and pool fees.
5. **Recycle**: Trading fees flow back to veNFT voters, incentivizing deeper locks and higher participation.

## Key Parameters

### Emission Controls

| Parameter       | Default                    | Bounds                        | Function                                                                    |
| --------------- | -------------------------- | ----------------------------- | --------------------------------------------------------------------------- |
| Weekly emission | 2.6M LITHOS                | 2-3M suggested                | `Minter.setEmission(uint256)` sets the starting weekly figure (18 decimals) |
| Decay           | 99%                        | 98-99.5% typical              | `Minter.setEmission(990)` → next week = `current * 990 / 1000`              |
| Tail emission   | 0.2% of circulating supply | Hard floor                    | `Minter.setTailEmission(2)`                                                 |
| Max rebase      | 30% of weekly              | 20-30% recommended            | `Minter.setRebase(300)`                                                     |
| Team allocation | 4%                         | Hard max 5% (`MAX_TEAM_RATE`) | `Minter.setTeamRate(40)`                                                    |

### veNFT & Voting

| Parameter     | Default          | Cap    | Function                                              |
| ------------- | ---------------- | ------ | ----------------------------------------------------- |
| Vote delay    | 0 seconds        | 7 days | `VoterV3.setVoteDelay(uint256)`                       |
| Whitelist     | Project-specific | -      | `VoterV3.whitelist(address[])` enables gauge creation |
| Epoch cadence | 604,800 seconds  | Fixed  | Epoch ticks drive emission and vote resets            |
| Lock window   | 1-104 weeks      | Fixed  | Enforced in `VotingEscrow`                            |

## Launch Checklist

- **Mint supply**: `LITHOS.initialMint(treasury)` (one-time 50M).
- **Bootstrap locks**: `Minter._initialize(recipients, amounts, total)` runs exactly once while `_initializer` is true; it mints up to `total`, approves `VotingEscrow`, and `create_lock_for` stakes each amount for the full two-year term so supply grows without increasing float.
- **Transfer control**: `LITHOS.setMinter(minter)`, `VotingEscrow.setVoter(voter)`, `VoterV3.setMinter(minter)`.
- **Confirm parameters**: Run `setEmission`, `setRebase`, `setTeamRate`, and factory fee calls prior to opening voting.

## Emission Mechanics

- **One-time mints**: `initialMint` drops a single 50M tranche to the treasury after `setMinter`, and `_initialize(claimants, amounts, max)` (callable once) streams up to `max` into two-year veNFT locks via `create_lock_for`; any remainder idles on the minter (`contracts/Thena.sol:34-39`, `contracts/MinterUpgradeable.sol:72-88`, `contracts/VotingEscrow.sol:764-776`).
- **Baseline schedule**: `update_period()` begins at 2.6M and applies `next = current * EMISSION / 1000` (default 0.99 multiplier) but never drops below `tail = circulating * 2 / 1000`, with circulating defined as total supply minus ve escrow (`contracts/MinterUpgradeable.sol:125-138`).
- **Allocation formulae**: `team = weekly * teamRate / 1000` (default 40, max 50), `lockedShare = veSupply * 1000 / totalSupply`, `rebase = weekly * min(lockedShare, REBASEMAX) / 1000`, `gauges = weekly - team - rebase`; rebases pipe through `RewardsDistributor` and relock when positions stay active (`contracts/MinterUpgradeable.sol:145-190`, `contracts/RewardsDistributor.sol:283-323`).

## Weekly Emission Lifecycle

1. **Trigger epoch**: Anyone may call `Minter.update_period()`; do so after the Thursday 00:00 UTC boundary.
2. **Team share**: Mint `team = weekly * teamRate / 1000` to the configured wallet.
3. **Rebase computation**: Apply the `lockedShare` cap (`min(..., REBASEMAX)`) and forward the result to `RewardsDistributor`; zero locks → zero rebase.
4. **Gauge budget**: Route `gauges = weekly - team - rebase` to `VoterV3`, where `distribute` pushes funds into gauges.
5. **Gauge distribution**: Each gauge receives `weight / totalWeight * emissions` for the epoch; LPs then claim via `GaugeV2.getReward()`.

### Example Split (2.6M weekly, 50% locked)

```
Team (4%)                104,000
Rebase (min(50%,30%))    780,000
Gauge emissions        1,716,000
Tail emission floor ensures emissions never drop below 0.2% of circulating supply.
```

Locked balances routed through `RewardsDistributor` re-lock automatically while positions stay active, so long-term lockers absorb inflation while shrinking the circulating base (`contracts/RewardsDistributor.sol:283-323`).

## Fee & Incentive Streams

| Stream           | Who receives it                                   | How it accrues                                                          |
| ---------------- | ------------------------------------------------- | ----------------------------------------------------------------------- |
| Trading fees     | LPs (≈58%), veNFT voters (≈30%), referrals (≤12%) | Set via factory parameters `setFee`, `setStakingFees`, `setReferralFee` |
| Emission rewards | Gauge stakers                                     | Pulled from `Minter → Voter → Gauge` each epoch                         |
| Rebases          | veNFT holders                                     | `Minter` mints pro-rata to `VotingEscrow` lockers (anti-dilution)       |
| Bribes           | veNFT holders who voted                           | Deposited via `Bribe.notifyRewardAmount` for next epoch                 |

### Referral System (Dibs)

- `PairFactory.setDibs(address)` wires the handler.
- During swaps `Pair._sendFees()` forwards up to 12% of the collected fee to the handler, which settles user-level rewards.

## Governance & Voting Notes

- Votes must sum to 10,000 (basis points); weights can be reused every epoch via `poke(tokenId)`.
- Gauge types: `0` standard AMM (default), `1` reserved for specialized pools (e.g., concentrated liquidity).
- `VoterV3.blacklist()` removes malicious tokens, while `killGauge()` halts emissions but keeps LP withdrawals open.

## Operations & Monitoring

- **Weekly**: run `update_period` then `VoterV3.distributeAll()`; verify `Gauge.notifyRewardAmount` events fire for active pools.
- **KPIs**: lock rate (>40%), vote participation (>60%), bribe efficiency (>1.2x), emission decay vs. fee growth.
- **Adjustments**: use `setEmission` for macro emission changes, `setRebase` if lock share deviates, and rebalance fee tiers to stay competitive.
- **Analytics**: track `VoterV3` vote weights and `GaugeV2` TVL to spot concentration risks early.

## Emergency Toolkit

- Slow vote swings: `VoterV3.setVoteDelay(86400-604800)` enforces a cooldown between re-votes.
- Halt emissions to a pool: `VoterV3.killGauge(gauge)`; revive with `reviveGauge` after mitigation.
- Gauge withdrawals-only: `GaugeV2.activateEmergencyMode()` lets LPs exit without compounding rewards until resolved.
- Token abuse: `VoterV3.blacklist(tokens[])` removes assets from new gauge eligibility.

## User & Admin Actions Snapshot

| Actor          | Key Calls                                                                                                                                       |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| User           | `VotingEscrow.create_lock`, `VoterV3.vote`, `GaugeV2.deposit`, `GaugeV2.getReward`, `VoterV3.claimFees/claimBribes`                             |
| Protocol Admin | `Minter.setEmission/setRebase/setTeamRate`, `VoterV3.createGauge`, `PairFactory.setReferralFee`, `PairFactory.setDibs`, `VoterV3.distributeAll` |
