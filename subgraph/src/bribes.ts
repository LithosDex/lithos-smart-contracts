import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  RewardAdded as RewardAddedEvent,
  Staked as StakedEvent,
  Withdrawn as WithdrawnEvent,
  RewardPaid as RewardPaidEvent,
  Recovered as RecoveredEvent,
  SetOwner as SetOwnerEvent,
  Bribes as BribesContract
} from "../generated/templates/Bribes/Bribes";

import {
  Bribe,
  BribeRewardToken,
  BribeRewardAdded,
  BribeStake,
  BribeWithdraw,
  BribeRewardPaid,
  Token
} from "../generated/schema";

import { BI_ZERO, BI_ONE, WEEK, createUser, getOrCreateToken, getEpoch } from "./helpers";

// Initialize Bribe entity
function getOrCreateBribe(address: Address): Bribe {
  let bribe = Bribe.load(address.toHexString());
  if (bribe === null) {
    bribe = new Bribe(address.toHexString());
    bribe.address = address;
    bribe.totalVotingPower = BI_ZERO;
    bribe.rewardTokenCount = BI_ZERO;
    
    // Try to get contract info
    let contract = BribesContract.bind(address);
    
    let typeResult = contract.try_type_();
    if (!typeResult.reverted) {
      bribe.type = typeResult.value;
    } else {
      bribe.type = "unknown";
    }
    
    let voterResult = contract.try_voter();
    if (!voterResult.reverted) {
      bribe.voter = voterResult.value;
    } else {
      bribe.voter = Address.zero();
    }
    
    let minterResult = contract.try_minter();
    if (!minterResult.reverted) {
      bribe.minter = minterResult.value;
    } else {
      bribe.minter = Address.zero();
    }
    
    let bribeFactoryResult = contract.try_bribeFactory();
    if (!bribeFactoryResult.reverted) {
      bribe.bribeFactory = bribeFactoryResult.value;
      bribe.factory = bribeFactoryResult.value.toHexString();
    } else {
      bribe.bribeFactory = Address.zero();
      bribe.factory = Address.zero().toHexString();
    }
    
    let ownerResult = contract.try_owner();
    if (!ownerResult.reverted) {
      let user = createUser(ownerResult.value);
      bribe.owner = user.id;
    } else {
      let user = createUser(Address.zero());
      bribe.owner = user.id;
    }
    
    bribe.save();
  }
  return bribe;
}

// Get or create BribeRewardToken entity
function getOrCreateBribeRewardToken(bribeAddress: Address, tokenAddress: Address): BribeRewardToken {
  let id = bribeAddress.toHexString() + "-" + tokenAddress.toHexString();
  let rewardToken = BribeRewardToken.load(id);
  if (rewardToken === null) {
    rewardToken = new BribeRewardToken(id);
    rewardToken.bribe = bribeAddress.toHexString();
    rewardToken.token = getOrCreateToken(tokenAddress).id;
    rewardToken.totalRewards = BI_ZERO;
    rewardToken.epochCount = BI_ZERO;
    rewardToken.isActive = true;
    rewardToken.save();
    
    // Update bribe reward token count
    let bribe = getOrCreateBribe(bribeAddress);
    bribe.rewardTokenCount = bribe.rewardTokenCount.plus(BI_ONE);
    bribe.save();
  }
  return rewardToken;
}

