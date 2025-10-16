// Example: Calculate LITH pool total votes using the subgraph only.

const SUBGRAPH =
  "https://api.goldsky.com/api/public/project_cmfuu39qbys1j01009omjbmts/subgraphs/lithos-subgraph-mainnet/v1.0.4/gn";

// WXPL/LITH pair address (LP token) — lowercased for subgraph IDs
const LITH_POOL = "0x7dab98cc51835beae6dee43bbda84cdb96896fb5";

const E18 = 10n ** 18n;
const fmt18 = (x: bigint) => {
  const neg = x < 0n;
  const v = neg ? -x : x;
  const int = v / E18;
  const frac = (v % E18).toString().padStart(18, "0").replace(/0+$/, "");
  return `${neg ? "-" : ""}${int}${frac ? "." + frac : ""}`;
};

async function gql<T>(query: string, variables?: any): Promise<T> {
  const res = await fetch(SUBGRAPH, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query, variables }),
  });
  const json = await res.json();
  if (json.errors) throw new Error(JSON.stringify(json.errors));
  return json.data as T;
}

async function main() {
  // 1) Fetch the gauge for the WXPL/LITH LP and its bribes
  const Q = `
query GaugeByPair($pair: ID!) {
  gauges(where: { stakingToken: $pair }) {
    address
    stakingToken { id symbol }
    internalBribe { id totalVotingPower }
  }
}
  `;

  type Resp = {
    gauges: Array<{
      address: string;
      stakingToken: { id: string; symbol: string };
      internalBribe: { id: string; totalVotingPower: string };
      externalBribe: { id: string; totalVotingPower: string };
    }>;
  };

  const data = await gql<Resp>(Q, { pair: LITH_POOL });
  if (!data.gauges.length) {
    console.log("No gauge found for pool", LITH_POOL);
    return;
  }
  const g = data.gauges[0];

  // 2) Total votes for the pool = bribe.totalVotingPower (matches Voter weight)
  const totalVotesInternal = BigInt(g.internalBribe.totalVotingPower);
  const totalVotesExternal = BigInt(g.externalBribe.totalVotingPower);

  console.log("LITH pool votes via subgraph:");
  console.log("- Pair:", g.stakingToken.symbol, g.stakingToken.id);
  console.log("- Gauge:", g.address);
  console.log("- Internal bribe:", g.internalBribe.id);
  console.log("  - totalVotingPower (raw):", totalVotesInternal.toString());
  console.log("  - totalVotingPower:      ", fmt18(totalVotesInternal));
  console.log("- External bribe:", g.externalBribe.id);
  console.log("  - totalVotingPower (raw):", totalVotesExternal.toString());
  console.log("  - totalVotingPower:      ", fmt18(totalVotesExternal));
  console.log("- Equal?", totalVotesInternal === totalVotesExternal);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
