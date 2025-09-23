import {
  Mint as MintEvent,
  Burn as BurnEvent,
  Swap as SwapEvent,
  Sync,
  Transfer,
  Fees,
  Claim,
  Approval,
} from "../generated/templates/Pair/Pair";

import {
  Bundle,
  Mint,
  Burn,
  Swap,
  Pair,
  Token,
  User,
  Transaction,
  LiquidityPosition,
  Factory,
} from "../generated/schema";

import { Pair as PairContract } from "../generated/templates/Pair/Pair";
import {
  Address,
  BigInt,
  BigDecimal,
  store,
  ethereum,
} from "@graphprotocol/graph-ts";
import {
  ZERO_BD,
  ZERO_BI,
  ONE_BI,
  convertTokenToDecimal,
  createUser,
  createLiquidityPosition,
  createTransaction,
  getTrackedVolumeUSD,
  getTrackedLiquidityUSD,
  updatePairHourData,
  updatePairDayData,
  updateTokenDayData,
  updatePlasmaDayData,
  findEthPerToken,
  fetchTokenDecimals,
} from "./helpers";

export function handleMint(event: MintEvent): void {
  let transaction = createTransaction(event);
  let pair = Pair.load(event.address.toHexString())!;
  let factory = Factory.load("1")!;

  let token0 = Token.load(pair.token0)!;
  let token1 = Token.load(pair.token1)!;

  // Get amounts
  let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals);
  let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals);

  // Update token tracking
  token0.txCount = token0.txCount.plus(ONE_BI);
  token1.txCount = token1.txCount.plus(ONE_BI);

  // Get new amounts of USD and ETH for tracking
  let bundle = Bundle.load("1")!;
  let amountTotalUSD = getTrackedVolumeUSD(amount0, token0, amount1, token1);

  // Update factory
  factory.txCount = factory.txCount.plus(ONE_BI);

  // Update pair
  pair.txCount = pair.txCount.plus(ONE_BI);

  // Create mint entity
  let mint = new Mint(
    event.transaction.hash
      .toHexString()
      .concat("-")
      .concat(BigInt.fromI32(event.logIndex.toI32()).toString())
  );
  mint.transaction = transaction.id;
  mint.pair = pair.id;
  mint.to = event.params.sender;
  mint.liquidity = ZERO_BD; // Will be updated when we get liquidity amount
  mint.timestamp = transaction.timestamp;
  mint.amount0 = amount0;
  mint.amount1 = amount1;
  mint.logIndex = event.logIndex;
  mint.amountUSD = amountTotalUSD;
  mint.sender = event.transaction.from;

  // Update hourly and daily data
  updatePairHourData(event);
  updatePairDayData(event);
  updateTokenDayData(token0, event);
  updateTokenDayData(token1, event);
  updatePlasmaDayData(event);

  token0.save();
  token1.save();
  pair.save();
  factory.save();
  mint.save();
}

export function handleBurn(event: BurnEvent): void {
  let transaction = createTransaction(event);
  let pair = Pair.load(event.address.toHexString())!;
  let factory = Factory.load("1")!;

  let token0 = Token.load(pair.token0)!;
  let token1 = Token.load(pair.token1)!;

  // Get amounts
  let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals);
  let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals);

  // Update token tracking
  token0.txCount = token0.txCount.plus(ONE_BI);
  token1.txCount = token1.txCount.plus(ONE_BI);

  // Get new amounts of USD and ETH for tracking
  let bundle = Bundle.load("1")!;
  let amountTotalUSD = getTrackedVolumeUSD(amount0, token0, amount1, token1);

  // Update factory
  factory.txCount = factory.txCount.plus(ONE_BI);

  // Update pair
  pair.txCount = pair.txCount.plus(ONE_BI);

  // Create burn entity
  let burn = new Burn(
    event.transaction.hash
      .toHexString()
      .concat("-")
      .concat(BigInt.fromI32(event.logIndex.toI32()).toString())
  );
  burn.transaction = transaction.id;
  burn.pair = pair.id;
  burn.liquidity = ZERO_BD; // Will be updated when we get liquidity amount
  burn.timestamp = transaction.timestamp;
  burn.amount0 = amount0;
  burn.amount1 = amount1;
  burn.to = event.params.to;
  burn.logIndex = event.logIndex;
  burn.amountUSD = amountTotalUSD;
  burn.sender = event.transaction.from;

  // Update hourly and daily data
  updatePairHourData(event);
  updatePairDayData(event);
  updateTokenDayData(token0, event);
  updateTokenDayData(token1, event);
  updatePlasmaDayData(event);

  token0.save();
  token1.save();
  pair.save();
  factory.save();
  burn.save();
}

