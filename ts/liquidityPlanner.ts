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
  pair: "0x01b968C1b663C3921Da5BE3C99Ee3c9B89a40B54",
  usde: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
  usdt0: "0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb"
} as const;

const PAIR_ABI = [
  "function metadata() view returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)",
  "function totalSupply() view returns (uint256)",
  "function name() view returns (string)",
  "function symbol() view returns (string)"
];

const ERC20_ABI = [
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)"
];

const MINIMUM_LIQUIDITY = 1000n;

type CliArgs = {
  amountUSDe?: string;
  amountUSDT0?: string;
};

function parseArgs(): CliArgs {
  const result: CliArgs = {};

  for (const arg of process.argv.slice(2)) {
    if (arg === "--help" || arg === "-h") {
      printUsage();
      process.exit(0);
    }

    if (arg.startsWith("--usde=")) {
      result.amountUSDe = arg.split("=")[1];
    } else if (arg.startsWith("--usdt0=")) {
      result.amountUSDT0 = arg.split("=")[1];
    } else {
      console.warn(`Unrecognized argument: ${arg}`);
    }
  }

  if (!result.amountUSDe && !result.amountUSDT0) {
    console.error("Provide at least one of --usde or --usdt0 (decimal values).");
    printUsage();
    process.exit(1);
  }

  return result;
}

function printUsage() {
  console.log(`Usage: tsx ts/liquidityPlanner.ts [--usde=AMOUNT] [--usdt0=AMOUNT]

Examples:
  RPC_URL=... tsx ts/liquidityPlanner.ts --usde=1000
  RPC_URL=... tsx ts/liquidityPlanner.ts --usdt0=1000
  RPC_URL=... tsx ts/liquidityPlanner.ts --usde=5000 --usdt0=5000
`);
}

function sqrtBigInt(value: bigint): bigint {
  if (value < 0n) {
    throw new Error("sqrtBigInt received negative value");
  }
  if (value < 2n) {
    return value;
  }

  // Newton's method
  let x0 = value / 2n;
  let x1 = (x0 + value / x0) / 2n;

  while (x1 < x0) {
    x0 = x1;
    x1 = (x0 + value / x0) / 2n;
  }

  return x0;
}

