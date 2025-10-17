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

// Manual price quotes (BASE/QUOTE = price). Update as needed.
const LITH_XPL_PRICE = 0.2; // 1 LITH = 0.2 XPL
const LITH_USDT_PRICE = 0.096; // 1 LITH = 0.096 USDT
const XPL_USDT_PRICE = 0.48; // 1 XPL = 0.48 USDT

// In this protocol, gauge emissions paid via Voter/Minter are LITH.
// Treat reward token as LITH even if the gauge's rewardToken() returns address(0).
const REWARD_TOKEN_IS_LITH = true;

type PriceQuote = { base: string; quote: string; price: number };
type PriceGraph = Map<string, Array<{ to: string; factor: number }>>;

const TOKEN_SYMBOL_ALIAS: Record<string, string> = {
  LITH: 'LITH',
  XPL: 'XPL',
  WXPL: 'XPL',
  USDT: 'USDT',
  USDt: 'USDT',
};

const TOKEN_ADDRESS_ALIAS: Record<string, string> = {
  [LITH_ADDRESS.toLowerCase()]: 'LITH',
};

const MANUAL_QUOTES: PriceQuote[] = [
  { base: 'LITH', quote: 'XPL', price: LITH_XPL_PRICE },
  { base: 'LITH', quote: 'USDT', price: LITH_USDT_PRICE },
  { base: 'XPL', quote: 'USDT', price: XPL_USDT_PRICE },
].filter((quote) => Number.isFinite(quote.price) && quote.price > 0);

const MANUAL_PRICE_GRAPH: PriceGraph = buildPriceGraph(MANUAL_QUOTES);

function pct(n: number): string {
  if (!isFinite(n)) return '0%';
  return (n * 100).toFixed(2) + '%';
}

function normalizeTokenSymbol(symbol: string): string {
  const upper = (symbol ?? '').toUpperCase();
  return TOKEN_SYMBOL_ALIAS[upper] ?? upper;
}

function resolveTokenKey(token: { id: string; symbol: string }): string {
  const addressKey = TOKEN_ADDRESS_ALIAS[token.id.toLowerCase()];
  if (addressKey) return addressKey;
  return normalizeTokenSymbol(token.symbol);
}

function getConversionFactor(
  graph: PriceGraph,
  from: string,
  to: string,
): number | null {
  if (!from || !to) return null;
  if (from === to) return 1;

  const queue: Array<{ token: string; factor: number }> = [{ token: from, factor: 1 }];
  const visited = new Set<string>();

  while (queue.length) {
    const { token, factor } = queue.shift()!;
    if (token === to) return factor;
    if (visited.has(token)) continue;
    visited.add(token);

    const edges = graph.get(token);
    if (!edges) continue;
    for (const edge of edges) {
      if (edge.factor <= 0 || !isFinite(edge.factor)) continue;
      queue.push({ token: edge.to, factor: factor * edge.factor });
    }
  }
  return null;
}

function buildPriceGraph(quotes: PriceQuote[]): PriceGraph {
  const graph: PriceGraph = new Map();
  const addEdge = (from: string, to: string, factor: number) => {
    if (!graph.has(from)) graph.set(from, []);
    graph.get(from)!.push({ to, factor });
  };

  for (const { base, quote, price } of quotes) {
    if (!base || !quote || !price || !isFinite(price) || price <= 0) continue;
    const baseKey = normalizeTokenSymbol(base);
    const quoteKey = normalizeTokenSymbol(quote);
    addEdge(baseKey, quoteKey, price);
    addEdge(quoteKey, baseKey, 1 / price);
  }
  return graph;
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

  // Resolve token identifiers for manual pricing
  const token0Key = resolveTokenKey(p.token0);
  const token1Key = resolveTokenKey(p.token1);
  const token0IsLITH = token0Key === 'LITH' || p.token0.id.toLowerCase() === lithAddress;
  const token1IsLITH = token1Key === 'LITH' || p.token1.id.toLowerCase() === lithAddress;

  let priceLITHperToken0: number | null = token0IsLITH
    ? 1
    : getConversionFactor(MANUAL_PRICE_GRAPH, token0Key, 'LITH');
  let priceLITHperToken1: number | null = token1IsLITH
    ? 1
    : getConversionFactor(MANUAL_PRICE_GRAPH, token1Key, 'LITH');

  // Fallback to on-pair ratio if one side is LITH
  if ((priceLITHperToken0 == null || !Number.isFinite(priceLITHperToken0)) && token1IsLITH) {
    if (reserve0 > 0 && reserve1 > 0) {
      priceLITHperToken0 = reserve1 / reserve0;
    }
  }
  if ((priceLITHperToken1 == null || !Number.isFinite(priceLITHperToken1)) && token0IsLITH) {
    if (reserve0 > 0 && reserve1 > 0) {
      priceLITHperToken1 = reserve0 / reserve1;
    }
  }

  const missingToLITH: string[] = [];
  if (priceLITHperToken0 == null || !Number.isFinite(priceLITHperToken0)) missingToLITH.push(token0Key);
  if (priceLITHperToken1 == null || !Number.isFinite(priceLITHperToken1)) missingToLITH.push(token1Key);
  if (missingToLITH.length) {
    console.error(`Unable to derive LITH price for tokens: ${missingToLITH.join(', ')}`);
    process.exit(1);
  }

  const lpPriceInLITH = perLP0 * (priceLITHperToken0 as number) + perLP1 * (priceLITHperToken1 as number);
  const stakedLP = totalStakedRaw / 10 ** stakingTokenDecimals;
  const stakedTVL_LITH = stakedLP * lpPriceInLITH;

  const rewardRateTokensPerSec = rewardRateRaw / 10 ** rewardTokenDecimals;
  const rewardsPerYearLITH = rewardRateTokensPerSec * 31_536_000; // seconds/year

  const aprLITH = stakedTVL_LITH > 0 ? rewardsPerYearLITH / stakedTVL_LITH : 0;

  // Optional USD projection via manual price graph
  let usdBlock: undefined | {
    xplUsdt: number;
    lithUsdt: number;
    lpPriceUSD: number;
    stakedTVL_USD: number;
    rewardsPerYearUSD: number;
    aprUSD: number;
  } = undefined;

  const priceToken0USD = getConversionFactor(MANUAL_PRICE_GRAPH, token0Key, 'USDT');
  const priceToken1USD = getConversionFactor(MANUAL_PRICE_GRAPH, token1Key, 'USDT');
  const lithUsdt = getConversionFactor(MANUAL_PRICE_GRAPH, 'LITH', 'USDT');
  const xplUsdtViaGraph = getConversionFactor(MANUAL_PRICE_GRAPH, 'XPL', 'USDT');

  if (
    lithUsdt != null &&
    priceToken0USD != null &&
    priceToken1USD != null &&
    Number.isFinite(lithUsdt) &&
    Number.isFinite(priceToken0USD) &&
    Number.isFinite(priceToken1USD)
  ) {
    const lpPriceUSD = perLP0 * priceToken0USD + perLP1 * priceToken1USD;
    const stakedTVL_USD = stakedLP * lpPriceUSD;
    const rewardsPerYearUSD = rewardsPerYearLITH * lithUsdt;
    const aprUSD = stakedTVL_USD > 0 ? rewardsPerYearUSD / stakedTVL_USD : 0; // should numerically match aprLITH
    const xplUsdtOut = xplUsdtViaGraph ?? xplUsdt;
    usdBlock = {
      xplUsdt: xplUsdtOut,
      lithUsdt,
      lpPriceUSD,
      stakedTVL_USD,
      rewardsPerYearUSD,
      aprUSD,
    };
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
