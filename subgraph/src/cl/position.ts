import { Address, BigInt, BigDecimal, Bytes, log } from "@graphprotocol/graph-ts"
import {
  IncreaseLiquidity,
  DecreaseLiquidity,
  Collect,
  Transfer,
  NonfungiblePositionManager
} from "../../generated/NonfungiblePositionManager/NonfungiblePositionManager"
import { AlgebraPool as AlgebraPoolTemplate } from "../../generated/templates"
import { CLPosition, CLPositionEvent, CLPool, User, Token } from "../../generated/schema"
import { 
  ZERO_BI, 
  ZERO_BD, 
  ONE_BI,
  createUser, 
  getOrCreateToken, 
  convertTokenToDecimal,
  getTrackedVolumeUSD,
  getTrackedLiquidityUSD
} from "../helpers"

// NFPM contract address
const NFPM_ADDRESS = "0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F"
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

/**
 * Get or create a CL Position entity
 */
function getOrCreateCLPosition(
  tokenId: BigInt,
  nfpmAddress: Address,
  event_timestamp: BigInt,
  event_blockNumber: BigInt
): CLPosition | null {
  let id = tokenId.toString()
  let position = CLPosition.load(id)
  
  if (position === null) {
    // Fetch position data from NFPM contract
    let nfpmContract = NonfungiblePositionManager.bind(nfpmAddress)
    let positionResult = nfpmContract.try_positions(tokenId)
    
    if (positionResult.reverted) {
      log.warning("Failed to fetch position data for tokenId {}", [tokenId.toString()])
      return null
    }
    
    let positionData = positionResult.value
    
    // Get owner
    let ownerResult = nfpmContract.try_ownerOf(tokenId)
    if (ownerResult.reverted) {
      log.warning("Failed to fetch owner for tokenId {}", [tokenId.toString()])
      return null
    }
    
    let owner = createUser(ownerResult.value)
    
    // Get tokens
    let token0 = getOrCreateToken(positionData.getToken0())
    let token1 = getOrCreateToken(positionData.getToken1())
    
    // Find pool - we need the actual pool address, not token-based lookup
    // For now, return null and let the event handler create it with pool address from event
    // This function is called when position doesn't exist yet, so we'll create it in handleIncreaseLiquidity
    return null
    
    // Create new position
    position = new CLPosition(id)
    position.tokenId = tokenId
    position.owner = owner.id
    position.pool = pool.id
    position.token0 = token0.id
    position.token1 = token1.id
    position.tickLower = positionData.getTickLower()
    position.tickUpper = positionData.getTickUpper()
    position.liquidity = positionData.getLiquidity()
    position.feeGrowthInside0LastX128 = positionData.getFeeGrowthInside0LastX128()
    position.feeGrowthInside1LastX128 = positionData.getFeeGrowthInside1LastX128()
    position.tokensOwed0 = positionData.getTokensOwed0()
    position.tokensOwed1 = positionData.getTokensOwed1()
    position.depositedToken0 = ZERO_BD
    position.depositedToken1 = ZERO_BD
    position.depositedUSD = ZERO_BD
    position.collectedToken0 = ZERO_BD
    position.collectedToken1 = ZERO_BD
    position.collectedUSD = ZERO_BD
    position.isActive = true
    position.createdAtTimestamp = event_timestamp
    position.createdAtBlockNumber = event_blockNumber
    position.lastUpdateTimestamp = event_timestamp
    position.lastUpdateBlockNumber = event_blockNumber
  }
  
  return position
}

/**
 * Find pool address from token addresses
 * Pool ID is typically stored as the pool contract address
 */
function findPoolForTokens(token0: Address, token1: Address): string {
  // The pool address should already exist in CLPool entities
  // We need to search for a pool with these tokens
  // In practice, the IncreaseLiquidity event includes the pool address
  // For now, we'll construct a lookup key
  
  // Pool ID format is typically the pool contract address
  // We may need to query all pools or use a different approach
  // For simplicity, construct from token addresses (sorted)
  let t0 = token0.toHexString()
  let t1 = token1.toHexString()
  
  // Pools are indexed by their contract address, not token combination
  // This is a placeholder - the actual pool address should come from the event
  // or be looked up from the AlgebraFactory
  return t0.concat("-").concat(t1)
}

/**
 * Update position value (deposited amounts) based on current state
 */
