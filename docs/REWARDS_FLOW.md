# Complete Rewards Flow

## Four Types of Rewards

### 1. LP Trading Fees
- **Source**: Traders pay 0.18% (volatile) or 0.04% (stable) on swaps
- **Recipients**: LP token holders (88% after referral fees, which LITH team is taking as protocol fee atm)
- **Claim**: Directly from Pair contract

### 2. Gauge Emissions (LITH rewards)
- **Source**: Weekly LITH emissions from Minter
- **Recipients**: LP tokens staked in gauges
- **Claim**: From Gauge contract

### 3. Bribe Rewards
- **Source**: External incentives added by projects/users
- **Recipients**: veNFT holders who vote for specific gauges
- **Claim**: From Bribe contracts

### 4. Rebase Rewards (Compounding)
- **Source**: Weekly LITH emissions from Minter
- **Recipients**: All veNFT holders (proportional to locked amount)
- **Claim**: Manual claim required via RewardsDistributor.claim() or claim_many() - compounds into veNFT if still locked

---

## Week 1: Setup Phase

### Protocol Owner Actions
```
1. Deploy contracts
2. Create pairs
3. Create gauges
4. Whitelist tokens in Voter (if needed)
```

### Early Users - Becoming veNFT Holders
```solidity
// 1. Get LITH tokens
LITH.approve(VotingEscrow, amount);

// 2. Create veNFT (locked LITH)
VotingEscrow.create_lock(amount, lockDuration);
// Returns NFT ID (e.g., tokenId = 1)
// Lock duration: up to 4 years
// Voting power = amount * time_remaining / max_time
```

### Early LPs - Providing Liquidity
```solidity
// 1. Add liquidity via Router
token0.approve(Router, amount0);
token1.approve(Router, amount1);
Router.addLiquidity(
    token0, token1,
    stable, // true for stable, false for volatile
    amount0, amount1,
    minAmount0, minAmount1,
    to, deadline
);
// Receive: LP tokens

// 2. Stake LP tokens in Gauge (optional but recommended)
lpToken.approve(Gauge, lpAmount);
Gauge.deposit(lpAmount);
```

---

## Week 1: Thursday (Before Epoch Flip)

### veNFT Holders - Vote for Gauges
```solidity
// Vote for which gauges should receive emissions
address[] memory pools = [gauge1, gauge2];
uint256[] memory weights = [4000, 6000]; // 40%, 60%

VoterV3.vote(tokenId, pools, weights);
// This stakes your veNFT voting power in the gauge's bribes
```

**What happens internally:**
- Your voting power gets recorded in internal & external bribes
- Gauges with more votes will receive more LITH emissions next week

### Projects/Protocols - Add Bribes (Optional)
```solidity
// Add external incentives to attract votes
rewardToken.approve(ExternalBribe, amount);
ExternalBribe.notifyRewardAmount(rewardToken, amount);
// These rewards go to voters in the next epoch
```

---

## Week 1: Thursday Midnight (Epoch Flip)

### Automated Process (Anyone can trigger)
```solidity
// 1. Update period - mints new LITH emissions
Minter.update_period();
```

**What happens internally in update_period():**
```solidity
// Starting weekly emission: 2.6M LITH (decays 1% per week)
weekly = 2_600_000e18;

// 1. Team allocation (4%)
teamEmissions = (weekly * 40) / 1000; // 104,000 LITH
// Minted to team address

// 2. Calculate rebase (anti-dilution for veNFT holders)
lockedSupply = VotingEscrow.totalSupply();
totalSupply = LITH.totalSupply();
lockedShare = (lockedSupply * 1000) / totalSupply; // e.g., 500 = 50%

// Rebase capped at 30% of weekly emissions
rebaseAmount = (weekly * min(lockedShare, 300)) / 1000; // max 780,000 LITH

// 3. Send rebase to RewardsDistributor
if (rebaseAmount > 0) {
    LITH.mint(RewardsDistributor, rebaseAmount);
    RewardsDistributor.checkpoint_token(); // Trigger distribution
    RewardsDistributor.checkpoint_total_supply(); // Update balances
}

// 4. Remaining goes to gauges
gaugeEmissions = weekly - teamEmissions - rebaseAmount; // ~1,716,000 LITH
LITH.mint(VoterV3, gaugeEmissions);
```

**Rebase Distribution Process:**
```solidity
// In RewardsDistributor, for each veNFT:
tokenReward = (rebaseAmount * veNFTBalance) / totalVeSupply;

// This gets added to the veNFT's locked balance automatically
// No claim needed - it compounds into the locked position
```

**Then distribute to gauges:**
```solidity
// 2. Distribute emissions to gauges based on votes
VoterV3.distribute(gauge1);
VoterV3.distribute(gauge2);
// Or distribute all at once:
VoterV3.distributeAll();
```

**What happens:**
- Team receives 4% allocation
- veNFT holders receive rebase (auto-compounds)
- Gauges receive LITH proportional to votes received
- Bribe rewards become claimable for voters
- New voting period begins

---

## Week 2+: Ongoing Rewards

### For LP Providers

