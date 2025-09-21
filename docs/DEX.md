# Lithos DEX Guide

## Protocol Parameters

### Admin Roles
| Role | Function | Setting |
|------|----------|------|
| **Pauser** | Halt/resume trading | `setPauser()` → `acceptPauser()` |
| **Fee Manager** | Control fees | `setFeeManager()` → `acceptFeeManager()` |

### Trading Fees
| Type | Default | Max | Setting |
|------|---------|-----|------|
| **Stable** | 0.04% | 0.25% | `setFee(true, 4)` |
| **Volatile** | 0.18% | 0.25% | `setFee(false, 18)` |

### Fee Distribution
| Component | Default | Max | Setting |
|-----------|---------|-----|------|
| **Referral** | 12% of fee | 12% | `setReferralFee(1200)` |
| **Staking** | 30% of remaining | 30% | `setStakingFees(3000)` |
| **LP** | ~58% of fee | - | Automatic |

### System Addresses
- **Staking Handler**: `setStakingFeeAddress(address)`
- **Referral Handler**: `setDibs(address)`


## Core Contracts

| Contract | Purpose | Admin Control |
|----------|---------|---------------|
| **GlobalRouter** | Main swap entry | None (immutable) |
| **TradeHelper** | Route calculation | None (pure utility) |
| **PairFactory** | Pair management | All fee parameters |
| **Pair** | Trading pools | Inherits from factory |
| **PairFees** | Fee distribution | Controlled by Pair |

## Fee Flow Example

**$10,000 Volatile Swap (0.18% = $18)**
```
Total Fee: $18
├── Referral (12%): $2.16
├── Staking (30% of remaining): $4.75
└── LPs: $11.09
```

## User Actions

### Traders
- **Swap**: `GlobalRouter.swapExactTokensForTokens()`

### Liquidity Providers
- **Add**: `RouterV2.addLiquidity()` or `addLiquidityETH()`
- **Claim**: `Pair.claimFees()`
- **Remove**: Burns LP tokens, auto-claims fees

### Protocol
- **Collect staking fees**: `Pair.claimStakingFees()`

## Setup Checklist

### Initial
1. Deploy PairFactory
2. Set fees: stable (4), volatile (18)
3. Set staking (3000) and referral handlers
4. Deploy routers

### Ongoing
- Monitor fees and TVL
- Adjust parameters within limits
- Manage emergency pauser

## Pair Creation

```solidity
PairFactory.createPair(tokenA, tokenB, stable)
```

- **Stable**: x³y+y³x=k (pegged assets)
- **Volatile**: xy=k (non-correlated)

## Emergency Actions

```solidity
// Halt trading
PairFactory.setPause(true)

// Adjust fees rapidly
PairFactory.setFee(true, 1)   // 0.01% stable
PairFactory.setFee(false, 5)  // 0.05% volatile

// Resume
PairFactory.setPause(false)
```

## Monitoring

### Key Metrics
| Metric | Target | Alert |
|--------|--------|-------|
| Swap Success | >99.5% | <99% |
| TVL Concentration | <40% per pair | >40% |
| Slippage | <2% avg | >5% |
| Gas/Swap | <$20 | >$50 |

### Alerts
- TVL drop >20% in 24h
- Fee accumulation stops
- Swap failures >1% hourly
