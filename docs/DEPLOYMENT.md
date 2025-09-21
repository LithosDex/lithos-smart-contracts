# Lithos Protocol Deployment & Operations Guide
## From Zero to Mainnet Launch

## Table of Contents
1. [Pre-Deployment Requirements](#pre-deployment-requirements)
2. [Deployment Sequence](#deployment-sequence)
3. [Post-Deployment Configuration](#post-deployment-configuration)
4. [Initial Distribution](#initial-distribution)
5. [Router Architecture](#router-architecture)
6. [Permissions & Access Control](#permissions--access-control)
7. [Testnet Deployment](#testnet-deployment)
8. [Launch Day Playbook](#launch-day-playbook)
9. [Integration Checklist](#integration-checklist)
10. [Emergency Procedures](#emergency-procedures)
11. [Contract Registry](#contract-registry)

---

## Pre-Deployment Requirements

### Environment Setup
```bash
# Required tools
node >= 18.0.0
npm >= 9.0.0
hardhat or foundry
etherscan-verify plugin

# Environment variables (.env)
PRIVATE_KEY=<deployer_private_key>
RPC_URL=<network_rpc_url>
ETHERSCAN_API_KEY=<for_verification>
MULTISIG_ADDRESS=<protocol_multisig>
```

### Initial Decisions Required
```yaml
Token Distribution (50M LITHOS):
  Team: 10M (20%)
  Partners: 15M (30%)
  Community: 10M (20%)
  Treasury: 10M (20%)
  Initial Liquidity: 5M (10%)

Economic Parameters:
  Initial Weekly Emission: 2,600,000 LITHOS
  Decay Rate: 990 (99%)
  Team Allocation: 40 (4%)
  Max Rebase: 300 (30%)

Fee Structure:
  Stable Pairs: 4 (0.04%)
  Volatile Pairs: 18 (0.18%)
  Staking Share: 3000 (30%)
  Max Referral: 1200 (12%)

Launch Partners:
  - Partner A: 5M LITHOS locked 1 year
  - Partner B: 3M LITHOS locked 6 months
  - Partner C: 2M LITHOS locked 1 year
```

---

## Deployment Sequence

### Phase 1: Core Token System
```javascript
// 1. Deploy LITHOS Token
const Lithos = await ethers.deployContract("Lithos", []);
await Lithos.waitForDeployment();
const LITHOS_ADDRESS = await Lithos.getAddress();
console.log("Lithos deployed:", LITHOS_ADDRESS);

// 2. Deploy VeArtProxyUpgradeable (NFT visual metadata)
const VeArtProxy = await ethers.deployContract("VeArtProxyUpgradeable", []);
await VeArtProxy.waitForDeployment();
const VEARTPROXY_ADDRESS = await VeArtProxy.getAddress();

// 3. Initialize VeArtProxy
await VeArtProxy.initialize();
console.log("VeArtProxy deployed:", VEARTPROXY_ADDRESS);

// 4. Deploy VotingEscrow (veNFT system)
const VotingEscrow = await ethers.deployContract("VotingEscrow", [
    LITHOS_ADDRESS,
    VEARTPROXY_ADDRESS
]);
await VotingEscrow.waitForDeployment();
const VOTINGESCROW_ADDRESS = await VotingEscrow.getAddress();
console.log("VotingEscrow deployed:", VOTINGESCROW_ADDRESS);
```

### Phase 2: DEX Infrastructure
```javascript
// 5. Deploy PairFactoryUpgradeable
const PairFactory = await ethers.deployContract("PairFactoryUpgradeable", []);
await PairFactory.waitForDeployment();
const PAIRFACTORY_ADDRESS = await PairFactory.getAddress();

// 6. Initialize PairFactory
await PairFactory.initialize(DEPLOYER_ADDRESS);
await PairFactory.setFee(true, 4);    // 0.04% stable
await PairFactory.setFee(false, 18);  // 0.18% volatile
await PairFactory.setStakingFees(3000); // 30% to stakers
console.log("PairFactory deployed:", PAIRFACTORY_ADDRESS);

// 7. Deploy TradeHelper (for GlobalRouter)
const TradeHelper = await ethers.deployContract("TradeHelper", [
    PAIRFACTORY_ADDRESS
]);
await TradeHelper.waitForDeployment();
const TRADEHELPER_ADDRESS = await TradeHelper.getAddress();
console.log("TradeHelper deployed:", TRADEHELPER_ADDRESS);

// 8. Deploy GlobalRouter (new optimized router)
const GlobalRouter = await ethers.deployContract("GlobalRouter", [
    TRADEHELPER_ADDRESS
]);
await GlobalRouter.waitForDeployment();
const GLOBALROUTER_ADDRESS = await GlobalRouter.getAddress();
console.log("GlobalRouter deployed:", GLOBALROUTER_ADDRESS);

// 9. Deploy RouterV2 (legacy compatibility router)
const RouterV2 = await ethers.deployContract("RouterV2", [
    PAIRFACTORY_ADDRESS,
    WETH_ADDRESS  // or WBNB for BSC
]);
await RouterV2.waitForDeployment();
const ROUTERV2_ADDRESS = await RouterV2.getAddress();
console.log("RouterV2 deployed:", ROUTERV2_ADDRESS);
```

### Phase 3: Gauge & Voting System
```javascript
// 10. Deploy GaugeFactoryV2
const GaugeFactory = await ethers.deployContract("GaugeFactoryV2", []);
await GaugeFactory.waitForDeployment();
const GAUGEFACTORY_ADDRESS = await GaugeFactory.getAddress();
console.log("GaugeFactory deployed:", GAUGEFACTORY_ADDRESS);

// 11. Deploy PermissionsRegistry (optional, for role management)
const PermissionsRegistry = await ethers.deployContract("PermissionsRegistry", []);
await PermissionsRegistry.waitForDeployment();
const PERMISSIONS_ADDRESS = await PermissionsRegistry.getAddress();
console.log("PermissionsRegistry deployed:", PERMISSIONS_ADDRESS);

// 12. Deploy BribeFactoryV3
const BribeFactory = await ethers.deployContract("BribeFactoryV3", []);
await BribeFactory.waitForDeployment();
const BRIBEFACTORY_ADDRESS = await BribeFactory.getAddress();

// 13. Initialize BribeFactory (voter address set later)
await BribeFactory.initialize(
    ethers.ZeroAddress,  // Voter set after VoterV3 deployment
    PERMISSIONS_ADDRESS  // or ethers.ZeroAddress if not using
);
console.log("BribeFactory deployed:", BRIBEFACTORY_ADDRESS);

// 14. Deploy VoterV3
const VoterV3 = await ethers.deployContract("VoterV3", []);
await VoterV3.waitForDeployment();
const VOTERV3_ADDRESS = await VoterV3.getAddress();

// 15. Initialize VoterV3
await VoterV3.initialize(
    VOTINGESCROW_ADDRESS,
    PAIRFACTORY_ADDRESS,
    GAUGEFACTORY_ADDRESS,
    BRIBEFACTORY_ADDRESS
);
console.log("VoterV3 deployed:", VOTERV3_ADDRESS);

// 16. Deploy RewardsDistributor (optional)
const RewardsDistributor = await ethers.deployContract("RewardsDistributorV2", [
    VOTINGESCROW_ADDRESS
]);
await RewardsDistributor.waitForDeployment();
const REWARDSDIST_ADDRESS = await RewardsDistributor.getAddress();
console.log("RewardsDistributor deployed:", REWARDSDIST_ADDRESS);

// 17. Deploy MinterUpgradeable
const Minter = await ethers.deployContract("MinterUpgradeable", []);
await Minter.waitForDeployment();
const MINTER_ADDRESS = await Minter.getAddress();

// 18. Initialize Minter
await Minter.initialize(
    VOTERV3_ADDRESS,
    VOTINGESCROW_ADDRESS,
    REWARDSDIST_ADDRESS  // or ethers.ZeroAddress if not using
);
console.log("Minter deployed:", MINTER_ADDRESS);
```

### Phase 4: Critical Contract Linking
```javascript
// ORDER MATTERS - Do these in exact sequence

// 1. Give Minter the minting rights
await Lithos.setMinter(MINTER_ADDRESS);
console.log("✓ Lithos minter set");

// 2. Connect VotingEscrow to Voter
await VotingEscrow.setVoter(VOTERV3_ADDRESS);
console.log("✓ VotingEscrow voter set");

// 3. Connect VotingEscrow to RewardsDistributor
await VotingEscrow.setRewardsDistributor(REWARDSDIST_ADDRESS);
console.log("✓ VotingEscrow rewards distributor set");

// 4. Connect Voter to Minter
await VoterV3.setMinter(MINTER_ADDRESS);
console.log("✓ VoterV3 minter set");

// 5. Connect BribeFactory to Voter
await BribeFactory.setVoter(VOTERV3_ADDRESS);
console.log("✓ BribeFactory voter set");

// 6. Set factory addresses for fees
await PairFactory.setStakingFeeAddress(MULTISIG_ADDRESS); // Initial recipient
console.log("✓ Staking fee address set");

// 7. Set team address for Minter
await Minter.setTeam(MULTISIG_ADDRESS);
console.log("✓ Minter team address set");

// 8. Configure Minter parameters
await Minter.setEmission(990);     // 99% decay
await Minter.setRebase(300);       // 30% max rebase
await Minter.setTeamRate(40);      // 4% team allocation
console.log("✓ Minter parameters configured");
```

---

## Post-Deployment Configuration

### Step 1: Token Whitelist
```javascript
// Whitelist tokens for gauge creation
const tokensToWhitelist = [
    LITHOS_ADDRESS,
    WETH_ADDRESS,    // or WBNB for BSC
    USDT_ADDRESS,
    USDC_ADDRESS,
    DAI_ADDRESS
];

await VoterV3.whitelist(tokensToWhitelist);
console.log("✓ Tokens whitelisted");
```

### Step 2: Create Initial Pairs
```javascript
// Create stable pairs
const stablePairs = [
    [USDT_ADDRESS, USDC_ADDRESS, true],
    [USDT_ADDRESS, DAI_ADDRESS, true],
    [USDC_ADDRESS, DAI_ADDRESS, true]
];

for (const [token0, token1, stable] of stablePairs) {
    await PairFactory.createPair(token0, token1, stable);
    const pairAddress = await PairFactory.getPair(token0, token1, stable);
    console.log(`✓ Created ${stable ? 'stable' : 'volatile'} pair:`, pairAddress);
}

// Create volatile pairs
const volatilePairs = [
    [WETH_ADDRESS, LITHOS_ADDRESS, false],
    [WETH_ADDRESS, USDT_ADDRESS, false],
    [LITHOS_ADDRESS, USDT_ADDRESS, false]
];

for (const [token0, token1, stable] of volatilePairs) {
    await PairFactory.createPair(token0, token1, stable);
    const pairAddress = await PairFactory.getPair(token0, token1, stable);
    console.log(`✓ Created volatile pair:`, pairAddress);
}
```

### Step 3: Create Gauges
```javascript
// Get all pair addresses
const pairs = [];
const gaugeTypes = [];

// Add stable pairs
for (const [token0, token1, stable] of stablePairs) {
    const pair = await PairFactory.getPair(token0, token1, stable);
    pairs.push(pair);
    gaugeTypes.push(0); // Type 0 for AMM pairs
}

// Add volatile pairs
for (const [token0, token1, stable] of volatilePairs) {
    const pair = await PairFactory.getPair(token0, token1, stable);
    pairs.push(pair);
    gaugeTypes.push(0);
}

// Create all gauges at once
await VoterV3.createGauges(pairs, gaugeTypes);
console.log("✓ Created gauges for all pairs");
```

---

## Initial Distribution

### Step 1: Initial Mint
```javascript
// Mint initial 50M supply to treasury
await Lithos.initialMint(TREASURY_ADDRESS);
console.log("✓ Initial 50M LITHOS minted to treasury");
```

### Step 2: Create Initial veNFTs
```javascript
// Prepare initial distribution arrays
const recipients = [
    PARTNER_A_ADDRESS,  // 5M locked 52 weeks
    PARTNER_B_ADDRESS,  // 3M locked 26 weeks
    PARTNER_C_ADDRESS,  // 2M locked 52 weeks
    TEAM_WALLET_1,      // 3M locked 104 weeks
    TEAM_WALLET_2,      // 2M locked 104 weeks
];

const amounts = [
    ethers.parseEther("5000000"),  // 5M
    ethers.parseEther("3000000"),  // 3M
    ethers.parseEther("2000000"),  // 2M
    ethers.parseEther("3000000"),  // 3M
    ethers.parseEther("2000000"),  // 2M
];

const lockDurations = [
    52,   // 52 weeks
    26,   // 26 weeks
    52,   // 52 weeks
    104,  // 104 weeks (max)
    104,  // 104 weeks
];

// Transfer LITHOS to Minter for distribution
const totalAmount = amounts.reduce((a, b) => a + b, 0n);
await Lithos.transfer(MINTER_ADDRESS, totalAmount);

// Initialize distribution
await Minter._initialize(recipients, amounts, totalAmount);
console.log("✓ Initial veNFTs created for partners and team");

// Create veNFTs with specific lock durations
for (let i = 0; i < recipients.length; i++) {
    const tokenId = await VotingEscrow.create_lock_for(
        amounts[i],
        lockDurations[i] * 604800, // Convert weeks to seconds
        recipients[i]
    );
    console.log(`✓ veNFT #${tokenId} created for ${recipients[i]}`);
}
```

### Step 3: Seed Initial Liquidity
```javascript
// Add initial liquidity to key pairs
const initialLiquidityPairs = [
    {
        pair: "LITHOS/WETH",
        token0: LITHOS_ADDRESS,
        token1: WETH_ADDRESS,
        amount0: ethers.parseEther("1000000"), // 1M LITHOS
        amount1: ethers.parseEther("500"),      // 500 ETH
        stable: false
    },
    {
        pair: "USDT/USDC",
        token0: USDT_ADDRESS,
        token1: USDC_ADDRESS,
        amount0: ethers.parseUnits("1000000", 6), // 1M USDT
        amount1: ethers.parseUnits("1000000", 6), // 1M USDC
        stable: true
    }
];

for (const liq of initialLiquidityPairs) {
    // Approve tokens
    await IERC20(liq.token0).approve(ROUTERV2_ADDRESS, liq.amount0);
    await IERC20(liq.token1).approve(ROUTERV2_ADDRESS, liq.amount1);

    // Add liquidity
    await RouterV2.addLiquidity(
        liq.token0,
        liq.token1,
        liq.stable,
        liq.amount0,
        liq.amount1,
        0,  // Accept any amounts for initial
        0,
        TREASURY_ADDRESS,
        Math.floor(Date.now() / 1000) + 3600
    );

    console.log(`✓ Added initial liquidity to ${liq.pair}`);
}
```

---

## Router Architecture

### Understanding Two Routers

#### GlobalRouter (Recommended)
```solidity
// Modern, gas-optimized router
// Uses TradeHelper for route calculations
// Better for complex multi-hop swaps

// Example usage:
GlobalRouter.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,      // Can be complex multi-hop
    to,
    deadline
)
```

**Use GlobalRouter for:**
- Multi-hop swaps
- Gas-sensitive operations
- New integrations
- Complex routing needs

#### RouterV2 (Legacy Support)
```solidity
// Traditional AMM router
// Direct pair interaction
// Compatibility with existing integrations

// Example usage:
RouterV2.swapExactTokensForTokensSimple(
    amountIn,
    amountOutMin,
    tokenFrom,
    tokenTo,
    stable,
    to,
    deadline
)
```

**Use RouterV2 for:**
- Adding/removing liquidity
- Simple direct swaps
- Legacy integration support
- Zap functions

### TradeHelper Role
```solidity
// TradeHelper is a view contract that:
// 1. Calculates optimal routes
// 2. Estimates output amounts
// 3. Finds best paths through pairs

// Used by GlobalRouter internally
// Can be called directly for quotes:
TradeHelper.getAmountOut(
    amountIn,
    tokenIn,
    tokenOut,
    stable
)
```

---

## Permissions & Access Control

### Role Structure
```
Owner (Multisig)
├── Pauser (Emergency)
├── Fee Manager (Economics)
├── Team (Emissions)
└── Governance (Future DAO)
```

### Two-Step Transfer Pattern
All critical roles use a two-step transfer:

```javascript
// Step 1: Propose new role holder
await PairFactory.setFeeManager(NEW_MANAGER);

// Step 2: New holder accepts (must be called from new address)
await PairFactory.acceptFeeManager();
```

### Multisig Configuration
```javascript
// Deploy Gnosis Safe or similar
// Recommended configuration:
// - 3/5 for routine operations
// - 4/5 for critical functions
// - 5/5 for protocol upgrades

const multisigOwners = [
    FOUNDER_1,
    FOUNDER_2,
    ADVISOR_1,
    ADVISOR_2,
    COMMUNITY_REP
];

// After multisig deployment, transfer ownership
await Lithos.transferOwnership(MULTISIG_ADDRESS);
await PairFactory.transferOwnership(MULTISIG_ADDRESS);
await VoterV3.transferOwnership(MULTISIG_ADDRESS);
await Minter.transferOwnership(MULTISIG_ADDRESS);
```

### PermissionsRegistry Setup
```javascript
// If using PermissionsRegistry for fine-grained control
await PermissionsRegistry.grantRole(
    keccak256("GAUGE_CREATOR"),
    AUTHORIZED_ADDRESS
);

await PermissionsRegistry.grantRole(
    keccak256("FEE_MANAGER"),
    FEE_MANAGER_ADDRESS
);
```

---

## Testnet Deployment

### Recommended Test Networks
- **Ethereum**: Sepolia or Goerli
- **BSC**: BSC Testnet
- **Arbitrum**: Arbitrum Sepolia
- **Base**: Base Sepolia

### Testnet Configuration
```javascript
// Use same deployment scripts with testnet config
const config = {
    network: "sepolia",
    rpcUrl: "https://sepolia.infura.io/v3/YOUR_KEY",
    chainId: 11155111,
    gasPrice: ethers.parseUnits("20", "gwei"),

    // Test parameters (accelerated timeline)
    weeklyEmission: ethers.parseEther("10000000"), // 10M for faster testing
    epochDuration: 3600, // 1 hour epochs for testing
    maxLock: 4 * 3600,   // 4 hour max lock for testing
};
```

### Testnet Checklist
- [ ] Deploy all contracts
- [ ] Verify all contracts on explorer
- [ ] Create initial pairs and gauges
- [ ] Test initial distribution
- [ ] Simulate first epoch transition
- [ ] Test voting mechanisms
- [ ] Test bribe distribution
- [ ] Test emergency procedures
- [ ] Load test with multiple users
- [ ] Test frontend integration

---

## Launch Day Playbook

### T-24 Hours
- [ ] Final contract review
- [ ] Verify all parameters
- [ ] Confirm multisig signers ready
- [ ] Test emergency procedures
- [ ] Prepare announcement materials

### T-2 Hours
- [ ] Deploy all contracts
- [ ] Verify on block explorer
- [ ] Execute initial configuration
- [ ] Create initial pairs
- [ ] Add initial liquidity

### T-0 Launch
- [ ] Execute initial distribution
- [ ] Enable trading
- [ ] Start first epoch
- [ ] Monitor all metrics
- [ ] Community announcement

### T+1 Hour
- [ ] Check all gauges active
- [ ] Verify voting working
- [ ] Monitor for issues
- [ ] Respond to community

### T+24 Hours
- [ ] First epoch transition
- [ ] Distribute initial rewards
- [ ] Review all metrics
- [ ] Adjust if needed

---

## Integration Checklist

### For Partner Protocols
```markdown
## Integration Checklist

### Pre-Integration
- [ ] Review documentation
- [ ] Get tokens whitelisted
- [ ] Prepare initial liquidity
- [ ] Set up multisig

### Liquidity Setup
- [ ] Create trading pair
- [ ] Request gauge creation
- [ ] Add initial liquidity
- [ ] Stake in gauge

### Voting Power
- [ ] Acquire LITHOS tokens
- [ ] Create veNFT position
- [ ] Vote for your gauge
- [ ] Monitor voting power

### Incentives
- [ ] Set up bribe contract
- [ ] Deposit bribe rewards
- [ ] Monitor bribe efficiency
- [ ] Adjust as needed

### Monitoring
- [ ] Track TVL in gauge
- [ ] Monitor trading volume
- [ ] Check fee generation
- [ ] Review APR metrics
```

### For Frontend Integration
```javascript
// Key contract ABIs needed
const requiredABIs = [
    "Lithos.json",
    "VotingEscrow.json",
    "VoterV3.json",
    "Pair.json",
    "Gauge.json",
    "GlobalRouter.json",
    "RouterV2.json",
    "MinterUpgradeable.json"
];

// Key events to monitor
const eventsToWatch = [
    "Voted",           // When users vote
    "GaugeCreated",    // New gauges
    "Deposit",         // LP deposits
    "Withdraw",        // LP withdrawals
    "RewardAdded",     // New bribes
    "RewardPaid",      // Reward claims
];

// Common user flows to implement
const userFlows = [
    "Create veNFT",
    "Vote for gauges",
    "Add liquidity",
    "Stake LP tokens",
    "Claim rewards",
    "Claim bribes",
    "Swap tokens"
];
```

---

## Emergency Procedures

### Level 1: Minor Issue
**Examples**: High slippage, delayed transactions

```javascript
// Monitor and adjust
// No intervention needed
// Document issue
```

### Level 2: Moderate Issue
**Examples**: Stuck gauge, incorrect fee

```javascript
// Pause specific component
await VoterV3.killGauge(PROBLEMATIC_GAUGE);

// Fix issue
// Test fix
// Resume
await VoterV3.reviveGauge(GAUGE);
```

### Level 3: Critical Issue
**Examples**: Exploit detected, critical bug

```javascript
// IMMEDIATE ACTIONS
// 1. Pause all trading
await PairFactory.setPause(true);

// 2. Activate emergency mode on affected gauges
await Gauge.activateEmergencyMode();

// 3. Alert community
// 4. Investigate issue
// 5. Deploy fix
// 6. Resume operations gradually
```

### Emergency Contacts
```yaml
Role: Contact Method
Technical Lead: [Secure channel]
Security Team: [Secure channel]
Community Manager: [Secure channel]
Legal Advisor: [Secure channel]
```

### War Room Procedures
1. Establish secure communication channel
2. Assess severity and impact
3. Execute emergency procedures
4. Communicate with community
5. Document all actions
6. Post-mortem analysis

---

## Contract Registry

### Mainnet Deployment Addresses
```javascript
// Core Token System
LITHOS_TOKEN:        "0x________________________________"
VOTING_ESCROW:       "0x________________________________"
VE_ART_PROXY:        "0x________________________________"

// DEX System
PAIR_FACTORY:        "0x________________________________"
GLOBAL_ROUTER:       "0x________________________________"
ROUTER_V2:           "0x________________________________"
TRADE_HELPER:        "0x________________________________"

// Voting & Gauges
VOTER_V3:            "0x________________________________"
GAUGE_FACTORY:       "0x________________________________"
BRIBE_FACTORY:       "0x________________________________"
MINTER:              "0x________________________________"

// Optional Components
REWARDS_DIST:        "0x________________________________"
PERMISSIONS_REG:     "0x________________________________"

// Multisigs & EOAs
PROTOCOL_MULTISIG:   "0x________________________________"
TREASURY:            "0x________________________________"
TEAM_MULTISIG:       "0x________________________________"

// Key Pairs
LITHOS_WETH_PAIR:    "0x________________________________"
USDT_USDC_PAIR:      "0x________________________________"

// Key Gauges
LITHOS_WETH_GAUGE:   "0x________________________________"
USDT_USDC_GAUGE:     "0x________________________________"

// Important Parameters
CHAIN_ID:            1  // or 56 for BSC
BLOCK_DEPLOYED:      00000000
DEPLOYMENT_DATE:     "2024-XX-XX"
INITIAL_SUPPLY:      "50000000"
```

### Subgraph Endpoints
```yaml
Production: https://api.thegraph.com/subgraphs/name/lithos/mainnet
Development: https://api.thegraph.com/subgraphs/name/lithos/testnet
```

### RPC Endpoints
```yaml
Primary: https://mainnet.infura.io/v3/YOUR_KEY
Backup1: https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
Backup2: https://rpc.ankr.com/eth
```

---

## Post-Launch Monitoring

### Critical Metrics Dashboard
```javascript
// Metrics to track every block
const criticalMetrics = {
    totalValueLocked: "Sum of all pair TVLs",
    weeklyVolume: "7-day trading volume",
    weeklyFees: "7-day fee generation",
    circulatingSupply: "LITHOS not in veNFTs",
    lockedSupply: "LITHOS in veNFTs",
    lockRatio: "locked / circulating",
    activeGauges: "Gauges with votes",
    uniqueVoters: "Unique veNFT voters",
    bribeEfficiency: "Bribes vs emissions value"
};

// Alert thresholds
const alerts = {
    tvlDrop: -20,        // 20% drop in 24h
    volumeDrop: -30,     // 30% volume drop
    lockRatio: 0.25,     // Below 25% locked
    gaugeConcentration: 0.5, // >50% to one gauge
};
```

### Weekly Reports
- Total emissions distributed
- Fee revenue generated
- New pairs created
- New partners onboarded
- Governance proposals
- Security incidents

---

## Appendix: Common Issues & Solutions

### Issue: First epoch won't start
```javascript
// Solution: Ensure 2 weeks have passed since deployment
// Or manually trigger if using modified timeline
await Minter.update_period();
```

### Issue: Votes not registering
```javascript
// Check vote delay setting
const delay = await VoterV3.voteDelay();
// Ensure enough time passed since last vote
```

### Issue: Gauge not receiving emissions
```javascript
// Verify gauge is not killed
const isAlive = await VoterV3.isAlive(gauge);
// Check if gauge has votes
const weight = await VoterV3.weights(gauge);
```

### Issue: High gas costs
```javascript
// Use GlobalRouter for multi-hop
// Batch operations where possible
// Consider increasing block gas limit
```

---

This completes the deployment and operations guide. Follow these steps carefully for a successful mainnet launch.