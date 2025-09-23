# Plasma DEX Subgraph

A comprehensive subgraph for indexing Plasma DEX - a V3 fork with AMM functionality. This subgraph tracks trading, liquidity, and fee data across the core DEX contracts.

## Overview

This subgraph indexes the following contracts:
- **PairFactory**: Creates new trading pairs
- **Pair**: Individual AMM pairs (stable/volatile)
- **RouterV2**: Router for executing swaps
- **GlobalRouter**: Global router with V3 integration
- **PairFees**: Fee collection and distribution

## Features

### Tracked Data
- ✅ **Trading Activity**: All swaps with volume and fee tracking
- ✅ **Liquidity Management**: Mint/burn events and LP positions
- ✅ **Price Data**: Token prices and TWAP oracles
- ✅ **Fee Analytics**: Fee collection and distribution
- ✅ **User Activity**: User positions and trading history
- ✅ **Historical Data**: Hourly and daily aggregations

### Key Entities
- **Factory**: Factory statistics and configuration
- **Pair**: Individual pair data and metrics
- **Token**: Token information and price tracking
- **User**: User positions and activity
- **Swap/Mint/Burn**: Transaction details
- **LiquidityPosition**: User LP positions

## Setup

### 1. Install Dependencies
```bash
cd subgraph
npm install
```

### 2. Update Configuration

#### Update `subgraph.yaml`:
```yaml
# Replace placeholders with actual values
dataSources:
  - name: PairFactory
    source:
      address: "0xYourFactoryAddress"  # Replace with actual factory address
      startBlock: 12345678            # Replace with deployment block
    network: mainnet                  # Change to your target network
```

#### Update `src/helpers.ts`:
```typescript
// Update contract addresses
export let FACTORY_ADDRESS = "0xYourFactoryAddress"
export let WETH_ADDRESS = "0xYourWETHAddress" 
export let USDC_ADDRESS = "0xYourUSDCAddress"
```

### 3. Generate Code and Build
```bash
npm run codegen
npm run build
```

### 4. Deploy

#### The Graph Studio:
```bash
# Authenticate
npm run auth

# Deploy
npm run deploy
```

#### Goldsky:
```bash
# Set environment variables
export GOLDSKY_API_KEY="your-api-key"
export ALCHEMY_API_KEY="your-alchemy-key"

# Deploy
npm run deploy:goldsky
```

#### Local Development:
```bash
# Start local graph node (requires Docker)
docker-compose up

# Create local subgraph
npm run create-local

# Deploy to local node
npm run deploy-local
```

## GraphQL Queries

### Get Pair Data
```graphql
{
  pairs(first: 10, orderBy: volumeUSD, orderDirection: desc) {
    id
    token0 {
      symbol
      name
    }
    token1 {
      symbol  
      name
    }
    stable
    reserve0
    reserve1
    volumeUSD
    txCount
  }
}
```

### Get User Positions
```graphql
{
  user(id: "0x...") {
    liquidityPositions {
      pair {
        token0 { symbol }
        token1 { symbol }
      }
      liquidityTokenBalance
    }
    usdSwapped
  }
}
```

### Get Recent Swaps
```graphql
{
  swaps(first: 100, orderBy: timestamp, orderDirection: desc) {
    timestamp
    pair {
      token0 { symbol }
      token1 { symbol }
    }
    amount0In
    amount1In
    amount0Out
    amount1Out
    amountUSD
  }
}
```

### Get Token Analytics
```graphql
{
  tokens(first: 20, orderBy: tradeVolumeUSD, orderDirection: desc) {
    symbol
    name
    tradeVolumeUSD
    totalLiquidity
    derivedETH
    txCount
  }
}
```

## Network Configuration

### Supported Networks
- Ethereum Mainnet
- Arbitrum
- Polygon
- Base
- Custom networks (update `goldsky.json`)

### Environment Variables
Create a `.env` file:
```bash
GOLDSKY_API_KEY=your_goldsky_api_key
ALCHEMY_API_KEY=your_alchemy_api_key
FACTORY_ADDRESS=0x...
ROUTER_ADDRESS=0x...
WETH_ADDRESS=0x...
```

## Development

### Project Structure
```
subgraph/
├── schema.graphql          # GraphQL schema
├── subgraph.yaml          # Subgraph manifest  
├── src/
│   ├── factory.ts         # Factory event handlers
│   ├── pair.ts           # Pair event handlers
│   ├── router.ts         # Router event handlers
│   └── helpers.ts        # Utility functions
├── abis/                 # Contract ABIs
├── package.json
└── goldsky.json         # Goldsky configuration
```

### Key Files

#### `schema.graphql`
Defines the GraphQL schema with all entities and their relationships.

#### `subgraph.yaml` 
Configures which contracts to index and which events to track.

#### `src/factory.ts`
Handles `PairCreated` events and creates new pair entities.

#### `src/pair.ts`
Handles all pair events: `Mint`, `Burn`, `Swap`, `Sync`, `Fees`, etc.

#### `src/router.ts`
Handles router swap events for additional analytics.

#### `src/helpers.ts`
Utility functions for price calculations, conversions, and entity creation.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the subgraph locally
5. Submit a pull request

## Troubleshooting

### Common Issues

**ABI not found errors**:
```bash
# Re-extract ABIs from contract builds
node extract-abis.js
```

**Codegen fails**:
```bash
# Check subgraph.yaml addresses and ABIs
npm run codegen --debug
```

**Build errors**:
```bash
# Check TypeScript in mapping files
npm run build --debug
```

**Sync issues**:
- Verify start block is correct
- Check contract addresses match deployed contracts
- Ensure network configuration is correct

## License

MIT License - see LICENSE file for details.