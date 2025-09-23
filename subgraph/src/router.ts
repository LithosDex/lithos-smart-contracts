import { Swap as RouterSwapEvent } from "../generated/RouterV2/RouterV2";
import { RouterSwap, Transaction, Token, User } from "../generated/schema";
import { BigInt, BigDecimal } from "@graphprotocol/graph-ts";
import {
  createTransaction,
  createUser,
  convertTokenToDecimal,
  fetchTokenDecimals,
  getTrackedVolumeUSD,
  ZERO_BD,
  ONE_BI,
} from "./helpers";

export function handleRouterSwap(event: RouterSwapEvent): void {
  let transaction = createTransaction(event);

  // Load or create user
  let user = createUser(event.params.sender);

  // Load token
  let token = Token.load(event.params._tokenIn.toHexString());
  if (token === null) {
    // Token might not exist yet, skip for now
    return;
  }

  // Convert amount
  let amountIn = convertTokenToDecimal(event.params.amount0In, token.decimals);

  // Create router swap entity
  let routerSwap = new RouterSwap(
    event.transaction.hash
      .toHexString()
      .concat("-")
      .concat(BigInt.fromI32(event.logIndex.toI32()).toString())
  );

  routerSwap.transaction = transaction.id;
  routerSwap.timestamp = transaction.timestamp;
  routerSwap.sender = event.params.sender;
  routerSwap.to = event.params.to;
  routerSwap.tokenIn = event.params._tokenIn;
  routerSwap.amountIn = amountIn;
  routerSwap.stable = event.params.stable;
  routerSwap.logIndex = event.logIndex;

  // Calculate USD amount if possible
  if (token.derivedETH.notEqual(ZERO_BD)) {
    routerSwap.amountUSD = amountIn
      .times(token.derivedETH)
      .times(BigDecimal.fromString("2000")); // Use bundle ETH price
  } else {
    routerSwap.amountUSD = null;
  }

  // Update user stats
  if (routerSwap.amountUSD !== null) {
    user.usdSwapped = user.usdSwapped.plus(routerSwap.amountUSD!);
  }

  // Update token stats
  token.tradeVolume = token.tradeVolume.plus(amountIn);
  if (routerSwap.amountUSD !== null) {
    token.tradeVolumeUSD = token.tradeVolumeUSD.plus(routerSwap.amountUSD!);
  }
  token.txCount = token.txCount.plus(ONE_BI);

  user.save();
  token.save();
  routerSwap.save();
}
