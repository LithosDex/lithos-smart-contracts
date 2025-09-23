# Lithos Tokenomics Guide

## Protocol Parameters

### Emissions
| Parameter | Default | Range | Setting |
|-----------|---------|-------|---------|
| **Weekly** | 2.6M LITHOS | 2-3M | `Minter.setEmission()` |
| **Decay** | 99% | 98-99.5% | `Minter.setEmission(990)` |
| **Tail** | 0.2% supply | Min | Automatic |
| **Rebase** | 30% max | 20-30% | `Minter.setRebase(300)` |
| **Team** | 4% | Max 5% | `Minter.setTeamRate(40)` |

### Voting
| Parameter | Default | Max | Setting |
|-----------|---------|-----|---------|
| **Vote Delay** | 0 | 7 days | `VoterV3.setVoteDelay()` |
| **Whitelist** | - | - | `VoterV3.whitelist(tokens[])` |

### System Constants
| Constant | Value |
|----------|-------|
| **Epoch Duration** | 1 week (604,800 seconds) |
| **Max Lock Period** | 104 weeks (2 years) |
| **Min Lock Period** | 1 week |
| **Vote Reset** | Weekly at epoch boundary |

## Core Contracts

| Contract | Purpose | Key Functions |
|----------|---------|---------------|
| **LITHOS** | ERC20 token (50M initial) | `initialMint()`, `setMinter()` |
| **VotingEscrow** | veNFT lock management | `create_lock()`, `merge()`, `split()` |
| **Minter** | Emission controller | `update_period()`, `setEmission()` |
| **VoterV3** | Voting & distribution hub | `vote()`, `claimFees()`, `claimBribes()` |
| **Gauges** | LP staking rewards | `deposit()`, `getReward()` |
| **Bribes** | Vote incentives | `notifyRewardAmount()` |

## Emissions & Fees

### Weekly Emission Distribution
```
Weekly Emission (2.6M LITHOS, 99% decay/week)
├── Team: 4%
├── Rebase: min(locked%, 30%)
└── Gauges: ~66% to voted pools
```

### Trading Fee Split
```
Total Fee (0.04% stable, 0.18% volatile)
├── Referral: 12% of fee
├── Staking (veNFT voters): 30% of remaining
└── LPs: ~58% of total
```

## Referral System (Dibs)

| Component | Description |
|-----------|-------------|
| **Interface** | `IDibs.reward()` processes referral payments |
| **Fee Share** | 12% of trading fees (max configurable) |
| **Integration** | Auto-processed during swaps via `Pair._sendFees()` |
| **Configuration** | `PairFactory.setDibs(address)` |

## Voting & Rewards

### Voting Mechanics
- **Frequency**: Weekly reset at epoch boundary
- **Weight**: Must sum to 10000 (100%)
- **Power**: Based on veNFT balance at vote time

### Gauge Types
- **Type 0**: Standard AMM pairs
- **Type 1**: Concentrated liquidity pools

### Bribes
Projects incentivize votes by depositing rewards that voters claim proportionally:

| Efficiency | Ratio | Description |
|------------|-------|-------------|
| **Good** | >1.2x | $1 bribe → $1.20+ emissions |
| **Break-even** | 1.0x | $1 bribe → $1 emissions |
| **Poor** | <1.0x | Bribe cost exceeds emissions |

## Operations

### Initial Configuration
| Parameter | Setting |
|-----------|---------|
| **Weekly Emission** | 2.6M LITHOS |
| **Decay Rate** | 99% |
| **Max Rebase** | 30% |
| **Team Share** | 4% |

### Weekly Maintenance (Thursday 00:00 UTC)
- **Start Epoch**: `Minter.update_period()`
- **Distribute**: `VoterV3.distributeAll()`

### Monitoring Targets
| Metric | Target | Alert |
|--------|--------|-------|
| **Lock Rate** | >40% | <25% |
| **Vote Participation** | >60% | <40% |
| **Bribe Efficiency** | >1.2x | <1.0x |

### Emergency Actions
- **Stop Gauge**: `VoterV3.killGauge(gauge)`
- **Emergency Mode**: `Gauge.activateEmergencyMode()`
- **Vote Delay**: `VoterV3.setVoteDelay(604800)`
- **Block Tokens**: `VoterV3.blacklist(tokens[])`

## Actions

### Users
- **Create Lock**: `VotingEscrow.create_lock(amount, weeks)`
- **Vote**: `VoterV3.vote(tokenId, pools[], weights[])`
- **Claim Fees**: `VoterV3.claimFees(pairs[], tokens[][], tokenId)`
- **Claim Bribes**: `VoterV3.claimBribes(bribes[], tokens[][], tokenId)`
- **Stake LP**: `Gauge.deposit(amount)`
- **Claim Rewards**: `Gauge.getReward()`

### Admin
- **Emissions**: `Minter.setEmission(weeklyAmount)`
- **Gauges**: `VoterV3.createGauge(pool, type)`
- **Fees**: `PairFactory.setReferralFee(bps)`
- **Referrals**: `PairFactory.setDibs(address)`
