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
  PairEpochData,
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
  ZERO_ADDRESS,
  WEEK,
  getEpoch,
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

  // Get LP token amount minted
  let liquidityAmount = ZERO_BD;
  let contract = PairContract.bind(event.address);
  let totalSupplyResult = contract.try_totalSupply();
  if (!totalSupplyResult.reverted) {
    let totalSupply = convertTokenToDecimal(totalSupplyResult.value, BigInt.fromI32(18));
    // Estimate liquidity minted (this is approximate, better to get from Transfer events)
    liquidityAmount = totalSupply.minus(pair.totalSupply);
    pair.totalSupply = totalSupply;
  }

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
  mint.liquidity = liquidityAmount;
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

  // Get LP token amount burned
  let liquidityAmount = ZERO_BD;
  let contract = PairContract.bind(event.address);
  let totalSupplyResult = contract.try_totalSupply();
  if (!totalSupplyResult.reverted) {
    let totalSupply = convertTokenToDecimal(totalSupplyResult.value, BigInt.fromI32(18));
    // Estimate liquidity burned
    liquidityAmount = pair.totalSupply.minus(totalSupply);
    pair.totalSupply = totalSupply;
  }

  // Create burn entity
  let burn = new Burn(
    event.transaction.hash
      .toHexString()
      .concat("-")
      .concat(BigInt.fromI32(event.logIndex.toI32()).toString())
  );
  burn.transaction = transaction.id;
  burn.pair = pair.id;
  burn.liquidity = liquidityAmount;
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

  // Update weekly epoch aggregation (volume)
  let epochStartVol = getEpoch(event.block.timestamp);
  let epochIdVol = pair.id.concat("-").concat(epochStartVol.toString());
  let epochVol = PairEpochData.load(epochIdVol);
  if (epochVol === null) {
    epochVol = new PairEpochData(epochIdVol);
    epochVol.pair = pair.id;
    epochVol.token0 = pair.token0;
    epochVol.token1 = pair.token1;
    epochVol.epoch = epochStartVol;
    epochVol.epochStart = epochStartVol;
    epochVol.epochEnd = epochStartVol.plus(WEEK);
    // initialize fees buckets to zero (may be filled by Fees handler)
    epochVol.feesToken0 = ZERO_BD;
    epochVol.feesToken1 = ZERO_BD;
    epochVol.feesUSD = ZERO_BD;
    epochVol.referralFeesToken0 = ZERO_BD;
    epochVol.referralFeesToken1 = ZERO_BD;
    epochVol.referralFeesUSD = ZERO_BD;
    epochVol.stakingFeesToken0 = ZERO_BD;
    epochVol.stakingFeesToken1 = ZERO_BD;
    epochVol.stakingFeesUSD = ZERO_BD;
    // initialize new volume fields
    epochVol.volumeToken0 = ZERO_BD;
    epochVol.volumeToken1 = ZERO_BD;
    epochVol.volumeUSD = ZERO_BD;
  }
  epochVol.volumeToken0 = epochVol.volumeToken0.plus(amount0Total);
  epochVol.volumeToken1 = epochVol.volumeToken1.plus(amount1Total);
  epochVol.volumeUSD = epochVol.volumeUSD.plus(trackedAmountUSD);
  epochVol.updatedAtTimestamp = event.block.timestamp;
  epochVol.updatedAtBlockNumber = event.block.number;
  epochVol.save();

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

  // Update liquidity positions
  let value = convertTokenToDecimal(event.params.amount, BigInt.fromI32(18));

  let pairAddress = event.address.toHexString();
  let from = event.params.from.toHexString();
  let to = event.params.to.toHexString();

  if (from != ZERO_ADDRESS && from != pairAddress) {
    let fromPosition = createLiquidityPosition(event.params.from, event.address);
    fromPosition.liquidityTokenBalance = fromPosition.liquidityTokenBalance.minus(
      value
    );
    fromPosition.save();
  }

  if (to != ZERO_ADDRESS && to != pairAddress) {
    let toPosition = createLiquidityPosition(event.params.to, event.address);
    toPosition.liquidityTokenBalance = toPosition.liquidityTokenBalance.plus(
      value
    );
    toPosition.save();
  }
}

