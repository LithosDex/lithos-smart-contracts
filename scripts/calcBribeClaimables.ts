#!/usr/bin/env tsx
// Query claimable bribes for a veNFT via on-chain calls, guided by subgraph for bribe discovery.

import 'dotenv/config';
import { ethers } from 'ethers';
import BribesAbi from '../subgraph/abis/Bribes.json';
import ERC20Abi from '../subgraph/abis/ERC20.json';

const ENDPOINT = 'https://api.goldsky.com/api/public/project_cmfuu39qbys1j01009omjbmts/subgraphs/lithos-subgraph-mainnet/v1.0.6/gn';
const RPC_URL = process.env.RPC_URL || 'https://plasma-mainnet.g.alchemy.com/v2/HBBqcp1MCr0wy49fuWDka';
const VE_ID = '70';

const BRIBES_ABI = BribesAbi as any;
const ERC20_ABI = ERC20Abi as any;

type GqlResp = {
  data: {
    bribeStakes: Array<{ bribe: { id: string } }>,
    bribes: Array<{ id: string; type: string }>
  }
}

async function gql(query: string, variables?: any) {
  const r = await fetch(ENDPOINT, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ query, variables }),
  });
  if (!r.ok) throw new Error(`Subgraph HTTP ${r.status}`);
  return r.json();
}

function uniq<T>(arr: T[]): T[] { return [...new Set(arr)]; }

function formatUnits(raw: bigint, decimals: number): string {
  if (decimals === 0) return raw.toString();
  const s = raw.toString().padStart(decimals + 1, '0');
  const i = s.length - decimals;
  const whole = s.slice(0, i);
  let frac = s.slice(i).replace(/0+$/, '');
  return frac.length ? `${whole}.${frac}` : whole;
}

async function main() {
  // 1) Find bribes where this veNFT has staked
  const QUERY = `
    query Q($ve: String!) {
      bribeStakes(first: 1000, where:{ veNFT: $ve }){ bribe { id } }
    }
  `;
  const { data } = (await gql(QUERY, { ve: VE_ID })) as GqlResp;
  const bribeIds = uniq((data.bribeStakes || []).map(s => s.bribe.id.toLowerCase()));

  if (bribeIds.length === 0) {
    console.log(JSON.stringify({ veNFT: VE_ID, claimables: [] }, null, 2));
    return;
  }

  // 2) Get bribe types for labeling
  const BRIBES_QUERY = `
    query QB($ids: [ID!]!) { bribes(where:{ id_in: $ids }) { id type } }
  `;
  const bribesMeta: Record<string, string> = {};
  try {
    const meta = (await gql(BRIBES_QUERY, { ids: bribeIds })) as GqlResp;
    for (const b of meta.data.bribes || []) bribesMeta[b.id.toLowerCase()] = b.type;
  } catch {}

  // 3) For each bribe, enumerate reward tokens and call earned(token, veId)
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  const results: any[] = [];
  for (const addr of bribeIds) {
    try {
      const bribe = new ethers.Contract(addr, BRIBES_ABI, provider);
      const n: bigint = await bribe.rewardsListLength();
      const tokens: string[] = [];
      for (let i = 0n; i < n; i++) {
        const t: string = await bribe.rewards(i);
        tokens.push(t.toLowerCase());
      }

      const tokenEntries: any[] = [];
      for (const t of tokens) {
        try {
          const amt: bigint = await bribe.earned(t, BigInt(VE_ID));
          if (amt === 0n) continue;
          const erc20 = new ethers.Contract(t, ERC20_ABI, provider);
          const [symbol, decimals] = await Promise.all([
            erc20.symbol().catch(() => 'TOKEN'),
            erc20.decimals().catch(() => 18),
          ]);
          tokenEntries.push({
            token: t,
            symbol,
            decimals,
            amount: amt.toString(),
            amountFormatted: formatUnits(amt, Number(decimals)),
          });
        } catch (e) {
          // ignore token error
        }
      }

      if (tokenEntries.length) {
        results.push({
          bribe: addr,
          type: bribesMeta[addr] || 'unknown',
          rewards: tokenEntries,
        });
      }
    } catch (e) {
      // ignore bribe error
    }
  }

  console.log(JSON.stringify({ veNFT: VE_ID, claimables: results }, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