async function main() {
  const args = parseArgs();

  const pair = new ethers.Contract(ADDRS.pair, PAIR_ABI, provider);
  const [metadata, totalSupplyRaw, pairName, pairSymbol] = await Promise.all([
    pair.metadata(),
    pair.totalSupply(),
    pair.name(),
    pair.symbol()
  ]);

  const dec0 = metadata.dec0 as bigint;
  const dec1 = metadata.dec1 as bigint;
  const reserve0 = metadata.r0 as bigint;
  const reserve1 = metadata.r1 as bigint;
  const stable = metadata.st as boolean;
  const token0 = (metadata.t0 as string).toLowerCase();
  const token1 = (metadata.t1 as string).toLowerCase();
  const totalSupply = BigInt(totalSupplyRaw);

  const usdeIsToken0 = token0 === ADDRS.usde.toLowerCase();
  const reserveUSDe = usdeIsToken0 ? reserve0 : reserve1;
  const reserveUSDT0 = usdeIsToken0 ? reserve1 : reserve0;

  const usdeContract = new ethers.Contract(ADDRS.usde, ERC20_ABI, provider);
  const usdt0Contract = new ethers.Contract(ADDRS.usdt0, ERC20_ABI, provider);

  const [usdeDecimals, usdt0Decimals, usdeSymbol, usdt0Symbol] = await Promise.all([
    usdeContract.decimals(),
    usdt0Contract.decimals(),
    usdeContract.symbol(),
    usdt0Contract.symbol()
  ]);

  const parseUSDe = (value: string) => ethers.parseUnits(value, usdeDecimals);
  const parseUSDT0 = (value: string) => ethers.parseUnits(value, usdt0Decimals);

  let amountUSDe = args.amountUSDe ? parseUSDe(args.amountUSDe) : undefined;
  let amountUSDT0 = args.amountUSDT0 ? parseUSDT0(args.amountUSDT0) : undefined;

  if (amountUSDe === undefined && amountUSDT0 !== undefined) {
    if (reserveUSDT0 === 0n || reserveUSDe === 0n) {
      throw new Error("Pool has zero reserves, provide both token amounts manually.");
    }
    amountUSDe = (amountUSDT0 * reserveUSDe) / reserveUSDT0;
  } else if (amountUSDT0 === undefined && amountUSDe !== undefined) {
    if (reserveUSDe === 0n || reserveUSDT0 === 0n) {
      throw new Error("Pool has zero reserves, provide both token amounts manually.");
    }
    amountUSDT0 = (amountUSDe * reserveUSDT0) / reserveUSDe;
  }

  if (amountUSDe === undefined || amountUSDT0 === undefined) {
    throw new Error("Failed to determine both token amounts.");
  }

  // Validate ratio deviation if user supplied both amounts explicitly
  const expectedUSDT0 = reserveUSDe === 0n ? undefined : (amountUSDe * reserveUSDT0) / reserveUSDe;
  let ratioWarning: string | undefined;
  if (args.amountUSDe && args.amountUSDT0 && expectedUSDT0 !== undefined) {
    const diff = expectedUSDT0 > amountUSDT0 ? expectedUSDT0 - amountUSDT0 : amountUSDT0 - expectedUSDT0;
    if (diff > expectedUSDT0 / 100n) { // >1% deviation
      ratioWarning = "Provided token amounts deviate more than 1% from pool ratio; expect price movement.";
    }
  }

  const amount0 = usdeIsToken0 ? amountUSDe : amountUSDT0;
  const amount1 = usdeIsToken0 ? amountUSDT0 : amountUSDe;

  let mintedLP = 0n;
  if (totalSupply === 0n) {
    const product = amount0 * amount1;
    mintedLP = sqrtBigInt(product) - MINIMUM_LIQUIDITY;
  } else {
    const liquidity0 = reserve0 === 0n ? 0n : (amount0 * totalSupply) / reserve0;
    const liquidity1 = reserve1 === 0n ? 0n : (amount1 * totalSupply) / reserve1;
    mintedLP = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
  }

  if (mintedLP < 0n) {
    mintedLP = 0n;
  }

  const newReserveUSDe = reserveUSDe + amountUSDe;
  const newReserveUSDT0 = reserveUSDT0 + amountUSDT0;

  const shareBps = mintedLP === 0n && totalSupply === 0n
    ? 10_000n
    : (mintedLP * 10_000n) / (totalSupply + mintedLP);

  const formatUSDe = (value: bigint) => ethers.formatUnits(value, usdeDecimals);
  const formatUSDT0 = (value: bigint) => ethers.formatUnits(value, usdt0Decimals);
  const formatLP = (value: bigint) => ethers.formatUnits(value, 18);

  console.log(`Pair: ${pairName} (${pairSymbol})`);
  console.log(`Stable Pool: ${stable}`);
  console.log("Current reserves:");
  console.log(`- ${usdeSymbol}: ${formatUSDe(reserveUSDe)} (raw ${reserveUSDe.toString()})`);
  console.log(`- ${usdt0Symbol}: ${formatUSDT0(reserveUSDT0)} (raw ${reserveUSDT0.toString()})`);
  console.log("");

  console.log("Proposed deposit:");
  console.log(`- ${usdeSymbol}: ${formatUSDe(amountUSDe)} (raw ${amountUSDe.toString()})`);
  console.log(`- ${usdt0Symbol}: ${formatUSDT0(amountUSDT0)} (raw ${amountUSDT0.toString()})`);

  if (ratioWarning) {
    console.warn(`\n⚠️  ${ratioWarning}`);
  }

  console.log("\nPost-deposit reserves:");
  console.log(`- ${usdeSymbol}: ${formatUSDe(newReserveUSDe)}`);
  console.log(`- ${usdt0Symbol}: ${formatUSDT0(newReserveUSDT0)}`);

  console.log("\nMinted LP estimate:");
  console.log(`- LP Tokens Minted: ${formatLP(mintedLP)} (raw ${mintedLP.toString()})`);
  console.log(`- New Total Supply: ${formatLP(totalSupply + mintedLP)} (raw ${(totalSupply + mintedLP).toString()})`);
  console.log(`- Ownership Share: ${(Number(shareBps) / 100).toFixed(2)}%`);

  console.log("\nNotes:");
  console.log("- Deposits assume pool ratio is maintained; deviating amounts will move price.");
  console.log("- Minted LP is an estimate reflecting on-chain mint() math (ignoring rounding edge cases).");
  if (reserveUSDe === 0n || reserveUSDT0 === 0n) {
    console.log("- Pool currently holds ~zero liquidity; initial deposit will effectively set the price.");
  }
}

main().catch((error) => {
  console.error("\nLiquidity planner failed:", error);
  process.exit(1);
});