#### A. Trading Fee Rewards (Continuous)
```solidity
// Fees accumulate automatically as swaps occur
// Check claimable fees
uint256 fees0 = Pair.claimable0(myAddress);
uint256 fees1 = Pair.claimable1(myAddress);

// Claim fees
Pair.claimFees();
// Receive: token0 and token1 fees
```

#### B. Gauge Emission Rewards (If Staked)
```solidity
// Check pending rewards
uint256 pending = Gauge.earned(myAddress);

// Claim LITH rewards
Gauge.getReward();
// Receive: LITH tokens

// Or withdraw and claim together
Gauge.withdrawAllAndHarvest();
// Receive: LP tokens back + LITH rewards
```

### For veNFT Holders

#### A. Rebase Rewards (Weekly, Manual Claim)
```solidity
// Claim your rebase rewards (compounds into veNFT if still locked)
RewardsDistributor.claim(tokenId);
// Or claim for multiple NFTs
RewardsDistributor.claim_many([tokenId1, tokenId2]);

// Check claimable amount before claiming
uint256 claimable = RewardsDistributor.claimable(tokenId);

// The rebase is calculated as:
// Your Share = (Your Locked / Total Locked) * Rebase Amount
// Rebase Amount = Weekly Emissions * min(Lock%, 30%)

// Example: If 50% of supply is locked, rebase = 30% of weekly
// Your veNFT with 10% of locked supply gets 10% of rebase
```

#### B. Bribe Rewards (Weekly after voting)
```solidity
// After epoch flip, claim from both bribes
address[] memory tokens = [token1, token2]; // reward tokens

// Method 1: Direct calls to each bribe contract
InternalBribe.getReward(tokenId, tokens);  // Claims trading fees
ExternalBribe.getReward(tokenId, tokens);  // Claims external incentives

// Method 2: Batch claim via VoterV3 (functionally equivalent)
address[] memory bribes = [internalBribe, externalBribe];
address[][] memory tokens = [[token1], [token2]];
VoterV3.claimFees(bribes, tokens, tokenId);
// Note: VoterV3.claimBribes() is identical to claimFees()
```

---

## Complete Week-by-Week Flow

### Week 0 (Setup)
1. **Users**: Create veNFTs, Add liquidity, Stake in gauges
2. **Projects**: Add external bribes to attract votes

### Week 1 (First Epoch)
**Monday-Wednesday**:
- LPs earn trading fees
- Staked LPs earn nothing yet (no emissions distributed)

**Thursday**:
- veNFT holders vote
- Votes determine next week's emissions

**Thursday Midnight**:
- Epoch flips
- Minter.update_period() called
- First emissions distributed to gauges

### Week 2+ (Steady State)
**Throughout Week**:
- LPs earn trading fees continuously
- Staked LPs earn LITH emissions (streaming)
- veNFT holders earn rebases (must claim, then compounds into lock)
- New votes can be cast (replace old votes)

**Weekly (Thursday 00:00 UTC)**:
- `update_period()` triggers: Team gets 4%, Rebases distributed, Gauges funded
- veNFT holders can claim rebase rewards (manual claim required)
- veNFT voters claim bribe rewards from previous epoch
- New emissions distributed to gauges based on votes
- Cycle repeats

---

## Key Points

1. **LP Fees**: Automatic, claimable anytime, no voting needed
2. **Gauge Emissions**: Requires staking LP tokens, rewards based on gauge's vote share
3. **Bribes**: Requires veNFT and voting, rewards after epoch flip
4. **Rebases**: Available for all veNFT holders, requires manual claim via RewardsDistributor, compounds into veNFT
5. **Protocol Owner**: Mainly needs to ensure `Minter.update_period()` runs weekly
6. **Permissionless**: Most functions can be called by anyone (distribute, update_period)

## Who Calls What

### Users Call
- `Pair.claimFees()` - claim trading fees
- `Gauge.getReward()` - claim LITH emissions
- `Bribe.getReward()` - claim bribe rewards
- `VoterV3.vote()` - cast votes
- `RewardsDistributor.claim()` - claim rebase rewards

### Anyone Can Call (Protocol or Keepers)
- `Minter.update_period()` - weekly emission mint
- `VoterV3.distribute()` - send emissions to gauges
- `Gauge.claimFees()` - update fee distribution from Pair

### Automatic
- Fee collection on swaps
- Emission streaming in gauges
- Vote tabulation

## Reward Formulas

**Trading Fees for LP**:
```
My Share = (My LP Tokens / Total LP Tokens) * Accumulated Fees
```

**Gauge Emissions for Staked LP**:
```
My Rate = (My Staked LP / Total Staked LP) * Gauge Emission Rate
Gauge Rate = (Votes for Gauge / Total Votes) * Weekly Emissions
```

**Bribe Rewards for Voters**:
```
My Reward = (My Vote Weight / Total Vote Weight) * Total Bribes
```

**Rebase Rewards for veNFT Holders**:
```
Weekly Rebase Pool = Weekly Emissions * min(Locked%, 30%)
My Rebase = (My Locked Amount / Total Locked Amount) * Weekly Rebase Pool

Example with 2.6M weekly emissions and 50% locked:
Rebase Pool = 2.6M * 30% = 780,000 LITH
If you have 10% of all locked LITH, you get 78,000 LITH (must claim to receive)
```
