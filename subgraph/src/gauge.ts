import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  RewardAdded as RewardAddedEvent,
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
  Harvest as HarvestEvent,
  ClaimFees as ClaimFeesEvent,
  EmergencyActivated as EmergencyActivatedEvent,
  EmergencyDeactivated as EmergencyDeactivatedEvent,
  GaugeV2 as GaugeV2Contract
} from "../generated/templates/GaugeV2/GaugeV2";

import {
  Gauge,
  GaugePosition,
  GaugeDeposit,
  GaugeWithdraw,
  GaugeRewardAdded,
  GaugeHarvest,
  GaugeFeeClaim,
  GaugeEmergencyEvent,
  Pair
} from "../generated/schema";

import { BI_ZERO, BI_ONE, createUser, getOrCreateToken } from "./helpers";

// Get or create Gauge entity
function getOrCreateGauge(address: Address): Gauge {
  let gauge = Gauge.load(address.toHexString());
  if (gauge === null) {
    gauge = new Gauge(address.toHexString());
    gauge.address = address;
    gauge.totalStaked = BI_ZERO;
    gauge.totalRewardsDistributed = BI_ZERO;
    gauge.rewardRate = BI_ZERO;
    gauge.periodFinish = BI_ZERO;
    gauge.lastUpdateTime = BI_ZERO;
    gauge.emergency = false;
    
    // Try to get contract info
    let contract = GaugeV2Contract.bind(address);
    
    // Get reward token
    let rewardTokenResult = contract.try_rewardToken();
    if (!rewardTokenResult.reverted) {
      let rewardToken = getOrCreateToken(rewardTokenResult.value);
      gauge.rewardToken = rewardToken.id;
    } else {
      // Fallback to zero address token
      let rewardToken = getOrCreateToken(Address.zero());
      gauge.rewardToken = rewardToken.id;
    }
    
    // Get staking token (LP token)
    let stakingTokenResult = contract.try_TOKEN();
    if (!stakingTokenResult.reverted) {
      let stakingToken = getOrCreateToken(stakingTokenResult.value);
      gauge.stakingToken = stakingToken.id;

      let pairEntity = Pair.load(stakingToken.id);
      if (pairEntity !== null) {
        pairEntity.gauge = gauge.id;
        pairEntity.save();
        gauge.pair = pairEntity.id;
      }
    } else {
      // Fallback to zero address token
      let stakingToken = getOrCreateToken(Address.zero());
      gauge.stakingToken = stakingToken.id;
    }
    
    // Get VotingEscrow address
    let veResult = contract.try_VE();
    if (!veResult.reverted) {
      gauge.votingEscrow = veResult.value;
    } else {
      gauge.votingEscrow = Address.zero();
    }
    
    // Get distribution address (VoterV3)
    let distributionResult = contract.try_DISTRIBUTION();
    if (!distributionResult.reverted) {
      gauge.distribution = distributionResult.value;
      gauge.voter = distributionResult.value.toHexString(); // Voter is the distribution contract
    } else {
      gauge.distribution = Address.zero();
      gauge.voter = Address.zero().toHexString();
    }
    
    // Get internal bribe address
    let internalBribeResult = contract.try_internal_bribe();
    if (!internalBribeResult.reverted) {
      gauge.internalBribe = internalBribeResult.value.toHexString();
    } else {
      gauge.internalBribe = Address.zero().toHexString();
    }
    
    // Get external bribe address
    let externalBribeResult = contract.try_external_bribe();
    if (!externalBribeResult.reverted) {
      gauge.externalBribe = externalBribeResult.value.toHexString();
    } else {
      gauge.externalBribe = Address.zero().toHexString();
    }
    
    // Get isForPair flag
    let isForPairResult = contract.try_isForPair();
    if (!isForPairResult.reverted) {
      gauge.isForPair = isForPairResult.value;
    } else {
      gauge.isForPair = false;
    }
    
    // Get gauge rewarder
    let gaugeRewarderResult = contract.try_gaugeRewarder();
    if (!gaugeRewarderResult.reverted) {
      gauge.gaugeRewarder = gaugeRewarderResult.value;
    } else {
      gauge.gaugeRewarder = Address.zero();
    }
    
    // Get current state
    let emergencyResult = contract.try_emergency();
    if (!emergencyResult.reverted) {
      gauge.emergency = emergencyResult.value;
    }
    
    let rewardRateResult = contract.try_rewardRate();
    if (!rewardRateResult.reverted) {
      gauge.rewardRate = rewardRateResult.value;
    }
    
    let periodFinishResult = contract.try_periodFinish();
    if (!periodFinishResult.reverted) {
      gauge.periodFinish = periodFinishResult.value;
    }
    
    let lastUpdateTimeResult = contract.try_lastUpdateTime();
    if (!lastUpdateTimeResult.reverted) {
      gauge.lastUpdateTime = lastUpdateTimeResult.value;
    }
    
    let totalSupplyResult = contract.try_totalSupply();
    if (!totalSupplyResult.reverted) {
      gauge.totalStaked = totalSupplyResult.value;
    }
    
    gauge.save();
  }
  return gauge;
}