export function handleSwap(event: SwapEvent): void {
  let transaction = createTransaction(event);
  let pair = Pair.load(event.address.toHexString())!;
  let factory = Factory.load("1")!;

  let token0 = Token.load(pair.token0)!;
  let token1 = Token.load(pair.token1)!;

  // Convert amounts to decimals
  let amount0In = convertTokenToDecimal(
    event.params.amount0In,
    token0.decimals
  );
  let amount1In = convertTokenToDecimal(
    event.params.amount1In,
    token1.decimals
  );
  let amount0Out = convertTokenToDecimal(
    event.params.amount0Out,
    token0.decimals
  );
  let amount1Out = convertTokenToDecimal(
    event.params.amount1Out,
    token1.decimals
  );

  // Totals for volume updates
  let amount0Total = amount0Out.plus(amount0In);
  let amount1Total = amount1Out.plus(amount1In);

  // Get tracked amounts
  let trackedAmountUSD = getTrackedVolumeUSD(
    amount0Total,
    token0,
    amount1Total,
    token1
  );

  // Update token counters
  token0.tradeVolume = token0.tradeVolume.plus(amount0Total);
  token0.tradeVolumeUSD = token0.tradeVolumeUSD.plus(trackedAmountUSD);
  token0.txCount = token0.txCount.plus(ONE_BI);

  token1.tradeVolume = token1.tradeVolume.plus(amount1Total);
  token1.tradeVolumeUSD = token1.tradeVolumeUSD.plus(trackedAmountUSD);
  token1.txCount = token1.txCount.plus(ONE_BI);

  // Update pair volume data
  pair.volumeToken0 = pair.volumeToken0.plus(amount0Total);
  pair.volumeToken1 = pair.volumeToken1.plus(amount1Total);
  pair.volumeUSD = pair.volumeUSD.plus(trackedAmountUSD);
  pair.txCount = pair.txCount.plus(ONE_BI);

  // Update factory
  factory.totalVolumeUSD = factory.totalVolumeUSD.plus(trackedAmountUSD);
  factory.txCount = factory.txCount.plus(ONE_BI);

  // Create swap entity
  let swap = new Swap(
    event.transaction.hash
      .toHexString()
      .concat("-")
      .concat(BigInt.fromI32(event.logIndex.toI32()).toString())
  );
  swap.transaction = transaction.id;
  swap.pair = pair.id;
  swap.timestamp = transaction.timestamp;
  swap.sender = event.params.sender;
  swap.to = event.params.to;
  swap.amount0In = amount0In;
  swap.amount1In = amount1In;
  swap.amount0Out = amount0Out;
  swap.amount1Out = amount1Out;
  swap.logIndex = event.logIndex;
  swap.amountUSD = trackedAmountUSD;

  // Update price info
  let bundle = Bundle.load("1")!;
  swap.token0PriceUSD = token0.derivedETH.times(bundle.ethPrice);
  swap.token1PriceUSD = token1.derivedETH.times(bundle.ethPrice);

  // Update hourly and daily data
  updatePairHourData(event);
  updatePairDayData(event);
  updateTokenDayData(token0, event);
  updateTokenDayData(token1, event);
  updatePlasmaDayData(event);

  // Update user
  if (event.transaction.from) {
    let user = createUser(event.transaction.from);
    user.usdSwapped = user.usdSwapped.plus(trackedAmountUSD);
    user.save();
  }

  token0.save();
  token1.save();
  pair.save();
  factory.save();
  swap.save();
}