function updatePositionValue(position: CLPosition): void {
  let pool = CLPool.load(position.pool)
  if (pool === null) return
  
  let token0 = Token.load(position.token0)
  let token1 = Token.load(position.token1)
  if (token0 === null || token1 === null) return
  
  // Calculate token amounts from liquidity
  // This requires sqrtPriceX96 and tick calculations
  // For now, track deposited amounts from events
  
  // Calculate USD value
  position.depositedUSD = getTrackedVolumeUSD(
    position.depositedToken0,
    token0,
    position.depositedToken1,
    token1
  )
}

/**
 * Fetch and update tokensOwed from contract
 */
function updateTokensOwed(position: CLPosition, nfpmAddress: Address): void {
  let nfpmContract = NonfungiblePositionManager.bind(nfpmAddress)
  let positionResult = nfpmContract.try_positions(position.tokenId)
  
  if (!positionResult.reverted) {
    let positionData = positionResult.value
    position.tokensOwed0 = positionData.getTokensOwed0()
    position.tokensOwed1 = positionData.getTokensOwed1()
    position.feeGrowthInside0LastX128 = positionData.getFeeGrowthInside0LastX128()
    position.feeGrowthInside1LastX128 = positionData.getFeeGrowthInside1LastX128()
    position.liquidity = positionData.getLiquidity()
  }
}

/**
 * Create position event record
 */
function createPositionEvent(
  position: CLPosition,
  eventType: string,
  amount0: BigDecimal | null,
  amount1: BigDecimal | null,
  liquidity: BigInt | null,
  recipient: Address | null,
  txHash: string,
  timestamp: BigInt,
  blockNumber: BigInt
): void {
  let id = txHash.concat("-").concat(position.tokenId.toString())
  let event = new CLPositionEvent(id)
  event.transaction = Bytes.fromHexString(txHash)
  event.timestamp = timestamp
  event.blockNumber = blockNumber
  event.position = position.id
  event.eventType = eventType
  event.amount0 = amount0
  event.amount1 = amount1
  event.liquidity = liquidity
  event.recipient = recipient
  event.save()
}

/**
 * Handle IncreaseLiquidity event
 * Emitted when liquidity is added to a position
 */