// Handle RewardAdded events
export function handleRewardAdded(event: RewardAddedEvent): void {
  let bribe = getOrCreateBribe(event.address);
  let rewardToken = getOrCreateBribeRewardToken(event.address, event.params.rewardToken);
  
  // Create reward added event
  let rewardAdded = new BribeRewardAdded(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  rewardAdded.transaction = event.transaction.hash;
  rewardAdded.timestamp = event.block.timestamp;
  rewardAdded.blockNumber = event.block.number;
  rewardAdded.bribe = bribe.id;
  rewardAdded.rewardToken = rewardToken.id;
  rewardAdded.rewardTokenAddress = event.params.rewardToken;
  rewardAdded.reward = event.params.reward;
  rewardAdded.startTimestamp = event.params.startTimestamp;
  rewardAdded.epoch = getEpoch(event.params.startTimestamp);
  rewardAdded.save();
  
  // Update reward token totals
  rewardToken.totalRewards = rewardToken.totalRewards.plus(event.params.reward);
  rewardToken.epochCount = rewardToken.epochCount.plus(BI_ONE);
  rewardToken.save();
}

// Handle Staked events (voting power deposits)
export function handleStaked(event: StakedEvent): void {
  let bribe = getOrCreateBribe(event.address);
  
  // Create stake event
  let stake = new BribeStake(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  stake.transaction = event.transaction.hash;
  stake.timestamp = event.block.timestamp;
  stake.blockNumber = event.block.number;
  stake.bribe = bribe.id;
  stake.veNFT = event.params.tokenId.toString();
  stake.amount = event.params.amount;
  
  // Calculate epoch (stakes apply to next epoch)
  let contract = BribesContract.bind(event.address);
  let nextEpochResult = contract.try_getNextEpochStart();
  if (!nextEpochResult.reverted) {
    stake.epoch = nextEpochResult.value;
  } else {
    // Fallback calculation
    stake.epoch = getEpoch(event.block.timestamp).plus(WEEK);
  }
  
  stake.save();
  
  // Update bribe total voting power
  bribe.totalVotingPower = bribe.totalVotingPower.plus(event.params.amount);
  bribe.save();
}

// Handle Withdrawn events (voting power withdrawals)
export function handleWithdrawn(event: WithdrawnEvent): void {
  let bribe = getOrCreateBribe(event.address);
  
  // Create withdraw event
  let withdraw = new BribeWithdraw(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  withdraw.transaction = event.transaction.hash;
  withdraw.timestamp = event.block.timestamp;
  withdraw.blockNumber = event.block.number;
  withdraw.bribe = bribe.id;
  withdraw.veNFTId = event.params.tokenId;
  withdraw.amount = event.params.amount;
  
  // Calculate epoch (withdrawals affect next epoch)
  let contract = BribesContract.bind(event.address);
  let nextEpochResult = contract.try_getNextEpochStart();
  if (!nextEpochResult.reverted) {
    withdraw.epoch = nextEpochResult.value;
  } else {
    // Fallback calculation
    withdraw.epoch = getEpoch(event.block.timestamp).plus(WEEK);
  }
  
  withdraw.save();
  
  // Update bribe total voting power
  bribe.totalVotingPower = bribe.totalVotingPower.minus(event.params.amount);
  bribe.save();
}

// Handle RewardPaid events
export function handleRewardPaid(event: RewardPaidEvent): void {
  let bribe = getOrCreateBribe(event.address);
  let user = createUser(event.params.user);
  
  // Create reward paid event
  let rewardPaid = new BribeRewardPaid(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  rewardPaid.transaction = event.transaction.hash;
  rewardPaid.timestamp = event.block.timestamp;
  rewardPaid.blockNumber = event.block.number;
  rewardPaid.bribe = bribe.id;
  rewardPaid.user = user.id;
  rewardPaid.rewardTokenAddress = event.params.rewardsToken;
  rewardPaid.reward = event.params.reward;
  rewardPaid.save();
}

// Handle Recovered events (emergency token recovery)
export function handleRecovered(event: RecoveredEvent): void {
  // Note: This is an admin function for emergency token recovery
  // We could track this if needed, but it's not core functionality
}

// Handle SetOwner events
export function handleSetOwner(event: SetOwnerEvent): void {
  let bribe = getOrCreateBribe(event.address);
  let user = createUser(event.params._owner);
  bribe.owner = user.id;
  bribe.save();
}
