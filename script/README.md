# Lithos Protocol Deployment Scripts

## Overview
The deployment process is split into four distinct phases, each with its own script:

1. **DeployAndInit.s.sol** - Deploys all contracts and initializes them in one atomic pass
2. **Link.s.sol** - Wires contracts together and performs initial mint
3. **InitialPairAndGauge.s.sol** - Creates the initial LITHOS/WXPL pair and gauge
4. **Ownership.s.sol** - Transfers control to governance multisig

## Quick Start

### Prerequisites
```bash
# Required environment variables
export DEPLOY_ENV=mainnet           # or testnet
export PRIVATE_KEY=0x...            # Deployer private key
export RPC_URL=https://...          # Network RPC endpoint
export MULTISIG=0x...               # Governance multisig address
export WXPL=0x...                   # Wrapped native token (XPL)

# Optional for contract verification
export ETHERSCAN_API_KEY=...        # Enables contract verification via Routescan

# For Phase 3 (Initial Pair & Gauge)
export INITIAL_LITHOS_AMOUNT=...    # Amount of LITHOS for initial liquidity
export INITIAL_WXPL_AMOUNT=...      # Amount of WXPL for initial liquidity

# Gas configuration (recommended for Plasma)
export GAS_LIMIT=30000000           # 30M gas limit
export GAS_PRICE=1000000000         # 1 gwei
```

### Run Deployment
```bash
# Phase 1: Deploy & initialize all contracts
source .env
forge script script/DeployAndInit.s.sol \
  --rpc-url "$RPC_URL" \
  --gas-limit "$GAS_LIMIT" \
  --gas-price "$GAS_PRICE" \
  --legacy \
  --broadcast \
  --slow

# To resume if interrupted:
forge script script/DeployAndInit.s.sol --rpc-url "$RPC_URL" --gas-limit "$GAS_LIMIT" --gas-price "$GAS_PRICE" --legacy --broadcast --resume --skip-simulation -vvv

# Phase 2: Link contracts
forge script script/Link.s.sol \
  --rpc-url "$RPC_URL" \
  --gas-limit "$GAS_LIMIT" \
  --gas-price "$GAS_PRICE" \
  --legacy \
  --broadcast \
  --slow

# Phase 3: Create initial pair & gauge
forge script script/InitialPairAndGauge.s.sol \
  --rpc-url "$RPC_URL" \
  --gas-limit "$GAS_LIMIT" \
  --gas-price "$GAS_PRICE" \
  --legacy \
  --broadcast \
  --slow

# Phase 4: Transfer ownership to multisig
forge script script/Ownership.s.sol \
  --rpc-url "$RPC_URL" \
  --gas-limit "$GAS_LIMIT" \
  --gas-price "$GAS_PRICE" \
  --legacy \
  --broadcast \
  --slow
```

## State Management
- Deployment state is saved to `deployments/<env>/state.json`
- Scripts automatically resume from last successful deployment
- State file contains all deployed contract addresses
- Delete or rename state file to run a fresh deployment

## Directory Structure
```
deployments/
  ├── mainnet/
  │   └── state.json
  └── testnet/
      └── state.json
```

## Contract Deployment Order

### Phase 1: Deploy & Initialize
Deploys every contract and executes its initializer in the same transaction bundle:

1. **Core Token System**
   - Lithos Token
   - VeArtProxyUpgradeable (NFT metadata)
   - VotingEscrow (veNFT system)

2. **DEX Infrastructure**
   - PairFactoryUpgradeable
   - TradeHelper (depends on PairFactory)
   - GlobalRouter (depends on TradeHelper)
   - RouterV2 (legacy compatibility, depends on PairFactory & WXPL)

3. **Gauge & Voting System**
   - GaugeFactoryV2
   - PermissionsRegistry
   - BribeFactoryV3
   - VoterV3
   - RewardsDistributor
   - MinterUpgradeable

### Phase 2: Link
Wires contracts together once every initializer is complete:
- Configure PairFactory trade fees (0.04% stable, 0.18% volatile)
- Set staking fee handler to deployer (keeps fees accessible until ownership transfer)
- Point BribeFactory at the live voter
- Wire VotingEscrow → VoterV3 connections
- **Perform initial mint of 50M LITHOS to deployer** (must be done before setting minter)
- Set Lithos minter to MinterUpgradeable contract
- Assign RewardsDistributor depositor rights to MinterUpgradeable
- Configure emission parameters (990 decay, 300 rebase, 40 team rate)

### Phase 3: Initial Pair & Gauge
Sets up the initial LITHOS/WXPL trading pair and gauge:
- Create the LITHOS/WXPL volatile pair
- Add initial liquidity to bootstrap the pair
- Whitelist LITHOS and WXPL tokens in VoterV3
- Create a gauge for the pair to receive emissions
- Save pair and gauge addresses to state.json

### Phase 4: Transfer Ownership
Transfers ownership to multisig and finalizes control:
- VoterV3 → Multisig
- GaugeFactoryV2 → VoterV3 (special case: owned by VoterV3)
- PairFactoryUpgradeable → Multisig
- BribeFactoryV3 → Multisig
- VeArtProxyUpgradeable → Multisig
- VotingEscrow team → Multisig
- Stage MinterUpgradeable team transfer (multisig must call `acceptTeam()`)
- Confirms Lithos minter is the Minter contract

## Security Notes

- **Upgradeables**: All upgradeable contracts are deployed and initialized in the same transaction to prevent takeover
- **Initial Mint**: 50M LITHOS minted to deployer in Phase 2, must be distributed according to tokenomics
- **Ownership Transfer**: Phase 4 is critical - ensure multisig is ready to accept roles
- **Two-Step Transfers**: Some roles (like MinterUpgradeable team) require the multisig to call `acceptTeam()` after Phase 4

## Additional Scripts

### WeeklyDistro.s.sol [TODO: Documentation]
Handles weekly emission distribution after protocol launch.

### Post-Deployment Operations [TODO: Scripts]
The following operational tasks from DEPLOYMENT.md still need scripts:
- Token whitelisting for additional tokens beyond LITHOS/WXPL
- Creating additional trading pairs and gauges
- Emergency procedures (pause trading, kill/revive gauges)
- Monitoring and metrics collection
