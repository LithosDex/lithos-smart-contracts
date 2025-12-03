---
name: vote-set
description: Generate Safe UI compatible multisig batch JSON to set veNFT votes. Use when the user wants to vote on gauges, allocate voting power to pools, or prepare vote transactions for a multisig wallet.
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Vote Set Safe Batch Generator

Generate Safe Transaction Builder compatible JSON for setting veNFT votes on the Lithos protocol.

## Prerequisites

- The `.env` file must contain `RPC_URL` for Plasma mainnet
- The owner address must be a multisig that owns veNFTs
- User must provide target vote amounts for each pool

## Contract Addresses (Plasma Mainnet)

- **Voter**: `0x2AF460a511849A7aA37Ac964074475b0E6249c69`
- **VotingEscrow**: `0x2Eff716Caa7F9EB441861340998B0952AF056686`
- **Chain ID**: `9745`

## Pool Address Reference

| Pool Name | Symbol | Pool Address |
|-----------|--------|--------------|
| XPL/USDT (CL) | aWXPL-USDT | 0x19F4eBc0a1744b93A355C2320899276aE7F79Ee5 |
| USDT/USDe | sAMM-USDe/USDT0 | 0x01b968C1b663C3921Da5BE3C99Ee3c9B89a40B54 |
| WETH/USDT (CL) | aWETH-USDT | 0xca8759814695516C34168BBedd86290964D37adA |
| WETH/WXPL | vAMM-WXPL/WETH | 0x15DF11A0b0917956fEa2b0D6382E5BA100B312df |
| LITH/XPL | vAMM-WXPL/LITH | 0x7dAB98CC51835Beae6dEE43BbdA84cDb96896fb5 |
| MSUSD/USDT0 | sAMM-msUSD/USDT0 | 0xaa1605fbd9c2Cd3854337dB654471a45B2276c12 |
| MSUSD/USDE | sAMM-msUSD/USDe | 0x7257bEC1613d056eD1295721B5f731C05d1302fb |
| XAUT0/USDT0 | vAMM-XAUt0/USDT0 | 0xB1F2724482D8DcCbDCc5480A70622F93d0A66ae8 |
| WXPL/USDT0 (V) | vAMM-WXPL/USDT0 | 0xA0926801A2abC718822a60d8Fa1bc2A51Fa09F1e |
| WETH/weETH (V) | vAMM-WETH/weETH | 0x7483eD877a1423f34Dc5e46CF463ea4A0783d165 |
| WETH/weETH (S) | sAMM-WETH/weETH | 0x82862237F37e8495D88287d72A4C0073250487E0 |
| FBOMB/USDT | vAMM-fBOMB/USDT0 | 0xa82d9DfC3e92907aa4D092f18d89F1C0E129B8AC |
| EBUSD/USDT0 | sAMM-USDT0/ebUSD | 0x4388DcA346165FdC6cbC9e1e388779c66C026d27 |

To get the full list of pools dynamically:

```bash
# Get number of pools
source .env && cast call 0x2AF460a511849A7aA37Ac964074475b0E6249c69 "length()(uint256)" --rpc-url $RPC_URL

# Get pool at index
source .env && cast call 0x2AF460a511849A7aA37Ac964074475b0E6249c69 "pools(uint256)(address)" <INDEX> --rpc-url $RPC_URL

# Get pool symbol
source .env && cast call <POOL_ADDRESS> "symbol()(string)" --rpc-url $RPC_URL
```

## Instructions

### Step 1: Query veNFTs owned by the address

```bash
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "balanceOf(address)(uint256)" <OWNER_ADDRESS> --rpc-url $RPC_URL
```

### Step 2: Get all token IDs and their voting power

For each index from 0 to (balance - 1):

```bash
# Get token ID
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "tokenOfOwnerByIndex(address,uint256)(uint256)" <OWNER_ADDRESS> <INDEX> --rpc-url $RPC_URL

# Get voting power for token
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "balanceOfNFT(uint256)(uint256)" <TOKEN_ID> --rpc-url $RPC_URL
```

### Step 3: Select the best veNFT

Compare the total target votes against each veNFT's voting power. Select the veNFT that is closest to the target (within 20% is acceptable). The votes are distributed proportionally by weight, so the actual votes will be scaled by:

