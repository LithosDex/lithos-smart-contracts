#!/usr/bin/env tsx
// Enumerate claimable bribes for a veNFT fully on-chain (no subgraph)

import 'dotenv/config';
import { ethers } from 'ethers';
import VoterAbi from '../subgraph/abis/VoterV3.json';
import PairFactoryAbi from '../subgraph/abis/PairFactory.json';
// Use a minimal, correct ABI for Bribes to avoid signature/order mismatch in subgraph ABI
const BRIBE_MIN_ABI = [
  { type: 'function', name: 'rewardsListLength', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
  { type: 'function', name: 'rewardTokens', stateMutability: 'view', inputs: [{ name: '', type: 'uint256' }], outputs: [{ name: '', type: 'address' }] },
  { type: 'function', name: 'earned', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }, { name: '_rewardToken', type: 'address' }], outputs: [{ name: '', type: 'uint256' }] },
  { type: 'function', name: 'earned', stateMutability: 'view', inputs: [{ name: '_owner', type: 'address' }, { name: '_rewardToken', type: 'address' }], outputs: [{ name: '', type: 'uint256' }] },
];
import ERC20Abi from '../subgraph/abis/ERC20.json';
import fs from 'fs';

const RPC_URL = process.env.RPC_URL || '';
const TOKEN_ID = (process.env.VE_ID || process.argv[2] || '').trim();
const OWNER_ADDR = (process.env.OWNER || process.argv[3] || '').trim().toLowerCase();

if (!RPC_URL) {
  console.error('Missing RPC_URL (set in .env)');
  process.exit(1);
}
if (!TOKEN_ID) {
  console.error('Usage: tsx scripts/calcVeBribeClaimablesOnchain.ts <veNFT_id> [owner_address]');
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
  const s = raw.toString().padStart(decimals + 1, '0');
  const i = s.length - decimals;
  const whole = s.slice(0, i);
  let frac = s.slice(i).replace(/0+$/, '');
  return frac.length ? `${whole}.${frac}` : whole;
}

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const voterAddr = readDeployment('Voter');
  const voter = new ethers.Contract(voterAddr, VoterAbi as any, provider);

  const id = BigInt(TOKEN_ID);
  const pools: string[] = [];
  try {
    const len: bigint = await voter.poolVoteLength(id);
    for (let i = 0n; i < len; i++) {
      const p: string = await voter.poolVote(id, i);
      pools.push(p.toLowerCase());
    }
  } catch {}

  // Also enumerate all pairs from the factory to find any historical bribes
  let factoryAddr: string | undefined;
  try { factoryAddr = await voter.factory(); } catch {}
  if (!factoryAddr) {
    try { factoryAddr = readDeployment('PairFactoryUpgradeable'); } catch {}
  }

  if (factoryAddr) {
    const factory = new ethers.Contract(factoryAddr, PairFactoryAbi as any, provider);
    try {
      const n: bigint = await factory.allPairsLength();
      for (let i = 0n; i < n; i++) {
        try {
          const p: string = await factory.allPairs(i);
          pools.push(p.toLowerCase());
        } catch {}
      }
    } catch {}
  }

  // dedupe pools
  const seen: Record<string, boolean> = {};
  const uniquePools = pools.filter(p => (seen[p] ? false : (seen[p] = true)));

  const results: any[] = [];
  for (const pair of uniquePools) {
    try {
      const gauge: string = await voter.gauges(pair);
      if (!gauge || gauge === ethers.ZeroAddress) continue;
      const extBribe: string = await voter.external_bribes(gauge);
      const intBribe: string = await voter.internal_bribes(gauge);

      for (const [bribeAddr, kind] of [[extBribe, 'external'] as const, [intBribe, 'internal'] as const]) {
        if (!bribeAddr || bribeAddr === ethers.ZeroAddress) continue;
        const bribe = new ethers.Contract(bribeAddr, BRIBE_MIN_ABI as any, provider);
        const n: bigint = await bribe.rewardsListLength();
        const rewards: any[] = [];
        for (let i = 0n; i < n; i++) {
          try {
            // Prefer rewardTokens() over rewards() for compatibility
            const token: string = await (bribe as any).rewardTokens(i);
            // Explicitly call both overloads with correct arg order
            const amtTokenId: bigint = await (bribe as any)["earned(uint256,address)"](id, token);
            const amtOwner: bigint = OWNER_ADDR ? await (bribe as any)["earned(address,address)"](OWNER_ADDR, token) : 0n;
            if (amtTokenId === 0n && amtOwner === 0n) continue;
            const erc20 = new ethers.Contract(token, ERC20Abi as any, provider);
            const [symbol, decimals] = await Promise.all([
              erc20.symbol().catch(()=>'TOKEN'),
              erc20.decimals().then((d:number)=>Number(d)).catch(()=>18),
            ]);
            rewards.push({
              token: token.toLowerCase(),
              symbol,
              decimals,
              amountTokenId: amtTokenId.toString(),
              amountTokenIdFormatted: formatUnits(amtTokenId, decimals),
              amountOwner: amtOwner.toString(),
              amountOwnerFormatted: formatUnits(amtOwner, decimals),
            });
          } catch {}
        }
        if (rewards.length) {
          results.push({ pair, gauge: gauge.toLowerCase(), bribe: bribeAddr.toLowerCase(), kind, rewards });
        }
      }
    } catch {}
  }

  console.log(JSON.stringify({ veNFT: TOKEN_ID, claimables: results }, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
