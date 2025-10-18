import { Address, BigInt, store, ethereum } from "@graphprotocol/graph-ts";
import {
  GaugeCreated as GaugeCreatedEvent,
  Voted as VotedEvent,
  Abstained as AbstainedEvent,
  VoterV3 as VoterV3Contract
} from "../generated/VoterV3/VoterV3";

import {
  Voter,
  GaugeCreatedEvent as GaugeCreatedEventEntity,
  BribeFactory,
  Bribe,
  Gauge,
  Pair,
  GaugeEpochVote,
  TokenGaugeEpochVote,
  TokenEpochVoting
} from "../generated/schema";

import { BI_ZERO, BI_ONE, WEEK, createUser, getOrCreateToken, getEpoch } from "./helpers";

// Import templates for dynamic contract instantiation
import { Bribes as BribesTemplate, GaugeV2 as GaugeV2Template } from "../generated/templates";

// Get or create Voter entity
function getOrCreateVoter(address: Address): Voter {
  let voter = Voter.load(address.toHexString());
  if (voter === null) {
    voter = new Voter(address.toHexString());
    voter.address = address;
    voter.totalGaugesCreated = BI_ZERO;
    voter.totalPoolsWithGauges = BI_ZERO;
    
    // Try to get contract info
    let contract = VoterV3Contract.bind(address);
    
    // Note: gaugeFactories returns an array, we'll take the first one
    let gaugeFactoriesResult = contract.try_gaugeFactories();
    if (!gaugeFactoriesResult.reverted && gaugeFactoriesResult.value.length > 0) {
      voter.gaugeFactory = gaugeFactoriesResult.value[0];
    } else {
      voter.gaugeFactory = Address.zero();
    }
    
    let bribeFactoryResult = contract.try_bribefactory();
    if (!bribeFactoryResult.reverted) {
      voter.bribeFactory = bribeFactoryResult.value;
    } else {
      voter.bribeFactory = Address.zero();
    }
    
    let minterResult = contract.try_minter();
    if (!minterResult.reverted) {
      voter.minter = minterResult.value;
    } else {
      voter.minter = Address.zero();
    }
    
    let veResult = contract.try__ve();
    if (!veResult.reverted) {
      voter.votingEscrow = veResult.value;
    } else {
      voter.votingEscrow = Address.zero();
    }
    
    voter.save();
  }
  return voter;
}

// Get or create BribeFactory entity
function getOrCreateBribeFactory(address: Address): BribeFactory {
  let factory = BribeFactory.load(address.toHexString());
  if (factory === null) {
    factory = new BribeFactory(address.toHexString());
    factory.address = address;
    factory.totalBribesCreated = BI_ZERO;
    factory.lastBribe = Address.zero();
    factory.defaultRewardTokenCount = BI_ZERO;
    factory.voter = Address.zero(); // Will be updated when we know the voter
    factory.permissionsRegistry = Address.zero();
    factory.save();
  }
  return factory;
}

// Create Bribe entity from address
function createBribe(address: Address, factoryAddress: Address, bribeType: string): Bribe {
  let bribe = new Bribe(address.toHexString());
  bribe.address = address;
  bribe.type = bribeType;
  bribe.factory = factoryAddress.toHexString();
  bribe.voter = Address.zero();
  bribe.minter = Address.zero();
  bribe.bribeFactory = factoryAddress;
  
  // Create a default user for owner (will be updated when bribe contract is called)
  let user = createUser(Address.zero());
  bribe.owner = user.id;
  
  bribe.totalVotingPower = BI_ZERO;
  bribe.rewardTokenCount = BI_ZERO;
  
  bribe.save();
  return bribe;
}

// Create Gauge entity from address
function createGauge(address: Address, voterAddress: Address): Gauge {
  let gauge = new Gauge(address.toHexString());
  gauge.address = address;
  gauge.voter = voterAddress.toHexString();
  
  // Initialize with default values - will be updated by gauge handlers
  let defaultToken = getOrCreateToken(Address.zero());
  gauge.rewardToken = defaultToken.id;
  gauge.stakingToken = defaultToken.id;
  gauge.votingEscrow = Address.zero();
  gauge.distribution = voterAddress;
  
  // Will be set when we process the bribes
  gauge.internalBribe = Address.zero().toHexString();
  gauge.externalBribe = Address.zero().toHexString();
  
  gauge.isForPair = true; // Assume true, will be updated by gauge handlers
  gauge.emergency = false;
  gauge.totalStaked = BI_ZERO;
  gauge.totalRewardsDistributed = BI_ZERO;
  gauge.rewardRate = BI_ZERO;
  gauge.periodFinish = BI_ZERO;
  gauge.lastUpdateTime = BI_ZERO;
  gauge.gaugeRewarder = Address.zero();
  
  gauge.save();
  return gauge;
}

