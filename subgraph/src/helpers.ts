import { BigDecimal, BigInt, Address, ethereum } from "@graphprotocol/graph-ts"
import { 
  User, 
  LiquidityPosition, 
  Transaction,
  Bundle,
  Token,
  Pair,
  Factory
} from "../generated/schema"
import { ERC20 } from "../generated/RouterV2/ERC20"

export let ZERO_BI = BigInt.fromI32(0)
export let ONE_BI = BigInt.fromI32(1)
export let ZERO_BD = BigDecimal.fromString("0")
export let ONE_BD = BigDecimal.fromString("1")
export let BI_18 = BigInt.fromI32(18)

// Export aliases for VotingEscrow handlers
export let BI_ZERO = ZERO_BI
export let BI_ONE = ONE_BI
export let ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

// Common contract addresses (update these with actual addresses)
export let FACTORY_ADDRESS = "0x0000000000000000000000000000000000000000" // Replace with actual factory
export let WETH_ADDRESS = "0x0000000000000000000000000000000000000000" // Replace with actual WETH
export let USDC_ADDRESS = "0x0000000000000000000000000000000000000000" // Replace with actual USDC
export let USDT_ADDRESS = "0x0000000000000000000000000000000000000000" // Replace with actual USDT

// Create or load user
export function createUser(address: Address): User {
  let user = User.load(address.toHexString())
  if (user === null) {
    user = new User(address.toHexString())
    user.usdSwapped = ZERO_BD
    // Initialize VotingEscrow fields
    user.veNFTCount = ZERO_BI
    user.totalLocked = ZERO_BD
    user.delegatedTo = null
    user.delegatedVotingPower = ZERO_BI
    user.save()
  }
  return user as User
}

// Create or load token
export function getOrCreateToken(address: Address): Token {
  let token = Token.load(address.toHexString())
  if (token === null) {
    token = new Token(address.toHexString())
    token.symbol = "UNKNOWN"
    token.name = "Unknown Token"
    token.decimals = BigInt.fromI32(18) // Default to 18 decimals
    token.derivedETH = ZERO_BD
    token.tradeVolume = ZERO_BD
    token.tradeVolumeUSD = ZERO_BD
    token.totalLiquidity = ZERO_BD
    token.txCount = ZERO_BI
    
    // Try to get token info from contract
    if (!address.equals(Address.zero())) {
      let contract = ERC20.bind(address)
      
      let symbolResult = contract.try_symbol()
      if (!symbolResult.reverted) {
        token.symbol = symbolResult.value
      }
      
      let decimalsResult = contract.try_decimals()
      if (!decimalsResult.reverted) {
        token.decimals = BigInt.fromI32(decimalsResult.value)
      }
    }
    
    token.save()
  }
  return token as Token
}

// Create or load liquidity position
export function createLiquidityPosition(user: Address, pair: Address): LiquidityPosition {
  let id = user.toHexString().concat("-").concat(pair.toHexString())
  let liquidityPosition = LiquidityPosition.load(id)
  
  if (liquidityPosition === null) {
    let pairEntity = Pair.load(pair.toHexString())
    liquidityPosition = new LiquidityPosition(id)
    liquidityPosition.liquidityTokenBalance = ZERO_BD
    liquidityPosition.user = user.toHexString()
    liquidityPosition.pair = pair.toHexString()
    liquidityPosition.supplyIndex0 = ZERO_BD
    liquidityPosition.supplyIndex1 = ZERO_BD
    liquidityPosition.claimable0 = ZERO_BD
    liquidityPosition.claimable1 = ZERO_BD
    liquidityPosition.save()
  }
  
  return liquidityPosition as LiquidityPosition
}

// Create transaction entity
export function createTransaction(event: ethereum.Event): Transaction {
  let transaction = Transaction.load(event.transaction.hash.toHexString())
  if (transaction === null) {
    transaction = new Transaction(event.transaction.hash.toHexString())
    transaction.blockNumber = event.block.number
    transaction.timestamp = event.block.timestamp
    transaction.gasUsed = event.receipt ? event.receipt!.gasUsed : BigInt.fromI32(0)
    transaction.gasPrice = event.transaction.gasPrice
    transaction.save()
  }
  return transaction as Transaction
}

