import { Address, BigDecimal, BigInt } from "@graphprotocol/graph-ts"
import {
  Burn,
  Initialize,
  Mint,
  Swap,
  AlgebraPool as AlgebraPoolContract
} from "../../generated/templates/AlgebraPool/AlgebraPool"
import { CLPool, CLPoolEpochData, Token } from "../../generated/schema"
import {
  convertTokenToDecimal,
  getTrackedVolumeUSD,
  ONE_BD,
  ONE_BI,
  ZERO_BD,
  ZERO_BI,
  exponentToBigDecimal,
  getEpoch
} from "../helpers"

const Q192_BD = BigInt.fromI32(2).pow(192).toBigDecimal()
const Q128_BD = BigInt.fromI32(2).pow(128).toBigDecimal()

function refreshPoolState(entity: CLPool, poolAddress: Address, timestamp: BigInt, blockNumber: BigInt): void {
  let poolContract = AlgebraPoolContract.bind(poolAddress)

  let liquidityCall = poolContract.try_liquidity()
  if (!liquidityCall.reverted) {
    entity.liquidity = liquidityCall.value
  }

  let slot0Call = poolContract.try_slot0()
  if (!slot0Call.reverted) {
    let slot0 = slot0Call.value
    entity.sqrtPriceX96 = slot0.sqrtPriceX96
    entity.tick = BigInt.fromI32(slot0.tick)
  }

  updateFeeAccrual(entity, poolAddress, timestamp, blockNumber)
  updateDerivedPrices(entity)
}

function updateTimestamps(entity: CLPool, blockNumber: BigInt, timestamp: BigInt): void {
  entity.lastUpdateBlockNumber = blockNumber
  entity.lastUpdateTimestamp = timestamp
}

function updateDerivedPrices(entity: CLPool): void {
  let token0 = Token.load(entity.token0)
  let token1 = Token.load(entity.token1)
  if (token0 === null || token1 === null) {
    entity.token0Price = ZERO_BD
    entity.token1Price = ZERO_BD
    return
  }

  if (entity.sqrtPriceX96.equals(ZERO_BI)) {
    entity.token0Price = ZERO_BD
    entity.token1Price = ZERO_BD
    return
  }

  let sqrtPrice = entity.sqrtPriceX96.toBigDecimal()
  let priceRatio = sqrtPrice.times(sqrtPrice).div(Q192_BD)

  let decimal0 = exponentToBigDecimal(token0.decimals)
  let decimal1 = exponentToBigDecimal(token1.decimals)
  if (decimal0.equals(ZERO_BD) || decimal1.equals(ZERO_BD)) {
    entity.token0Price = ZERO_BD
    entity.token1Price = ZERO_BD
    return
  }

  let price0 = priceRatio.times(decimal1).div(decimal0)
  entity.token0Price = price0
  if (price0.equals(ZERO_BD)) {
    entity.token1Price = ZERO_BD
  } else {
    entity.token1Price = ONE_BD.div(price0)
  }
}

function updateFeeAccrual(entity: CLPool, poolAddress: Address, timestamp: BigInt, blockNumber: BigInt): void {
  let token0 = Token.load(entity.token0)
  let token1 = Token.load(entity.token1)
  if (token0 === null || token1 === null) {
    return
  }

  let poolContract = AlgebraPoolContract.bind(poolAddress)
  let fee0Call = poolContract.try_feeGrowthGlobal0X128()
  let fee1Call = poolContract.try_feeGrowthGlobal1X128()
  if (fee0Call.reverted || fee1Call.reverted) {
    return
  }

  let nextFeeGrowth0 = fee0Call.value
  let nextFeeGrowth1 = fee1Call.value

  let delta0 = nextFeeGrowth0.minus(entity.feeGrowthGlobal0X128)
  let delta1 = nextFeeGrowth1.minus(entity.feeGrowthGlobal1X128)

  if (delta0.gt(ZERO_BI) || delta1.gt(ZERO_BI)) {
    let liquidityDecimal = entity.liquidity.toBigDecimal()

    if (!liquidityDecimal.equals(ZERO_BD)) {
      let fee0Raw = ZERO_BD
      let fee1Raw = ZERO_BD

      if (delta0.gt(ZERO_BI)) {
        fee0Raw = delta0.toBigDecimal().times(liquidityDecimal).div(Q128_BD)
      }

      if (delta1.gt(ZERO_BI)) {
        fee1Raw = delta1.toBigDecimal().times(liquidityDecimal).div(Q128_BD)
      }

      let decimal0 = exponentToBigDecimal(token0.decimals)
      let decimal1 = exponentToBigDecimal(token1.decimals)

      let fee0Amount = decimal0.equals(ZERO_BD) ? ZERO_BD : fee0Raw.div(decimal0)
      let fee1Amount = decimal1.equals(ZERO_BD) ? ZERO_BD : fee1Raw.div(decimal1)

      entity.feesToken0 = entity.feesToken0.plus(fee0Amount)
      entity.feesToken1 = entity.feesToken1.plus(fee1Amount)

      let feeUSD = getTrackedVolumeUSD(fee0Amount, token0, fee1Amount, token1)
      entity.feesUSD = entity.feesUSD.plus(feeUSD)
      updateEpoch(
        entity,
        token0,
        token1,
        fee0Amount,
        fee1Amount,
        feeUSD,
        ZERO_BD,
        ZERO_BD,
        ZERO_BD,
        timestamp,
        blockNumber
      )
    }
  }

  entity.feeGrowthGlobal0X128 = nextFeeGrowth0
  entity.feeGrowthGlobal1X128 = nextFeeGrowth1
}