// Synchronize per-token votes and aggregate weights for the current epoch
function syncTokenVotes(event: ethereum.Event, tokenId: BigInt): void {
  let contract = VoterV3Contract.bind(event.address);
  let epochStart = getEpoch(event.block.timestamp);
  let epochEnd = epochStart.plus(WEEK);

  let tokenEpochId = tokenId
    .toString()
    .concat("-")
    .concat(epochStart.toString());
  let tokenEpoch = TokenEpochVoting.load(tokenEpochId);
  if (tokenEpoch === null) {
    tokenEpoch = new TokenEpochVoting(tokenEpochId);
    tokenEpoch.tokenId = tokenId;
    tokenEpoch.epoch = epochStart;
    tokenEpoch.pools = new Array<string>();
  }

  let previousPools = tokenEpoch.pools;
  if (previousPools === null) {
    previousPools = new Array<string>();
  }

  let currentPools = new Array<string>();
  let currentWeights = new Array<BigInt>();

  let poolVoteLengthResult = contract.try_poolVoteLength(tokenId);
  if (!poolVoteLengthResult.reverted) {
    let length = poolVoteLengthResult.value.toI32();
    for (let i = 0; i < length; i++) {
      let poolResult = contract.try_poolVote(tokenId, BigInt.fromI32(i));
      if (poolResult.reverted) {
        continue;
      }
      let poolAddress = poolResult.value;
      let poolId = poolAddress.toHexString();
      if (currentPools.indexOf(poolId) != -1) {
        continue;
      }
      currentPools.push(poolId);
      let voteResult = contract.try_votes(tokenId, poolAddress);
      if (!voteResult.reverted) {
        currentWeights.push(voteResult.value);
      } else {
        currentWeights.push(BI_ZERO);
      }
    }
  }

  let mergedPools = previousPools.concat(currentPools);
  let uniquePools = new Array<string>();
  for (let i = 0; i < mergedPools.length; i++) {
    let poolId = mergedPools[i];
    if (uniquePools.indexOf(poolId) == -1) {
      uniquePools.push(poolId);
    }
  }

  for (let i = 0; i < uniquePools.length; i++) {
    let poolId = uniquePools[i];
    let pair = Pair.load(poolId);
    if (pair === null) {
      continue;
    }
    let gaugeId = pair.gauge;
    if (gaugeId === null) {
      continue;
    }
    let gauge = Gauge.load(gaugeId as string);
    if (gauge === null) {
      continue;
    }
    let weightResult = contract.try_weights(Address.fromString(poolId));
    if (weightResult.reverted) {
      continue;
    }
    let epochVoteId = (gaugeId as string)
      .concat("-")
      .concat(epochStart.toString());
    let epochVote = GaugeEpochVote.load(epochVoteId);
    if (epochVote === null) {
      epochVote = new GaugeEpochVote(epochVoteId);
      epochVote.gauge = gaugeId as string;
      epochVote.bribe = gauge.externalBribe;
      epochVote.pair = pair.id;
      epochVote.epoch = epochStart;
      epochVote.epochStart = epochStart;
      epochVote.epochEnd = epochEnd;
      epochVote.totalWeight = weightResult.value;
    } else {
      epochVote.totalWeight = weightResult.value;
      epochVote.epoch = epochStart;
      epochVote.epochStart = epochStart;
      epochVote.epochEnd = epochEnd;
    }
    epochVote.updatedAtTimestamp = event.block.timestamp;
    epochVote.updatedAtBlockNumber = event.block.number;
    epochVote.save();
  }

  for (let i = 0; i < currentPools.length; i++) {
    let poolId = currentPools[i];
    let pair = Pair.load(poolId);
    if (pair === null) {
      continue;
    }
    let gaugeId = pair.gauge;
    if (gaugeId === null) {
      continue;
    }
    let gauge = Gauge.load(gaugeId as string);
    if (gauge === null) {
      continue;
    }
    let tokenVoteId = tokenId
      .toString()
      .concat("-")
      .concat(epochStart.toString())
      .concat("-")
      .concat(poolId);
    let tokenVote = TokenGaugeEpochVote.load(tokenVoteId);
    if (tokenVote === null) {
      tokenVote = new TokenGaugeEpochVote(tokenVoteId);
      tokenVote.tokenId = tokenId;
      tokenVote.gauge = gaugeId as string;
      tokenVote.bribe = gauge.externalBribe;
      tokenVote.pair = pair.id;
      tokenVote.epoch = epochStart;
      tokenVote.epochStart = epochStart;
      tokenVote.epochEnd = epochEnd;
    }
    tokenVote.weight = currentWeights[i];
    tokenVote.updatedAtTimestamp = event.block.timestamp;
    tokenVote.updatedAtBlockNumber = event.block.number;
    tokenVote.save();
  }

  for (let i = 0; i < previousPools.length; i++) {
    let poolId = previousPools[i];
    if (currentPools.indexOf(poolId) != -1) {
      continue;
    }
    let tokenVoteId = tokenId
      .toString()
      .concat("-")
      .concat(epochStart.toString())
      .concat("-")
      .concat(poolId);
    store.remove("TokenGaugeEpochVote", tokenVoteId);
  }

  tokenEpoch.pools = currentPools;
  tokenEpoch.epoch = epochStart;
  tokenEpoch.updatedAtTimestamp = event.block.timestamp;
  tokenEpoch.updatedAtBlockNumber = event.block.number;
  tokenEpoch.save();
}

