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

## LP Token Mechanics

### Minting (Adding Liquidity)
When liquidity is added via `RouterV2.addLiquidity()`:
1. Router transfers tokens to the Pair contract
2. Pair calculates LP tokens to mint:
   - **First deposit**: `liquidity = sqrt(amount0 × amount1) - MINIMUM_LIQUIDITY`
   - **Subsequent**: `liquidity = min((amount0 × totalSupply) / reserve0, (amount1 × totalSupply) / reserve1)`
3. LP tokens are minted to the liquidity provider's address

### Burning (Removing Liquidity)
When liquidity is removed via `RouterV2.removeLiquidity()`:
1. LP tokens are burned
2. Proportional share is returned: `amount = (lpTokens × poolBalance) / totalSupply`
3. **Important**: Fees are NOT automatically claimed - `claimFees()` must be called separately

### Fee Accounting System

The protocol uses an index-based system to track fees without constant token transfers:

| Component | Purpose |
|-----------|---------|
| `index0/index1` | Global fee accumulator per LP token |
| `supplyIndex0/1[user]` | User's last synced position |
| `claimable0/1[user]` | Accumulated unclaimed fees |

#### When Fee Accounting Updates
Fee positions are automatically **calculated and stored** (but NOT claimed) when:
- **Minting LP tokens**: Updates fee position before increasing balance
- **Burning LP tokens**: Updates fee position before decreasing balance
- **Transferring LP tokens**: Updates both sender and receiver positions

#### How Fees Accumulate
```
1. Swap occurs → fees collected → global index increases
2. User action triggers _updateFor(address)
3. System calculates: delta = globalIndex - userIndex
4. Adds to claimable: fees = (lpBalance × delta) / 1e18
5. Updates user index to current global index
```

### Important: Manual Fee Claiming Required

**Fees are NEVER automatically sent to users.** The protocol only tracks owed amounts in internal mappings:
- `claimable0[address]`: Unclaimed token0 fees
- `claimable1[address]`: Unclaimed token1 fees

To receive fees, `Pair.claimFees()` must be explicitly called, which:
1. Reads claimable balances
2. Resets them to zero
3. Transfers tokens from PairFees contract to the caller

This design is gas-efficient and prevents dust attacks, but requires active claiming.

## Actions

### Traders
- **Swap**: `GlobalRouter.swapExactTokensForTokens()`

### Liquidity Providers
- **Add**: `RouterV2.addLiquidity()` or `addLiquidityETH()`
- **Claim**: `Pair.claimFees()` - must be called manually to receive fees
- **Remove**: `RouterV2.removeLiquidity()` - burns LP tokens, returns liquidity (fees must be claimed separately)

### Protocol
- **Pair Creation**: `PairFactory.createPair(tokenA, tokenB, stable)`
  - **Stable**: x³y+y³x=k (pegged assets)
  - **Volatile**: xy=k (non-correlated)
- **Collect staking fees**: `Pair.claimStakingFees()`

### Emergency
- **Halt trading**: `PairFactory.setPause(true)`
- **Adjust stable fees**: `PairFactory.setFee(true, 1)` - sets to 0.01%
- **Adjust volatile fees**: `PairFactory.setFee(false, 5)` - sets to 0.05%
- **Resume trading**: `PairFactory.setPause(false)`
