import { config as loadEnv } from "dotenv";
import {
  createPublicClient,
  createWalletClient,
  defineChain,
  formatEther,
  http,
  parseEther,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

type Mode = "wrap" | "unwrap";

type CliArgs = {
  mode: Mode;
  amount: string;
};

loadEnv();

const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}` | undefined;

if (!RPC_URL) {
  console.error("Missing RPC_URL env var. Set it in .env before running this script.");
  process.exit(1);
}

if (!PRIVATE_KEY) {
  console.error("Missing PRIVATE_KEY env var. Set it in .env before running this script.");
  process.exit(1);
}

const plasmaMainnet = defineChain({
  id: 9745,
  name: "Plasma Mainnet",
  network: "plasma-mainnet",
  nativeCurrency: {
    name: "Plasma",
    symbol: "XPL",
    decimals: 18
  },
  rpcUrls: {
    default: { http: [RPC_URL] },
    public: { http: [RPC_URL] }
  },
  blockExplorers: {
    default: { name: "Plasmascan", url: "https://plasmascan.to" }
  }
});

const WXPL_ADDRESS = "0x6100E367285b01F48D07953803A2d8dCA5D19873"; // Wrapped XPL (WETH9-compatible)

const account = privateKeyToAccount(PRIVATE_KEY);

const walletClient = createWalletClient({
  account,
  chain: plasmaMainnet,
  transport: http(RPC_URL)
});

const publicClient = createPublicClient({
  chain: plasmaMainnet,
  transport: http(RPC_URL)
});

function parseArgs(): CliArgs {
  const [mode, amount] = process.argv.slice(2);

  if (mode !== "wrap" && mode !== "unwrap") {
    printUsage();
    console.error("First argument must be either 'wrap' or 'unwrap'.");
    process.exit(1);
  }

  if (!amount) {
    printUsage();
    console.error("Second argument must be the amount of XPL/WXPL (as a decimal string).");
    process.exit(1);
  }

  return { mode, amount };
}

function printUsage() {
  console.log(`Usage: tsx ts/wrapUnwrapWeth.ts <wrap|unwrap> <amount>

Examples (Plasma mainnet):
  RPC_URL=... PRIVATE_KEY=... tsx ts/wrapUnwrapWeth.ts wrap 0.5
  RPC_URL=... PRIVATE_KEY=... tsx ts/wrapUnwrapWeth.ts unwrap 1.2
`);
}

async function getBalances() {
  const [wxplBalance, nativeBalance] = await Promise.all([
    publicClient.readContract({
      abi: wethAbi,
      address: WXPL_ADDRESS,
      functionName: "balanceOf",
      args: [account.address]
    }),
    publicClient.getBalance({
      address: account.address
    })
  ]);

  return {
    wxpl: formatEther(wxplBalance),
    xpl: formatEther(nativeBalance)
  };
}

async function wrap(amount: bigint) {
  console.log(`Wrapping ${formatEther(amount)} XPL into WXPL...`);

  const hash = await walletClient.writeContract({
    abi: wethAbi,
    address: WXPL_ADDRESS,
    functionName: "deposit",
    value: amount
  });

  console.log(`Submitted deposit tx: ${hash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Wrap confirmed in block ${receipt.blockNumber}`);
}

async function unwrap(amount: bigint) {
  console.log(`Unwrapping ${formatEther(amount)} WXPL back to XPL...`);

  const hash = await walletClient.writeContract({
    abi: wethAbi,
    address: WXPL_ADDRESS,
    functionName: "withdraw",
    args: [amount]
  });

  console.log(`Submitted withdraw tx: ${hash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`Unwrap confirmed in block ${receipt.blockNumber}`);
}

async function main() {
  const args = parseArgs();
  const amount = parseEther(args.amount);

  console.log("Target chain: Plasma Mainnet (chain id 9745)");
  console.log(`Using Plasma mainnet wallet ${account.address}`);
  console.log(`Current balances before tx:`);
  console.log(await getBalances());

  if (args.mode === "wrap") {
    await wrap(amount);
  } else {
    await unwrap(amount);
  }

  console.log("Balances after tx:");
  console.log(await getBalances());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
