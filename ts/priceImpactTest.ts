import { config as loadEnv } from "dotenv";
import { ethers } from "ethers";

loadEnv();

const RPC_URL = process.env.RPC_URL;
if (!RPC_URL) {
  console.error("Missing RPC_URL in environment. Set it in your .env file.");
  process.exit(1);
}

const provider = new ethers.JsonRpcProvider(RPC_URL);

const ADDRS = {
  pairFactory: "0x71a870D1c935C2146b87644DF3B5316e8756aE18",
  routerV2: "0xD70962bd7C6B3567a8c893b55a8aBC1E151759f3",
  tradeHelper: "0xf2e70f25a712B2FEE0B76d5728a620707AF5D42c",
  globalRouter: "0xC7E4BCC695a9788fd0f952250cA058273BE7F6A3"
} as const;

const TOKENS = {
  WXPL: "0x6100E367285b01F48D07953803A2d8dCA5D19873",
  USDT0: "0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb"
} as const;

type Route = {
  from: string;
  to: string;
  stable: boolean;
};

const TRADE_HELPER_ABI = [
  "function getAmountsOut(uint256 amountIn, tuple(address from, address to, bool stable)[] routes) view returns (uint256[] amounts)",
  "function pairFor(address tokenA, address tokenB, bool stable) view returns (address pair)"
];

const PAIR_FACTORY_ABI = [
  "function getPair(address tokenA, address tokenB, bool stable) view returns (address pair)",
  "function getFee(bool _stable) external view returns (uint256)"
];

const PAIR_ABI = [
  "function metadata() view returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)",
  "function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256)"
];

const ERC20_ABI = [
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)"
];

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const ONE = 10n ** 18n;
const FEE_DENOM = 10_000n;

async function findPair(factory: ethers.Contract, tokenA: string, tokenB: string): Promise<Route & { pair: string }> {
  const stablePair = await factory.getPair(tokenA, tokenB, true);
  if (stablePair !== ZERO_ADDRESS) {
    return { from: tokenA, to: tokenB, stable: true, pair: stablePair };
  }

  const volatilePair = await factory.getPair(tokenA, tokenB, false);
  if (volatilePair !== ZERO_ADDRESS) {
    return { from: tokenA, to: tokenB, stable: false, pair: volatilePair };
  }

  throw new Error(`No pair found for ${tokenA} -> ${tokenB}`);
}


async function computePriceImpact(
  amountIn: bigint,
  route: Route & { pair: string },
  tradeHelper: ethers.Contract,
  factory: ethers.Contract
) {
  const amounts: bigint[] = await tradeHelper.getAmountsOut(amountIn, [route]);
  const amountOut = amounts[amounts.length - 1];
  if (amountOut === 0n) {
    throw new Error("TradeHelper returned zero output for the provided route.");
  }

  const pair = new ethers.Contract(route.pair, PAIR_ABI, provider);
  const metadata = await pair.metadata();
  const dec0 = metadata.dec0 as bigint;
  const dec1 = metadata.dec1 as bigint;
  const reserve0 = metadata.r0 as bigint;
  const reserve1 = metadata.r1 as bigint;
  const token0 = (metadata.t0 as string).toLowerCase();
  const token1 = (metadata.t1 as string).toLowerCase();

  const fromLower = route.from.toLowerCase();
  const reserveIn = fromLower === token0 ? reserve0 : reserve1;
  const reserveOut = fromLower === token0 ? reserve1 : reserve0;
  const decIn = fromLower === token0 ? dec0 : dec1;
  const decOut = fromLower === token0 ? dec1 : dec0;

  const feeBps = BigInt(await factory.getFee(route.stable));
  const amountInNet = (amountIn * (FEE_DENOM - feeBps)) / FEE_DENOM;

  // Use a very small trade to approximate the no-impact spot price (net of fees) directly from the pair
  let epsilon = decIn / 1_000n;
  if (epsilon === 0n) {
    epsilon = decIn;
  }
  const epsilonOut = BigInt(await pair.getAmountOut(epsilon, route.from));
  const epsilonNet = (epsilon * (FEE_DENOM - feeBps)) / FEE_DENOM;
  if (epsilonOut === 0n || epsilonNet === 0n) {
    throw new Error("Unable to determine spot price from the pair reserves.");
  }

  const spotPrice = (epsilonOut * ONE) / epsilonNet;
  const execPrice = (amountOut * ONE) / amountInNet;

  const priceImpactBps = spotPrice > execPrice
    ? ((spotPrice - execPrice) * FEE_DENOM) / spotPrice
    : 0n;

  return {
    amountOut,
    amountIn,
    amountInNet,
    execPrice,
    spotPrice,
    priceImpactBps,
    reserveIn,
    reserveOut,
    decIn,
    decOut,
    feeBps
  };
}

async function main() {
  const factory = new ethers.Contract(ADDRS.pairFactory, PAIR_FACTORY_ABI, provider);
  const tradeHelper = new ethers.Contract(ADDRS.tradeHelper, TRADE_HELPER_ABI, provider);

  const amountArg = process.argv[2] ?? "10";
  const tokenIn = new ethers.Contract(TOKENS.WXPL, ERC20_ABI, provider);
  const tokenOut = new ethers.Contract(TOKENS.USDT0, ERC20_ABI, provider);
  const [decimalsIn, decimalsOut, symbolIn, symbolOut] = await Promise.all([
    tokenIn.decimals(),
    tokenOut.decimals(),
    tokenIn.symbol(),
    tokenOut.symbol()
  ]);

  const parsedAmountIn = ethers.parseUnits(amountArg, decimalsIn);
  const route = await findPair(factory, TOKENS.WXPL, TOKENS.USDT0);

  console.log("Running price impact test with the following configuration:\n", {
    amountIn: `${amountArg} ${symbolIn}`,
    routeStable: route.stable,
    pair: route.pair
  });

  const result = await computePriceImpact(parsedAmountIn, route, tradeHelper, factory);

  const formattedOut = ethers.formatUnits(result.amountOut, decimalsOut);
  const priceImpactPct = Number(result.priceImpactBps) / 100;

  console.log("\nSwap results:");
  console.log(`- Input Amount (raw): ${result.amountIn.toString()}`);
  console.log(`- Net Input After Fees (raw): ${result.amountInNet.toString()}`);
  console.log(`- Output Amount: ${formattedOut} ${symbolOut}`);
  console.log(`- Pool Fee (bps): ${result.feeBps.toString()}`);
  console.log(`- Spot Price (scaled 1e18): ${result.spotPrice.toString()}`);
  console.log(`- Execution Price (scaled 1e18): ${result.execPrice.toString()}`);
  console.log(`- Price Impact (bps, includes fees): ${result.priceImpactBps.toString()}`);
  console.log(`- Price Impact (%): ${priceImpactPct.toFixed(2)}%`);

  if (result.amountOut === 0n) {
    throw new Error("FAIL: got zero output from TradeHelper");
  }

  console.log("\nPASS: TradeHelper produced a non-zero swap with quantified price impact.");
}

main().catch((error) => {
  console.error("\nTest script failed:", error);
  process.exit(1);
});