// Get or create GaugePosition entity
function getOrCreateGaugePosition(gaugeAddress: Address, userAddress: Address): GaugePosition {
  let id = gaugeAddress.toHexString() + "-" + userAddress.toHexString();
  let position = GaugePosition.load(id);
  if (position === null) {
    position = new GaugePosition(id);
    position.gauge = gaugeAddress.toHexString();
    position.user = createUser(userAddress).id;
    position.stakedBalance = BI_ZERO;
    position.rewardDebt = BI_ZERO;
    position.pendingRewards = BI_ZERO;
    position.totalDeposited = BI_ZERO;
    position.totalWithdrawn = BI_ZERO;
    position.totalRewardsClaimed = BI_ZERO;
    position.lastDepositTime = BI_ZERO;
    position.lastWithdrawTime = BI_ZERO;
    position.lastHarvestTime = BI_ZERO;
    position.save();
  }
  return position;
}

// Handle RewardAdded events (from VoterV3 distribution)
export function handleRewardAdded(event: RewardAddedEvent): void {
  let gauge = getOrCreateGauge(event.address);
  
  // Create reward added event
  let rewardAdded = new GaugeRewardAdded(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  rewardAdded.transaction = event.transaction.hash;
  rewardAdded.timestamp = event.block.timestamp;
  rewardAdded.blockNumber = event.block.number;
  rewardAdded.gauge = gauge.id;
  rewardAdded.reward = event.params.reward;
  
  // Get updated contract state
  let contract = GaugeV2Contract.bind(event.address);
  
  let rewardRateResult = contract.try_rewardRate();
  if (!rewardRateResult.reverted) {
    rewardAdded.newRewardRate = rewardRateResult.value;
    gauge.rewardRate = rewardRateResult.value;
  } else {
    rewardAdded.newRewardRate = BI_ZERO;
  }
  
  let periodFinishResult = contract.try_periodFinish();
  if (!periodFinishResult.reverted) {
    rewardAdded.periodFinish = periodFinishResult.value;
    gauge.periodFinish = periodFinishResult.value;
  } else {
    rewardAdded.periodFinish = BI_ZERO;
  }
  
  rewardAdded.save();
  
  // Update gauge totals
  gauge.totalRewardsDistributed = gauge.totalRewardsDistributed.plus(event.params.reward);
  gauge.lastUpdateTime = event.block.timestamp;
  gauge.save();
}

// Handle Deposit events (LP token staking)
export function handleDeposit(event: DepositEvent): void {
  let gauge = getOrCreateGauge(event.address);
  let user = createUser(event.params.user);
  let position = getOrCreateGaugePosition(event.address, event.params.user);
  
  // Create deposit event
  let deposit = new GaugeDeposit(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  deposit.transaction = event.transaction.hash;
  deposit.timestamp = event.block.timestamp;
  deposit.blockNumber = event.block.number;
  deposit.gauge = gauge.id;
  deposit.user = user.id;
  deposit.amount = event.params.amount;
  deposit.save();
  
  // Update position
  position.stakedBalance = position.stakedBalance.plus(event.params.amount);
  position.totalDeposited = position.totalDeposited.plus(event.params.amount);
  position.lastDepositTime = event.block.timestamp;
  position.save();
  
  // Update gauge total
  gauge.totalStaked = gauge.totalStaked.plus(event.params.amount);
  gauge.save();
}

// Handle Withdraw events (LP token unstaking)
export function handleWithdraw(event: WithdrawEvent): void {
  let gauge = getOrCreateGauge(event.address);
  let user = createUser(event.params.user);
  let position = getOrCreateGaugePosition(event.address, event.params.user);
  
  // Create withdraw event
  let withdraw = new GaugeWithdraw(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  withdraw.transaction = event.transaction.hash;
  withdraw.timestamp = event.block.timestamp;
  withdraw.blockNumber = event.block.number;
  withdraw.gauge = gauge.id;
  withdraw.user = user.id;
  withdraw.amount = event.params.amount;
  withdraw.isEmergency = gauge.emergency; // Check if this was during emergency mode
  withdraw.save();
  
  // Update position
  position.stakedBalance = position.stakedBalance.minus(event.params.amount);
  position.totalWithdrawn = position.totalWithdrawn.plus(event.params.amount);
  position.lastWithdrawTime = event.block.timestamp;
  position.save();
  
  // Update gauge total
  gauge.totalStaked = gauge.totalStaked.minus(event.params.amount);
  gauge.save();
}

// Handle Harvest events (reward claiming)
export function handleHarvest(event: HarvestEvent): void {
  let gauge = getOrCreateGauge(event.address);
  let user = createUser(event.params.user);
  let position = getOrCreateGaugePosition(event.address, event.params.user);
  
  // Create harvest event
  let harvest = new GaugeHarvest(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  harvest.transaction = event.transaction.hash;
  harvest.timestamp = event.block.timestamp;
  harvest.blockNumber = event.block.number;
  harvest.gauge = gauge.id;
  harvest.user = user.id;
  harvest.reward = event.params.reward;
  harvest.save();
  
  // Update position
  position.totalRewardsClaimed = position.totalRewardsClaimed.plus(event.params.reward);
  position.lastHarvestTime = event.block.timestamp;
  position.save();
}

// Handle ClaimFees events (fee collection from underlying pair)
export function handleClaimFees(event: ClaimFeesEvent): void {
  let gauge = getOrCreateGauge(event.address);
  
  // Create fee claim event
  let feeClaim = new GaugeFeeClaim(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  feeClaim.transaction = event.transaction.hash;
  feeClaim.timestamp = event.block.timestamp;
  feeClaim.blockNumber = event.block.number;
  feeClaim.gauge = gauge.id;
  feeClaim.from = event.params.from;
  feeClaim.claimed0 = event.params.claimed0;
  feeClaim.claimed1 = event.params.claimed1;
  feeClaim.save();
}

// Handle EmergencyActivated events
export function handleEmergencyActivated(event: EmergencyActivatedEvent): void {
  let gauge = getOrCreateGauge(event.address);
  
  // Create emergency event
  let emergencyEvent = new GaugeEmergencyEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  emergencyEvent.transaction = event.transaction.hash;
  emergencyEvent.timestamp = event.block.timestamp;
  emergencyEvent.blockNumber = event.block.number;
  emergencyEvent.gauge = gauge.id;
  emergencyEvent.eventType = "activated";
  emergencyEvent.save();
  
  // Update gauge emergency status
  gauge.emergency = true;
  gauge.save();
}

// Handle EmergencyDeactivated events
export function handleEmergencyDeactivated(event: EmergencyDeactivatedEvent): void {
  let gauge = getOrCreateGauge(event.address);
  
  // Create emergency event
  let emergencyEvent = new GaugeEmergencyEvent(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  emergencyEvent.transaction = event.transaction.hash;
  emergencyEvent.timestamp = event.block.timestamp;
  emergencyEvent.blockNumber = event.block.number;
  emergencyEvent.gauge = gauge.id;
  emergencyEvent.eventType = "deactivated";
  emergencyEvent.save();
  
  // Update gauge emergency status
  gauge.emergency = false;
  gauge.save();
}
