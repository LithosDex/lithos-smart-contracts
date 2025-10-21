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
- `RewardsDistributor`: `0x3B867F78D3eCfCad997b18220444AdafBC8372A8`

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

## Notes & Next Steps

- Expand each section with standard operating procedures (SOPs) as new responsibilities are delegated.
- Keep this file in sync with address rotations (`TransferOwnershipMainnet.s.sol`) and any updates to multisig compositions.
- When adding new operations, prefer including: purpose, prerequisites, calldata example, gas considerations, and post-checks.