export function handleSync(event: Sync): void {
  let pair = Pair.load(event.address.toHexString())!;
  let token0 = Token.load(pair.token0)!;
  let token1 = Token.load(pair.token1)!;

  // Update reserves
  pair.reserve0 = convertTokenToDecimal(event.params.reserve0, token0.decimals);
  pair.reserve1 = convertTokenToDecimal(event.params.reserve1, token1.decimals);

  // Update prices if reserves are not zero
  if (pair.reserve1.notEqual(ZERO_BD)) {
    pair.token0Price = pair.reserve1.div(pair.reserve0);
  }
  if (pair.reserve0.notEqual(ZERO_BD)) {
    pair.token1Price = pair.reserve0.div(pair.reserve1);
  }

  // Update tracked liquidity
  let trackedLiquidityUSD = getTrackedLiquidityUSD(
    pair.reserve0,
    token0,
    pair.reserve1,
    token1
  );
  pair.reserveUSD = trackedLiquidityUSD;

  // Update bundle liquidity
  let bundle = Bundle.load("1")!;
  pair.reserveETH = trackedLiquidityUSD.div(bundle.ethPrice);

  // Update last sync time
  pair.lastUpdateTimestamp = event.block.timestamp;
  pair.lastUpdateBlockNumber = event.block.number;

  pair.save();

  // Update token liquidity
  token0.totalLiquidity = token0.totalLiquidity.plus(pair.reserve0);
  token1.totalLiquidity = token1.totalLiquidity.plus(pair.reserve1);

  token0.save();
  token1.save();
}

export function handleTransfer(event: Transfer): void {
  // Handle LP token transfers
  let pair = Pair.load(event.address.toHexString());

  if (pair === null) {
    return;
  }

  // Only handle non-zero transfers (skip mint/burn to zero address)
  if (
    event.params.from.toHexString() ==
    "0x0000000000000000000000000000000000000000"
  ) {
    return;
  }

  if (
    event.params.to.toHexString() ==
    "0x0000000000000000000000000000000000000000"
  ) {
    return;
  }

  // Update liquidity positions
  let fromPosition = createLiquidityPosition(event.params.from, event.address);
  let toPosition = createLiquidityPosition(event.params.to, event.address);

  let value = convertTokenToDecimal(event.params.amount, BigInt.fromI32(18));

  fromPosition.liquidityTokenBalance = fromPosition.liquidityTokenBalance.minus(
    value
  );
  toPosition.liquidityTokenBalance = toPosition.liquidityTokenBalance.plus(
    value
  );

  fromPosition.save();
  toPosition.save();
}

export function handleFees(event: Fees): void {
  let pair = Pair.load(event.address.toHexString())!;
  let token0 = Token.load(pair.token0)!;
  let token1 = Token.load(pair.token1)!;

  // Convert fee amounts
  let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals);
  let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals);

  // Update pair fees
  pair.feesToken0 = pair.feesToken0.plus(amount0);
  pair.feesToken1 = pair.feesToken1.plus(amount1);

  // Calculate USD value
  let bundle = Bundle.load("1")!;
  let feeUSD = amount0
    .times(token0.derivedETH.times(bundle.ethPrice))
    .plus(amount1.times(token1.derivedETH.times(bundle.ethPrice)));

  pair.feesUSD = pair.feesUSD.plus(feeUSD);

  pair.save();
}

export function handleClaim(event: Claim): void {
  // Handle fee claims by users
  let user = createUser(event.params.sender);
  let pair = Pair.load(event.address.toHexString())!;
  let position = createLiquidityPosition(event.params.sender, event.address);

  let token0 = Token.load(pair.token0)!;
  let token1 = Token.load(pair.token1)!;

  // Convert claim amounts
  let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals);
  let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals);

  // Update claimable amounts (should go to zero after claim)
  position.claimable0 = ZERO_BD;
  position.claimable1 = ZERO_BD;

  position.save();
  user.save();
}

export function handleApproval(event: Approval): void {
  // Handle LP token approvals - mostly for completeness
  // Could be used for tracking approved amounts if needed
}
