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
  router: "0xD70962bd7C6B3567a8c893b55a8aBC1E151759f3",
  factory: "0x71a870D1c935C2146b87644DF3B5316e8756aE18",
  USDe: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
  USDT0: "0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb"
} as const;

const PAIR_ABI = [
  "function metadata() view returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)",
  "function totalSupply() view returns (uint256)",
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function balanceOf(address) view returns (uint256)"
];

const ERC20_ABI = [
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "function balanceOf(address) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)"
];

const ROUTER_ABI = [
  "function addLiquidity(address tokenA, address tokenB, bool stable, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity)",
  "function quoteAddLiquidity(address tokenA, address tokenB, bool stable, uint256 amountADesired, uint256 amountBDesired) view returns (uint256 amountA, uint256 amountB, uint256 liquidity)"
];

type CliArgs = {
  amountUSDe?: string;
  amountUSDT0?: string;
  wallet?: string;
  slippageBps: number;
  deadlineMinutes: number;
};

function parseArgs(): CliArgs {
  const args: CliArgs = { slippageBps: 50, deadlineMinutes: 20 };

  for (const raw of process.argv.slice(2)) {
    if (raw === "--help" || raw === "-h") {
      printUsage();
      process.exit(0);
    }
    const [key, value] = raw.split("=");
    switch (key) {
      case "--usde":
        args.amountUSDe = value;
        break;
      case "--usdt0":
        args.amountUSDT0 = value;
        break;
      case "--wallet":
        args.wallet = value;
        break;
      case "--slippage":
        args.slippageBps = Number(value);
        break;
      case "--deadline":
        args.deadlineMinutes = Number(value);
        break;
      default:
        console.warn(`Unrecognized argument: ${raw}`);
    }
  }

  if (!args.wallet) {
    console.error("Missing --wallet=<address> argument.");
    printUsage();
    process.exit(1);
  }

  if (!args.amountUSDe && !args.amountUSDT0) {
    console.error("Provide at least one of --usde or --usdt0.");
    printUsage();
    process.exit(1);
  }

  if (!ethers.isAddress(args.wallet)) {
    console.error(`Invalid wallet address: ${args.wallet}`);
    process.exit(1);
  }

  return args;
}

function printUsage() {
  console.log(`Usage: tsx ts/addLiquiditySim.ts --wallet=ADDRESS [--usde=AMOUNT] [--usdt0=AMOUNT] [--slippage=50] [--deadline=20]

Simulates addLiquidity quote and builds calldata for RouterV2.addLiquidity.
`);
}