export function handleInitialize(event: Initialize): void {
  let poolId = event.address.toHexString()
  let entity = CLPool.load(poolId)
  if (entity === null) {
    return
  }

  entity.sqrtPriceX96 = event.params.sqrtPriceX96
  entity.tick = BigInt.fromI32(event.params.tick)
  updateFeeAccrual(entity, event.address, event.block.timestamp, event.block.number)
  updateDerivedPrices(entity)
  updateTimestamps(entity, event.block.number, event.block.timestamp)
  entity.save()
}

export function handleMint(event: Mint): void {
  let poolId = event.address.toHexString()
  let entity = CLPool.load(poolId)
  if (entity === null) {
    return
  }

  refreshPoolState(entity, event.address, event.block.timestamp, event.block.number)
  updateTimestamps(entity, event.block.number, event.block.timestamp)
  entity.save()
}

export function handleBurn(event: Burn): void {
  let poolId = event.address.toHexString()
  let entity = CLPool.load(poolId)
  if (entity === null) {
    return
  }

  refreshPoolState(entity, event.address, event.block.timestamp, event.block.number)
  updateTimestamps(entity, event.block.number, event.block.timestamp)
  entity.save()
}

export function handleSwap(event: Swap): void {
  let poolId = event.address.toHexString()
  let entity = CLPool.load(poolId)
  if (entity === null) {
    return
  }

  let token0 = Token.load(entity.token0)
  let token1 = Token.load(entity.token1)
  if (token0 === null || token1 === null) {
    return
  }

  let amount0Abs = event.params.amount0.abs()
  let amount1Abs = event.params.amount1.abs()

  let amount0 = convertTokenToDecimal(amount0Abs, token0.decimals)
  let amount1 = convertTokenToDecimal(amount1Abs, token1.decimals)

  entity.volumeToken0 = entity.volumeToken0.plus(amount0)
  entity.volumeToken1 = entity.volumeToken1.plus(amount1)
  let trackedUSD = getTrackedVolumeUSD(amount0, token0, amount1, token1)
  entity.volumeUSD = entity.volumeUSD.plus(trackedUSD)
  entity.txCount = entity.txCount.plus(ONE_BI)

  updateEpoch(
    entity,
    token0,
    token1,
    ZERO_BD,
    ZERO_BD,
    ZERO_BD,
    amount0,
    amount1,
    trackedUSD,
    event.block.timestamp,
    event.block.number
  )

  // Update pool state from event data
  entity.sqrtPriceX96 = event.params.sqrtPriceX96
  entity.tick = BigInt.fromI32(event.params.tick)
  entity.liquidity = event.params.liquidity
  updateFeeAccrual(entity, event.address, event.block.timestamp, event.block.number)
  updateDerivedPrices(entity)

  updateTimestamps(entity, event.block.number, event.block.timestamp)
  entity.save()
}

function updateEpoch(
  pool: CLPool,
  token0: Token,
  token1: Token,
  fee0: BigDecimal,
  fee1: BigDecimal,
  feeUSD: BigDecimal,
  volume0: BigDecimal,
  volume1: BigDecimal,
  volumeUSD: BigDecimal,
  timestamp: BigInt,
  blockNumber: BigInt
): void {
  let epoch = getEpoch(timestamp)
  let epochId = pool.id.concat("-").concat(epoch.toString())
  let entity = CLPoolEpochData.load(epochId)
  if (entity === null) {
    entity = new CLPoolEpochData(epochId)
    entity.pool = pool.id
    entity.token0 = token0.id
    entity.token1 = token1.id
    entity.epoch = epoch
    entity.epochStart = epoch
    entity.epochEnd = epoch.plus(BigInt.fromI32(7 * 86400))
    entity.feesToken0 = ZERO_BD
    entity.feesToken1 = ZERO_BD
    entity.feesUSD = ZERO_BD
    entity.volumeToken0 = ZERO_BD
    entity.volumeToken1 = ZERO_BD
    entity.volumeUSD = ZERO_BD
    entity.updatedAtTimestamp = timestamp
    entity.updatedAtBlockNumber = blockNumber
  }

  entity.feesToken0 = entity.feesToken0.plus(fee0)
  entity.feesToken1 = entity.feesToken1.plus(fee1)
  entity.feesUSD = entity.feesUSD.plus(feeUSD)
  entity.volumeToken0 = entity.volumeToken0.plus(volume0)
  entity.volumeToken1 = entity.volumeToken1.plus(volume1)
  entity.volumeUSD = entity.volumeUSD.plus(volumeUSD)
  entity.updatedAtTimestamp = timestamp
  entity.updatedAtBlockNumber = blockNumber
  entity.save()
}