// Convert token amount to decimal based on token decimals
export function convertTokenToDecimal(tokenAmount: BigInt, exchangeDecimals: BigInt): BigDecimal {
  if (exchangeDecimals == ZERO_BI) {
    return tokenAmount.toBigDecimal()
  }
  return tokenAmount.toBigDecimal().div(exponentToBigDecimal(exchangeDecimals))
}

// Get token decimals
export function fetchTokenDecimals(tokenAddress: Address): BigInt {
  let token = Token.load(tokenAddress.toHexString())
  if (token !== null) {
    return token.decimals
  }
  return BigInt.fromI32(18) // Default to 18 decimals
}

// Convert BigInt exponent to BigDecimal
export function exponentToBigDecimal(decimals: BigInt): BigDecimal {
  let bd = BigDecimal.fromString("1")
  for (let i = ZERO_BI; i.lt(decimals); i = i.plus(ONE_BI)) {
    bd = bd.times(BigDecimal.fromString("10"))
  }
  return bd
}

// Get ETH price in USD
export function getEthPriceInUSD(): BigDecimal {
  let bundle = Bundle.load("1")
  if (bundle !== null) {
    return bundle.ethPrice
  }
  return BigDecimal.fromString("2000") // Default ETH price
}

// Find ETH per token
export function findEthPerToken(token: Token): BigDecimal {
  if (token.id == WETH_ADDRESS) {
    return ONE_BD
  }
  
  // Add logic to find ETH price through pairs
  // This would involve finding the most liquid WETH pair for this token
  
  return ZERO_BD
}

// Get tracked volume USD
export function getTrackedVolumeUSD(
  tokenAmount0: BigDecimal,
  token0: Token,
  tokenAmount1: BigDecimal,
  token1: Token
): BigDecimal {
  let bundle = Bundle.load("1")
  let price0 = token0.derivedETH.times(bundle!.ethPrice)
  let price1 = token1.derivedETH.times(bundle!.ethPrice)

  // Take average of two amounts
  if (price0.notEqual(ZERO_BD) && price1.notEqual(ZERO_BD)) {
    return tokenAmount0.times(price0).plus(tokenAmount1.times(price1)).div(BigDecimal.fromString("2"))
  }

  // Take volume from token with price
  if (price0.notEqual(ZERO_BD)) {
    return tokenAmount0.times(price0)
  }

  if (price1.notEqual(ZERO_BD)) {
    return tokenAmount1.times(price1)
  }

  return ZERO_BD
}

// Get tracked liquidity USD
export function getTrackedLiquidityUSD(
  tokenAmount0: BigDecimal,
  token0: Token,
  tokenAmount1: BigDecimal,
  token1: Token
): BigDecimal {
  let bundle = Bundle.load("1")
  let price0 = token0.derivedETH.times(bundle!.ethPrice)
  let price1 = token1.derivedETH.times(bundle!.ethPrice)

  // Both tokens have USD price
  if (price0.notEqual(ZERO_BD) && price1.notEqual(ZERO_BD)) {
    return tokenAmount0.times(price0).plus(tokenAmount1.times(price1))
  }

  // Take double value of the token with price
  if (price0.notEqual(ZERO_BD)) {
    return tokenAmount0.times(price0).times(BigDecimal.fromString("2"))
  }

  if (price1.notEqual(ZERO_BD)) {
    return tokenAmount1.times(price1).times(BigDecimal.fromString("2"))
  }

  return ZERO_BD
}

// Update pair hour data
export function updatePairHourData(event: ethereum.Event): void {
  // Implementation for hour data tracking
}

// Update pair day data  
export function updatePairDayData(event: ethereum.Event): void {
  // Implementation for day data tracking
}

// Update token day data
export function updateTokenDayData(token: Token, event: ethereum.Event): void {
  // Implementation for token day data tracking
}

// Update Plasma DEX day data
export function updatePlasmaDayData(event: ethereum.Event): void {
  // Implementation for protocol day data tracking
}