export function handleIncreaseLiquidity(event: IncreaseLiquidity): void {
  let tokenId = event.params.tokenId
  let poolAddress = event.params.pool
  
  // Get or create position
  let position = getOrCreateCLPosition(
    tokenId,
    event.address,
    event.block.timestamp,
    event.block.number
  )
  
  if (position === null) {
    // Try to create position with pool address from event
    let id = tokenId.toString()
    let nfpmContract = NonfungiblePositionManager.bind(event.address)
    let positionResult = nfpmContract.try_positions(tokenId)
    
    if (positionResult.reverted) {
      log.warning("IncreaseLiquidity: Failed to fetch position {}", [id])
      return
    }
    
    let positionData = positionResult.value
    let ownerResult = nfpmContract.try_ownerOf(tokenId)
    if (ownerResult.reverted) return
    
    let owner = createUser(ownerResult.value)
    let token0 = getOrCreateToken(positionData.getToken0())
    let token1 = getOrCreateToken(positionData.getToken1())
    
    // Check if pool exists, create if it doesn't
    let pool = CLPool.load(poolAddress.toHexString())
    if (pool === null) {
      // Pool doesn't exist - create it from on-chain data
      log.warning("IncreaseLiquidity: Pool {} not found, creating from on-chain data", [poolAddress.toHexString()])
  
      let token0 = positionData.getToken0()
      let token1 = positionData.getToken1()
      
      // Create pool entity
      pool = new CLPool(poolAddress.toHexString())
      pool.factory = Address.zero() // Unknown factory, set to zero
      pool.token0 = token0.toString()
      pool.token1 = token1.toString()
      pool.liquidity = ZERO_BI
      pool.sqrtPriceX96 = ZERO_BI
      pool.tick = ZERO_BI
      pool.volumeToken0 = ZERO_BD
      pool.volumeToken1 = ZERO_BD
      pool.volumeUSD = ZERO_BD
      pool.token0Price = ZERO_BD
      pool.token1Price = ZERO_BD
      pool.feeGrowthGlobal0X128 = ZERO_BI
      pool.feeGrowthGlobal1X128 = ZERO_BI
      pool.feesToken0 = ZERO_BD
      pool.feesToken1 = ZERO_BD
      pool.feesUSD = ZERO_BD
      pool.txCount = ZERO_BI
      pool.createdAtTimestamp = event.block.timestamp
      pool.createdAtBlockNumber = event.block.number
      pool.lastUpdateTimestamp = event.block.timestamp
      pool.lastUpdateBlockNumber = event.block.number
      pool.save()
      
      // Create AlgebraPool template to track pool events (Swap, Mint, Burn, Initialize)
      AlgebraPoolTemplate.create(poolAddress)
      
      log.info("IncreaseLiquidity: Created pool {} from on-chain data and started tracking", [poolAddress.toHexString()])
    }
    
    position = new CLPosition(id)
    position.tokenId = tokenId
    position.owner = owner.id
    position.pool = pool.id
    position.token0 = token0.id
    position.token1 = token1.id
    position.tickLower = positionData.getTickLower()
    position.tickUpper = positionData.getTickUpper()
    position.liquidity = ZERO_BI
    position.feeGrowthInside0LastX128 = ZERO_BI
    position.feeGrowthInside1LastX128 = ZERO_BI
    position.tokensOwed0 = ZERO_BI
    position.tokensOwed1 = ZERO_BI
    position.depositedToken0 = ZERO_BD
    position.depositedToken1 = ZERO_BD
    position.depositedUSD = ZERO_BD
    position.collectedToken0 = ZERO_BD
    position.collectedToken1 = ZERO_BD
    position.collectedUSD = ZERO_BD
    position.isActive = true
    position.createdAtTimestamp = event.block.timestamp
    position.createdAtBlockNumber = event.block.number
    position.lastUpdateTimestamp = event.block.timestamp
    position.lastUpdateBlockNumber = event.block.number
  }
  
  // Update position liquidity
  position.liquidity = position.liquidity.plus(event.params.actualLiquidity)
  
  // Track deposited amounts
  let token0 = Token.load(position.token0)
  let token1 = Token.load(position.token1)
  
  if (token0 !== null && token1 !== null) {
    let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals)
    let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals)
    
    position.depositedToken0 = position.depositedToken0.plus(amount0)
    position.depositedToken1 = position.depositedToken1.plus(amount1)
    
    // Update USD value
    position.depositedUSD = getTrackedVolumeUSD(
      position.depositedToken0,
      token0,
      position.depositedToken1,
      token1
    )
    
    // Create event record
    createPositionEvent(
      position,
      "increase",
      amount0,
      amount1,
      event.params.actualLiquidity,
      null,
      event.transaction.hash.toHexString(),
      event.block.timestamp,
      event.block.number
    )
  }
  
  // Fetch latest tokensOwed from contract
  updateTokensOwed(position, event.address)
  
  position.lastUpdateTimestamp = event.block.timestamp
  position.lastUpdateBlockNumber = event.block.number
  position.save()
  
  log.info("IncreaseLiquidity: Position {} updated, liquidity={}", [
    position.id,
    position.liquidity.toString()
  ])
}

/**
 * Handle DecreaseLiquidity event
 * Emitted when liquidity is removed from a position
 */
export function handleDecreaseLiquidity(event: DecreaseLiquidity): void {
  let tokenId = event.params.tokenId
  let position = CLPosition.load(tokenId.toString())
  
  if (position === null) {
    log.warning("DecreaseLiquidity: Position {} not found", [tokenId.toString()])
    return
  }
  
  // Update position liquidity
  position.liquidity = position.liquidity.minus(event.params.liquidity)
  
  // Track withdrawn amounts
  let token0 = Token.load(position.token0)
  let token1 = Token.load(position.token1)
  
  if (token0 !== null && token1 !== null) {
    let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals)
    let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals)
    
    // Decrease deposited amounts
    position.depositedToken0 = position.depositedToken0.minus(amount0)
    position.depositedToken1 = position.depositedToken1.minus(amount1)
    
    // Ensure no negative values
    if (position.depositedToken0.lt(ZERO_BD)) {
      position.depositedToken0 = ZERO_BD
    }
    if (position.depositedToken1.lt(ZERO_BD)) {
      position.depositedToken1 = ZERO_BD
    }
    
    // Update USD value
    position.depositedUSD = getTrackedVolumeUSD(
      position.depositedToken0,
      token0,
      position.depositedToken1,
      token1
    )
    
    // Create event record
    createPositionEvent(
      position,
      "decrease",
      amount0,
      amount1,
      event.params.liquidity,
      null,
      event.transaction.hash.toHexString(),
      event.block.timestamp,
      event.block.number
    )
  }
  
  // Fetch latest tokensOwed from contract
  updateTokensOwed(position, event.address)
  
  // Mark as inactive if liquidity is 0
  if (position.liquidity.equals(ZERO_BI)) {
    position.isActive = false
  }
  
  position.lastUpdateTimestamp = event.block.timestamp
  position.lastUpdateBlockNumber = event.block.number
  position.save()
  
  log.info("DecreaseLiquidity: Position {} updated, liquidity={}", [
    position.id,
    position.liquidity.toString()
  ])
}