// Handle GaugeCreated events from VoterV3
export function handleGaugeCreated(event: GaugeCreatedEvent): void {
  let voter = getOrCreateVoter(event.address);
  let bribeFactoryAddress = Address.fromBytes(voter.bribeFactory);
  let bribeFactory = getOrCreateBribeFactory(bribeFactoryAddress);
  
  // Create pool token entity
  let poolToken = getOrCreateToken(event.params.pool);
  
  // Create Bribe entities
  let internalBribe = createBribe(event.params.internal_bribe, bribeFactoryAddress, "internal");
  let externalBribe = createBribe(event.params.external_bribe, bribeFactoryAddress, "external");
  
  // Create Gauge entity
  let gauge = createGauge(event.params.gauge, event.address);
  gauge.stakingToken = poolToken.id;
  gauge.internalBribe = internalBribe.id;
  gauge.externalBribe = externalBribe.id;

  let pairEntity = Pair.load(event.params.pool.toHexString());
  if (pairEntity !== null) {
    pairEntity.gauge = gauge.id;
    pairEntity.save();
    gauge.pair = pairEntity.id;
  }

  gauge.save();
  
  internalBribe.gauge = gauge.id;
  internalBribe.pair = gauge.pair;
  internalBribe.save();
  externalBribe.gauge = gauge.id;
  externalBribe.pair = gauge.pair;
  externalBribe.save();
  
  // Create GaugeCreatedEvent entity
  let gaugeCreatedEvent = new GaugeCreatedEventEntity(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  gaugeCreatedEvent.transaction = event.transaction.hash;
  gaugeCreatedEvent.timestamp = event.block.timestamp;
  gaugeCreatedEvent.blockNumber = event.block.number;
  gaugeCreatedEvent.voter = voter.id;
  gaugeCreatedEvent.gauge = gauge.id;
  gaugeCreatedEvent.poolToken = poolToken.id;
  gaugeCreatedEvent.internalBribe = internalBribe.id;
  gaugeCreatedEvent.externalBribe = externalBribe.id;
  gaugeCreatedEvent.save();
  
  // Update Voter statistics
  voter.totalGaugesCreated = voter.totalGaugesCreated.plus(BI_ONE);
  voter.totalPoolsWithGauges = voter.totalPoolsWithGauges.plus(BI_ONE);
  voter.save();
  
  // Update BribeFactory statistics
  bribeFactory.totalBribesCreated = bribeFactory.totalBribesCreated.plus(BigInt.fromI32(2)); // Internal + External
  bribeFactory.lastBribe = event.params.external_bribe; // Use external as "last"
  bribeFactory.voter = event.address;
  bribeFactory.save();
  
  // Create template instances for dynamic indexing
  BribesTemplate.create(event.params.internal_bribe);
  BribesTemplate.create(event.params.external_bribe);
  GaugeV2Template.create(event.params.gauge);
}

export function handleVoted(event: VotedEvent): void {
  syncTokenVotes(event, event.params.tokenId);
}

export function handleAbstained(event: AbstainedEvent): void {
  syncTokenVotes(event, event.params.tokenId);
}
