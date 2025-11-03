#!/usr/bin/env tsx
// Compute expected next-epoch voting rewards for a veNFT across all pairs.
// This mirrors RewardAPI.getExpectedClaimForNextEpoch but runs fully client-side.

import 'dotenv/config';
import { ethers } from 'ethers';
import fs from 'fs';
import VoterAbi from '../subgraph/abis/VoterV3.json';
import PairFactoryAbi from '../subgraph/abis/PairFactory.json';
import ERC20Abi from '../subgraph/abis/ERC20.json';

// Minimal Bribe ABI surface used here
const BRIBE_ABI = [
  { type: 'function', name: 'getEpochStart', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'totalSupplyAt', stateMutability: 'view', inputs: [{ type: 'uint256' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'balanceOfAt', stateMutability: 'view', inputs: [{ type: 'uint256' }, { type: 'uint256' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'rewardsListLength', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'rewardTokens', stateMutability: 'view', inputs: [{ type: 'uint256' }], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'rewardData', stateMutability: 'view', inputs: [{ type: 'address' }, { type: 'uint256' }], outputs: [
    { components: [
      { name: 'periodFinish', type: 'uint256' },
      { name: 'rewardsPerEpoch', type: 'uint256' },
      { name: 'lastUpdateTime', type: 'uint256' },
    ], type: 'tuple' }
  ] },
];

const RPC_URL = process.env.RPC_URL || '';
const TOKEN_ID = (process.env.VE_ID || process.argv[2] || '').trim();

if (!RPC_URL) {
  console.error('Missing RPC_URL (set in .env)');
  process.exit(1);
}
if (!TOKEN_ID) {
  console.error('Usage: tsx scripts/calcVeExpectedBribes.ts <veNFT_id>');
  process.exit(1);
}

function readDeployment(key: string): string {
  const raw = fs.readFileSync('deployments/mainnet/state.json', 'utf8');
  const obj = JSON.parse(raw);
  const addr = obj[key];
  if (!addr) throw new Error(`Address for ${key} not found in deployments/mainnet/state.json`);
  return addr;
}

function formatUnits(raw: bigint, decimals: number): string {
  if (decimals === 0) return raw.toString();
  const neg = raw < 0n;
  const n = neg ? -raw : raw;
  const s = n.toString().padStart(decimals + 1, '0');
  const i = s.length - decimals;
  const whole = s.slice(0, i);
  let frac = s.slice(i).replace(/0+$/, '');
  const out = frac.length ? `${whole}.${frac}` : whole;
  return neg ? `-${out}` : out;
}

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const voterAddr = readDeployment('Voter');
  const factoryAddr = readDeployment('PairFactoryUpgradeable');

  const voter = new ethers.Contract(voterAddr, VoterAbi as any, provider);
  const factory = new ethers.Contract(factoryAddr, PairFactoryAbi as any, provider);

  const id = BigInt(TOKEN_ID);

  // Fetch all pairs
  const pairs: string[] = [];
  const nPairs: bigint = await factory.allPairsLength();
  for (let i = 0n; i < nPairs; i++) {
    const p: string = await factory.allPairs(i);
    pairs.push(p);
  }

  // For each pair, resolve gauge and its internal/external bribes
  type RewardRow = {
    kind: 'external' | 'internal';
    bribe: string;
    token: string;
    symbol: string;
    decimals: number;
    amount: bigint; // expected at next flip
  };

  const rows: RewardRow[] = [];

  for (const pair of pairs) {
    try {
      const gauge: string = await voter.gauges(pair);
      if (!gauge || gauge === ethers.ZeroAddress) continue;
      const [ext, intb] = await Promise.all([
        voter.external_bribes(gauge),
        voter.internal_bribes(gauge),
      ]);
      for (const [bribeAddr, kind] of [[ext, 'external'] as const, [intb, 'internal'] as const]) {
        if (!bribeAddr || bribeAddr === ethers.ZeroAddress) continue;
        const bribe = new ethers.Contract(bribeAddr, BRIBE_ABI as any, provider);
        const ts: bigint = await bribe.getEpochStart();
        const [supply, balance, listLen] = await Promise.all([
          bribe.totalSupplyAt(ts),
          bribe.balanceOfAt(id, ts),
          bribe.rewardsListLength(),
        ]);
        if (balance === 0n || listLen === 0n) continue;
        for (let i = 0n; i < listLen; i++) {
          const token: string = await bribe.rewardTokens(i);
          const [_, rpe, __] = await bribe.rewardData(token, ts);
          if (rpe === 0n || supply === 0n) continue;
          // amount = rewardsPerEpoch * balance / supply
          const amt = (rpe * balance) / supply;
          if (amt === 0n) continue;
          const erc20 = new ethers.Contract(token, ERC20Abi as any, provider);
          const [symbol, decimals] = await Promise.all([
            erc20.symbol().catch(() => 'TOKEN'),
            erc20.decimals().catch(() => 18),
          ]);
          rows.push({ kind, bribe: bribeAddr, token, symbol, decimals: Number(decimals), amount: amt });
        }
      }
    } catch {
      // ignore per-pair errors
    }
  }

  // Aggregate totals per token (address)
  const totals: Record<string, { symbol: string; decimals: number; amount: bigint }> = {};
  for (const r of rows) {
    const key = r.token.toLowerCase();
    if (!totals[key]) totals[key] = { symbol: r.symbol, decimals: r.decimals, amount: 0n };
    totals[key].amount += r.amount;
  }

  // Shape output
  // Resolve epochStart from any seen bribe (if none, it stays 0)
  let epochStart = 0n;
  if (rows.length) {
    try {
      const br = new ethers.Contract(rows[0].bribe, BRIBE_ABI as any, provider);
      epochStart = await br.getEpochStart();
    } catch {}
  }

  const out = {
    veNFT: TOKEN_ID,
    epochStart: Number(epochStart),
    rewards: rows.map(r => ({
      kind: r.kind,
      bribe: r.bribe.toLowerCase(),
      token: r.token.toLowerCase(),
      symbol: r.symbol,
      decimals: r.decimals,
      amount: r.amount.toString(),
      amountFormatted: formatUnits(r.amount, r.decimals),
    })),
    totals: Object.entries(totals).map(([token, v]) => ({
      token,
      symbol: v.symbol,
      decimals: v.decimals,
      amount: v.amount.toString(),
      amountFormatted: formatUnits(v.amount, v.decimals),
    }))
  };

  console.log(JSON.stringify(out, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
