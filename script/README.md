# Lithos Protocol ve(3,3) Deployment Scripts

# Epochs
- Epoch 0: Oct 2-9 - deployment
- Epoch 1: Oct 9-16
  - Bribes start coming in: Oct 9-12
  - TGE: Oct 12
- Epoch 2: Oct 16-23
- Epoch 3: Oct 23-30

## Overview
The DEX infrastructure is already deployed on mainnet. These scripts handle the ve(3,3) governance system deployment.

**DEX (Already Deployed - Mainnet):**
- PairFactoryUpgradeable - not actually upgradeable rip
- TradeHelper
- GlobalRouter
- RouterV2

**ve(3,3) (To Deploy - Oct 3-16):**
- Phase 1 (Oct 3): Deploy contracts and mint 50M LITHOS to deployer
- Phase 2 (Oct 9): Activate minter and set as minter on Lithos
- Phase 3 (Oct 12): Airdrop and locking/voting
- Phase 4 (Oct 16): First emissions distributed

## Deployment Timeline

**Oct 3:** Deploy all contracts (Phase 1)
- Contracts deployed but minter inactive
- `active_period` set to Oct 16
- Mint 50M LITHOS to deployer

**Oct 9:** Activate minter (Phase 2)
- Set `active_period` to Oct 9
- Transfer LITHOS to Minter for emissions

**Oct 12:** Airdrop & voting (Phase 3)
- Users lock LITHOS → receive veLITH NFTs
- Users vote on gauges
- Votes recorded for Oct 9 epoch

**Oct 16:** First distribution (Phase 4)
- Call `distributeAll()` - uses Oct 9 votes
- Gauges receive emissions

**Oct 16+:** Ownership handoff
1. Verify system stable for several days
2. Run `TransferToTimelock.s.sol` (control → timelock)
3. Run `RenounceTimelockAdmin.s.sol` (remove admin backdoor)

## State Management

The deployment uses `deployments/{env}/state.json` to persist contract addresses between phases:

**Phase 1 (Deploy):**
- Loads DEX addresses (must exist)
- Deploys ve33 contracts
- Saves all addresses to state.json

**Phase 2 (Activate):**
- Loads ve33 addresses from state.json
- Activates minter with saved addresses

**IMPORTANT:** Do not delete or modify `deployments/mainnet/state.json` between phases. Other scripts (TransferToTimelock, RenounceTimelockAdmin) also read from this file.

## Deployment Scripts

### 1. DeployAndInitVe33.s.sol
Deploys ve(3,3) governance system with two-phase activation.

#### Prerequisites
```bash
export DEPLOY_ENV=mainnet
export PRIVATE_KEY=0x...
export RPC_URL=https://...
export GAS_LIMIT=30000000
export GAS_PRICE=1000000000
```

#### Phase 1 - Oct 3 (Deploy)
```bash
forge script script/DeployAndInitVe33.s.sol \
  --rpc-url "$RPC_URL" \
  --gas-limit "$GAS_LIMIT" \
  --gas-price "$GAS_PRICE" \
  --legacy \
  --broadcast \
  --verify
```

**What it deploys:**
- Lithos token - mints 50M LITHOS to deployer
- VotingEscrow (veNFT system)
- VeArtProxyUpgradeable (via TransparentProxy)
- VoterV3
- MinterUpgradeable (via TransparentProxy)
- GaugeFactoryV2
- BribeFactoryV3
- RewardsDistributor
- PermissionsRegistry
- ProxyAdmin
- TimelockController (48hr delay)

#### Phase 2 - Oct 9 (Activate)
```bash
ACTIVATE_MINTER=true \
forge script script/DeployAndInitVe33.s.sol \
  --rpc-url "$RPC_URL" \
  --gas-limit "$GAS_LIMIT" \
  --gas-price "$GAS_PRICE" \
  --legacy \
  --broadcast
```

**What it does:**
- Activates minter (sets `active_period` to Oct 9)
- Deployer can now distribute LITHOS for airdrop and emissions

## Governance Transfer (Run after deployment is stable)

### 2. TransferToTimelock.s.sol
Transfer control from deployer to TimelockController.

**Run after system is stable (Oct 16+):**
```bash
export PROXY_ADMIN=0x...
export PERMISSIONS_REGISTRY=0x...
export TIMELOCK=0x...
export DEPLOYER=0x...

forge script script/TransferToTimelock.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast
```

**What it does:**
- Transfers ProxyAdmin ownership → Timelock (all upgrades require 48hr delay)
- Grants GOVERNANCE + VOTER_ADMIN roles → Timelock
- Revokes deployer roles (optional security measure)

### 3. RenounceTimelockAdmin.s.sol
**IRREVERSIBLE**

**Run after first distribution succeeds (Oct 16+):**
```bash
export CONFIRM_RENOUNCE=true

forge script script/RenounceTimelockAdmin.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast
```

**What it does:**
- Deployer renounces TIMELOCK_ADMIN_ROLE
- ALL future role changes require 48hr timelock process
- No admin backdoor

**Only proceed if:**
1. First distribution (Oct 16) succeeded
2. System verified stable for several days
3. All necessary roles properly configured
4. Emergency procedures documented

## Security

**Upgradeability:**
- MinterUpgradeable & VeArtProxyUpgradeable use TransparentProxy pattern
- ProxyAdmin controls upgrades