/**
 * Handle Collect event
 * Emitted when fees are collected from a position
 */
export function handleCollect(event: Collect): void {
  let tokenId = event.params.tokenId
  let position = CLPosition.load(tokenId.toString())
  
  if (position === null) {
    log.warning("Collect: Position {} not found", [tokenId.toString()])
    return
  }
  
  // Track collected fees
  let token0 = Token.load(position.token0)
  let token1 = Token.load(position.token1)
  
  if (token0 !== null && token1 !== null) {
    let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals)
    let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals)
    
    position.collectedToken0 = position.collectedToken0.plus(amount0)
    position.collectedToken1 = position.collectedToken1.plus(amount1)
    
    // Update collected USD
    position.collectedUSD = getTrackedVolumeUSD(
      position.collectedToken0,
      token0,
      position.collectedToken1,
      token1
    )
    
    // Create event record
    createPositionEvent(
      position,
      "collect",
      amount0,
      amount1,
      null,
      event.params.recipient,
      event.transaction.hash.toHexString(),
      event.block.timestamp,
      event.block.number
    )
  }
  
  // Fetch latest tokensOwed from contract (should be reduced after collect)
  updateTokensOwed(position, event.address)
  
  position.lastUpdateTimestamp = event.block.timestamp
  position.lastUpdateBlockNumber = event.block.number
  position.save()
  
  log.info("Collect: Position {} collected fees, amount0={}, amount1={}", [
    position.id,
    event.params.amount0.toString(),
    event.params.amount1.toString()
  ])
}

/**
 * Handle Transfer event
 * Emitted when position NFT ownership changes
 */
export function handleTransfer(event: Transfer): void {
  let tokenId = event.params.tokenId
  let from = event.params.from.toHexString()
  let to = event.params.to.toHexString()
  
  // Mint (from == 0x0)
  if (from == ZERO_ADDRESS) {
    // Position will be created in IncreaseLiquidity handler
    log.info("Transfer: Mint position {}", [tokenId.toString()])
    return
  }
  
  // Burn (to == 0x0)
  if (to == ZERO_ADDRESS) {
    let position = CLPosition.load(tokenId.toString())
    if (position !== null) {
      position.isActive = false
      position.lastUpdateTimestamp = event.block.timestamp
      position.lastUpdateBlockNumber = event.block.number
      position.save()
      
      // Create event record
      createPositionEvent(
        position,
        "burn",
        null,
        null,
        null,
        event.params.to,
        event.transaction.hash.toHexString(),
        event.block.timestamp,
        event.block.number
      )
    }
    log.info("Transfer: Burn position {}", [tokenId.toString()])
    return
  }
  
  // Normal transfer
  let position = CLPosition.load(tokenId.toString())
  if (position === null) {
    log.warning("Transfer: Position {} not found", [tokenId.toString()])
    return
  }
  
  // Update owner
  let newOwner = createUser(event.params.to)
  position.owner = newOwner.id
  position.lastUpdateTimestamp = event.block.timestamp
  position.lastUpdateBlockNumber = event.block.number
  position.save()
  
  // Create event record
  createPositionEvent(
    position,
    "transfer",
    null,
    null,
    null,
    event.params.to,
    event.transaction.hash.toHexString(),
    event.block.timestamp,
    event.block.number
  )
  
  log.info("Transfer: Position {} transferred from {} to {}", [
    tokenId.toString(),
    from,
    to
  ])
}
