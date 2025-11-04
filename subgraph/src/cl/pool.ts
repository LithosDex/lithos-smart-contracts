import { Address, BigInt } from "@graphprotocol/graph-ts"
import {
  Burn,
  Initialize,
  Mint,
  Swap,
  AlgebraPool as AlgebraPoolContract
} from "../../generated/templates/AlgebraPool/AlgebraPool"
import { CLPool, Token } from "../../generated/schema"
import {
  convertTokenToDecimal,
  getTrackedVolumeUSD,
  ONE_BI
} from "../helpers"

function refreshPoolState(entity: CLPool, poolAddress: Address): void {
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
}

function updateTimestamps(entity: CLPool, blockNumber: BigInt, timestamp: BigInt): void {
  entity.lastUpdateBlockNumber = blockNumber
  entity.lastUpdateTimestamp = timestamp
}

export function handleInitialize(event: Initialize): void {
  let poolId = event.address.toHexString()
  let entity = CLPool.load(poolId)
  if (entity === null) {
    return
  }

  entity.sqrtPriceX96 = event.params.sqrtPriceX96
  entity.tick = BigInt.fromI32(event.params.tick)
  updateTimestamps(entity, event.block.number, event.block.timestamp)
  entity.save()
}

export function handleMint(event: Mint): void {
  let poolId = event.address.toHexString()
  let entity = CLPool.load(poolId)
  if (entity === null) {
    return
  }

  refreshPoolState(entity, event.address)
  updateTimestamps(entity, event.block.number, event.block.timestamp)
  entity.save()
}

export function handleBurn(event: Burn): void {
  let poolId = event.address.toHexString()
  let entity = CLPool.load(poolId)
  if (entity === null) {
    return
  }

  refreshPoolState(entity, event.address)
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

  // Update pool state from event data
  entity.sqrtPriceX96 = event.params.sqrtPriceX96
  entity.tick = BigInt.fromI32(event.params.tick)
  entity.liquidity = event.params.liquidity

  updateTimestamps(entity, event.block.number, event.block.timestamp)
  entity.save()
}
