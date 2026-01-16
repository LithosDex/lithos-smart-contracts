import { config as loadEnv } from "dotenv";
import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

loadEnv();

// Contract addresses
const LITHOS_TOKEN = "0xAbB48792A3161E81B47cA084c0b7A22a50324A44";
const VOTING_ESCROW = "0x2Eff716Caa7F9EB441861340998B0952AF056686";
const CHAIN_ID = "9745";

// Lock duration constants (in seconds)
const LOCK_DURATIONS = {
  "2years": 63_072_000,
  "1year": 31_536_000,
  "6months": 15_768_000,
  "3months": 7_884_000,
  "1month": 2_628_000,
  "1week": 604_800,
} as const;

type LockDuration = keyof typeof LOCK_DURATIONS;

interface Recipient {
  address: string;
  amount: bigint; // in wei
  amountHuman: number; // in tokens
}

interface SafeTransaction {
  to: string;
  value: string;
  data: string;
  contractMethod: {
    inputs: Array<{
      internalType: string;
      name: string;
      type: string;
    }>;
    name: string;
    payable: boolean;
  };
  contractInputsValues: Record<string, string>;
}

interface SafeBatch {
  version: string;
  chainId: string;
  createdAt: number;
  meta: {
    name: string;
    description: string;
    txBuilderVersion: string;
  };
  transactions: SafeTransaction[];
}

function parseRecipients(input: string): Recipient[] {
  const lines = input.trim().split("\n").filter((line) => line.trim());
  return lines.map((line) => {
    const parts = line.trim().split(/[\s,]+/).filter((p) => p);
    if (parts.length < 2) {
      throw new Error(`Invalid line: ${line}`);
    }
    const address = parts[0];
    const amountHuman = parseFloat(parts[1]);
    if (!ethers.isAddress(address)) {
      throw new Error(`Invalid address: ${address}`);
    }
    if (isNaN(amountHuman) || amountHuman <= 0) {
      throw new Error(`Invalid amount for ${address}: ${parts[1]}`);
    }
    return {
      address,
      amount: ethers.parseUnits(amountHuman.toString(), 18),
      amountHuman,
    };
  });
}

function generateApproveCalldata(amount: bigint): string {
  const iface = new ethers.Interface([
    "function approve(address spender, uint256 amount)",
  ]);
  return iface.encodeFunctionData("approve", [VOTING_ESCROW, amount]);
}

function generateCreateLockForCalldata(
  value: bigint,
  duration: number,
  to: string
): string {
  const iface = new ethers.Interface([
    "function create_lock_for(uint256 _value, uint256 _lock_duration, address _to)",
  ]);
  return iface.encodeFunctionData("create_lock_for", [value, duration, to]);
}

function buildApproveTransaction(totalAmount: bigint): SafeTransaction {
  return {
    to: LITHOS_TOKEN,
    value: "0",
    data: generateApproveCalldata(totalAmount),
    contractMethod: {
      inputs: [
        { internalType: "address", name: "spender", type: "address" },
        { internalType: "uint256", name: "amount", type: "uint256" },
      ],
      name: "approve",
      payable: false,
    },
    contractInputsValues: {
      spender: VOTING_ESCROW,
      amount: totalAmount.toString(),
    },
  };
}

function buildCreateLockForTransaction(
  recipient: Recipient,
  durationSeconds: number
): SafeTransaction {
  return {
    to: VOTING_ESCROW,
    value: "0",
    data: generateCreateLockForCalldata(
      recipient.amount,
      durationSeconds,
      recipient.address
    ),
    contractMethod: {
      inputs: [
        { internalType: "uint256", name: "_value", type: "uint256" },
        { internalType: "uint256", name: "_lock_duration", type: "uint256" },
        { internalType: "address", name: "_to", type: "address" },
      ],
      name: "create_lock_for",
      payable: false,
    },
    contractInputsValues: {
      _value: recipient.amount.toString(),
      _lock_duration: durationSeconds.toString(),
      _to: recipient.address,
    },
  };
}

