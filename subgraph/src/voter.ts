import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  GaugeCreated as GaugeCreatedEvent,
  VoterV3 as VoterV3Contract
} from "../generated/VoterV3/VoterV3";

import {
  Voter,
  GaugeCreatedEvent as GaugeCreatedEventEntity,
  BribeFactory,
  Bribe,
  Gauge
} from "../generated/schema";

import { BI_ZERO, BI_ONE, createUser, getOrCreateToken } from "./helpers";

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
  gauge.save();
  
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