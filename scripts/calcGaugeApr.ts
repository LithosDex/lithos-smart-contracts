#!/usr/bin/env tsx
// Calculates Gauge APR in LITH terms for a given LP pair (staking token).
// Fully hardcoded: endpoint, pair, LITH address, and XPL/USDT price.

import 'dotenv/config';

type GaugeResp = {
  data: {
    gauges: Array<{
      id: string;
      rewardRate: string;
      periodFinish: string;
      totalStaked: string;
      rewardToken: { id: string; symbol: string; decimals: string };
      stakingToken: { id: string; decimals: string };
    }>;
    pair: {
      id: string;
      token0: { id: string; symbol: string; decimals: string };
      token1: { id: string; symbol: string; decimals: string };
      reserve0: string;
      reserve1: string;
      totalSupply: string;
      stable: boolean;
    } | null;
  };
};

const ENDPOINT = 'https://api.goldsky.com/api/public/project_cmfuu39qbys1j01009omjbmts/subgraphs/lithos-subgraph-mainnet/v1.0.4/gn';
const PAIR_ID = '0x7dab98cc51835beae6dee43bbda84cdb96896fb5'; // WXPL/LITH
const LITH_ADDRESS = '0xabb48792a3161e81b47ca084c0b7a22a50324a44';
const XPL_USDT_PRICE = 0.48; // Manual XPL price in USDT

// In this protocol, gauge emissions paid via Voter/Minter are LITH.
// Treat reward token as LITH even if the gauge's rewardToken() returns address(0).
const REWARD_TOKEN_IS_LITH = true;

function pct(n: number): string {
  if (!isFinite(n)) return '0%';
  return (n * 100).toFixed(2) + '%';
}

