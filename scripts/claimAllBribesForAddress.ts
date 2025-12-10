#!/usr/bin/env tsx
// Claim all voting rewards (internal + external bribes) for an owner address across ALL gauges
// Usage: tsx scripts/claimAllBribesForAddress.ts <owner_address>

import 'dotenv/config';
import { ethers } from 'ethers';
import fs from 'fs';

const RPC_URL = process.env.RPC_URL || '';
const OWNER_ADDR = (process.argv[2] || '').trim();

if (!RPC_URL) {
  console.error('Missing RPC_URL (set in .env)');
  process.exit(1);
}
if (!OWNER_ADDR) {
  console.error('Usage: tsx scripts/claimAllBribesForAddress.ts <owner_address>');
  process.exit(1);
}

const VOTER_ADDR = '0x2AF460a511849A7aA37Ac964074475b0E6249c69';

const VOTER_ABI = [
  'function length() view returns (uint256)',
  'function pools(uint256) view returns (address)',
  'function gauges(address) view returns (address)',
  'function internal_bribes(address) view returns (address)',
  'function external_bribes(address) view returns (address)',
];

const BRIBE_ABI = [
  'function rewardsListLength() view returns (uint256)',
  'function rewardTokens(uint256) view returns (address)',
  'function earned(address _owner, address _rewardToken) view returns (uint256)',
  'function getReward(address[] memory tokens)',
];

const ERC20_ABI = [
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function balanceOf(address) view returns (uint256)',
];

interface ClaimableReward {
  token: string;
  symbol: string;
  amount: string;
  amountFormatted: string;
  decimals: number;
  bribeBalance: string;
  isClaimable: boolean; // true if bribe has enough balance to pay out
}

interface BribeData {
  poolSymbol: string;
  poolAddr: string;
  gaugeAddr: string;
  bribeAddr: string;
  bribeType: 'internal' | 'external';
  rewardTokens: string[];
  claimableAmounts: ClaimableReward[];
}

