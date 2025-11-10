import { BigInt, BigDecimal, log } from "@graphprotocol/graph-ts";
import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
  Transfer as TransferEvent,
  Rebalance as RebalanceEvent
} from "../../generated/templates/Hypervisor/Hypervisor";
import {
  Hypervisor,
  HypervisorDeposit,
  HypervisorWithdraw
} from "../../generated/schema";
import { createUser, createTransaction } from "../helpers";

export function handleDeposit(event: DepositEvent): void {
  log.info("Hypervisor Deposit: sender={}, to={}, shares={}, amount0={}, amount1={}", [
    event.params.sender.toHexString(),
    event.params.to.toHexString(),
    event.params.shares.toString(),
    event.params.amount0.toString(),
    event.params.amount1.toString()
  ]);

  let hypervisor = Hypervisor.load(event.address.toHexString());
  if (hypervisor === null) {
    log.error("Hypervisor not found: {}", [event.address.toHexString()]);
    return;
  }

  // Create deposit entity
  let depositId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let deposit = new HypervisorDeposit(depositId);
  
  deposit.hypervisor = hypervisor.id;
  deposit.sender = createUser(event.params.sender).id;
  deposit.to = createUser(event.params.to).id;
  
  deposit.amount0 = event.params.amount0.toBigDecimal();
  deposit.amount1 = event.params.amount1.toBigDecimal();
  deposit.shares = event.params.shares.toBigDecimal();
  
  // TODO: Calculate USD value using token prices
  deposit.amountUSD = BigInt.fromI32(0).toBigDecimal();
  
  deposit.transaction = createTransaction(event).id;
  deposit.timestamp = event.block.timestamp;
  deposit.blockNumber = event.block.number;
  
  deposit.save();

  // Update hypervisor totals
  hypervisor.totalAmount0 = hypervisor.totalAmount0.plus(deposit.amount0);
  hypervisor.totalAmount1 = hypervisor.totalAmount1.plus(deposit.amount1);
  hypervisor.depositCount = hypervisor.depositCount.plus(BigInt.fromI32(1));
  
  // Update total supply
  hypervisor.totalSupply = hypervisor.totalSupply.plus(event.params.shares);
  
  hypervisor.save();

  log.info("Created HypervisorDeposit: {}", [deposit.id]);
}

export function handleWithdraw(event: WithdrawEvent): void {
  log.info("Hypervisor Withdraw: sender={}, to={}, shares={}, amount0={}, amount1={}", [
    event.params.sender.toHexString(),
    event.params.to.toHexString(),
    event.params.shares.toString(),
    event.params.amount0.toString(),
    event.params.amount1.toString()
  ]);

  let hypervisor = Hypervisor.load(event.address.toHexString());
  if (hypervisor === null) {
    log.error("Hypervisor not found: {}", [event.address.toHexString()]);
    return;
  }

  // Create withdraw entity
  let withdrawId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let withdraw = new HypervisorWithdraw(withdrawId);
  
  withdraw.hypervisor = hypervisor.id;
  withdraw.sender = createUser(event.params.sender).id;
  withdraw.to = createUser(event.params.to).id;
  
  withdraw.amount0 = event.params.amount0.toBigDecimal();
  withdraw.amount1 = event.params.amount1.toBigDecimal();
  withdraw.shares = event.params.shares.toBigDecimal();
  
  // TODO: Calculate USD value using token prices
  withdraw.amountUSD = BigInt.fromI32(0).toBigDecimal();
  
  withdraw.transaction = createTransaction(event).id;
  withdraw.timestamp = event.block.timestamp;
  withdraw.blockNumber = event.block.number;
  
  withdraw.save();

  // Update hypervisor totals
  hypervisor.totalAmount0 = hypervisor.totalAmount0.minus(withdraw.amount0);
  hypervisor.totalAmount1 = hypervisor.totalAmount1.minus(withdraw.amount1);
  hypervisor.withdrawCount = hypervisor.withdrawCount.plus(BigInt.fromI32(1));
  
  // Update total supply
  hypervisor.totalSupply = hypervisor.totalSupply.minus(event.params.shares);
  
  hypervisor.save();

  log.info("Created HypervisorWithdraw: {}", [withdraw.id]);
}

export function handleTransfer(event: TransferEvent): void {
  // Handle ERC20 transfers of hypervisor tokens
  // This is useful for tracking LP token movements
  log.debug("Hypervisor Transfer: from={}, to={}, value={}", [
    event.params.from.toHexString(),
    event.params.to.toHexString(),
    event.params.value.toString()
  ]);

  // We can track ownership changes, but for now we'll just log
  // In the future, we might want to track user balances
}

export function handleRebalance(event: RebalanceEvent): void {
  log.info("Hypervisor Rebalance: tick={}, totalAmount0={}, totalAmount1={}, feeAmount0={}, feeAmount1={}, totalSupply={}", [
    event.params.tick.toString(),
    event.params.totalAmount0.toString(),
    event.params.totalAmount1.toString(),
    event.params.feeAmount0.toString(),
    event.params.feeAmount1.toString(),
    event.params.totalSupply.toString()
  ]);

  let hypervisor = Hypervisor.load(event.address.toHexString());
  if (hypervisor === null) {
    log.error("Hypervisor not found: {}", [event.address.toHexString()]);
    return;
  }

  // Update hypervisor amounts after rebalance
  hypervisor.totalAmount0 = event.params.totalAmount0.toBigDecimal();
  hypervisor.totalAmount1 = event.params.totalAmount1.toBigDecimal();
  hypervisor.totalSupply = event.params.totalSupply;
  
  // Add fees earned
  hypervisor.feesEarned0 = hypervisor.feesEarned0.plus(event.params.feeAmount0.toBigDecimal());
  hypervisor.feesEarned1 = hypervisor.feesEarned1.plus(event.params.feeAmount1.toBigDecimal());
  
  hypervisor.save();

  log.info("Updated Hypervisor after rebalance: {}", [hypervisor.id]);
}