async function main() {
  const args = parseArgs();
  const wallet = ethers.getAddress(args.wallet!);

  const pair = new ethers.Contract(ADDRS.pair, PAIR_ABI, provider);
  const router = new ethers.Contract(ADDRS.router, ROUTER_ABI, provider);
  const tokenUSDe = new ethers.Contract(ADDRS.USDe, ERC20_ABI, provider);
  const tokenUSDT0 = new ethers.Contract(ADDRS.USDT0, ERC20_ABI, provider);

  const [metadata, totalSupplyRaw, lpName, lpSymbol] = await Promise.all([
    pair.metadata(),
    pair.totalSupply(),
    pair.name(),
    pair.symbol()
  ]);

  const dec0 = metadata.dec0 as bigint;
  const dec1 = metadata.dec1 as bigint;
  const r0 = metadata.r0 as bigint;
  const r1 = metadata.r1 as bigint;
  const stable = metadata.st as boolean;
  const token0Addr = (metadata.t0 as string).toLowerCase();

  const usdeIsToken0 = token0Addr === ADDRS.USDe.toLowerCase();
  const reserveUSDe = usdeIsToken0 ? r0 : r1;
  const reserveUSDT0 = usdeIsToken0 ? r1 : r0;

  const [usdeDecimals, usdt0Decimals, usdeSymbol, usdt0Symbol, walletUSDeBal, walletUSDT0Bal, allowanceUSDe, allowanceUSDT0] =
    await Promise.all([
      tokenUSDe.decimals(),
      tokenUSDT0.decimals(),
      tokenUSDe.symbol(),
      tokenUSDT0.symbol(),
      tokenUSDe.balanceOf(wallet),
      tokenUSDT0.balanceOf(wallet),
      tokenUSDe.allowance(wallet, ADDRS.router),
      tokenUSDT0.allowance(wallet, ADDRS.router)
    ]);

  const parseUSDe = (value: string) => ethers.parseUnits(value, usdeDecimals);
  const parseUSDT0 = (value: string) => ethers.parseUnits(value, usdt0Decimals);

  let amountUSDe = args.amountUSDe ? parseUSDe(args.amountUSDe) : undefined;
  let amountUSDT0 = args.amountUSDT0 ? parseUSDT0(args.amountUSDT0) : undefined;

  if (amountUSDe === undefined && amountUSDT0 !== undefined) {
    if (reserveUSDe === 0n || reserveUSDT0 === 0n) {
      throw new Error("Pool has zero liquidity; specify both token amounts.");
    }
    amountUSDe = (amountUSDT0 * reserveUSDe) / reserveUSDT0;
  }
  if (amountUSDT0 === undefined && amountUSDe !== undefined) {
    if (reserveUSDe === 0n || reserveUSDT0 === 0n) {
      throw new Error("Pool has zero liquidity; specify both token amounts.");
    }
    amountUSDT0 = (amountUSDe * reserveUSDT0) / reserveUSDe;
  }

  if (amountUSDe === undefined || amountUSDT0 === undefined) {
    throw new Error("Unable to determine both token amounts.");
  }

  const amountADesired = usdeIsToken0 ? amountUSDe : amountUSDT0;
  const amountBDesired = usdeIsToken0 ? amountUSDT0 : amountUSDe;

  const [amountAQuoted, amountBQuoted, liquidityQuoted] = await router["quoteAddLiquidity"](
    ADDRS.USDe,
    ADDRS.USDT0,
    stable,
    amountUSDe,
    amountUSDT0
  ) as [bigint, bigint, bigint];

  const slippageBps = BigInt(args.slippageBps);
  const amountAMin = (amountAQuoted * (10_000n - slippageBps) + 9_999n) / 10_000n;
  const amountBMin = (amountBQuoted * (10_000n - slippageBps) + 9_999n) / 10_000n;

  const deadline = Math.floor(Date.now() / 1000 + args.deadlineMinutes * 60);

  const txData = router.interface.encodeFunctionData(
    "addLiquidity",
    [ADDRS.USDe, ADDRS.USDT0, stable, amountUSDe, amountUSDT0, amountAMin, amountBMin, wallet, deadline]
  );

  const lpBalanceBefore = await pair.balanceOf(wallet);
  const totalSupply = BigInt(totalSupplyRaw);
  const shareBps = totalSupply + liquidityQuoted === 0n
    ? 10_000n
    : (liquidityQuoted * 10_000n) / (totalSupply + liquidityQuoted);

  console.log(`Pair: ${lpName} (${lpSymbol})`);
  console.log(`Stable: ${stable}`);
  console.log("Current reserves (raw):", {
    USDe: reserveUSDe.toString(),
    USDT0: reserveUSDT0.toString()
  });
  console.log(`Desired deposit: ${ethers.formatUnits(amountUSDe, usdeDecimals)} ${usdeSymbol} + ${ethers.formatUnits(amountUSDT0, usdt0Decimals)} ${usdt0Symbol}`);

  console.log("\nRouter quote (post-ratio adjustment):");
  console.log(`- amountA (USDe): ${ethers.formatUnits(amountAQuoted, usdeDecimals)}`);
  console.log(`- amountB (USDT0): ${ethers.formatUnits(amountBQuoted, usdt0Decimals)}`);
  console.log(`- LP minted: ${ethers.formatUnits(liquidityQuoted, 18)}`);

  console.log("\nSlippage protections (bps):", args.slippageBps);
  console.log(`- amountAMin: ${ethers.formatUnits(amountAMin, usdeDecimals)}`);
  console.log(`- amountBMin: ${ethers.formatUnits(amountBMin, usdt0Decimals)}`);

  console.log("\nWallet state:");
  console.log(`- ${usdeSymbol} balance: ${ethers.formatUnits(walletUSDeBal, usdeDecimals)} (allowance ${ethers.formatUnits(allowanceUSDe, usdeDecimals)})`);
  console.log(`- ${usdt0Symbol} balance: ${ethers.formatUnits(walletUSDT0Bal, usdt0Decimals)} (allowance ${ethers.formatUnits(allowanceUSDT0, usdt0Decimals)})`);
  console.log(`- LP balance before: ${ethers.formatUnits(lpBalanceBefore, 18)}`);

  console.log("\nEstimated ownership share post-deposit:");
  console.log(`- Share ≈ ${(Number(shareBps) / 100).toFixed(4)}%`);

  console.log("\nTransaction preview:");
  console.log({
    to: ADDRS.router,
    data: txData,
    value: "0",
    deadline
  });

  console.log("\nNext steps:");
  console.log("1. Ensure allowances for both tokens >= desired amounts.");
  console.log("2. Submit the populated transaction from the provided wallet.");
}

main().catch((error) => {
  console.error("\nSimulation failed:", error);
  process.exit(1);
});