function formatUnits(raw: bigint, decimals: number): string {
  if (decimals === 0) return raw.toString();
  const s = raw.toString().padStart(decimals + 1, '0');
  const i = s.length - decimals;
  const whole = s.slice(0, i);
  let frac = s.slice(i).replace(/0+$/, '');
  return frac.length ? `${whole}.${frac}` : whole;
}

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const voter = new ethers.Contract(VOTER_ADDR, VOTER_ABI, provider);

  const numPools = await voter.length();
  console.log(`Found ${numPools} pools/gauges`);
  console.log(`Checking claimable rewards for: ${OWNER_ADDR}\n`);

  const allBribes: BribeData[] = [];
  const claimableBribes: BribeData[] = [];

  for (let i = 0n; i < numPools; i++) {
    const poolAddr = await voter.pools(i);
    const gaugeAddr = await voter.gauges(poolAddr);

    if (gaugeAddr === ethers.ZeroAddress) continue;

    const intBribeAddr = await voter.internal_bribes(gaugeAddr);
    const extBribeAddr = await voter.external_bribes(gaugeAddr);

    // Get pool symbol
    let poolSymbol = 'UNKNOWN';
    try {
      const pool = new ethers.Contract(poolAddr, ERC20_ABI, provider);
      poolSymbol = await pool.symbol();
    } catch {}

    console.log(`[${Number(i)+1}/${numPools}] ${poolSymbol}`);

    // Check internal bribe
    if (intBribeAddr && intBribeAddr !== ethers.ZeroAddress) {
      const bribeData = await checkBribe(provider, poolSymbol, poolAddr, gaugeAddr, intBribeAddr, 'internal', OWNER_ADDR);
      if (bribeData) {
        allBribes.push(bribeData);
        if (bribeData.claimableAmounts.length > 0) {
          claimableBribes.push(bribeData);
        }
      }
    }

    // Check external bribe
    if (extBribeAddr && extBribeAddr !== ethers.ZeroAddress) {
      const bribeData = await checkBribe(provider, poolSymbol, poolAddr, gaugeAddr, extBribeAddr, 'external', OWNER_ADDR);
      if (bribeData) {
        allBribes.push(bribeData);
        if (bribeData.claimableAmounts.length > 0) {
          claimableBribes.push(bribeData);
        }
      }
    }
  }

  console.log('\n=== CLAIMABLE REWARDS SUMMARY ===\n');

  if (claimableBribes.length === 0) {
    console.log('No claimable rewards found.');
  } else {
    for (const bribe of claimableBribes) {
      console.log(`${bribe.poolSymbol} (${bribe.bribeType}):`);
      for (const reward of bribe.claimableAmounts) {
        const status = reward.isClaimable ? '✓' : '⚠️ SKIP (underfunded)';
        console.log(`  ${status} ${reward.amountFormatted} ${reward.symbol}`);
      }
    }
  }

  // Show skipped rewards summary
  const skippedRewards = claimableBribes.flatMap(b =>
    b.claimableAmounts.filter(c => !c.isClaimable).map(c => ({
      pool: b.poolSymbol,
      bribeType: b.bribeType,
      token: c.symbol,
      earned: c.amountFormatted,
      balance: formatUnits(BigInt(c.bribeBalance), c.decimals),
    }))
  );

  if (skippedRewards.length > 0) {
    console.log('\n=== SKIPPED REWARDS (underfunded bribes) ===\n');
    for (const r of skippedRewards) {
      console.log(`${r.pool} (${r.bribeType}): ${r.earned} ${r.token} (bribe balance: ${r.balance})`);
    }
  }

  // Generate Safe batch JSON for ALL bribes (even those with 0 claimable, to ensure we don't miss anything)
  const safeBatch = generateSafeBatch(allBribes, OWNER_ADDR);

  // Ensure safe-txs directory exists
  if (!fs.existsSync('safe-txs')) {
    fs.mkdirSync('safe-txs');
  }

  const filename = `safe-txs/safe.claim-bribes-${OWNER_ADDR.slice(0, 8)}.json`;
  fs.writeFileSync(filename, JSON.stringify(safeBatch, null, 2));
  console.log(`\nSafe batch JSON written to: ${filename}`);
  console.log(`Total transactions: ${safeBatch.transactions.length}`);

  // Output JSON summary
  const summary = {
    owner: OWNER_ADDR,
    totalBribesChecked: allBribes.length,
    claimableBribes: claimableBribes.length,
    claimableRewards: claimableBribes.flatMap(b => b.claimableAmounts.map(r => ({
      pool: b.poolSymbol,
      bribeType: b.bribeType,
      token: r.symbol,
      amount: r.amountFormatted,
    }))),
  };

  fs.writeFileSync(`safe-txs/claim-summary-${OWNER_ADDR.slice(0, 8)}.json`, JSON.stringify(summary, null, 2));
}

async function checkBribe(
  provider: ethers.JsonRpcProvider,
  poolSymbol: string,
  poolAddr: string,
  gaugeAddr: string,
  bribeAddr: string,
  bribeType: 'internal' | 'external',
  owner: string
): Promise<BribeData | null> {
  try {
    const bribe = new ethers.Contract(bribeAddr, BRIBE_ABI, provider);
    const numRewards = await bribe.rewardsListLength();

    const rewardTokens: string[] = [];
    const claimableAmounts: BribeData['claimableAmounts'] = [];

    for (let j = 0n; j < numRewards; j++) {
      try {
        const token = await bribe.rewardTokens(j);
        rewardTokens.push(token);

        const earned = await bribe.earned(owner, token);

        if (earned > 0n) {
          const erc20 = new ethers.Contract(token, ERC20_ABI, provider);
          let symbol = 'TOKEN';
          let decimals = 18;
          let bribeBalance = 0n;
          try {
            symbol = await erc20.symbol();
            decimals = Number(await erc20.decimals());
            bribeBalance = await erc20.balanceOf(bribeAddr);
          } catch {}

          // Check if bribe has enough balance to pay out
          const isClaimable = bribeBalance >= earned;

          claimableAmounts.push({
            token,
            symbol,
            amount: earned.toString(),
            amountFormatted: formatUnits(earned, decimals),
            decimals,
            bribeBalance: bribeBalance.toString(),
            isClaimable,
          });

          if (!isClaimable) {
            console.warn(`  ⚠️ UNDERFUNDED: ${symbol} earned=${formatUnits(earned, decimals)}, bribe balance=${formatUnits(bribeBalance, decimals)}`);
          }
        }
      } catch {}
    }

    return {
      poolSymbol,
      poolAddr,
      gaugeAddr,
      bribeAddr,
      bribeType,
      rewardTokens,
      claimableAmounts,
    };
  } catch {
    return null;
  }
}