async function main() {
  const endpoint = ENDPOINT;
  const pair = PAIR_ID;
  const now = Math.floor(Date.now() / 1000);
  const lithAddress = LITH_ADDRESS.toLowerCase();
  const xplUsdt = XPL_USDT_PRICE;

  const query = `
    query Q($pair: ID!) {
      gauges(where:{stakingToken:$pair}){
        id rewardRate periodFinish totalStaked
        rewardToken{ id symbol decimals }
        stakingToken{ id decimals }
      }
      pair(id:$pair){
        id
        token0{ id symbol decimals }
        token1{ id symbol decimals }
        reserve0 reserve1 totalSupply stable
      }
    }
  `;

  const resp = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ query, variables: { pair: pair.toLowerCase() } }),
  });
  if (!resp.ok) {
    console.error(`Subgraph request failed: ${resp.status} ${resp.statusText}`);
    process.exit(1);
  }
  const data = (await resp.json()) as GaugeResp;

  const g = data.data.gauges?.[0];
  const p = data.data.pair;
  if (!g || !p) {
    console.error('No gauge or pair found for the given pair address.');
    process.exit(1);
  }

  const periodFinish = Number(g.periodFinish);
  if (Number.isFinite(periodFinish) && now > periodFinish) {
    console.log(JSON.stringify({
      pairId: p.id,
      gaugeId: g.id,
      aprLITH: 0,
      reason: 'reward period finished',
    }, null, 2));
    return;
  }

  // Parse numeric fields
  const stakingTokenDecimals = Number(g.stakingToken.decimals || '18');
  const rewardTokenDecimals = REWARD_TOKEN_IS_LITH
    ? 18
    : Number(g.rewardToken.decimals || '18');

  const reserve0 = Number(p.reserve0);
  const reserve1 = Number(p.reserve1);
  const totalSupply = Number(p.totalSupply);
  const totalStakedRaw = Number(g.totalStaked);
  const rewardRateRaw = Number(g.rewardRate);

  if ([reserve0, reserve1, totalSupply, totalStakedRaw, rewardRateRaw].some((n) => !Number.isFinite(n))) {
    console.error('Non-finite numeric values returned from subgraph.');
    process.exit(1);
  }

  // LP composition per LP token
  const perLP0 = reserve0 / totalSupply; // token0 per LP
  const perLP1 = reserve1 / totalSupply; // token1 per LP

  // Identify which token is LITH and compute LP value in LITH terms
  const token0IsLITH = p.token0.id.toLowerCase() === lithAddress;
  const token1IsLITH = p.token1.id.toLowerCase() === lithAddress;
  if (!token0IsLITH && !token1IsLITH) {
    console.error(`Pair does not contain provided LITH token (${lithAddress}).`);
    process.exit(1);
  }

  let priceLITHperToken0 = 0; // how many LITH per 1 token0
  let priceLITHperToken1 = 0; // how many LITH per 1 token1

  if (token0IsLITH) {
    // 1 token1 = (reserve0 / reserve1) LITH
    priceLITHperToken0 = 1; // token0 is LITH
    priceLITHperToken1 = reserve0 / reserve1;
  } else {
    // token1 is LITH
    priceLITHperToken0 = reserve1 / reserve0; // 1 token0 = (reserve1 / reserve0) LITH
    priceLITHperToken1 = 1;
  }

  const lpPriceInLITH = perLP0 * priceLITHperToken0 + perLP1 * priceLITHperToken1;
  const stakedLP = totalStakedRaw / 10 ** stakingTokenDecimals;
  const stakedTVL_LITH = stakedLP * lpPriceInLITH;

  const rewardRateTokensPerSec = rewardRateRaw / 10 ** rewardTokenDecimals;
  const rewardsPerYearLITH = rewardRateTokensPerSec * 31_536_000; // seconds/year

  const aprLITH = stakedTVL_LITH > 0 ? rewardsPerYearLITH / stakedTVL_LITH : 0;

  // Optional USD projection via manual XPL/USDT input
  let usdBlock: undefined | {
    xplUsdt: number;
    lithUsdt: number;
    lpPriceUSD: number;
    stakedTVL_USD: number;
    rewardsPerYearUSD: number;
    aprUSD: number;
  } = undefined;

  if (xplUsdt && xplUsdt > 0) {
    // Derive LITH price in XPL via pool ratio, then USD via XPL/USDT
    // If token0 is WXPL and token1 is LITH: LITH_per_XPL = reserve1/reserve0
    // USD(LITH) = USD(XPL) / (LITH_per_XPL)
    let lithPerXpl: number;
    if (token0IsLITH) {
      // token0=LITH, token1=WXPL => WXPL per LITH = reserve1/reserve0, so LITH per XPL = 1 / (reserve1/reserve0) = reserve0/reserve1
      lithPerXpl = reserve0 / reserve1;
    } else {
      // token1=LITH, token0=WXPL => LITH per XPL = reserve1/reserve0
      lithPerXpl = reserve1 / reserve0;
    }
    const lithUsdt = xplUsdt / lithPerXpl;
    const lpPriceUSD = lpPriceInLITH * lithUsdt;
    const stakedTVL_USD = stakedLP * lpPriceUSD;
    const rewardsPerYearUSD = rewardsPerYearLITH * lithUsdt;
    const aprUSD = stakedTVL_USD > 0 ? rewardsPerYearUSD / stakedTVL_USD : 0; // should numerically match aprLITH
    usdBlock = { xplUsdt, lithUsdt, lpPriceUSD, stakedTVL_USD, rewardsPerYearUSD, aprUSD };
  }

  const out = {
    pairId: p.id,
    gaugeId: g.id,
    rewardRateTokensPerSec: rewardRateTokensPerSec,
    rewardsPerYearLITH,
    stakedLP,
    lpPriceInLITH,
    stakedTVL_LITH,
    aprLITH,
    aprLITHPct: pct(aprLITH),
    periodFinish,
    stable: p.stable,
    token0: { id: p.token0.id, symbol: p.token0.symbol },
    token1: { id: p.token1.id, symbol: p.token1.symbol },
    rewardToken: REWARD_TOKEN_IS_LITH
      ? { id: LITH_ADDRESS, symbol: 'LITH', decimals: '18' }
      : g.rewardToken,
    ...(usdBlock ? { usd: { ...usdBlock, aprUSDPct: pct(usdBlock.aprUSD) } } : {}),
  };

  console.log(JSON.stringify(out, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
