# Lithos DEX Deployment Guide

## Complete Deployment Checklist

This checklist provides the complete order of operations for deploying the Lithos ve(3,3) DEX protocol from scratch.

### Phase 1: Core DEX Infrastructure

- [ ] **1. Deploy WXPL (Wrapped Native Token)**
  ```bash
  # Deploy wrapped native token contract
  ```

- [ ] **2. Deploy PairFactory**
  ```bash
  # Deploy the factory contract for creating liquidity pairs
  ```

- [ ] **3. Deploy RouterV2**
  ```bash
  # Deploy main router for swaps and liquidity
  ```

- [ ] **4. Deploy GlobalRouter**
  ```bash
  # Deploy global router for advanced routing
  ```

- [ ] **5. Deploy TradeHelper**
  ```bash
  # Deploy trade helper for price calculations
  ```

### Phase 2: Governance Token

- [ ] **6. Deploy LITHOS Token**
  ```bash
  # Deploy the LITHOS governance token
  ```

### Phase 3: Vote Escrow System

- [ ] **7. Deploy VotingEscrow**
  ```bash
  forge create src/contracts/VotingEscrow.sol:VotingEscrow \
    --constructor-args <TOKEN_ADDRESS> <VEARTPROXY_ADDRESS> \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --verify
  ```

- [ ] **8. Deploy VeArtProxyUpgradeable**
  ```bash
  # Deploy the NFT art proxy for veNFTs
  ```

- [ ] **9. Deploy RewardsDistributor**
  ```bash
  # Deploy rewards distributor for veNFT holders
  ```

- [ ] **10. Deploy PermissionsRegistry**
  ```bash
  # Deploy permissions registry for role management
  ```

### Phase 4: Gauge & Voting System

- [ ] **11. Deploy GaugeFactoryV2**
  ```bash
  forge create src/contracts/factories/GaugeFactoryV2.sol:GaugeFactoryV2 \
    --constructor-args <OWNER_ADDRESS> \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --verify
  ```

- [ ] **12. Deploy BribeFactoryV3**
  ```bash
  forge create src/contracts/factories/BribeFactoryV3.sol:BribeFactoryV3 \
    --constructor-args <VOTER_ADDRESS> <PERMISSIONS_REGISTRY> \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --verify
  ```

- [ ] **13. Deploy VoterV3**
  ```bash
  forge create src/contracts/VoterV3.sol:VoterV3 \
    --constructor-args <VE_ADDRESS> <PAIR_FACTORY> <GAUGE_FACTORY> <BRIBE_FACTORY> \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --verify
  ```
  **Note**: Ensure VoterV3 includes the `ve()` getter function for IVoter interface compatibility

- [ ] **14. Update BribeFactory Voter Reference**
  ```bash
  forge script script/UpdateBribeFactoryVoter.s.sol:UpdateBribeFactoryVoter \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --broadcast
  ```

### Phase 5: Emissions & Minting

- [ ] **15. Deploy MinterUpgradeable**
  ```bash
  forge script script/DeployMinter.s.sol:DeployMinter \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --broadcast
  ```

- [ ] **16. Update Minter Voter Reference**
  ```bash
  forge script script/UpdateMinterVoter.s.sol:UpdateMinterVoter \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --broadcast
  ```

### Phase 6: Contract Initialization & Linking

- [ ] **17. Initialize VoterV3**
  ```bash
  forge script script/InitializeVoter.s.sol:InitializeVoter \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --broadcast
  ```
  - Sets Minter address
  - Whitelists initial tokens (LITHOS, WXPL, stablecoins)

- [ ] **18. Update VotingEscrow Voter**
  ```bash
  forge script script/UpdateVotingEscrowVoter.s.sol:UpdateVotingEscrowVoter \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --broadcast
  ```

- [ ] **19. Update LITHOS Token Minter**
  ```bash
  forge script script/UpdateLithosMinter.s.sol:UpdateLithosMinter \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --broadcast
  ```

### Phase 7: Permissions & Access Control

- [ ] **20. Set Permissions in Registry**
  ```bash
  forge script script/SetPermissions.s.sol:SetPermissions \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --broadcast
  ```
  - Configures VOTER_ADMIN role
  - Configures GOVERNANCE role
  - Configures GAUGE_ADMIN role
  - Configures BRIBE_ADMIN role

### Phase 8: Initial Liquidity & Gauges

- [ ] **21. Create Initial Liquidity Pools**
  - Deploy priority trading pairs through PairFactory
  - Add initial liquidity to pairs

