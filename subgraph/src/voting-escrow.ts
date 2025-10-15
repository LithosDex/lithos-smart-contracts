import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
  Supply as SupplyEvent,
  Transfer as TransferEvent,
  Approval as ApprovalEvent,
  ApprovalForAll as ApprovalForAllEvent,
  DelegateChanged as DelegateChangedEvent,
  DelegateVotesChanged as DelegateVotesChangedEvent,
  VotingEscrow as VotingEscrowContract
} from "../generated/VotingEscrow/VotingEscrow";

import {
  VotingEscrow,
  VeNFT,
  User,
  VeDeposit,
  VeWithdraw,
  VeTransfer,
  VeDelegation
} from "../generated/schema";

import { BI_ZERO, BI_ONE, createUser, ZERO_ADDRESS, convertTokenToDecimal, BI_18 } from "./helpers";

// Initialize VotingEscrow entity
function getOrCreateVotingEscrow(address: Address): VotingEscrow {
  let votingEscrow = VotingEscrow.load(address.toHexString());
  if (votingEscrow === null) {
    votingEscrow = new VotingEscrow(address.toHexString());
    votingEscrow.address = address;
    votingEscrow.totalSupply = BI_ZERO;
    votingEscrow.totalLocked = BI_ZERO;
    votingEscrow.totalNFTs = BI_ZERO;
    votingEscrow.save();
  }
  return votingEscrow;
}

// Initialize veNFT entity
function getOrCreateVeNFT(tokenId: BigInt, votingEscrowAddress: Address): VeNFT {
  let veNFT = VeNFT.load(tokenId.toString());
  if (veNFT === null) {
    veNFT = new VeNFT(tokenId.toString());
    veNFT.tokenId = tokenId;
    veNFT.votingEscrow = votingEscrowAddress.toHexString();
    // Create a default user for uninitialized veNFTs
    let defaultUser = createUser(Address.fromString(ZERO_ADDRESS));
    veNFT.owner = defaultUser.id;
    veNFT.value = BI_ZERO;
    veNFT.lockEnd = BI_ZERO;
    veNFT.lockDuration = BI_ZERO;
    veNFT.delegatedTo = null;
    veNFT.createdAt = BI_ZERO;
    veNFT.updatedAt = BI_ZERO;
    veNFT.isActive = true;
    veNFT.save();
  }
  return veNFT;
}

