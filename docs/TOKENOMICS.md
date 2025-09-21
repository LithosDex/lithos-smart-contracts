# Lithos Tokenomics Guide

## Protocol Parameters

### Emissions
| Parameter | Default | Range | Setting |
|-----------|---------|-------|------|
| **Weekly** | 2.6M LITHOS | 2-3M | `Minter.setEmission()` |
| **Decay** | 99% | 98-99.5% | `Minter.setEmission(990)` |
| **Tail** | 0.2% supply | Min | Automatic |
| **Rebase** | 30% max | 20-30% | `Minter.setRebase(300)` |
| **Team** | 4% | Max 5% | `Minter.setTeamRate(40)` |

### Voting
| Parameter | Default | Max | Setting |
|-----------|---------|-----|------|
| **Vote Delay** | 0 | 7 days | `VoterV3.setVoteDelay()` |
| **Whitelist** | - | - | `VoterV3.whitelist(tokens[])` |

## ve(3,3) Flywheel

```
Lock LITHOS → Get veNFT → Vote for Pools
     ↑                           ↓
High APR ← Earn Fees ← Direct Emissions
```

**Key**: Fees go to voters, not LPs

### Lock Rules
- **Duration**: 1-104 weeks
- **Power**: Linear decay
- **NFT**: Transferable, splittable

## Core Contracts

| Contract | Supply/Purpose | Key Functions |
|----------|---------------|---------------|
| **LITHOS** | 50M initial | `initialMint()`, `setMinter()` |
| **VotingEscrow** | veNFT locks | `create_lock()`, `merge()`, `split()` |
| **Minter** | Emissions | `update_period()`, `setEmission()` |
| **VoterV3** | Voting hub | `vote()`, `claimFees()`, `claimBribes()` |
| **Gauges** | LP rewards | `deposit()`, `getReward()` |
| **Bribes** | Vote incentives | `notifyRewardAmount()` |

## Emission Schedule

**Weekly Decay**: 2.6M → 2.574M → 2.548M (99% each week)

**Distribution**:
```
Weekly Emission
├── Team: 4%
├── Rebase: up to 30%
└── Gauges: ~66%
```

**Rebase**: min(locked%, 30%) × emissions

## Voting System

### Actions
```solidity
vote(tokenId, pools[], weights[])  // Weekly voting
reset(tokenId)                      // Clear votes
poke(tokenId)                       // Update power
claimFees(pairs[], tokens[][], id)  // Claim fees
claimBribes(bribes[], tokens[][], id) // Claim bribes
```

### Rules
- Vote weekly (resets each epoch)
- Weights sum to 10000
- Power = veNFT balance

## Gauges

### Types
- **Type 0**: AMM pairs
- **Type 1**: Concentrated liquidity

### Management
```solidity
VoterV3.createGauge(pool, type)
VoterV3.killGauge(gauge)    // Emergency
VoterV3.reviveGauge(gauge)  // Re-enable
```

### LP Flow
1. Add liquidity → Get LP tokens
2. Stake in gauge → Earn emissions
3. `Gauge.getReward()` anytime

## Bribes

### Flow
1. Deposit bribes (for next epoch)
2. Voters direct emissions
3. Claim after epoch ends

```solidity
Bribe.notifyRewardAmount(token, amount)
```

### Efficiency
- **Good**: $1 bribe → $1.2+ emissions
- **Bad**: <$1 emissions per $1 bribe

## Fee Distribution

**Traditional AMM**: 100% fees to LPs
**ve(3,3)**: Fees to veNFT voters

```
Trading Fee
├── Referral: 12%
├── Staking: 30% of remaining
└── LPs: ~58%
```

veNFT holders earn from pairs they vote for.

## Launch Phases

### Week 0: Setup
- Initial mint 50M
- Create partner veNFTs
- Deploy core pairs

### Week 1-2: Soft Launch
- Partners vote
- First emissions
- Monitor metrics

### Week 3+: Public
- Open veNFT creation
- Launch UI
- Start bribes

### Initial Settings
```
Weekly: 2.6M LITHOS
Decay: 99%
Rebase: 30% max
Team: 4%
```

## Operations

### Weekly (Thursday 00:00 UTC)
```solidity
Minter.update_period()      // New epoch
VoterV3.distributeAll()     // Send rewards
```

### Monitoring
| Metric | Target | Alert |
|--------|--------|-------|
| Lock Rate | >40% | <25% |
| Vote Participation | >60% | <40% |
| Bribe Efficiency | 1.2x | <1x |
| Concentration | <50% | >50% |

### Emergency
```solidity
VoterV3.killGauge(gauge)           // Stop gauge
Gauge.activateEmergencyMode()      // Withdrawals only
VoterV3.setVoteDelay(604800)       // 7-day delay
VoterV3.blacklist(tokens[])        // Block tokens
```

## Success Metrics

### Launch (Week 1-4)
- 30%+ locked
- $10M+ TVL
- $50k+ weekly fees

### Growth (Month 2-6)
- 40%+ locked
- $50M+ TVL
- $250k+ weekly fees

### Mature (6+ months)
- 50%+ locked
- Self-sustaining fees
- Efficient bribes (1.2x+)

## Quick Reference

### Key Actions
```solidity
VotingEscrow.create_lock(amount, weeks)
VoterV3.vote(id, pools[], weights[])
VoterV3.claimFees(pairs[], tokens[][], id)
Gauge.deposit(amount)
```

### Constants
- **Epoch**: 1 week (604,800s)
- **Max Lock**: 104 weeks
- **Vote Reset**: Weekly
