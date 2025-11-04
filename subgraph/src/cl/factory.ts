import { Address } from "@graphprotocol/graph-ts"
import { Pool as PoolEvent } from "../../generated/AlgebraFactory/AlgebraFactory"
import { AlgebraPool as AlgebraPoolTemplate } from "../../generated/templates"
import { CLPool } from "../../generated/schema"
import { getOrCreateToken, ZERO_BD, ZERO_BI } from "../helpers"

export function handlePoolCreated(event: PoolEvent): void {
  let poolAddress = event.params.pool
  let poolId = poolAddress.toHexString()

  let entity = CLPool.load(poolId)
  if (entity !== null) {
    return
  }

  let token0 = getOrCreateToken(event.params.token0)
  let token1 = getOrCreateToken(event.params.token1)

  entity = new CLPool(poolId)
  entity.factory = event.address
  entity.token0 = token0.id
  entity.token1 = token1.id
  entity.liquidity = ZERO_BI
  entity.sqrtPriceX96 = ZERO_BI
  entity.tick = ZERO_BI
  entity.volumeToken0 = ZERO_BD
  entity.volumeToken1 = ZERO_BD
  entity.volumeUSD = ZERO_BD
  entity.txCount = ZERO_BI
  entity.createdAtTimestamp = event.block.timestamp
  entity.createdAtBlockNumber = event.block.number
  entity.lastUpdateTimestamp = event.block.timestamp
  entity.lastUpdateBlockNumber = event.block.number
  entity.save()

  AlgebraPoolTemplate.create(poolAddress)
}
