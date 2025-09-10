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
- **PairFactory**: [0xF1471A005b7557C1d472f0a060040f93ae074297](https://testnet.plasmascan.to/address/0xF1471A005b7557C1d472f0a060040f93ae074297)
- **TradeHelper**: [0x08798C36d9e1d274Ab48C732B588d9eEE7526E0e](https://testnet.plasmascan.to/address/0x08798C36d9e1d274Ab48C732B588d9eEE7526E0e)
- **RouterV2** (Main): [0x84E8a39C85F645c7f7671689a9337B33Bdc784f8](https://testnet.plasmascan.to/address/0x84E8a39C85F645c7f7671689a9337B33Bdc784f8)
- **WXPL**: [0x6100E367285b01F48D07953803A2d8dCA5D19873](https://testnet.plasmascan.to/address/0x6100E367285b01F48D07953803A2d8dCA5D19873)

> **Note**: RouterV2 is the primary contract for frontend integration. It handles all liquidity and swap operations.

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
const pairFactory = new ethers.Contract(PAIR_FACTORY_ADDRESS, pairFactoryAbi, signer);

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
    true,  // stable pool
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

**JavaScript Example:**
```javascript
// Simple swap: USDC -> USDT (stable pool)
await usdc.approve(ROUTER_V2_ADDRESS, amountIn);
const tx = await router.swapExactTokensForTokensSimple(
    amountIn,
    amountOutMin,
    USDC_ADDRESS,
    USDT_ADDRESS,
    true,  // use stable pool
    userAddress,
    deadline
);

// Multi-hop swap: TokenA -> TokenB -> TokenC
const routes = [
    { from: TOKEN_A, to: TOKEN_B, stable: false },
    { from: TOKEN_B, to: TOKEN_C, stable: true }
];

await tokenA.approve(ROUTER_V2_ADDRESS, amountIn);
const tx2 = await router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    routes,
    userAddress,
    deadline
);

// XPL -> Token swap
const tx3 = await router.swapExactETHForTokens(
    amountOutMin,
    [{ from: WXPL_ADDRESS, to: TOKEN_ADDRESS, stable: false }],
    userAddress,
    deadline,
    { value: ethers.utils.parseEther("1.0") }
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

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

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
