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
  BribeEpochReward,
  BribeEpochStake,
  BribeEpochVeStake,
  Pair,
  PairBribeEpochReward,
  Token
} from "../generated/schema";

import { BI_ZERO, BI_ONE, WEEK, createUser, getOrCreateToken, getEpoch } from "./helpers";

function getOrCreateEpochStake(
  bribe: Bribe,
  epoch: BigInt,
  timestamp: BigInt,
  blockNumber: BigInt
): BribeEpochStake {
  let id = bribe.id.concat("-").concat(epoch.toString());
  let epochStake = BribeEpochStake.load(id);
  if (epochStake === null) {
    epochStake = new BribeEpochStake(id);
    epochStake.bribe = bribe.id;
    epochStake.epoch = epoch;
    epochStake.totalWeight = BI_ZERO;
  }
  epochStake.updatedAtTimestamp = timestamp;
  epochStake.updatedAtBlockNumber = blockNumber;
  return epochStake;
}

function getOrCreateEpochVeStake(
  bribe: Bribe,
  epochStake: BribeEpochStake,
  veNFT: string,
  epoch: BigInt,
  timestamp: BigInt,
  blockNumber: BigInt
): BribeEpochVeStake {
  let id = epochStake.id.concat("-").concat(veNFT);
  let veStake = BribeEpochVeStake.load(id);
  if (veStake === null) {
    veStake = new BribeEpochVeStake(id);
    veStake.epochStake = epochStake.id;
    veStake.bribe = bribe.id;
    veStake.veNFT = veNFT;
    veStake.epoch = epoch;
    veStake.weight = BI_ZERO;
  }
  veStake.updatedAtTimestamp = timestamp;
  veStake.updatedAtBlockNumber = blockNumber;
  return veStake;
}

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
  let epochStart = getEpoch(event.params.startTimestamp);

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
  rewardAdded.epoch = epochStart;
  rewardAdded.save();
  
  // Aggregate rewards per epoch
  let epochRewardId = rewardToken.id.concat("-").concat(epochStart.toString());
  let epochReward = BribeEpochReward.load(epochRewardId);
  if (epochReward === null) {
    epochReward = new BribeEpochReward(epochRewardId);
    epochReward.bribe = bribe.id;
    epochReward.rewardToken = rewardToken.id;
    epochReward.epoch = epochStart;
    epochReward.epochStart = epochStart;
    epochReward.epochEnd = epochStart.plus(WEEK);
    epochReward.reward = BI_ZERO;
    epochReward.updatedAtTimestamp = event.block.timestamp;
    epochReward.updatedAtBlockNumber = event.block.number;
  }
  epochReward.reward = epochReward.reward.plus(event.params.reward);
  epochReward.updatedAtTimestamp = event.block.timestamp;
  epochReward.updatedAtBlockNumber = event.block.number;
  epochReward.save();

  // Track bribe rewards per pair/epoch (internal and external)
  if (bribe.pair !== null) {
    let pairId = bribe.pair as string;
    let pair = Pair.load(pairId);
    if (pair !== null) {
      let rewardTokenId = rewardToken.token;
      let internalEpochId = pairId
        .concat("-")
        .concat(epochStart.toString())
        .concat("-")
        .concat(rewardTokenId);
      let internalEpoch = PairBribeEpochReward.load(internalEpochId);
      if (internalEpoch === null) {
        internalEpoch = new PairBribeEpochReward(internalEpochId);
        internalEpoch.pair = pairId;
        internalEpoch.bribe = bribe.id;
        if (bribe.gauge !== null) {
          internalEpoch.gauge = bribe.gauge as string;
        }
        internalEpoch.rewardToken = rewardTokenId;
        internalEpoch.isInternal = bribe.type == "internal";
        internalEpoch.epoch = epochStart;
        internalEpoch.epochStart = epochStart;
        internalEpoch.epochEnd = epochStart.plus(WEEK);
        internalEpoch.reward = BI_ZERO;
      }
      if (bribe.gauge !== null) {
        internalEpoch.gauge = bribe.gauge as string;
      }
      internalEpoch.isInternal = bribe.type == "internal";
      internalEpoch.reward = internalEpoch.reward.plus(event.params.reward);
      internalEpoch.updatedAtTimestamp = event.block.timestamp;
      internalEpoch.updatedAtBlockNumber = event.block.number;
      internalEpoch.save();
    }
  }
  
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

  let epochStake = getOrCreateEpochStake(
    bribe,
    stake.epoch,
    event.block.timestamp,
    event.block.number
  );
  epochStake.totalWeight = epochStake.totalWeight.plus(event.params.amount);
  epochStake.save();

  let veStake = getOrCreateEpochVeStake(
    bribe,
    epochStake,
    stake.veNFT,
    stake.epoch,
    event.block.timestamp,
    event.block.number
  );
  veStake.weight = veStake.weight.plus(event.params.amount);
  veStake.save();

  stake.epochStake = epochStake.id;
  
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
  if (bribe.totalVotingPower.lt(BI_ZERO)) {
    bribe.totalVotingPower = BI_ZERO;
  }
  bribe.save();

  let epochStake = getOrCreateEpochStake(
    bribe,
    withdraw.epoch,
    event.block.timestamp,
    event.block.number
  );
  epochStake.totalWeight = epochStake.totalWeight.minus(event.params.amount);
  if (epochStake.totalWeight.lt(BI_ZERO)) {
    epochStake.totalWeight = BI_ZERO;
  }
  epochStake.save();

  let veStake = getOrCreateEpochVeStake(
    bribe,
    epochStake,
    event.params.tokenId.toString(),
    withdraw.epoch,
    event.block.timestamp,
    event.block.number
  );
  veStake.weight = veStake.weight.minus(event.params.amount);
  if (veStake.weight.lt(BI_ZERO)) {
    veStake.weight = BI_ZERO;
  }
  veStake.save();
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
