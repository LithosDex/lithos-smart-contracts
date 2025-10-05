import { PairCreated } from "../generated/PairFactory/PairFactory";
import { Factory, Pair, Token, Bundle } from "../generated/schema";
import { Pair as PairTemplate } from "../generated/templates";
import { ERC20 } from "../generated/PairFactory/ERC20";
import { BigDecimal, BigInt, Address } from "@graphprotocol/graph-ts";
import { ZERO_BD, ZERO_BI } from "./helpers";

export function handlePairCreated(event: PairCreated): void {
  // Load factory
  let factory = Factory.load("1");
  if (factory === null) {
    factory = new Factory("1");
    factory.pairCount = 0;
    factory.totalVolumeUSD = ZERO_BD;
    factory.totalVolumeETH = ZERO_BD;
    factory.totalLiquidityUSD = ZERO_BD;
    factory.totalLiquidityETH = ZERO_BD;
    factory.txCount = ZERO_BI;

    // Seed with current mainnet configuration
    factory.stableFee = BigInt.fromI32(4); // 0.04%
    factory.volatileFee = BigInt.fromI32(18); // 0.18%
    factory.stakingNFTFee = BigInt.fromI32(0); // staking disabled
    factory.maxReferralFee = BigInt.fromI32(1200); // 12%

    factory.pauser = Address.fromString(
      "0x0000000000000000000000000000000000000000"
    );
    factory.feeManager = Address.fromString(
      "0x0000000000000000000000000000000000000000"
    );
    factory.dibs = Address.fromString(
      "0xe98c1e28805A06F23B41cf6d356dFC7709DB9385"
    );
    factory.stakingFeeHandler = null;
    factory.isPaused = false;

    // Create bundle for ETH price tracking
    let bundle = Bundle.load("1");
    if (bundle === null) {
      bundle = new Bundle("1");
      bundle.ethPrice = BigDecimal.fromString("2000"); // Initialize with reasonable ETH price
      bundle.save();
    }
  }

  // Hardcoded mainnet configuration
  factory.stableFee = BigInt.fromI32(4); // 0.04%
  factory.volatileFee = BigInt.fromI32(18); // 0.18%
  factory.stakingNFTFee = BigInt.fromI32(0); // staking disabled
  factory.maxReferralFee = BigInt.fromI32(1200); // 12%
  factory.dibs = Address.fromString("0xe98c1e28805A06F23B41cf6d356dFC7709DB9385");
  factory.stakingFeeHandler = null; // no staking handler on mainnet

  factory.pairCount = factory.pairCount + 1;
  factory.save();

  // Create tokens if they don't exist
  let token0 = Token.load(event.params.token0.toHexString());
  if (token0 === null) {
    token0 = new Token(event.params.token0.toHexString());
    let token0Contract = ERC20.bind(event.params.token0);

    // Try to get token info from contract, use defaults if calls fail
    token0.symbol = "UNKNOWN";
    token0.name = "Unknown Token";
    token0.decimals = BigInt.fromI32(18);

    let symbolResult = token0Contract.try_symbol();
    if (!symbolResult.reverted) {
      token0.symbol = symbolResult.value;
      // Use symbol as name if no specific name function available
      token0.name = symbolResult.value;
    }

    let decimalsResult = token0Contract.try_decimals();
    if (!decimalsResult.reverted) {
      token0.decimals = BigInt.fromI32(decimalsResult.value);
    }

    token0.derivedETH = ZERO_BD;
    token0.tradeVolume = ZERO_BD;
    token0.tradeVolumeUSD = ZERO_BD;
    token0.totalLiquidity = ZERO_BD;
    token0.txCount = ZERO_BI;

    token0.save();
  }

  let token1 = Token.load(event.params.token1.toHexString());
  if (token1 === null) {
    token1 = new Token(event.params.token1.toHexString());
    let token1Contract = ERC20.bind(event.params.token1);

    // Try to get token info from contract, use defaults if calls fail
    token1.symbol = "UNKNOWN";
    token1.name = "Unknown Token";
    token1.decimals = BigInt.fromI32(18);

    let symbolResult = token1Contract.try_symbol();
    if (!symbolResult.reverted) {
      token1.symbol = symbolResult.value;
      // Use symbol as name if no specific name function available
      token1.name = symbolResult.value;
    }

    let decimalsResult = token1Contract.try_decimals();
    if (!decimalsResult.reverted) {
      token1.decimals = BigInt.fromI32(decimalsResult.value);
    }

    token1.derivedETH = ZERO_BD;
    token1.tradeVolume = ZERO_BD;
    token1.tradeVolumeUSD = ZERO_BD;
    token1.totalLiquidity = ZERO_BD;
    token1.txCount = ZERO_BI;

    token1.save();
  }

  // Create pair
  let pair = new Pair(event.params.pair.toHexString());
  pair.factory = factory.id;
  pair.token0 = token0.id;
  pair.token1 = token1.id;
  pair.stable = event.params.stable;

  pair.reserve0 = ZERO_BD;
  pair.reserve1 = ZERO_BD;
  pair.totalSupply = ZERO_BD;
  pair.reserveETH = ZERO_BD;
  pair.reserveUSD = ZERO_BD;

  pair.reserve0CumulativeLast = ZERO_BI;
  pair.reserve1CumulativeLast = ZERO_BI;

  pair.token0Price = ZERO_BD;
  pair.token1Price = ZERO_BD;

  pair.volumeToken0 = ZERO_BD;
  pair.volumeToken1 = ZERO_BD;
  pair.volumeUSD = ZERO_BD;

  pair.txCount = ZERO_BI;

  pair.feesToken0 = ZERO_BD;
  pair.feesToken1 = ZERO_BD;
  pair.feesUSD = ZERO_BD;
  pair.referralFeesToken0 = ZERO_BD;
  pair.referralFeesToken1 = ZERO_BD;
  pair.referralFeesUSD = ZERO_BD;
  pair.stakingFeesToken0 = ZERO_BD;
  pair.stakingFeesToken1 = ZERO_BD;
  pair.stakingFeesUSD = ZERO_BD;

  pair.index0 = ZERO_BD;
  pair.index1 = ZERO_BD;

  pair.createdAtTimestamp = event.block.timestamp;
  pair.createdAtBlockNumber = event.block.number;
  pair.lastUpdateTimestamp = event.block.timestamp;
  pair.lastUpdateBlockNumber = event.block.number;

  pair.save();

  // Create the tracked contract based on the template
  PairTemplate.create(event.params.pair);
}
