import { PairCreated } from "../generated/PairFactory/PairFactory"
import { Factory, Pair, Token, Bundle } from "../generated/schema"
import { Pair as PairTemplate } from "../generated/templates"
import { ERC20 } from "../generated/PairFactory/ERC20"
import { Pair as PairContract } from "../generated/PairFactory/Pair"
import { BigDecimal, BigInt, Address } from "@graphprotocol/graph-ts"
import { ZERO_BD, ZERO_BI, ONE_BI, createUser, createLiquidityPosition } from "./helpers"

export function handlePairCreated(event: PairCreated): void {
  // Load factory
  let factory = Factory.load("1")
  if (factory === null) {
    factory = new Factory("1")
    factory.pairCount = 0
    factory.totalVolumeUSD = ZERO_BD
    factory.totalVolumeETH = ZERO_BD
    factory.totalLiquidityUSD = ZERO_BD
    factory.totalLiquidityETH = ZERO_BD
    factory.txCount = ZERO_BI
    
    // Initialize fee settings (these should be fetched from contract)
    factory.stableFee = BigInt.fromI32(4)  // 0.04%
    factory.volatileFee = BigInt.fromI32(18) // 0.18%
    factory.stakingNFTFee = BigInt.fromI32(3000) // 30%
    factory.maxReferralFee = BigInt.fromI32(1200) // 12%
    
    factory.pauser = Address.fromString("0x0000000000000000000000000000000000000000")
    factory.feeManager = Address.fromString("0x0000000000000000000000000000000000000000")
    factory.dibs = null
    factory.stakingFeeHandler = null
    factory.isPaused = false
    
    // Create bundle for ETH price tracking
    let bundle = Bundle.load("1")
    if (bundle === null) {
      bundle = new Bundle("1")
      bundle.ethPrice = BigDecimal.fromString("2000") // Initialize with reasonable ETH price
      bundle.save()
    }
  }

  factory.pairCount = factory.pairCount + 1
  factory.save()

  // Create tokens if they don't exist
  let token0 = Token.load(event.params.token0.toHexString())
  if (token0 === null) {
    token0 = new Token(event.params.token0.toHexString())
    let token0Contract = ERC20.bind(event.params.token0)
    
    // Try to get token info, use defaults if contract calls fail
    token0.symbol = "TOKEN0"
    token0.name = "Token 0"
    token0.decimals = BigInt.fromI32(18)
    token0.derivedETH = ZERO_BD
    token0.tradeVolume = ZERO_BD
    token0.tradeVolumeUSD = ZERO_BD
    token0.totalLiquidity = ZERO_BD
    token0.txCount = ZERO_BI
    
    token0.save()
  }

  let token1 = Token.load(event.params.token1.toHexString())
  if (token1 === null) {
    token1 = new Token(event.params.token1.toHexString())
    let token1Contract = ERC20.bind(event.params.token1)
    
    // Try to get token info, use defaults if contract calls fail
    token1.symbol = "TOKEN1"
    token1.name = "Token 1"
    token1.decimals = BigInt.fromI32(18)
    token1.derivedETH = ZERO_BD
    token1.tradeVolume = ZERO_BD
    token1.tradeVolumeUSD = ZERO_BD
    token1.totalLiquidity = ZERO_BD
    token1.txCount = ZERO_BI
    
    token1.save()
  }

  // Create pair
  let pair = new Pair(event.params.pair.toHexString())
  pair.factory = factory.id
  pair.token0 = token0.id
  pair.token1 = token1.id
  pair.stable = event.params.stable
  
  pair.reserve0 = ZERO_BD
  pair.reserve1 = ZERO_BD
  pair.totalSupply = ZERO_BD
  pair.reserveETH = ZERO_BD
  pair.reserveUSD = ZERO_BD
  
  pair.reserve0CumulativeLast = ZERO_BI
  pair.reserve1CumulativeLast = ZERO_BI
  
  pair.token0Price = ZERO_BD
  pair.token1Price = ZERO_BD
  
  pair.volumeToken0 = ZERO_BD
  pair.volumeToken1 = ZERO_BD
  pair.volumeUSD = ZERO_BD
  
  pair.txCount = ZERO_BI
  
  pair.feesToken0 = ZERO_BD
  pair.feesToken1 = ZERO_BD
  pair.feesUSD = ZERO_BD
  
  pair.index0 = ZERO_BD
  pair.index1 = ZERO_BD
  
  pair.createdAtTimestamp = event.block.timestamp
  pair.createdAtBlockNumber = event.block.number
  pair.lastUpdateTimestamp = event.block.timestamp
  pair.lastUpdateBlockNumber = event.block.number
  
  pair.save()

  // Create the tracked contract based on the template
  PairTemplate.create(event.params.pair)
}