```
actual_votes = target_votes * (veNFT_voting_power / total_target_votes)
```

### Step 4: Check if veNFT has already voted

```bash
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "voted(uint256)(bool)" <TOKEN_ID> --rpc-url $RPC_URL
```

If `true`, the user must reset votes first using the `vote-reset` skill.

### Step 5: Generate vote calldata

**IMPORTANT**: The `vote()` function takes **POOL addresses**, not gauge addresses!

```bash
cast calldata "vote(uint256,address[],uint256[])" <TOKEN_ID> "[<POOL1>,<POOL2>,...]" "[<WEIGHT1>,<WEIGHT2>,...]"
```

The function selector for `vote(uint256,address[],uint256[])` is `0x7ac09bf7`.

### Step 6: Create Safe batch JSON

Generate a JSON file with this structure:

```json
{
  "version": "1.0",
  "chainId": "9745",
  "createdAt": <UNIX_TIMESTAMP>,
  "meta": {
    "name": "Vote with veNFT #<TOKEN_ID>",
    "description": "Cast votes for veNFT #<TOKEN_ID> (<VOTING_POWER> voting power) across <NUM_POOLS> pools.\n\nVote Distribution:\n<POOL_BREAKDOWN>",
    "txBuilderVersion": "1.16.5"
  },
  "transactions": [
    {
      "to": "0x2AF460a511849A7aA37Ac964074475b0E6249c69",
      "value": "0",
      "data": "<VOTE_CALLDATA>",
      "contractMethod": {
        "inputs": [
          {
            "internalType": "uint256",
            "name": "_tokenId",
            "type": "uint256"
          },
          {
            "internalType": "address[]",
            "name": "_poolVote",
            "type": "address[]"
          },
          {
            "internalType": "uint256[]",
            "name": "_weights",
            "type": "uint256[]"
          }
        ],
        "name": "vote",
        "payable": false
      },
      "contractInputsValues": {
        "_tokenId": "<TOKEN_ID>",
        "_poolVote": "[<POOL_ADDRESSES>]",
        "_weights": "[<WEIGHTS>]"
      }
    }
  ]
}
```

### Step 7: Write to file

Save the JSON to `safe-txs/safe.vote-<TOKEN_ID>.json`.

## Verification

After the transaction is executed, verify the vote was successful:

```bash
# Check voted status
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "voted(uint256)(bool)" <TOKEN_ID> --rpc-url $RPC_URL

# Check vote amount on a specific pool
source .env && cast call 0x2AF460a511849A7aA37Ac964074475b0E6249c69 "votes(uint256,address)(uint256)" <TOKEN_ID> <POOL_ADDRESS> --rpc-url $RPC_URL
```

## Example Usage

User: "Set votes for veNFTs owned by 0x495a98fd059551385Fc9bAbBcFD88878Da3A1b78 with these targets:
- XPL/USDT (CL): 4,000,000
- LITH/XPL: 1,500,000
- MSUSD/USDT0: 2,000,000"

1. Query veNFTs: finds 1163 (11.5M), 1447 (6.7M), 1448 (0.2M)
2. Calculate total target: 7,500,000
3. Select best match: veNFT 1447 (6.7M) is 89% of target - acceptable
4. Check voted status: false (can proceed)
5. Map pool names to addresses
6. Generate calldata with pool addresses (NOT gauge addresses!)
7. Create `safe-txs/safe.vote-1447.json`
8. Report success with vote distribution breakdown

## Common Mistakes to Avoid

1. **Using gauge addresses instead of pool addresses** - The `vote()` function takes pool addresses. Use the Pool Address Reference table above.

2. **Forgetting to check voted status** - If the veNFT has already voted this epoch, the transaction will fail. Reset first.

3. **Including pools with 0 weight** - Only include pools with non-zero weights in the arrays.

## Notes

- Votes are proportional: weights determine the ratio, not absolute amounts
- The veNFT's total voting power is distributed across pools based on weight ratios
- Voting automatically resets previous votes for that token
- Votes persist until the next epoch or until manually reset
- Only the veNFT owner or approved address can vote