export function handleFees(event: Fees): void {
  let pair = Pair.load(event.address.toHexString())!;
  let factory = Factory.load("1");
  if (factory === null) {
    return;
  }
  let token0 = Token.load(pair.token0)!;
  let token1 = Token.load(pair.token1)!;

  // Convert fee amounts
  let amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals);
  let amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals);

  let denominator = BigDecimal.fromString("10000");
  let referralRate = factory.maxReferralFee.toBigDecimal().div(denominator);
  let stakingRate = factory.stakingNFTFee.toBigDecimal().div(denominator);

  let referralAmount0 = amount0.times(referralRate);
  let referralAmount1 = amount1.times(referralRate);

  let afterReferral0 = amount0.minus(referralAmount0);
  let afterReferral1 = amount1.minus(referralAmount1);
  if (afterReferral0.lt(ZERO_BD)) {
    afterReferral0 = ZERO_BD;
  }
  if (afterReferral1.lt(ZERO_BD)) {
    afterReferral1 = ZERO_BD;
  }

  let stakingAmount0 = afterReferral0.times(stakingRate);
  let stakingAmount1 = afterReferral1.times(stakingRate);

  let lpAmount0 = afterReferral0.minus(stakingAmount0);
  let lpAmount1 = afterReferral1.minus(stakingAmount1);
  if (lpAmount0.lt(ZERO_BD)) {
    lpAmount0 = ZERO_BD;
  }
  if (lpAmount1.lt(ZERO_BD)) {
    lpAmount1 = ZERO_BD;
  }

  // Update pair fees for each bucket
  pair.feesToken0 = pair.feesToken0.plus(lpAmount0);
  pair.feesToken1 = pair.feesToken1.plus(lpAmount1);
  pair.referralFeesToken0 = pair.referralFeesToken0.plus(referralAmount0);
  pair.referralFeesToken1 = pair.referralFeesToken1.plus(referralAmount1);
  pair.stakingFeesToken0 = pair.stakingFeesToken0.plus(stakingAmount0);
  pair.stakingFeesToken1 = pair.stakingFeesToken1.plus(stakingAmount1);

  // Calculate USD value for each bucket
  let bundle = Bundle.load("1")!;
  let price0USD = token0.derivedETH.times(bundle.ethPrice);
  let price1USD = token1.derivedETH.times(bundle.ethPrice);

  let lpUSD = lpAmount0.times(price0USD).plus(lpAmount1.times(price1USD));
  let referralUSD = referralAmount0
    .times(price0USD)
    .plus(referralAmount1.times(price1USD));
  let stakingUSD = stakingAmount0
    .times(price0USD)
    .plus(stakingAmount1.times(price1USD));

  pair.feesUSD = pair.feesUSD.plus(lpUSD);
  pair.referralFeesUSD = pair.referralFeesUSD.plus(referralUSD);
  pair.stakingFeesUSD = pair.stakingFeesUSD.plus(stakingUSD);

  // Update weekly epoch aggregation
  let epochStart = getEpoch(event.block.timestamp);
  let epochId = pair.id.concat("-").concat(epochStart.toString());
  let epochData = PairEpochData.load(epochId);
  if (epochData === null) {
    epochData = new PairEpochData(epochId);
    epochData.pair = pair.id;
    epochData.token0 = pair.token0;
    epochData.token1 = pair.token1;
    epochData.epoch = epochStart;
    epochData.epochStart = epochStart;
    epochData.epochEnd = epochStart.plus(WEEK);
    epochData.feesToken0 = ZERO_BD;
    epochData.feesToken1 = ZERO_BD;
    epochData.feesUSD = ZERO_BD;
    epochData.referralFeesToken0 = ZERO_BD;
    epochData.referralFeesToken1 = ZERO_BD;
    epochData.referralFeesUSD = ZERO_BD;
    epochData.stakingFeesToken0 = ZERO_BD;
    epochData.stakingFeesToken1 = ZERO_BD;
    epochData.stakingFeesUSD = ZERO_BD;
    // initialize new volume fields if created here first
    epochData.volumeToken0 = ZERO_BD;
    epochData.volumeToken1 = ZERO_BD;
    epochData.volumeUSD = ZERO_BD;
  }

  epochData.feesToken0 = epochData.feesToken0.plus(lpAmount0);
  epochData.feesToken1 = epochData.feesToken1.plus(lpAmount1);
  epochData.feesUSD = epochData.feesUSD.plus(lpUSD);
  epochData.referralFeesToken0 = epochData.referralFeesToken0.plus(referralAmount0);
  epochData.referralFeesToken1 = epochData.referralFeesToken1.plus(referralAmount1);
  epochData.referralFeesUSD = epochData.referralFeesUSD.plus(referralUSD);
  epochData.stakingFeesToken0 = epochData.stakingFeesToken0.plus(stakingAmount0);
  epochData.stakingFeesToken1 = epochData.stakingFeesToken1.plus(stakingAmount1);
  epochData.stakingFeesUSD = epochData.stakingFeesUSD.plus(stakingUSD);
  epochData.updatedAtTimestamp = event.block.timestamp;
  epochData.updatedAtBlockNumber = event.block.number;
  epochData.save();

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