// Handle Deposit events (create_lock, increase_amount, increase_unlock_time)
export function handleDeposit(event: DepositEvent): void {
  let votingEscrow = getOrCreateVotingEscrow(event.address);
  let veNFT = getOrCreateVeNFT(event.params.tokenId, event.address);
  let user = createUser(event.params.provider);

  // Create deposit entity
  let deposit = new VeDeposit(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  deposit.transaction = event.transaction.hash;
  deposit.timestamp = event.block.timestamp;
  deposit.blockNumber = event.block.number;
  deposit.user = user.id;
  deposit.veNFT = veNFT.id;
  deposit.votingEscrow = votingEscrow.id;
  deposit.value = event.params.value;
  deposit.locktime = event.params.locktime;
  deposit.depositType = event.params.deposit_type;
  deposit.save();

  // Update veNFT with event data
  if (event.params.value.gt(BI_ZERO)) {
    // Add value for deposits carrying additional token amount
    veNFT.value = veNFT.value.plus(event.params.value);
  }
  // For increase_unlock_time (type 3), don't change value
  
  veNFT.lockEnd = event.params.locktime;
  veNFT.lockDuration = event.params.locktime.minus(event.block.timestamp);

  veNFT.updatedAt = event.block.timestamp;
  if (veNFT.createdAt.equals(BI_ZERO)) {
    veNFT.createdAt = event.block.timestamp;
    votingEscrow.totalNFTs = votingEscrow.totalNFTs.plus(BI_ONE);
  }
  veNFT.save();

  // Update owner stats with locked amount
  if (event.params.value.gt(BI_ZERO) && veNFT.owner != ZERO_ADDRESS) {
    let ownerAddress = Address.fromString(veNFT.owner);
    let ownerUser = createUser(ownerAddress);
    ownerUser.totalLocked = ownerUser.totalLocked.plus(convertTokenToDecimal(event.params.value, BI_18));
    ownerUser.save();
  }

  // Update voting escrow stats
  votingEscrow.totalLocked = votingEscrow.totalLocked.plus(event.params.value);
  votingEscrow.save();
}

// Handle Withdraw events
export function handleWithdraw(event: WithdrawEvent): void {
  let votingEscrow = getOrCreateVotingEscrow(event.address);
  let veNFT = VeNFT.load(event.params.tokenId.toString());
  let user = createUser(event.params.provider);

  // Create withdraw entity
  let withdraw = new VeWithdraw(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  withdraw.transaction = event.transaction.hash;
  withdraw.timestamp = event.block.timestamp;
  withdraw.blockNumber = event.block.number;
  withdraw.user = user.id;
  withdraw.veNFTId = veNFT ? veNFT.id : "";
  withdraw.votingEscrow = votingEscrow.id;
  withdraw.value = event.params.value;
  withdraw.save();

  // Update veNFT (mark as inactive after withdrawal)
  if (veNFT) {
    veNFT.value = BI_ZERO;
    veNFT.lockEnd = BI_ZERO;
    veNFT.lockDuration = BI_ZERO;
    veNFT.isActive = false;
    veNFT.updatedAt = event.block.timestamp;
    veNFT.save();
  }

  // Update voting escrow stats
  votingEscrow.totalLocked = votingEscrow.totalLocked.minus(event.params.value);
  votingEscrow.save();
}

// Handle Supply events
export function handleSupply(event: SupplyEvent): void {
  let votingEscrow = getOrCreateVotingEscrow(event.address);
  votingEscrow.totalSupply = event.params.supply;
  votingEscrow.save();
}

// Handle NFT Transfer events
export function handleTransfer(event: TransferEvent): void {
  let veNFT = getOrCreateVeNFT(event.params.tokenId, event.address);

  let fromUser = event.params.from.toHexString() != ZERO_ADDRESS ? createUser(event.params.from) : null;
  let toUser = event.params.to.toHexString() != ZERO_ADDRESS ? createUser(event.params.to) : null;
  let lockedValueDecimal = convertTokenToDecimal(veNFT.value, BI_18);

  // Create transfer entity
  let transfer = new VeTransfer(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  transfer.transaction = event.transaction.hash;
  transfer.timestamp = event.block.timestamp;
  transfer.blockNumber = event.block.number;
  transfer.fromUser = fromUser ? fromUser.id : null;
  transfer.toUser = toUser ? toUser.id : null;
  transfer.fromAddress = fromUser ? fromUser.id : ZERO_ADDRESS;
  transfer.toAddress = toUser ? toUser.id : ZERO_ADDRESS;
  transfer.veNFT = veNFT.id;
  transfer.save();

  // Update veNFT owner
  // Ensure we have a valid user entity for the owner
  if (toUser) {
    veNFT.owner = toUser.id;
  } else {
    let defaultUser = createUser(Address.fromString(ZERO_ADDRESS));
    veNFT.owner = defaultUser.id;
  }
  veNFT.updatedAt = event.block.timestamp;
  veNFT.save();

  // Update user counts
  if (fromUser && fromUser.id != ZERO_ADDRESS) {
    fromUser.veNFTCount = fromUser.veNFTCount.minus(BI_ONE);
    fromUser.totalLocked = fromUser.totalLocked.minus(lockedValueDecimal);
    fromUser.save();
  }
  if (toUser && toUser.id != ZERO_ADDRESS) {
    toUser.veNFTCount = toUser.veNFTCount.plus(BI_ONE);
    toUser.totalLocked = toUser.totalLocked.plus(lockedValueDecimal);
    toUser.save();
  }
}

// Handle Approval events
export function handleApproval(event: ApprovalEvent): void {
  // Track NFT approvals if needed for advanced queries
  // Implementation can be added based on requirements
}

// Handle ApprovalForAll events
export function handleApprovalForAll(event: ApprovalForAllEvent): void {
  // Track operator approvals if needed for advanced queries
  // Implementation can be added based on requirements
}

// Handle DelegateChanged events
export function handleDelegateChanged(event: DelegateChangedEvent): void {
  let delegator = createUser(event.params.delegator);
  let fromDelegate = event.params.fromDelegate.toHexString() != ZERO_ADDRESS ? createUser(event.params.fromDelegate) : null;
  let toDelegate = event.params.toDelegate.toHexString() != ZERO_ADDRESS ? createUser(event.params.toDelegate) : null;

  // Create delegation entity
  let delegation = new VeDelegation(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  delegation.transaction = event.transaction.hash;
  delegation.timestamp = event.block.timestamp;
  delegation.blockNumber = event.block.number;
  delegation.delegator = delegator.id;
  delegation.fromDelegate = fromDelegate ? fromDelegate.id : ZERO_ADDRESS;
  delegation.toDelegate = toDelegate ? toDelegate.id : ZERO_ADDRESS;
  delegation.save();

  // Update user delegation info
  delegator.delegatedTo = toDelegate ? toDelegate.id : null;
  delegator.save();
}

// Handle DelegateVotesChanged events
export function handleDelegateVotesChanged(event: DelegateVotesChangedEvent): void {
  let delegate = createUser(event.params.delegate);
  
  // Update delegate's voting power - using newVotes from the event  
  delegate.delegatedVotingPower = event.params.newVotes;
  delegate.save();
}