function generateSafeBatch(bribes: BribeData[], owner: string) {
  // Group bribes by type and create batch transactions
  // We'll use Voter.claimBribes for external and Voter.claimFees for internal
  // ONLY include bribes that have actual claimable rewards AND sufficient balance
  // to avoid "transfer amount exceeds balance" errors

  // Filter to only include bribes that have at least one claimable token with sufficient balance
  const internalBribes = bribes
    .filter(b => b.bribeType === 'internal')
    .map(b => ({
      ...b,
      // Only keep tokens that are actually claimable (bribe has sufficient balance)
      claimableAmounts: b.claimableAmounts.filter(c => c.isClaimable)
    }))
    .filter(b => b.claimableAmounts.length > 0);

  const externalBribes = bribes
    .filter(b => b.bribeType === 'external')
    .map(b => ({
      ...b,
      claimableAmounts: b.claimableAmounts.filter(c => c.isClaimable)
    }))
    .filter(b => b.claimableAmounts.length > 0);

  const transactions: any[] = [];

  // Create claimFees transaction for internal bribes (LP fees)
  if (internalBribes.length > 0) {
    const bribeAddrs = internalBribes.map(b => b.bribeAddr);
    // Only include tokens that have claimable amounts (not all reward tokens)
    const tokenArrays = internalBribes.map(b => b.claimableAmounts.map(c => c.token));

    // Encode claimFees(address[] memory _fees, address[][] memory _tokens)
    const iface = new ethers.Interface([
      'function claimFees(address[] memory _fees, address[][] memory _tokens)',
    ]);
    const data = iface.encodeFunctionData('claimFees', [bribeAddrs, tokenArrays]);

    transactions.push({
      to: VOTER_ADDR,
      value: '0',
      data,
      contractMethod: {
        inputs: [
          { internalType: 'address[]', name: '_fees', type: 'address[]' },
          { internalType: 'address[][]', name: '_tokens', type: 'address[][]' },
        ],
        name: 'claimFees',
        payable: false,
      },
      contractInputsValues: {
        _fees: JSON.stringify(bribeAddrs),
        _tokens: JSON.stringify(tokenArrays),
      },
    });
  }

  // Create claimBribes transaction for external bribes
  if (externalBribes.length > 0) {
    const bribeAddrs = externalBribes.map(b => b.bribeAddr);
    // Only include tokens that have claimable amounts (not all reward tokens)
    const tokenArrays = externalBribes.map(b => b.claimableAmounts.map(c => c.token));

    // Encode claimBribes(address[] memory _bribes, address[][] memory _tokens)
    const iface = new ethers.Interface([
      'function claimBribes(address[] memory _bribes, address[][] memory _tokens)',
    ]);
    const data = iface.encodeFunctionData('claimBribes', [bribeAddrs, tokenArrays]);

    transactions.push({
      to: VOTER_ADDR,
      value: '0',
      data,
      contractMethod: {
        inputs: [
          { internalType: 'address[]', name: '_bribes', type: 'address[]' },
          { internalType: 'address[][]', name: '_tokens', type: 'address[][]' },
        ],
        name: 'claimBribes',
        payable: false,
      },
      contractInputsValues: {
        _bribes: JSON.stringify(bribeAddrs),
        _tokens: JSON.stringify(tokenArrays),
      },
    });
  }

  return {
    version: '1.0',
    chainId: '9745',
    createdAt: Date.now(),
    meta: {
      name: `Claim All Voting Rewards for ${owner.slice(0, 8)}...`,
      description: `Claim all internal (LP fees) and external bribes across ${bribes.length} bribe contracts for address ${owner}`,
      txBuilderVersion: '1.16.5',
    },
    transactions,
  };
}

main().catch((e) => { console.error(e); process.exit(1); });
