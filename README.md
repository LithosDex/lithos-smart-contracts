## Deployed Contracts

# Lithos DEX

A decentralized exchange (DEX) built on Plasma testnet featuring both stable and volatile AMM pools, inspired by Solidly's design with Uniswap V2-like interface.

## Key Features

- **Dual AMM Types**: Support for both stable (low-slippage) and volatile (standard xy=k) pools
- **Uniswap V2 Compatible**: Standard interface for easy frontend integration
- **Fee-on-Transfer Support**: Works with tokens that charge fees on transfers
- **Native Token Integration**: Full XPL/WXPL support with automatic wrapping/unwrapping

## Contract Addresses

### Mainnet (Plasma)

- **PairFactory**: [0x71a870D1c935C2146b87644DF3B5316e8756aE18](https://plasmascan.to/address/0x71a870D1c935C2146b87644DF3B5316e8756aE18)
- **RouterV2** (Main): [0xD70962bd7C6B3567a8c893b55a8aBC1E151759f3](https://plasmascan.to/address/0xD70962bd7C6B3567a8c893b55a8aBC1E151759f3)
- **GlobalRouter**: [0xC7E4BCC695a9788fd0f952250cA058273BE7F6A3](https://plasmascan.to/address/0xC7E4BCC695a9788fd0f952250cA058273BE7F6A3)
- **TradeHelper**: [0xf2e70f25a712B2FEE0B76d5728a620707AF5D42c](https://plasmascan.to/address/0xf2e70f25a712B2FEE0B76d5728a620707AF5D42c)

#### Tokens

- **WXPL**: [0x6100e367285b01f48d07953803a2d8dca5d19873](https://plasmascan.to/address/0x6100e367285b01f48d07953803a2d8dca5d19873)
- **USDT0**: [0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb](https://plasmascan.to/address/0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb)
- **USDe**: [0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34](https://plasmascan.to/address/0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34)
- **USDai**: [0x0a1a1a107e45b7ced86833863f482bc5f4ed82ef](https://plasmascan.to/address/0x0a1a1a107e45b7ced86833863f482bc5f4ed82ef)
- **WETH**: [0x9895d81bb462a195b4922ed7de0e3acd007c32cb](https://plasmascan.to/address/0x9895d81bb462a195b4922ed7de0e3acd007c32cb)
- **weETH**: [0xa3d68b74bf0528fdd07263c60d6488749044914b](https://plasmascan.to/address/0xa3d68b74bf0528fdd07263c60d6488749044914b)
- **xUSD**: [0x6eaf19b2fc24552925db245f9ff613157a7dbb4c](https://plasmascan.to/address/0x6eaf19b2fc24552925db245f9ff613157a7dbb4c)
- **tcUSDT0**: [0xa9c251f8304b1b3fc2b9e8fcae78d94eff82ac66](https://plasmascan.to/address/0xa9c251f8304b1b3fc2b9e8fcae78d94eff82ac66)

> **Note**: RouterV2 is the primary contract for frontend integration. It handles all liquidity and swap operations.

#### Pairs

1. **WXPL/USDT0** (Volatile)

   - Pair: [0xa0926801a2abc718822a60d8fa1bc2a51fa09f1e](https://plasmascan.to/address/0xa0926801a2abc718822a60d8fa1bc2a51fa09f1e)

2. **USDe/USDT0** (Stable)

   - Pair: [0x01b968c1b663c3921da5be3c99ee3c9b89a40b54](https://plasmascan.to/address/0x01b968c1b663c3921da5be3c99ee3c9b89a40b54)

3. **USDe/USDT0** (Volatile)

   - Pair: [0x08f68c9d37ce08470099dc9a8d43038de9674a8b](https://plasmascan.to/address/0x08f68c9d37ce08470099dc9a8d43038de9674a8b)

4. **USDai/USDT0** (Stable)

   - Pair: [0x548064df5e0c2d7f9076f75de0a4c6c3d72a5acc](https://plasmascan.to/address/0x548064df5e0c2d7f9076f75de0a4c6c3d72a5acc)

5. **WETH/weETH** (Volatile)

   - Pair: [0x7483ed877a1423f34dc5e46cf463ea4a0783d165](https://plasmascan.to/address/0x7483ed877a1423f34dc5e46cf463ea4a0783d165)

6. **WXPL/WETH** (Volatile)

   - Pair: [0x15df11a0b0917956fea2b0d6382e5ba100b312df](https://plasmascan.to/address/0x15df11a0b0917956fea2b0d6382e5ba100b312df)

7. **xUSD/tcUSDT0** (Stable)
   - Pair: [0x0d6f93edff269656dfac82e8992afa9e719b137e](https://plasmascan.to/address/0x0d6f93edff269656dfac82e8992afa9e719b137e)

#### ve(3,3) Governance (Deploying Oct 3-9, 2025)

**Deployment Schedule:**

- **Oct 3**: Core contracts deployed (inactive)
- **Oct 9**: System activated with initial LITH supply
- **Oct 12**: LITH airdrop and voting begins
- **Oct 16**: First emissions distributed

**Contracts (Pending Oct 3 Deployment):**

- **Lithos Token**: [Pending]
- **VotingEscrow**: [Pending]
- **VoterV3**: [Pending]
- **MinterUpgradeable** (proxy): [Pending]
- **VeArtProxyUpgradeable** (proxy): [Pending]
- **GaugeFactoryV2**: [Pending]
- **BribeFactoryV3**: [Pending]
- **RewardsDistributor**: [Pending]
- **PermissionsRegistry**: [Pending]
- **ProxyAdmin**: [Pending]
- **TimelockController**: [Pending]

**Initial Gauges (Created Oct 9):**

- LITH/WXPL: [Pending]
- [Additional gauges TBD]

### Testnet (Plasma)

#### Core DEX

- **PairFactory**: [0xa74848bAC41c4B1E6d1CFA6615Afb8893805075A](https://testnet.plasmascan.to/address/0xa74848bAC41c4B1E6d1CFA6615Afb8893805075A)
- **RouterV2** (Main): [0xb7Be9aB86d1A18c0425C3f6ABbbD58d0Ef19f1a9](https://testnet.plasmascan.to/address/0xb7Be9aB86d1A18c0425C3f6ABbbD58d0Ef19f1a9)
- **GlobalRouter**: [0x88C19a127aa22C7826546F34E63FE0e8995c88d0](https://testnet.plasmascan.to/address/0x88C19a127aa22C7826546F34E63FE0e8995c88d0)
- **TradeHelper**: [0xf30E5cD4E25603fd2262Aa00bf78D1A4b9AEDeEF](https://testnet.plasmascan.to/address/0xf30E5cD4E25603fd2262Aa00bf78D1A4b9AEDeEF)

#### ve(3,3) Governance

- **VotingEscrow**: [0x516C42d4BcF32531Cb7cf5Eb89Bb8870A4a60011](https://testnet.plasmascan.to/address/0x516C42d4BcF32531Cb7cf5Eb89Bb8870A4a60011)
- **VeArtProxyUpgradeable**: [0xbc1e64DBdF71AC6A7Df0FD656E2D4F5A628faf7F](https://testnet.plasmascan.to/address/0xbc1e64DBdF71AC6A7Df0FD656E2D4F5A628faf7F)
- **RewardsDistributor**: [0xEa132AE719aa6280a0f72AF3E4ee44Dd6888B1Ec](https://testnet.plasmascan.to/address/0xEa132AE719aa6280a0f72AF3E4ee44Dd6888B1Ec)
- **PermissionsRegistry**: [0xEcBb3aE0e0Cb7D5AdFa6F88c366Bb0D44Aba986A](https://testnet.plasmascan.to/address/0xEcBb3aE0e0Cb7D5AdFa6F88c366Bb0D44Aba986A)
- **VoterV3**: [0x5C1f4391ad20475D76f4738d3faAF3B170A06919](https://testnet.plasmascan.to/address/0x5C1f4391ad20475D76f4738d3faAF3B170A06919)
- **GaugeFactoryV2**: [0x4c7410dEd27c8DE462A288801F23ec08977f0F62](https://testnet.plasmascan.to/address/0x4c7410dEd27c8DE462A288801F23ec08977f0F62)
- **BribeFactoryV3**: [0x7f38E9a5cA4F8279eCEb0ab02eA5291F23e350b8](https://testnet.plasmascan.to/address/0x7f38E9a5cA4F8279eCEb0ab02eA5291F23e350b8)
- **MinterUpgradeable**: [0x4f00b43CD851ac5d5599834f71434f245A92D973](https://testnet.plasmascan.to/address/0x4f00b43CD851ac5d5599834f71434f245A92D973)

#### Tokens

- **LITH**: [0x3a6a2309Bc05b9798CF46699Bba9F6536039B72D](https://testnet.plasmascan.to/address/0x3a6a2309Bc05b9798CF46699Bba9F6536039B72D)
- **WXPL**: [0x3576E9157cF2e1dB071b3587dEbBFb67D9e0962d](https://testnet.plasmascan.to/address/0x3576E9157cF2e1dB071b3587dEbBFb67D9e0962d)
- **TEST**: [0xb89cdFf170b45797BF93536773113861EBEABAfa](https://testnet.plasmascan.to/address/0xb89cdFf170b45797BF93536773113861EBEABAfa) _(Test token for bribes contract)_

> **Note**: RouterV2 is the primary contract for frontend integration. It handles all liquidity and swap operations.

#### Pairs/Gauge

LITHOS/WXPL Pair

- Pair: [0xa9a6b6A0F249e90C999e96010554814907B8f9D7](https://testnet.plasmascan.to/address/0xa9a6b6A0F249e90C999e96010554814907B8f9D7)
- Gauge: [0xa5471946F66c8eaFFa101feF465B912C0255D1f8](https://testnet.plasmascan.to/address/0xa5471946F66c8eaFFa101feF465B912C0255D1f8)
- Internal Bribe: [0x17a7be2A7Ea0dcea799EA6f8d37FEE33Ff52636A](https://testnet.plasmascan.to/address/0x17a7be2A7Ea0dcea799EA6f8d37FEE33Ff52636A)
- External Bribe: [0x2E3a318e5289f5C6f94A822c779d91D58c907fb4](https://testnet.plasmascan.to/address/0x2E3a318e5289f5C6f94A822c779d91D58c907fb4)
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

- [ ] Import RouterV2 ABI and connect to `0xb7Be9aB86d1A18c0425C3f6ABbbD58d0Ef19f1a9`
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

- [ ] Import GlobalRouter ABI and connect to `0x88C19a127aa22C7826546F34E63FE0e8995c88d0`
- [ ] Implement token approval flows before liquidity/swap operations
- [ ] Add slippage tolerance settings (recommend 0.5% for stable, 2% for volatile)
- [ ] Implement deadline parameter (recommend current timestamp + 20 minutes)
- [ ] Handle both stable and volatile pool routing
- [ ] Add support for XPL (native token) operations via `*ETH` functions
- [ ] Implement price impact warnings for large trades
- [ ] Add liquidity preview using `quoteAddLiquidity`

### Voting Escrow (veNFT) Features

- [ ] Import VotingEscrow ABI and connect to `0x516C42d4BcF32531Cb7cf5Eb89Bb8870A4a60011`
- [ ] Import Lithos token ABI and connect to `0x3a6a2309Bc05b9798CF46699Bba9F6536039B72D`
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

## Subgraph Deployment

Deploy the subgraph to index blockchain data using Goldsky CLI:

### Prerequisites

1. **Install Goldsky CLI** (if not already installed):

   ```shell
   npm install -g @goldsky/cli
   ```

2. **Login to Goldsky** (if not already logged in):
   ```shell
   goldsky login
   ```
   Use the shared API key provided by the team.

### Deployment Steps

1. **Navigate to subgraph directory:**

   ```shell
   cd subgraph
   ```

2. **Generate types from schema:**

   ```shell
   yarn codegen
   ```

3. **Build the subgraph:**

   ```shell
   yarn build
   ```

4. **Deploy to Goldsky:**
   ```shell
   goldsky subgraph deploy <subgraph-name>/<version> --path .
   ```

### Example Deployment Commands

**For mainnet:**

```shell
cd subgraph
yarn codegen
yarn build
goldsky subgraph deploy lithos-subgraph-mainnet/v1.0.0 --path .
```

### Additional Goldsky Commands

**List deployed subgraphs:**

```shell
goldsky subgraph list
```

**Get subgraph info:**

```shell
goldsky subgraph info <subgraph-name>/<version>
```

**Delete a subgraph:**

```shell
goldsky subgraph delete <subgraph-name>/<version>
```

> **Note:** Ensure your `subgraph.yaml` manifest has the correct contract addresses from your deployment state file before deploying.
