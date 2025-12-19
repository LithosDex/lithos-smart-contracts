# Lithos Multisig Operations Runbook

This living document captures the on-chain actions that each Lithos multisig is expected to execute, together with the exact call targets, argument formats, and ABI fragments. Always confirm contract addresses from the latest deployment snapshot (`deployments/mainnet/state.json`) before broadcasting transactions.

## Multisig Directory

| Label | Address | Primary Authority |
| --- | --- | --- |
| Governance (4/6) | `0x21F1c2F66d30e22DaC1e2D509228407ccEff4dBC` | `PermissionsRegistry.lithosMultisig` |
| Operations (3/4) | `0xbEe8e366fEeB999993841a17C1DCaaad9d4618F7` | `Minter.team`, `VotingEscrow.team`, `RewardsDistributor.owner` |
| Emergency Council (2/3) | `0x771675A54f18816aC9CD71b07d3d6e6Be7a9D799` | `PermissionsRegistry.emergencyCouncil` fallback |
| Treasury (4/6) | `0xe98c1e28805A06F23B41cf6d356dFC7709DB9385` | Treasury reserves (no direct contract control yet) |
| Foundation Steward | `0xD333A0106DEfC9468C53B95779281B20475d7735` | Long-term veNFT stewarding |
| Plasma PGF (veNFT #70) | `0x495a98fd059551385Fc9bAbBcFD88878Da3A1b78` | Owns PGF veNFT voting power |

Addresses below reference the current mainnet deployment (`deployments/mainnet/state.json`):

- `Voter`: `0x2AF460a511849A7aA37Ac964074475b0E6249c69`
- `VotingEscrow`: `0x2Eff716Caa7F9EB441861340998B0952AF056686`
- `PermissionsRegistry`: `0x97A5AD8B3d1c16565d9EC94A95cBE2D61d0a4ac7`
- `PairFactoryUpgradeable`: `0x71a870D1c935C2146b87644DF3B5316e8756aE18`
- `Minter` (proxy): `0x3bE9e60902D5840306d3Eb45A29015B7EC3d10a6`
- `RewardsDistributor`: `0x0E68ac23a0aFEF4f018d647C3E58d59c55065308`

Use `cast` or your transaction builder of choice to reproduce the calldata shown in the examples.

---

## Governance Multisig (4/6)

### Manage Permissions Registry Roles
- **To**: `PermissionsRegistry`
- **Function**: `setRoleFor(address,string)`
- **Selector**: `0x9c058964`
- **Example calldata** (assign `GAUGE_ADMIN` to `0x1234...`):
  ```
  cast calldata "setRoleFor(address,string)" 0x1234123412341234123412341234123412341234 "GAUGE_ADMIN"
  ```
- **ABI fragment**:
  ```json
  {
    "inputs": [
      { "internalType": "address", "name": "c", "type": "address" },
      { "internalType": "string", "name": "role", "type": "string" }
    ],
    "name": "setRoleFor",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
Remove roles with `removeRoleFrom(address,string)` (`0x70f536b8`) following the same pattern.

### Rotate Governance Multisig
- **To**: `PermissionsRegistry`
- **Function**: `setLithosMultisig(address)`
- **Selector**: `0xe74bbb49`
- **Example calldata**:
  ```
  cast calldata "setLithosMultisig(address)" 0xABCDabcdABCDabcdABCDabcdABCDabcdABCDabcd
  ```
- **ABI fragment**:
  ```json
  {
    "inputs": [{ "internalType": "address", "name": "_new", "type": "address" }],
    "name": "setLithosMultisig",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```

### Accept Pair Factory Fee Manager
- **To**: `PairFactoryUpgradeable`
- **Function**: `acceptFeeManager()`
- **Selector**: `0xf94c53c7`
- **Call data**: `0xf94c53c7`
- **ABI fragment**:
  ```json
  {
    "inputs": [],
    "name": "acceptFeeManager",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
Prerequisite: `pendingFeeManager` must already be set to the governance multisig via `setFeeManager`.

### Whitelist XAUt0 & Create xAUT0/USDT0 Gauge
- **Multisig**: Governance (4/6) — `0x21F1c2F66d30e22DaC1e2D509228407ccEff4dBC`
- **Purpose**: Lists the XAUt0 collateral token so its pool can emit incentives, then deploys a new gauge for the `xAUT0/USDT0` volatile pair (`PairFactoryUpgradeable` id `49`).

**Pre-flight checks**
- Confirm the token is not yet whitelisted:
  ```
  cast call 0x2AF460a511849A7aA37Ac964074475b0E6249c69 "isWhitelisted(address)(bool)" 0x1B64B9025EEBb9A6239575DF9EA4B9AC46D4D193 --rpc-url <RPC_URL>
  ```
- Confirm no gauge exists yet for the pool:
  ```
  cast call 0x2AF460a511849A7aA37Ac964074475b0E6249c69 "gauges(address)(address)" 0xB1F2724482D8DcCbDCc5480A70622F93d0A66ae8 --rpc-url <RPC_URL>
  ```

**Transaction 1 — Whitelist XAUt0**
- **To**: `Voter` (`0x2AF460a511849A7aA37Ac964074475b0E6249c69`)
- **Function**: `whitelist(address[])`
- **Selector**: `0xbd8aa780`
- **Call data**:
  ```
  0xbd8aa780000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000001b64b9025eebb9a6239575df9ea4b9ac46d4d193
  ```
- **ABI fragment**:
  ```json
  [{
    "inputs": [
      { "internalType": "address[]", "name": "_token", "type": "address[]" }
    ],
    "name": "whitelist",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }]
  ```

**Transaction 2 — Create Gauge**
- Queue only after Transaction 1 succeeds.
- **To**: `Voter` (`0x2AF460a511849A7aA37Ac964074475b0E6249c69`)
- **Function**: `createGauge(address,uint256)`
- **Selector**: `0xdcd9e47a`
- **Arguments**:
  - `_pool`: `0xB1F2724482D8DcCbDCc5480A70622F93d0A66ae8`
  - `_gaugeType`: `0` (legacy volatile/stable factory)
- **Call data**:
  ```
  0xdcd9e47a000000000000000000000000b1f2724482d8dccbdcc5480a70622f93d0a66ae80000000000000000000000000000000000000000000000000000000000000000
  ```
- **ABI fragment**:
  ```json
  {
    "inputs": [
      { "internalType": "address", "name": "_pool", "type": "address" },
      { "internalType": "uint256", "name": "_gaugeType", "type": "uint256" }
    ],
    "name": "createGauge",
    "outputs": [
      { "internalType": "address", "name": "_gauge", "type": "address" },
      { "internalType": "address", "name": "_internal_bribe", "type": "address" },
      { "internalType": "address", "name": "_external_bribe", "type": "address" }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
- **Post-checks**:
  - Verify `whitelist` status returns `true`.
  - Fetch the new gauge address:
    ```
    cast call 0x2AF460a511849A7aA37Ac964074475b0E6249c69 "gauges(address)(address)" 0xB1F2724482D8DcCbDCc5480A70622F93d0A66ae8 --rpc-url <RPC_URL>
    ```
  - Record the emitted `GaugeCreated` event and add the address to your gauge registry.

---

## Operations Multisig (3/4)

### Finalize Minter Team Handoff
- **To**: `Minter` (proxy)
- **Function**: `acceptTeam()`
- **Selector**: `0x12d17f2c`
- **Call data**: `0x12d17f2c`
- **ABI fragment**:
  ```json
  {
    "inputs": [],
    "name": "acceptTeam",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
Follow-up knobs (all restricted to `team`):
- `setTeam(address)` (`0x704b6c02`)
- `setVoter(address)` (`0xaaab1da8`)
- `setTeamRate(uint256)` (`0xf4a4d3e9`)
- `setEmission(uint256)` (`0x1fc58d31`)
- `setRebase(uint256)` (`0x75c91079`)

### Maintain VotingEscrow Team
- **To**: `VotingEscrow`
- **Function**: `setTeam(address)`
- **Selector**: `0x704b6c02`
- **Example calldata**:
  ```
  cast calldata "setTeam(address)" 0xbEe8e366fEeB999993841a17C1DCaaad9d4618F7
  ```
- **ABI fragment**:
  ```json
  {
    "inputs": [{ "internalType": "address", "name": "_team", "type": "address" }],
    "name": "setTeam",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```

### Administer Rewards Distributor
- **To**: `RewardsDistributor`
- **Functions**:
  - `setOwner(address)` (`0x13af4035`)
  - `setDepositor(address)` (`0x0d8e6e2c`)
  - `withdrawERC20(address)` (`0x1e2fff87`)
- **Example** (change depositor):
  ```
  cast calldata "setDepositor(address)" 0x1234123412341234123412341234123412341234
  ```
- **ABI fragment** (for `setDepositor`):
  ```json
  {
    "inputs": [{ "internalType": "address", "name": "_depositor", "type": "address" }],
    "name": "setDepositor",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
Only call `withdrawERC20` in emergencies when the distributor must be drained; document the token and amount out-of-band.

### Reduce Weekly Emissions to 50% (temporary)
- **Multisig**: Operations (3/4) — must already be the active `Minter.team`.
- **Purpose**: Cut the next epoch’s target emissions in half by setting `EMISSION` to `500` (50% of prior `weekly` value). Tail emissions still apply.

**Pre-flight checks**
1. Confirm the caller controls the `team` role:
   ```
   cast call 0x3bE9e60902D5840306d3Eb45A29015B7EC3d10a6 "team()(address)" --rpc-url <RPC_URL>
   ```
2. Record the current emission knob for later restoration:
   ```
   cast call 0x3bE9e60902D5840306d3Eb45A29015B7EC3d10a6 "EMISSION()(uint256)" --rpc-url <RPC_URL>
   ```
   Baseline is `990` (99%).

**Transaction — halve emissions**
- **To**: `Minter` proxy (`0x3bE9e60902D5840306d3Eb45A29015B7EC3d10a6`)
- **Function**: `setEmission(uint256)`
- **Selector**: `0x1fc58d31`
- **Arguments**: `_emission = 500`
- **Call data**:
  ```
  cast calldata "setEmission(uint256)" 500
  ```
- **ABI fragment**:
  ```json
  [{
    "inputs": [{ "internalType": "uint256", "name": "_emission", "type": "uint256" }],
    "name": "setEmission",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }]
  ```

**Post-flight**
- Verify the knob updated:
  ```
  cast call 0x3bE9e60902D5840306d3Eb45A29015B7EC3d10a6 "EMISSION()(uint256)" --rpc-url <RPC_URL>
  ```
- Remember to restore the prior value (e.g., `setEmission(990)`) once emissions should return to normal; queue that follow-up before the desired epoch rollover.

---

## Emergency Council (2/3)

### Rotate Emergency Council
- **To**: `PermissionsRegistry`
- **Function**: `setEmergencyCouncil(address)`
- **Selector**: `0x2178508d`
- **Example calldata**:
  ```
  cast calldata "setEmergencyCouncil(address)" 0x9876987698769876987698769876987698769876
  ```
- **ABI fragment**:
  ```json
  {
    "inputs": [{ "internalType": "address", "name": "_new", "type": "address" }],
    "name": "setEmergencyCouncil",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
Callable either by the current emergency council or the governance multisig.

---

## Plasma PGF Multisig (veNFT #70)

The Plasma PGF multisig (`0x495a98fd059551385Fc9bAbBcFD88878Da3A1b78`) owns veNFT `#70` (`VotingEscrow.ownerOf(70)` verifies this). All voting interactions target the `Voter` contract.

### Pre-flight Checklist
- Confirm the multisig is still the owner or approved operator for veNFT `#70`.
- Check `Voter.VOTE_DELAY()` (currently `0` on mainnet) to ensure you are past any cooldown.
- Identify target pools and their gauges via:
  ```
  cast call <Voter> "gauges(address)(address)" <poolAddress> --rpc-url <RPC>
  ```

### Reset Votes (full abstain)
- **To**: `Voter`
- **Function**: `reset(uint256)`
- **Selector**: `0x310bd74b`
- **Call data** for veNFT `#70`: `0x310bd74b0000000000000000000000000000000000000000000000000000000000000046`
- **ABI fragment**:
  ```json
  {
    "inputs": [{ "internalType": "uint256", "name": "_tokenId", "type": "uint256" }],
    "name": "reset",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
Execution withdraws bribes/fees from all active gauges and calls `VotingEscrow.abstain(70)`.

### Vote Example: 100% Weight to WXPL/LITH
- **Pool (LP token)**: `0x7dab98cc51835beae6dee43bbda84cdb96896fb5`
- **Gauge**: `0xdaFD14335AEE92098b13ae3Ed9F5ce3B675E92cc`
- **To**: `Voter`
- **Function**: `vote(uint256,address[],uint256[])`
- **Selector**: `0x7ac09bf7`
- **Example calldata** (`weights = [10000]`):
  ```
  cast calldata \
    "vote(uint256,address[],uint256[])" \
    70 \
    "[0x7dab98cc51835beae6dee43bbda84cdb96896fb5]" \
    "[10000]"
  ```
  This produces:
  ```
  0x7ac09bf70000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000007dab98cc51835beae6dee43bbda84cdb96896fb500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000002710
  ```
- **ABI fragment**:
  ```json
  {
    "inputs": [
      { "internalType": "uint256", "name": "_tokenId", "type": "uint256" },
      { "internalType": "address[]", "name": "_poolVote", "type": "address[]" },
      { "internalType": "uint256[]", "name": "_weights", "type": "uint256[]" }
    ],
    "name": "vote",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  ```
Weights are relative; the contract rescales them against the veNFT balance. Include only gauges that return `true` for `Voter.isAlive(gauge)`.
- From (must be sender): `0x495a98fd059551385Fc9bAbBcFD88878Da3A1b78` (confirmed owner of veNFT `#70`)
- To: `Voter` (`0x2AF460a511849A7aA37Ac964074475b0E6249c69`)
- Function: `vote(uint256,address[],uint256[])`
- Selector: `0x7ac09bf7`
- TokenId: `70`

- ABI fragment:
  ```json
  [{
    "inputs": [
      { "internalType": "uint256", "name": "_tokenId", "type": "uint256" },
      { "internalType": "address[]", "name": "_poolVote", "type": "address[]" },
      { "internalType": "uint256[]", "name": "_weights", "type": "uint256[]" }
    ],
    "name": "vote",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }]
  ```

- Pools and weights (addresses are LP tokens; Voter resolves gauges):
  - `XPL/USDT (V)` → `WXPL/USDT0 (volatile)` `0xa0926801a2abc718822a60d8fa1bc2a51fa09f1e` → `1400000`
  - `XPL/USDT (S)` → `WXPL/USDT0 (stable)`   `0x8a07ca51227b3d2588341d8927b4bacf37dbf28f` → `5000`
  - `USDT/USDe` → `USDe/USDT0 (stable)`       `0x01b968c1b663c3921da5be3c99ee3c9b89a40b54` → `700000`
  - `WETH/weETH (V)`                          `0x7483ed877a1423f34dc5e46cf463ea4a0783d165` → `65000`
  - `WETH/WXPL (V)`                           `0x15df11a0b0917956fea2b0d6382e5ba100b312df` → `5000`
  - `WETH/USDT0 (V)`                          `0xf402c0c55285436e2d598c25faf906c62f2ea998` → `14000`
  - `LITH/XPL (V)` → `LITH/WXPL (volatile)`   `0x7dab98cc51835beae6dee43bbda84cdb96896fb5` → `1300000`
  - `FBOMB/USDT`                               `0xa82d9dfc3e92907aa4d092f18d89f1c0e129b8ac` → `300000`
  - `MSUSD/USDT0 (S)`                         `0xaa1605fbd9c2cd3854337db654471a45b2276c12` → `250000`
  - `XUSD/USDT` → `xUSD/tcUSDT0 (stable)`     `0x0d6f93edff269656dfac82e8992afa9e719b137e` → `40000`
  - `EBUSD/USDT0 (S)`                          `0x4388dca346165fdc6cbc9e1e388779c66c026d27` → `85000`
  - `XAUTO/USDT0 (V)` → `XAUt0/USDT0`         `0xb1f2724482d8dccbdcc5480a70622f93d0a66ae8` → `35000`
  - `SPLUSD/PLUSD (S)`                        `0x55078defe265a66451fd9da109e7362a70b3fdac` → `175000`
  - `PLUSD/USDT0 (S)`                         `0x7c735d31f0e77d430648c368b7b61196e13f9e23` → `70000`
  - `TREVEE/PLUSD (V)`                        `0xc8319a16ae5ab41c2d715bd65045c9473b0ec4e0` → `250000`

- Calldata (for the above 15 pools, in order):
  ```
  0x7ac09bf7000000000000000000000000000000000000000000000000000000000000004600000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000a0926801a2abc718822a60d8fa1bc2a51fa09f1e0000000000000000000000008a07ca51227b3d2588341d8927b4bacf37dbf28f00000000000000000000000001b968c1b663c3921da5be3c99ee3c9b89a40b540000000000000000000000007483ed877a1423f34dc5e46cf463ea4a0783d16500000000000000000000000015df11a0b0917956fea2b0d6382e5ba100b312df000000000000000000000000f402c0c55285436e2d598c25faf906c62f2ea9980000000000000000000000007dab98cc51835beae6dee43bbda84cdb96896fb5000000000000000000000000a82d9dfc3e92907aa4d092f18d89f1c0e129b8ac000000000000000000000000aa1605fbd9c2cd3854337db654471a45b2276c120000000000000000000000000d6f93edff269656dfac82e8992afa9e719b137e0000000000000000000000004388dca346165fdc6cbc9e1e388779c66c026d27000000000000000000000000b1f2724482d8dccbdcc5480a70622f93d0a66ae800000000000000000000000055078defe265a66451fd9da109e7362a70b3fdac0000000000000000000000007c735d31f0e77d430648c368b7b61196e13f9e23000000000000000000000000c8319a16ae5ab41c2d715bd65045c9473b0ec4e0000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000155cc0000000000000000000000000000000000000000000000000000000000000138800000000000000000000000000000000000000000000000000000000000aae60000000000000000000000000000000000000000000000000000000000000fde8000000000000000000000000000000000000000000000000000000000000138800000000000000000000000000000000000000000000000000000000000036b0000000000000000000000000000000000000000000000000000000000013d62000000000000000000000000000000000000000000000000000000000000493e0000000000000000000000000000000000000000000000000000000000003d0900000000000000000000000000000000000000000000000000000000000009c400000000000000000000000000000000000000000000000000000000000014c0800000000000000000000000000000000000000000000000000000000000088b8000000000000000000000000000000000000000000000000000000000002ab980000000000000000000000000000000000000000000000000000000000011170000000000000000000000000000000000000000000000000000000000003d090
  ```

- Semantics
  - VoterV3 only accepts relative `weights` and always allocates 100% of ve power across the provided pools proportionally.
  - There is no entrypoint to cast exact absolute “vote amounts” below the ve balance. To use fewer absolute votes:
    - Use the numbers as relative weights (they will be scaled to full ve power, preserving ratios), or
    - Split veNFT `#70` into smaller veNFTs via `VotingEscrow.split(...)` and vote with a smaller tokenId (token IDs change), or
    - Adjust the list to reflect proportions recognizing full usage per epoch.

> Pre-flight: No need to call `reset(70)` separately; `vote` internally resets before applying new weights. Ensure you’re past any `VOTE_DELAY`.


### Claim Bribes or Fees (Optional)
- **To**: `Voter`
- **Functions**:
  - `claimBribes(address[],address[][],uint256)` (`0xece3a8f4`)
  - `claimFees(address[],address[][],uint256)` (`0xe1d1b441`)
- **Example** (claim bribes from two bribe contracts):
  ```
  cast calldata \
    "claimBribes(address[],address[][],uint256)" \
    "[0xBd80E74F20B957F36D20975206a5D649e499961E,0x727B96B5E4A8c5ED1F057EA0D34723e4D81EDaAB]" \
    "[[0xTokenA],[0xTokenB,0xTokenC]]" \
    70
  ```
Document the reward token list alongside the transaction so reviewers can verify expectations.

---

## Split veNFT 70 Into 5M Voting Power Child

- Purpose: Create a smaller veNFT with approximately 5,000,000 voting power (wei units, i.e., 5,000,000e18) while preserving the same unlock time, so you can vote only a subset of total power.

Important behavior
- Splitting burns the original NFT and mints new NFTs; tokenId `70` will be destroyed and replaced by two new token IDs owned by the same address.
- Both children inherit the same `end` (unlock timestamp) and split the underlying locked amount proportionally to the `amounts` vector.
- You must not be in a voted/attached state to split.

Pre‑flight checks
- Confirm veNFT is not voted/attached; if currently voted, reset first:
  - To: `Voter` (`0x2AF460a511849A7aA37Ac964074475b0E6249c69`)
  - Function: `reset(uint256)`
- Calldata (for tokenId 70):
  - `0x310bd74b0000000000000000000000000000000000000000000000000000000000000046`
- ABI fragments:
  - `reset(uint256)`
    ```json
    {
      "inputs": [ { "internalType": "uint256", "name": "_tokenId", "type": "uint256" } ],
      "name": "reset",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
    ```
  - `locked(uint256)` (view)
    ```json
    {
      "inputs": [ { "internalType": "uint256", "name": "_tokenId", "type": "uint256" } ],
      "name": "locked",
      "outputs": [
        { "internalType": "int128", "name": "amount", "type": "int128" },
        { "internalType": "uint256", "name": "end", "type": "uint256" }
      ],
      "stateMutability": "view",
      "type": "function"
    }
    ```
- Confirm the lock has not expired (end > now):
  - `cast call <VotingEscrow> "locked(uint256)(int128,uint256)" 70`

Transaction — Split into [5,000,000e18 , remainder]
- To: `VotingEscrow` (`0x2Eff716Caa7F9EB441861340998B0952AF056686`)
- Function: `split(uint256[] amounts, uint256 tokenId)`
- Parameters chosen using current `balanceOfNFT(70)` to target ~5,000,000e18 voting power child:
  - `amounts`: `[5000000000000000000000000, 14020714651509386091945330]`
  - `tokenId`: `70`
- Calldata:
  - `0x56afe7440000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004600000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000422ca8b0a00a4250000000000000000000000000000000000000000000000000b990076d8f9dac53fdd72`
- ABI fragment:
  ```json
  [{
    "inputs": [
      { "internalType": "uint256[]", "name": "amounts", "type": "uint256[]" },
      { "internalType": "uint256", "name": "_tokenId", "type": "uint256" }
    ],
    "name": "split",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }]
  ```

Post‑split
- Record the two new token IDs from the transaction Transfer events.
- The first minted ID corresponds to the first entry in `amounts` (the ~5M ve child); the second to the remainder.
- To vote using the new ~5M veNFT, re‑encode the vote calldata with the new tokenId and the previously prepared 15‑pool list and weights:
  - Example command: `cast calldata "vote(uint256,address[],uint256[])" <NEW_TOKEN_ID> [<LPs...>] [<weights...>]`
  - Use the LP list and weights exactly as documented above; only the tokenId changes.

Notes on precision
- Voter power decays linearly with time for a fixed unlock; splitting by ratios preserves proportional voting power across children.
- Minor rounding may occur due to integer division; the child’s voting power may differ by one or a few wei.

---

## Notes & Next Steps

- Expand each section with standard operating procedures (SOPs) as new responsibilities are delegated.
- Keep this file in sync with address rotations (`TransferOwnershipMainnet.s.sol`) and any updates to multisig compositions.
- When adding new operations, prefer including: purpose, prerequisites, calldata example, gas considerations, and post-checks.