import { config as loadEnv } from "dotenv";
import { ethers } from "ethers";

loadEnv();

const RPC_URL = process.env.RPC_URL ?? "https://rpc.plasma.to";
const provider = new ethers.JsonRpcProvider(RPC_URL);

const PAIR_ADDRESS = process.env.PAIR_ADDRESS ?? "0xa0926801a2abc718822a60d8fa1bc2a51fa09f1e";
const AMOUNT_XPL = 100;

const PAIR_ABI = [
  "function metadata() view returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)",
  "function getAmountOut(uint256 amountIn, address tokenIn) view returns (uint256)"
];

const ERC20_ABI = [
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)"
];

async function main() {
  const pair = new ethers.Contract(PAIR_ADDRESS, PAIR_ABI, provider);
  const metadata = await pair.metadata();
  const dec0 = metadata.dec0 as bigint;
  const dec1 = metadata.dec1 as bigint;
  const reserve0 = metadata.r0 as bigint;
  const reserve1 = metadata.r1 as bigint;
  const token0 = metadata.t0 as string;
  const token1 = metadata.t1 as string;

  const token0Contract = new ethers.Contract(token0, ERC20_ABI, provider);
  const token1Contract = new ethers.Contract(token1, ERC20_ABI, provider);
  const [symbol0, symbol1, decimals0, decimals1] = await Promise.all([
    token0Contract.symbol(),
    token1Contract.symbol(),
    token0Contract.decimals(),
    token1Contract.decimals()
  ]);

  const inputIsToken0 = symbol0 === "WXPL";
  const inputIsToken1 = symbol1 === "WXPL";
  if (!inputIsToken0 && !inputIsToken1) {
    throw new Error("Pair does not contain WXPL.");
  }

  const symbolIn = inputIsToken0 ? symbol0 : symbol1;
  const symbolOut = inputIsToken0 ? symbol1 : symbol0;
  const decimalsIn = inputIsToken0 ? decimals0 : decimals1;
  const decimalsOut = inputIsToken0 ? decimals1 : decimals0;
  const reserveIn = inputIsToken0 ? reserve0 : reserve1;
  const reserveOut = inputIsToken0 ? reserve1 : reserve0;
  const decIn = inputIsToken0 ? dec0 : dec1;
  const decOut = inputIsToken0 ? dec1 : dec0;
  const tokenIn = inputIsToken0 ? token0 : token1;

  const amountInRaw = ethers.parseUnits(AMOUNT_XPL.toString(), decimalsIn);
  const amountOutRaw = await pair.getAmountOut(amountInRaw, tokenIn);
  if (amountOutRaw === 0n) {
    throw new Error("Swap simulation returned zero output.");
  }

  const amountOutHuman = Number(ethers.formatUnits(amountOutRaw, decimalsOut));

  const ONE = 10n ** 18n;
  const spotPriceRay = reserveOut * decIn * ONE / (reserveIn * decOut);
  const spotPrice = Number(ethers.formatUnits(spotPriceRay, 18));

  const amountInNetRaw = reserveIn * amountOutRaw / (reserveOut - amountOutRaw);
  const amountInNetHuman = Number(ethers.formatUnits(amountInNetRaw, decimalsIn));

  const execPriceGross = amountOutHuman / AMOUNT_XPL;
  const execPriceNet = amountOutHuman / amountInNetHuman;

  const execPriceGrossRay = amountOutRaw * decIn * ONE / (amountInRaw * decOut);
  const execPriceNetRay = amountOutRaw * decIn * ONE / (amountInNetRaw * decOut);

  const priceImpactTotalRay = spotPriceRay > execPriceGrossRay
    ? (spotPriceRay - execPriceGrossRay) * ONE / spotPriceRay
    : 0n;
  const priceImpactPoolOnlyRay = spotPriceRay > execPriceNetRay
    ? (spotPriceRay - execPriceNetRay) * ONE / spotPriceRay
    : 0n;

  const priceImpactTotal = Number(ethers.formatUnits(priceImpactTotalRay, 18)) * 100;
  const priceImpactPoolOnly = Number(ethers.formatUnits(priceImpactPoolOnlyRay, 18)) * 100;

  const feeBps = Number((amountInRaw - amountInNetRaw) * 10000n / amountInRaw);

  console.log("Pair:", PAIR_ADDRESS);
  console.log("Reserves:");
  console.log(`  ${symbol0}: ${ethers.formatUnits(reserve0, decimals0)}`);
  console.log(`  ${symbol1}: ${ethers.formatUnits(reserve1, decimals1)}`);
  console.log("");
  console.log(`Swap: ${AMOUNT_XPL} ${symbolIn} -> ${symbolOut}`);
  console.log("  Output:", amountOutHuman.toFixed(6), symbolOut);
  console.log("  Execution price (gross):", execPriceGross.toFixed(6), `${symbolOut}/${symbolIn}`);
  console.log("  Execution price (net fee removed):", execPriceNet.toFixed(6), `${symbolOut}/${symbolIn}`);
  console.log("  Spot price:", spotPrice.toFixed(6), `${symbolOut}/${symbolIn}`);
  console.log("  Price impact (pool only):", priceImpactPoolOnly.toFixed(3), "%");
  console.log("  Price impact (incl. fee):", priceImpactTotal.toFixed(3), "%");
  console.log("  Net input after fee:", amountInNetHuman.toFixed(6), symbolIn);
  console.log("  Fee (bps):", feeBps);
}

main().catch((error) => {
  console.error("Price impact script failed:", error);
  process.exit(1);
});
