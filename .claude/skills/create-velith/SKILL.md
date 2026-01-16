---
name: create-velith
description: Generate Safe UI compatible multisig batch JSON to create and distribute veLITH (veNFTs) to multiple recipients. Use when you need to lock LITHOS tokens and create veNFTs for a list of addresses.
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Create veLITH Safe Batch Generator

Generate Safe Transaction Builder compatible JSON for creating and distributing veLITH (veNFTs) to multiple recipients by locking LITHOS tokens.

## Prerequisites

- The `.env` file must contain `RPC_URL` for Plasma mainnet
- The multisig must hold sufficient LITHOS tokens for the distribution
- User must provide recipient addresses and amounts

## Contract Addresses (Plasma Mainnet)

- **LITHOS Token**: `0xAbB48792A3161E81B47cA084c0b7A22a50324A44`
- **VotingEscrow**: `0x2Eff716Caa7F9EB441861340998B0952AF056686`
- **Chain ID**: `9745`

## Lock Duration Reference

| Duration | Seconds |
|----------|---------|
| 2 years (max) | 63,072,000 |
| 1 year | 31,536,000 |
| 6 months | 15,768,000 |
| 3 months | 7,884,000 |
| 1 month | 2,628,000 |
| 1 week | 604,800 |

Note: VotingEscrow rounds lock end time DOWN to the nearest week.

## Instructions

### Step 1: Parse recipient list

Accept input in format (whitespace or comma separated):
```
<address>    <amount>
<address>    <amount>
...
```

Amounts are in whole LITHOS tokens (not wei).

### Step 2: Verify multisig has sufficient LITHOS

```bash
source .env && cast call 0xAbB48792A3161E81B47cA084c0b7A22a50324A44 "balanceOf(address)(uint256)" <MULTISIG_ADDRESS> --rpc-url $RPC_URL
```

Convert the result from wei to tokens (divide by 10^18) and compare to total required.

### Step 3: Generate approve calldata

The multisig must approve VotingEscrow to spend LITHOS tokens.

```bash
# Total amount in wei = sum of all amounts * 10^18
cast calldata "approve(address,uint256)" 0x2Eff716Caa7F9EB441861340998B0952AF056686 <TOTAL_AMOUNT_WEI>
```

The function selector for `approve(address,uint256)` is `0x095ea7b3`.

### Step 4: Generate create_lock_for calldata for each recipient

```bash
# For each recipient:
# _value = amount in wei (amount * 10^18)
# _lock_duration = duration in seconds (e.g., 63072000 for 2 years)
# _to = recipient address
cast calldata "create_lock_for(uint256,uint256,address)" <VALUE_WEI> <DURATION_SECONDS> <RECIPIENT_ADDRESS>
```

The function selector for `create_lock_for(uint256,uint256,address)` is `0xd4e54c3b`.

### Step 5: Create Safe batch JSON

Generate a JSON file with this structure:

```json
{
  "version": "1.0",
  "chainId": "9745",
  "createdAt": <UNIX_TIMESTAMP>,
  "meta": {
    "name": "Distribute veLITH to <NUM_RECIPIENTS> recipients",
    "description": "Lock <TOTAL_AMOUNT> LITHOS tokens for <DURATION> and distribute veNFTs to <NUM_RECIPIENTS> addresses.",
    "txBuilderVersion": "1.16.5"
  },
  "transactions": [
    {
      "to": "0xAbB48792A3161E81B47cA084c0b7A22a50324A44",
      "value": "0",
      "data": "<APPROVE_CALLDATA>",
      "contractMethod": {
        "inputs": [
          {
            "internalType": "address",
            "name": "spender",
            "type": "address"
          },
          {
            "internalType": "uint256",
            "name": "amount",
            "type": "uint256"
          }
        ],
        "name": "approve",
        "payable": false
      },
      "contractInputsValues": {
        "spender": "0x2Eff716Caa7F9EB441861340998B0952AF056686",
        "amount": "<TOTAL_AMOUNT_WEI>"
      }
    },
    {
      "to": "0x2Eff716Caa7F9EB441861340998B0952AF056686",
      "value": "0",
      "data": "<CREATE_LOCK_FOR_CALLDATA>",
      "contractMethod": {
        "inputs": [
          {
            "internalType": "uint256",
            "name": "_value",
            "type": "uint256"
          },
          {
            "internalType": "uint256",
            "name": "_lock_duration",
            "type": "uint256"
          },
          {
            "internalType": "address",
            "name": "_to",
            "type": "address"
          }
        ],
        "name": "create_lock_for",
        "payable": false
      },
      "contractInputsValues": {
        "_value": "<AMOUNT_WEI>",
        "_lock_duration": "<DURATION_SECONDS>",
        "_to": "<RECIPIENT_ADDRESS>"
      }
    }
    // ... repeat for each recipient
  ]
}
```

### Step 6: Write to file

Save the JSON to `safe-txs/safe.distribute-velith-<TIMESTAMP>.json`.

## Verification

After the transaction is executed, verify the veNFTs were created:

```bash
# Check recipient received a veNFT
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "balanceOf(address)(uint256)" <RECIPIENT> --rpc-url $RPC_URL

# Get the token ID
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "tokenOfOwnerByIndex(address,uint256)(uint256)" <RECIPIENT> 0 --rpc-url $RPC_URL

# Check voting power
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "balanceOfNFT(uint256)(uint256)" <TOKEN_ID> --rpc-url $RPC_URL

# Check lock details
source .env && cast call 0x2Eff716Caa7F9EB441861340998B0952AF056686 "locked(uint256)((int128,uint256))" <TOKEN_ID> --rpc-url $RPC_URL
```

## Example Usage

User: "Create veLITH for these addresses with 2-year locks:
0x1234...abcd    100000
0x5678...efgh    50000
0x9abc...ijkl    25000"

**Workflow:**

1. Parse: 3 recipients, total 175,000 LITHOS
2. Query multisig balance: 200,000 LITHOS (sufficient)
3. Calculate wei amounts:
   - Total: 175000 * 10^18 = 175000000000000000000000
   - Each recipient's amount * 10^18
4. Generate approve calldata for 175000000000000000000000 wei
5. Generate 3 create_lock_for calldatas (63072000 seconds for 2 years)
6. Create batch JSON with 4 transactions (1 approve + 3 creates)
7. Save to safe-txs/safe.distribute-velith-1705000000.json

## Common Mistakes to Avoid

1. **Forgetting to convert to wei** - All amounts must be multiplied by 10^18.

2. **Insufficient approval** - The approve amount must be >= total of all create_lock_for amounts.

3. **Wrong lock duration units** - Duration is in SECONDS, not days or weeks.

4. **Exceeding max lock** - Maximum lock duration is 2 years (63,072,000 seconds). VotingEscrow will revert if exceeded.

5. **Zero amounts** - VotingEscrow reverts on zero-value locks.

6. **Duplicate recipients** - Each recipient will get a SEPARATE veNFT. If you want to add to an existing lock, use `deposit_for()` instead.

## Notes

- Each `create_lock_for()` call creates a NEW veNFT for the recipient
- The recipient immediately owns the veNFT and can vote, transfer, or manage it
- Voting power decays linearly over the lock period
- Recipients can extend their lock duration or add more tokens after receiving
- The multisig pays the LITHOS tokens; recipients receive veNFTs at no cost
