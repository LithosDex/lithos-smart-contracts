#!/usr/bin/env tsx
// Fetch RewardsDistributor.claimable for a given veNFT tokenId.

import 'dotenv/config';
import { readFileSync } from 'fs';
import { join } from 'path';
import { ethers } from 'ethers';

const RPC_URL = process.env.RPC_URL || 'https://plasma-mainnet.g.alchemy.com/v2/HBBqcp1MCr0wy49fuWDka';
const TOKEN_ID = process.env.VE_ID || '70';

type Deploys = { [k: string]: string };

function loadRewardsDistributor(): string {
  try {
    const p = join(process.cwd(), 'deployments', 'mainnet', 'state.json');
    const j = JSON.parse(readFileSync(p, 'utf8')) as Deploys;
    if (j && j.RewardsDistributor) return j.RewardsDistributor;
  } catch {}
  throw new Error('RewardsDistributor address not found in deployments/mainnet/state.json');
}

const RD_ABI = [
  'function claimable(uint256 tokenId) view returns (uint256)',
  'function token() view returns (address)'
];

const ERC20_ABI = [
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)'
];

function formatUnits(raw: bigint, decimals: number): string {
  if (decimals === 0) return raw.toString();
  const s = raw.toString().padStart(decimals + 1, '0');
  const i = s.length - decimals;
  const whole = s.slice(0, i);
  let frac = s.slice(i).replace(/0+$/, '');
  return frac.length ? `${whole}.${frac}` : whole;
}

async function main() {
  if (!RPC_URL) throw new Error('RPC_URL not set');
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const rd = loadRewardsDistributor();
  const rdC = new ethers.Contract(rd, RD_ABI, provider);

  const [raw, tokenAddr] = await Promise.all([
    rdC.claimable(BigInt(TOKEN_ID)),
    rdC.token().catch(() => ethers.ZeroAddress)
  ]);

  let symbol = 'LITH';
  let decimals = 18;
  if (tokenAddr && tokenAddr !== ethers.ZeroAddress) {
    try {
      const t = new ethers.Contract(tokenAddr, ERC20_ABI, provider);
      const [sym, dec] = await Promise.all([
        t.symbol().catch(() => 'TOKEN'),
        t.decimals().catch(() => 18),
      ]);
      symbol = sym;
      decimals = Number(dec);
    } catch {}
  }

  const out = {
    veNFT: TOKEN_ID,
    rewardsDistributor: rd,
    token: tokenAddr,
    symbol,
    claimable: raw.toString(),
    claimableFormatted: formatUnits(raw as bigint, decimals),
  };
  console.log(JSON.stringify(out, null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
