import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  Mint as MintEvent,
  MinterUpgradeable as MinterUpgradeableContract
} from "../generated/MinterUpgradeable/MinterUpgradeable";

import {
  Minter,
  MintEvent as MintEventEntity
} from "../generated/schema";

import { BI_ZERO, BI_ONE, createUser } from "./helpers";

// Initialize Minter entity
function getOrCreateMinter(address: Address): Minter {
  let minter = Minter.load(address.toHexString());
  if (minter === null) {
    minter = new Minter(address.toHexString());
    minter.address = address;
    minter.totalEmissions = BI_ZERO;
    minter.currentWeeklyEmission = BI_ZERO;
    minter.mintCount = BI_ZERO;
    minter.activePeriod = BI_ZERO;
    minter.emissionRate = BigInt.fromI32(10); // Default 1% (10/1000)
    minter.tailEmissionRate = BigInt.fromI32(2); // Default 0.2% (2/1000)
    minter.teamRate = BI_ZERO;
    minter.lastMintTimestamp = BI_ZERO;
    minter.save();
  }
  return minter;
}

// Handle Mint events
export function handleMint(event: MintEvent): void {
  let minter = getOrCreateMinter(event.address);
  let user = createUser(event.params.sender);

  // Create mint event entity
  let mintEvent = new MintEventEntity(
    event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  );
  mintEvent.transaction = event.transaction.hash;
  mintEvent.timestamp = event.block.timestamp;
  mintEvent.blockNumber = event.block.number;
  mintEvent.minter = minter.id;
  mintEvent.sender = user.id;
  mintEvent.weeklyEmission = event.params.weekly;
  mintEvent.circulatingSupply = event.params.circulating_supply;
  mintEvent.circulatingEmission = event.params.circulating_emission;
  
  // Calculate the period from timestamp
  // Period = (timestamp / WEEK) * WEEK where WEEK = 86400 * 7
  let WEEK = BigInt.fromI32(86400 * 7);
  mintEvent.period = (event.block.timestamp.div(WEEK)).times(WEEK);
  
  mintEvent.save();

  // Update minter statistics
  minter.totalEmissions = minter.totalEmissions.plus(event.params.weekly);
  minter.currentWeeklyEmission = event.params.weekly;
  minter.mintCount = minter.mintCount.plus(BI_ONE);
  minter.activePeriod = mintEvent.period;
  minter.lastMintTimestamp = event.block.timestamp;
  
  // Try to get current contract parameters
  let contract = MinterUpgradeableContract.bind(event.address);
  
  let emissionResult = contract.try_EMISSION();
  if (!emissionResult.reverted) {
    minter.emissionRate = emissionResult.value;
  }
  
  let tailEmissionResult = contract.try_TAIL_EMISSION();
  if (!tailEmissionResult.reverted) {
    minter.tailEmissionRate = tailEmissionResult.value;
  }
  
  let teamRateResult = contract.try_teamRate();
  if (!teamRateResult.reverted) {
    minter.teamRate = teamRateResult.value;
  }
  
  minter.save();
}