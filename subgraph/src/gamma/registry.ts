import { BigInt, log } from "@graphprotocol/graph-ts";
import {
  HypeAdded as HypeAddedEvent,
  HypeRemoved as HypeRemovedEvent
} from "../../generated/HypeRegistry/HypeRegistry";
import {
  HypeRegistry,
  Hypervisor,
  CLPool
} from "../../generated/schema";
import { Hypervisor as HypervisorTemplate } from "../../generated/templates";
import { Hypervisor as HypervisorContract } from "../../generated/templates/Hypervisor/Hypervisor";
import { createUser, createTransaction } from "../helpers";

export function handleHypeAdded(event: HypeAddedEvent): void {
  log.info("HypeAdded event: hypervisor={}, index={}", [
    event.params.hype.toHexString(),
    event.params.index.toString()
  ]);

  // Get or create registry
  let registry = HypeRegistry.load(event.address.toHexString());
  if (registry === null) {
    registry = new HypeRegistry(event.address.toHexString());
    registry.hypervisorCount = BigInt.fromI32(0);
    log.info("Created new HypeRegistry entity: {}", [registry.id]);
  }

  // Create Hypervisor template to start tracking events
  HypervisorTemplate.create(event.params.hype);
  log.info("Created Hypervisor template for: {}", [event.params.hype.toHexString()]);

  // Get hypervisor contract to read pool address
  let hypervisorContract = HypervisorContract.bind(event.params.hype);
  
  let poolResult = hypervisorContract.try_pool();
  if (poolResult.reverted) {
    log.warning("Failed to get pool address from Hypervisor: {}", [
      event.params.hype.toHexString()
    ]);
    return;
  }

  let poolAddress = poolResult.value;
  
  // Create Hypervisor entity
  let hypervisor = new Hypervisor(event.params.hype.toHexString());
  hypervisor.registry = registry.id;
  hypervisor.registryIndex = event.params.index;
  hypervisor.pool = poolAddress.toHexString();

  // Get ERC20 details
  let nameResult = hypervisorContract.try_name();
  hypervisor.name = nameResult.reverted ? "Unknown" : nameResult.value;
  
  let symbolResult = hypervisorContract.try_symbol();
  hypervisor.symbol = symbolResult.reverted ? "UNK" : symbolResult.value;
  
  let decimalsResult = hypervisorContract.try_decimals();
  hypervisor.decimals = decimalsResult.reverted ? BigInt.fromI32(18) : BigInt.fromI32(decimalsResult.value);
  
  let totalSupplyResult = hypervisorContract.try_totalSupply();
  hypervisor.totalSupply = totalSupplyResult.reverted ? BigInt.fromI32(0) : totalSupplyResult.value;

  // Get position ranges
  let baseLowerResult = hypervisorContract.try_baseLower();
  hypervisor.baseLower = baseLowerResult.reverted ? BigInt.fromI32(0) : BigInt.fromI32(baseLowerResult.value);
  
  let baseUpperResult = hypervisorContract.try_baseUpper();
  hypervisor.baseUpper = baseUpperResult.reverted ? BigInt.fromI32(0) : BigInt.fromI32(baseUpperResult.value);
  
  let limitLowerResult = hypervisorContract.try_limitLower();
  hypervisor.limitLower = limitLowerResult.reverted ? BigInt.fromI32(0) : BigInt.fromI32(limitLowerResult.value);
  
  let limitUpperResult = hypervisorContract.try_limitUpper();
  hypervisor.limitUpper = limitUpperResult.reverted ? BigInt.fromI32(0) : BigInt.fromI32(limitUpperResult.value);

  // Initialize amounts and stats
  hypervisor.totalAmount0 = BigInt.fromI32(0).toBigDecimal();
  hypervisor.totalAmount1 = BigInt.fromI32(0).toBigDecimal();
  hypervisor.totalValueUSD = BigInt.fromI32(0).toBigDecimal();
  
  hypervisor.feesEarned0 = BigInt.fromI32(0).toBigDecimal();
  hypervisor.feesEarned1 = BigInt.fromI32(0).toBigDecimal();
  hypervisor.feesEarnedUSD = BigInt.fromI32(0).toBigDecimal();
  
  hypervisor.depositCount = BigInt.fromI32(0);
  hypervisor.withdrawCount = BigInt.fromI32(0);

  // Creation metadata
  hypervisor.createdAtTimestamp = event.block.timestamp;
  hypervisor.createdAtBlockNumber = event.block.number;

  hypervisor.save();

  // Update registry count
  registry.hypervisorCount = registry.hypervisorCount.plus(BigInt.fromI32(1));
  registry.save();

  // Update CLPool to link to this hypervisor
  let clPool = CLPool.load(poolAddress.toHexString());
  if (clPool !== null) {
    clPool.hypervisor = hypervisor.id;
    clPool.save();
    log.info("Linked CLPool {} to Hypervisor {}", [clPool.id, hypervisor.id]);
  } else {
    log.warning("CLPool not found for address: {}", [poolAddress.toHexString()]);
  }

  log.info("Created Hypervisor entity: {} for pool: {}", [
    hypervisor.id, 
    poolAddress.toHexString()
  ]);
}

export function handleHypeRemoved(event: HypeRemovedEvent): void {
  log.info("HypeRemoved event: hypervisor={}, index={}", [
    event.params.hype.toHexString(),
    event.params.index.toString()
  ]);

  // Note: We don't delete the Hypervisor entity, just mark it as removed
  // by updating the registry count and potentially adding a status field
  let registry = HypeRegistry.load(event.address.toHexString());
  if (registry !== null && registry.hypervisorCount.gt(BigInt.fromI32(0))) {
    registry.hypervisorCount = registry.hypervisorCount.minus(BigInt.fromI32(1));
    registry.save();
    
    log.info("Updated HypeRegistry count: {}", [registry.hypervisorCount.toString()]);
  }
}