- [ ] **22. Create Gauges for Pools**
  ```bash
  # For each pool, create a gauge (one at a time due to gas limits)
  forge script script/CreateSingleGauge.s.sol:CreateSingleGauge \
    --sig "run(uint256)" <PAIR_INDEX> \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --legacy --gas-price 25000000000 --gas-limit 8000000 --broadcast
  ```

- [ ] **23. Verify Gauge Contracts**
  ```bash
  # For each gauge created, verify the gauge and its bribe contracts
  # 1. Encode constructor args
  cast abi-encode "constructor(address,address,address,address,address,address,address,address[])" \
    <STAKE_TOKEN> <VOTER> <PERMISSIONS> <VE> <REWARDS_DIST> <TEST_TOKEN> <LITHOS> "[]"

  # 2. Verify gauge
  forge verify-contract <GAUGE_ADDRESS> src/contracts/GaugeV2.sol:GaugeV2 \
    --chain-id <CHAIN_ID> \
    --constructor-args <ENCODED_ARGS>

  # 3. Verify internal & external bribes (same process)
  ```

### Phase 9: Final Configuration

- [ ] **24. Set Initial Emission Rate**
  - Configure weekly emissions in Minter

- [ ] **25. Transfer Ownership (if using multisig)**
  - Transfer ownership of critical contracts to multisig
  - Contracts: VoterV3, MinterUpgradeable, PermissionsRegistry

- [ ] **26. Final Verification**
  - Verify all contract addresses are correctly linked
  - Test critical functions (swap, add liquidity, lock tokens, vote, claim rewards)
  - Verify emissions are working correctly

## Testnet Deployment Reference

### Plasma Testnet (Chain ID: 9746)

#### Core DEX
- **PairFactory**: `0xF1471A005b7557C1d472f0a060040f93ae074297`
- **RouterV2**: `0x84E8a39C85F645c7f7671689a9337B33Bdc784f8`
- **GlobalRouter**: `0x48406768424369b69Cc52886A6520a1839CC426E`
- **TradeHelper**: `0x08798C36d9e1d274Ab48C732B588d9eEE7526E0e`
- **WXPL**: `0x6100E367285b01F48D07953803A2d8dCA5D19873`

#### ve(3,3) Governance
- **VotingEscrow**: `0x592FA200950B053aCE9Be6d4FB3F58b1763898C0`
- **VeArtProxyUpgradeable**: `0x2A66F82F6ce9976179D191224A1E4aC8b50e68D1`
- **RewardsDistributor**: `0x3b32FEDe4309265Cacc601368787F4264C69070e`
- **PermissionsRegistry**: `0x3A908c6095bD1A69b651D7B32AB42806528d88c8`
- **VoterV3**: `0xb7cF73026b3a35955081BB8D9025aE13C50C74cd`
- **GaugeFactoryV2**: `0x23e7E5f66Ff4396F0D95ad630f4297D768193DE1`
- **BribeFactoryV3**: `0xC4B0BeCF35366629712FCEfcB4A88727236A531E`
- **MinterUpgradeable**: `0x6e74245E7E7582790bE61a1a16b459945cCf65A2`

#### Tokens
- **LITHOS**: `0x45b7C44DC11c6b0E2399F4fd1730F2dB3A30aD51`
- **TEST**: `0xb89cdFf170b45797BF93536773113861EBEABAfa`

#### Example Gauge & Bribes (Pair 0)
- **Pair**: `0xaFF8bE2810F056384e5E15dcF8AB8FAf5Aa92d8A`
- **Gauge**: `0xaff8EF3a3aCfeF558cb6b32DB1d8b0C7d0Bd43ED` ✅
- **Internal Bribe**: `0xf9ED85d7c293B9773f9f84A285f8a950A9C21d86` ✅
- **External Bribe**: `0xf1f95E914cED73f95F1323CFd8F8f0bdf902bC06` ✅

## Important Notes

1. **Gas Settings**: Use `--legacy --gas-price 25000000000` flags for all deployments on Plasma
2. **Gauge Creation**: Create gauges one at a time with 8M gas limit to avoid out-of-gas errors
3. **VoterV3 Interface**: Ensure VoterV3 includes the `ve()` function to match IVoter interface
4. **Token Whitelisting**: Whitelist all trading tokens in VoterV3 before creating gauges
5. **Verification**: Verify contracts immediately after deployment for transparency

## Scripts Available

Current scripts in `/script` cover phases 4-8.