function generateSafeBatch(
  recipients: Recipient[],
  lockDuration: LockDuration
): SafeBatch {
  const durationSeconds = LOCK_DURATIONS[lockDuration];
  const totalAmount = recipients.reduce((sum, r) => sum + r.amount, 0n);
  const totalHuman = recipients.reduce((sum, r) => sum + r.amountHuman, 0);

  const transactions: SafeTransaction[] = [
    buildApproveTransaction(totalAmount),
    ...recipients.map((r) => buildCreateLockForTransaction(r, durationSeconds)),
  ];

  const durationLabel = lockDuration.replace("years", " years").replace("year", " year")
    .replace("months", " months").replace("month", " month").replace("week", " week");

  const recipientList = recipients
    .map((r) => `  - ${r.address}: ${r.amountHuman.toLocaleString()} LITHOS`)
    .join("\n");

  return {
    version: "1.0",
    chainId: CHAIN_ID,
    createdAt: Math.floor(Date.now() / 1000),
    meta: {
      name: `Distribute veLITH to ${recipients.length} recipients`,
      description: `Lock ${totalHuman.toLocaleString()} LITHOS tokens for ${durationLabel} and distribute veNFTs to ${recipients.length} addresses.\n\nRecipients:\n${recipientList}`,
      txBuilderVersion: "1.16.5",
    },
    transactions,
  };
}

function saveBatch(batch: SafeBatch, filename?: string): string {
  const safeTxsDir = path.join(process.cwd(), "safe-txs");
  if (!fs.existsSync(safeTxsDir)) {
    fs.mkdirSync(safeTxsDir, { recursive: true });
  }

  const outputFile = filename ?? `safe.distribute-velith-${batch.createdAt}.json`;
  const outputPath = path.join(safeTxsDir, outputFile);
  fs.writeFileSync(outputPath, JSON.stringify(batch, null, 2));
  return outputPath;
}

// Main execution
async function main() {
  // Default recipient list - can be customized
  const recipientInput = `
0x1c3354d276b49fe8941a09b822a9100d50e88727    46879
0x1cf8da0110f4cb8924aa4eba7ef3a04430897c05    2017
0x3dd51e24fca00c33c2e5a74e5c373a705b749fa0    259702
0x5e75d8a59bba836bee68b91073b7106a296b3be5    33341
0x5f7b8841489969d3c0abf56a339571bb4076d840    7895
0x7480fcee78db93f9ac3df95dca9459a82b8e7718    28569
0x7b94d5a96e52b3109764a0a4fe80e741c5fa14fd    9055
0x975a03ffccbdb080655952eae6b608931a84a7cb    36363
0xb9413036fc903350d37008113caf3a25adcd5343    21889
0xb9c0aba138b98656ffea4309bfe2881b0b7c1d96    183052
0xbbac86f386c4ca388d74752fff5999343cc88888    78600
0xeef9ff72ce27a25eb0b4e45e1459990eb88990ef    9132
0xf37443d22712dbe250a9be0d2295b4ea4aa646a6    26885
0xf93e3b13103a22b49d272a8b638da0acfe79edd7    147000
`;

  const lockDuration: LockDuration = "2years";

  console.log("Parsing recipients...");
  const recipients = parseRecipients(recipientInput);

  const totalAmount = recipients.reduce((sum, r) => sum + r.amount, 0n);
  const totalHuman = recipients.reduce((sum, r) => sum + r.amountHuman, 0);

  console.log(`\nRecipients: ${recipients.length}`);
  console.log(`Total LITHOS: ${totalHuman.toLocaleString()}`);
  console.log(`Lock duration: ${lockDuration}`);

  console.log("\nRecipient breakdown:");
  for (const r of recipients) {
    console.log(`  ${r.address}: ${r.amountHuman.toLocaleString()} LITHOS`);
  }

  console.log("\nGenerating Safe batch...");
  const batch = generateSafeBatch(recipients, lockDuration);

  console.log(`\nTransactions: ${batch.transactions.length}`);
  console.log("  1x approve()");
  console.log(`  ${recipients.length}x create_lock_for()`);

  const outputPath = saveBatch(batch);
  console.log(`\nSaved to: ${outputPath}`);
  console.log("\nImport this file into Safe Transaction Builder to execute.");
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});

export {
  parseRecipients,
  generateSafeBatch,
  saveBatch,
  LOCK_DURATIONS,
  type LockDuration,
  type Recipient,
  type SafeBatch,
};
