## Deployed Contracts

# Lithos DEX

A decentralized exchange (DEX) built on Plasma testnet featuring both stable and volatile AMM pools, inspired by Solidly's design with Uniswap V2-like interface.

## Key Features

- **Dual AMM Types**: Support for both stable (low-slippage) and volatile (standard xy=k) pools
- **Uniswap V2 Compatible**: Standard interface for easy frontend integration
- **Fee-on-Transfer Support**: Works with tokens that charge fees on transfers
- **Native Token Integration**: Full XPL/WXPL support with automatic wrapping/unwrapping

## Contract Addresses

### Testnet (Plasma)

#### Core DEX
- **PairFactory**: [0xF1471A005b7557C1d472f0a060040f93ae074297](https://testnet.plasmascan.to/address/0xF1471A005b7557C1d472f0a060040f93ae074297)
- **RouterV2** (Main): [0x84E8a39C85F645c7f7671689a9337B33Bdc784f8](https://testnet.plasmascan.to/address/0x84E8a39C85F645c7f7671689a9337B33Bdc784f8)
- **GlobalRouter**: [0x48406768424369b69Cc52886A6520a1839CC426E](https://testnet.plasmascan.to/address/0x48406768424369b69Cc52886A6520a1839CC426E)
- **TradeHelper**: [0x08798C36d9e1d274Ab48C732B588d9eEE7526E0e](https://testnet.plasmascan.to/address/0x08798C36d9e1d274Ab48C732B588d9eEE7526E0e)

#### ve(3,3) Governance
- **VotingEscrow**: [0x592FA200950B053aCE9Be6d4FB3F58b1763898C0](https://testnet.plasmascan.to/address/0x592FA200950B053aCE9Be6d4FB3F58b1763898C0)
- **VeArtProxyUpgradeable**: [0x2A66F82F6ce9976179D191224A1E4aC8b50e68D1](https://testnet.plasmascan.to/address/0x2A66F82F6ce9976179D191224A1E4aC8b50e68D1)
- **RewardsDistributor**: [0x3b32FEDe4309265Cacc601368787F4264C69070e](https://testnet.plasmascan.to/address/0x3b32FEDe4309265Cacc601368787F4264C69070e)
- **PermissionsRegistry**: [0x3A908c6095bD1A69b651D7B32AB42806528d88c8](https://testnet.plasmascan.to/address/0x3A908c6095bD1A69b651D7B32AB42806528d88c8)
- **VoterV3**: [0xb7cF73026b3a35955081BB8D9025aE13C50C74cd](https://testnet.plasmascan.to/address/0xb7cF73026b3a35955081BB8D9025aE13C50C74cd)
- **GaugeFactoryV2**: [0x23e7E5f66Ff4396F0D95ad630f4297D768193DE1](https://testnet.plasmascan.to/address/0x23e7E5f66Ff4396F0D95ad630f4297D768193DE1)
- **BribeFactoryV3**: [0xC4B0BeCF35366629712FCEfcB4A88727236A531E](https://testnet.plasmascan.to/address/0xC4B0BeCF35366629712FCEfcB4A88727236A531E)
- **MinterUpgradeable**: [0x6e74245E7E7582790bE61a1a16b459945cCf65A2](https://testnet.plasmascan.to/address/0x6e74245E7E7582790bE61a1a16b459945cCf65A2)

#### Tokens
- **LITH**: [0x45b7C44DC11c6b0E2399F4fd1730F2dB3A30aD51](https://testnet.plasmascan.to/address/0x45b7C44DC11c6b0E2399F4fd1730F2dB3A30aD51)
- **WXPL**: [0x6100E367285b01F48D07953803A2d8dCA5D19873](https://testnet.plasmascan.to/address/0x6100E367285b01F48D07953803A2d8dCA5D19873)
- **TEST**: [0xb89cdFf170b45797BF93536773113861EBEABAfa](https://testnet.plasmascan.to/address/0xb89cdFf170b45797BF93536773113861EBEABAfa) _(Test token for bribes contract)_

> **Note**: RouterV2 is the primary contract for frontend integration. It handles all liquidity and swap operations.

#### Pairs/Gauge
Pair Index 0
- Token0: 0x3576E9157cF2e1dB071b3587dEbBFb67D9e0962d (WXPL)
- Token1: 0x726A66766A784A582F5f48E81A5772DD6bD1F34E (USDT)
- Pair: 0xf89834bA86E8D74c7E691796F80badc817D0c764
- Gauge: 0xaff8EF3a3aCfeF558cb6b32DB1d8b0C7d0Bd43ED
- Internal Bribe: 0xf9ED85d7c293B9773f9f84A285f8a950A9C21d86
- External Bribe: 0xf1f95E914cED73f95F1323CFd8F8f0bdf902bC06
- Pool Type: Volatile


## Frontend Integration Guide

### 1. Pool Creation

Create trading pairs through the PairFactory contract:

```solidity
// Create a new trading pair
function createPair(
    address tokenA,
    address tokenB,
    bool stable      // true for stable pool, false for volatile pool
) external returns (address pair)
```

**JavaScript Example:**

```javascript
const pairFactory = new ethers.Contract(
  PAIR_FACTORY_ADDRESS,
  pairFactoryAbi,
  signer
);

// Create volatile pool (standard AMM)
const volatilePair = await pairFactory.createPair(tokenA, tokenB, false);

// Create stable pool (low slippage for similar assets)
const stablePair = await pairFactory.createPair(USDC, USDT, true);
```

### 2. Liquidity Management

All liquidity operations are handled through RouterV2:

#### Add Liquidity (ERC20 + ERC20)

```solidity
function addLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,      // Slippage protection
    uint amountBMin,      // Slippage protection
    address to,           // LP token recipient
    uint deadline
) external returns (uint amountA, uint amountB, uint liquidity)
```

#### Add Liquidity (Token + XPL)

```solidity
function addLiquidityETH(
    address token,
    bool stable,
    uint amountTokenDesired,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
) external payable returns (uint amountToken, uint amountETH, uint liquidity)
```

#### Remove Liquidity

```solidity
function removeLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint liquidity,       // LP tokens to burn
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB)
```

#### Remove Liquidity (Get XPL back)

```solidity
function removeLiquidityETH(
    address token,
    bool stable,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline
) external returns (uint amountToken, uint amountETH)
```

**JavaScript Example:**

```javascript
const router = new ethers.Contract(ROUTER_V2_ADDRESS, routerV2Abi, signer);

// Add liquidity to USDC/USDT stable pool
await tokenA.approve(ROUTER_V2_ADDRESS, amountADesired);
await tokenB.approve(ROUTER_V2_ADDRESS, amountBDesired);

const tx = await router.addLiquidity(
  USDC_ADDRESS,
  USDT_ADDRESS,
  true, // stable pool
  amountADesired,
  amountBDesired,
  amountAMin,
  amountBMin,
  userAddress,
  deadline
);

// Add liquidity with XPL
await token.approve(ROUTER_V2_ADDRESS, amountTokenDesired);
const tx2 = await router.addLiquidityETH(
  TOKEN_ADDRESS,
  false, // volatile pool
  amountTokenDesired,
  amountTokenMin,
  amountETHMin,
  userAddress,
  deadline,
  { value: ethers.utils.parseEther("1.0") }
);
```

### 3. Token Swaps

#### Basic Token Swaps

```solidity
// Multi-hop swap with custom routing
function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    route[] calldata routes,  // Custom routing path
    address to,
    uint deadline
) external returns (uint[] memory amounts)

// Simple single-hop swap
function swapExactTokensForTokensSimple(
    uint amountIn,
    uint amountOutMin,
    address tokenFrom,
    address tokenTo,
    bool stable,      // Which pool type to use
    address to,
    uint deadline
) external returns (uint[] memory amounts)
```

#### XPL Swaps

```solidity
// XPL -> Token
function swapExactETHForTokens(
    uint amountOutMin,
    route[] calldata routes,
    address to,
    uint deadline
) external payable returns (uint[] memory amounts)

// Token -> XPL
function swapExactTokensForETH(
    uint amountIn,
    uint amountOutMin,
    route[] calldata routes,
    address to,
    uint deadline
) external returns (uint[] memory amounts)
```

#### Route Structure

```solidity
struct route {
    address from;    // Input token
    address to;      // Output token
    bool stable;     // Pool type (true = stable, false = volatile)
}
```

**JavaScript Example (GlobalRouter):**

```javascript
const globalRouter = new ethers.Contract(
  GLOBAL_ROUTER_ADDRESS,
  globalRouterAbi,
  signer
);

// Simple swap: USDC -> USDT (stable pool)
await usdc.approve(GLOBAL_ROUTER_ADDRESS, amountIn);
const tx = await globalRouter.swapExactTokensForTokens(
  amountIn,
  amountOutMin,
  [{ from: USDC_ADDRESS, to: USDT_ADDRESS, stable: true }],
  userAddress,
  deadline,
  true // _type = true for V2 pools, false for V3 pools
);

// Multi-hop swap: TokenA -> TokenB -> TokenC
const routes = [
  { from: TOKEN_A, to: TOKEN_B, stable: false },
  { from: TOKEN_B, to: TOKEN_C, stable: true },
];

await tokenA.approve(GLOBAL_ROUTER_ADDRESS, amountIn);
const tx2 = await globalRouter.swapExactTokensForTokens(
  amountIn,
  amountOutMin,
  routes,
  userAddress,
  deadline,
  true // use V2 pools
);

// Get swap preview using GlobalRouter
const [amount, isStablePool] = await globalRouter.getAmountOut(
  amountIn,
  TOKEN_A,
  TOKEN_B
);
```

### 4. Price Queries & Calculations

Use TradeHelper for price calculations without executing trades:

```solidity
// Get best rate between stable and volatile pools
function getAmountOut(
    uint amountIn,
    address tokenIn,
    address tokenOut
) external view returns (uint amount, bool stable)

// Calculate multi-hop swap output
function getAmountsOut(
    uint amountIn,
    route[] memory routes
) external view returns (uint[] memory amounts)

// Quote liquidity addition
function quoteAddLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint amountADesired,
    uint amountBDesired
) external view returns (uint amountA, uint amountB, uint liquidity)
```

### 5. Fee-on-Transfer Token Support

For tokens that charge fees on transfers, use the `SupportingFeeOnTransferTokens` variants:

```solidity
function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    route[] calldata routes,
    address to,
    uint deadline
) external

function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint amountOutMin,
    route[] calldata routes,
    address to,
    uint deadline
) external payable
```

## Pool Types

### Stable Pools (`stable = true`)

- **Use Case**: Assets with similar values (USDC/USDT, ETH/stETH)
- **Algorithm**: Curve-like stable swap math
- **Benefits**: Lower slippage, better rates for similar assets
- **Fees**: 0.04% (4 basis points)

### Volatile Pools (`stable = false`)

- **Use Case**: Standard trading pairs with different values
- **Algorithm**: Uniswap V2 xy=k formula
- **Benefits**: Standard AMM behavior, suitable for all assets
- **Fees**: 0.18% (18 basis points)

## Integration Checklist

- [ ] Import RouterV2 ABI and connect to `0x84E8a39C85F645c7f7671689a9337B33Bdc784f8`
- [ ] Implement token approval flows before liquidity/swap operations
- [ ] Add slippage tolerance settings (recommend 0.5% for stable, 2% for volatile)
- [ ] Implement deadline parameter (recommend current timestamp + 20 minutes)
- [ ] Handle both stable and volatile pool routing
- [ ] Add support for XPL (native token) operations via `*ETH` functions
- [ ] Implement price impact warnings for large trades
- [ ] Add liquidity preview using `quoteAddLiquidity`

## Voting Escrow (veNFT) System

Lock LITHOS tokens to receive veNFTs with voting power and revenue sharing rights:

### Create Lock

```solidity
// Create a new lock position
function create_lock(uint256 _value, uint256 _lock_duration) external returns (uint256)

// Create lock for another address
function create_lock_for(uint256 _value, uint256 _lock_duration, address _to) external returns (uint256)
```

### Manage Existing Lock

```solidity
// Add more tokens to existing lock
function increase_amount(uint256 _tokenId, uint256 _value) external

// Extend lock duration
function increase_unlock_time(uint256 _tokenId, uint256 _lock_duration) external

// Withdraw after lock expires
function withdraw(uint256 _tokenId) external
```

### NFT Features

```solidity
// Get voting power of NFT
function balanceOfNFT(uint256 _tokenId) external view returns (uint256)

// Transfer veNFT (standard ERC-721)
function transferFrom(address _from, address _to, uint256 _tokenId) external

// Merge two NFTs into one
function merge(uint256 _from, uint256 _to) external

// Split NFT into multiple (specify percentages)
function split(uint256[] memory amounts, uint256 _tokenId) external
```

**JavaScript Example:**

```javascript
const votingEscrow = new ethers.Contract(
  VOTING_ESCROW_ADDRESS,
  votingEscrowAbi,
  signer
);

// Approve LITHOS tokens
await lithos.approve(VOTING_ESCROW_ADDRESS, lockAmount);

// Create 1 year lock
const lockDuration = 365 * 24 * 60 * 60; // 1 year in seconds
const tx = await votingEscrow.create_lock(lockAmount, lockDuration);

// Get veNFT ID from event
const receipt = await tx.wait();
const tokenId = receipt.events.find((e) => e.event === "Transfer").args.tokenId;

// Check voting power
const votingPower = await votingEscrow.balanceOfNFT(tokenId);

// Increase lock amount
await lithos.approve(VOTING_ESCROW_ADDRESS, additionalAmount);
await votingEscrow.increase_amount(tokenId, additionalAmount);

// Transfer veNFT
await votingEscrow.transferFrom(userAddress, recipientAddress, tokenId);
```

**Lock Parameters:**

- **Min Duration**: 1 week
- **Max Duration**: 2 years (104 weeks)
- **Voting Power**: Linear decay over time
- **Revenue Sharing**: Proportional to voting power

## Integration Checklist

### DEX Features

- [ ] Import GlobalRouter ABI and connect to `0x48406768424369b69Cc52886A6520a1839CC426E`
- [ ] Implement token approval flows before liquidity/swap operations
- [ ] Add slippage tolerance settings (recommend 0.5% for stable, 2% for volatile)
- [ ] Implement deadline parameter (recommend current timestamp + 20 minutes)
- [ ] Handle both stable and volatile pool routing
- [ ] Add support for XPL (native token) operations via `*ETH` functions
- [ ] Implement price impact warnings for large trades
- [ ] Add liquidity preview using `quoteAddLiquidity`

### Voting Escrow (veNFT) Features

- [ ] Import VotingEscrow ABI and connect to `0x592FA200950B053aCE9Be6d4FB3F58b1763898C0`
- [ ] Import Lithos token ABI and connect to `0x45b7C44DC11c6b0E2399F4fd1730F2dB3A30aD51`
- [ ] Implement LITHOS token approval for locking operations
- [ ] Add lock duration selector (1 week to 2 years)
- [ ] Display voting power decay over time
- [ ] Implement veNFT transfer functionality (ERC-721 standard)
- [ ] Add merge/split NFT features for advanced users
- [ ] Show lock expiration dates and withdrawal eligibility

## Error Handling

Common revert reasons:

- `BaseV1Router: EXPIRED` - Transaction deadline passed
- `BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT` - Slippage tolerance exceeded
- `BaseV1Router: INSUFFICIENT_A_AMOUNT` - Minimum amount not met
- `BaseV1Router: INVALID_PATH` - Routing path invalid (check WXPL address)
- `Pair: INSUFFICIENT_LIQUIDITY` - Pool has no liquidity

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
