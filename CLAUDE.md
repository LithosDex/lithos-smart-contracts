# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lithos is a ve(3,3) DEX protocol on Plasma network combining:
- **Dual-AMM DEX**: Stable (Curve-like) and volatile (Uniswap V2) pools
- **ve(3,3) Governance**: Lock LITHOS tokens → veNFTs → vote on gauge emissions
- **Concentrated Liquidity**: Algebra-based CL pools with Hypervisor integration

**Networks**: Mainnet (Plasma, Chain ID 9745) and Testnet (Plasma)

## Build & Test Commands

```bash
# Build
forge build                    # Compile with optimizer (200 runs, viaIR)
forge build --sizes            # Show contract sizes

# Test
forge test                     # Run all unit tests
forge test -vvv                # Verbose output with traces
forge test --no-match-contract E2ETest  # Skip E2E tests (used in CI)
forge test --fork-url $RPC_URL # Fork testing against live network

# Format & Lint
forge fmt                      # Format Solidity files
forge fmt --check              # Check formatting (CI)

# Gas
forge snapshot                 # Create gas benchmark snapshot

# Deploy Scripts
forge script script/DeployAndInit.s.sol:DeployAndInitScript \
  --rpc-url $RPC_URL --broadcast

# Contract Interaction
cast call <addr> "func(type)(returnType)" <args> --rpc-url $RPC_URL
cast calldata "func(type)" <args>  # Generate calldata for multisig
```

## Project Structure

```
src/contracts/           # Core Solidity contracts
├── Pair.sol             # AMM pool (stable/volatile)
├── PairFactory*.sol     # Pool creation
├── RouterV2.sol         # Primary swap/liquidity router
├── GlobalRouter.sol     # V2 + CL unified router
├── VotingEscrow.sol     # veNFT system
├── VoterV3.sol          # Gauge voting & emissions
├── GaugeV2.sol          # LP staking for emissions
├── MinterUpgradeable.sol # Weekly emission scheduler
├── Bribes.sol           # External voting incentives
├── interfaces/          # All interfaces (I* prefix)
├── factories/           # Gauge, Bribe factories
├── libraries/           # Math libs (Decimal, FixedPoint)
└── APIHelper/           # Read-only query contracts
test/                    # Foundry tests (*.t.sol)
script/                  # Deployment & operational scripts
deployments/             # Persisted state per network
├── mainnet/state.json
└── testnet/state.json
docs/                    # Protocol documentation
ts/                      # TypeScript calculation utilities
subgraph/                # The Graph indexing (Goldsky)
```

## Architecture

```
LITHOS Token
    └─> VotingEscrow (lock → veNFT)
        └─> Voter (gauge voting)
            ├─> GaugeV2 (LP staking → emissions)
            │   └─> Bribes (voting incentives)
            └─> Minter (weekly emission supply)

RouterV2/GlobalRouter
    └─> PairFactory
        └─> Pair (xy=k or stable swap)
            └─> PairFees (fee escrow)
```

**Key Relationships**:
- `Minter` distributes weekly emissions to `Voter`
- `Voter` allocates emissions to gauges based on veNFT votes
- `GaugeV2` streams emissions to LP stakers
- `Bribes` collect external incentives for voters

## Development Patterns

**Solidity Style**:
- Solidity 0.8.29, 4-space indent, explicit `uint256` types
- Interfaces prefixed with `I` (e.g., `IVoter`)
- Constants in `ALL_CAPS`
- NatSpec on public/external functions
- One contract per file, filename matches contract name

**Testing**:
- Use `forge-std/Test.sol` with `vm.*` cheatcodes
- Use `makeAddr("name")` for test accounts
- Fork tests excluded from CI via `--no-match-contract E2ETest`
- Gas limit: 90M (Plasma-specific)

**Upgradeable Contracts**:
- `MinterUpgradeable`, `PairFactoryUpgradeable`, `VeArtProxyUpgradeable` use TransparentProxy
- ProxyAdmin controls upgrades

## Key Mainnet Addresses

| Contract | Address |
|----------|---------|
| Voter | `0x2AF460a511849A7aA37Ac964074475b0E6249c69` |
| VotingEscrow | `0x2Eff716Caa7F9EB441861340998B0952AF056686` |
| Minter (proxy) | `0x3bE9e60902D5840306d3Eb45A29015B7EC3d10a6` |
| RouterV2 | `0xD70962bd7C6B3567a8c893b55a8aBC1E151759f3` |
| GlobalRouter | `0xC7E4BCC695a9788fd0f952250cA058273BE7F6A3` |
| PairFactory | `0x71a870D1c935C2146b87644DF3B5316e8756aE18` |
| LITHOS Token | `0xAbB48792A3161E81B47cA084c0b7A22a50324A44` |

Full addresses: `deployments/mainnet/state.json`

## Multisig Governance

| Role | Address | Purpose |
|------|---------|---------|
| Governance (4/6) | `0x21F1c2F66d30e22DaC1e2D509228407ccEff4dBC` | PermissionsRegistry roles |
| Operations (3/4) | `0xbEe8e366fEeB999993841a17C1DCaaad9d4618F7` | Minter/VE team address |
| Emergency (2/3) | `0x771675A54f18816aC9CD71b07d3d6e6Be7a9D799` | Emergency council |
| Plasma PGF | `0x495a98fd059551385Fc9bAbBcFD88878Da3A1b78` | Weekly veNFT voting |

See `docs/multisig-operations.md` for calldata examples and procedures.

## Claude Skills

This repo has Claude skills in `.claude/skills/`:
- **vote-set**: Generate Safe UI batch JSON for setting veNFT votes
- **vote-reset**: Generate Safe UI batch JSON to reset votes
- **claim-rewards**: Generate Safe UI batch JSON to claim bribes/rewards

Usage: Invoke via skill commands when generating multisig transactions.

## TypeScript Utilities

```bash
pnpm run ts:price-impact    # Price impact simulation
pnpm run ts:liquidity       # Liquidity planning
pnpm run calc:votes         # Vote calculation
pnpm run calc:apr           # Gauge APR calculation
pnpm run calc:bribes        # Bribe claimables
```

## Environment Setup

Copy `.env.example` to `.env`:
```
DEPLOY_ENV=mainnet          # or testnet
RPC_URL=https://...         # Plasma RPC
PRIVATE_KEY=0x...           # Deployer key
ETHERSCAN_API_KEY=verify    # Routescan verification
```

## Subgraph Deployment

```bash
cd subgraph
yarn codegen && yarn build
goldsky subgraph deploy lithos-subgraph-mainnet/v1.0.x --path .
```

## Documentation

- `docs/DEPLOYMENT.md` - Full deployment sequence
- `docs/DEX.md` - AMM mechanics and fee flows
- `docs/TOKENOMICS.md` - Emissions, voting, rebases
- `docs/REWARDS_FLOW.md` - Reward distribution mechanics
- `docs/OWNERSHIP_ROLES.md` - Access control matrix
- `docs/multisig-operations.md` - Safe transaction procedures
- `AGENTS.md` - Memory system integration
