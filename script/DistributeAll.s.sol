// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";
import {IGauge} from "../src/contracts/interfaces/IGauge.sol";

/// @title DistributeAll Script
/// @notice Run this script periodically to distribute fees and emissions to all gauges
/// @dev Calls distributeFees() then distributeAll() on VoterV3
contract DistributeAllScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");

        string memory statePath = string.concat("deployments/", env, "/state.json");
        _loadState(statePath);

        VoterV3 voter = VoterV3(deployed["Voter"]);
        MinterUpgradeable minter = MinterUpgradeable(deployed["Minter"]);

        console2.log("=== Distribute All Emissions ===");
        console2.log("Environment:", env);
        console2.log("Timestamp:", block.timestamp);
        console2.log("Voter:", address(voter));
        console2.log("Minter:", address(minter));

        // Check epoch status
        uint256 activePeriod = minter.active_period();
        uint256 nextPeriod = activePeriod + 604800; // 1 week in seconds
        bool canUpdate = minter.check();

        console2.log("\n--- Epoch Status ---");
        console2.log("Active period:", activePeriod);
        console2.log("Next period:", nextPeriod);
        console2.log("New epoch available:", canUpdate);

        if (block.timestamp < nextPeriod) {
            uint256 hoursRemaining = (nextPeriod - block.timestamp) / 3600;
            console2.log("Hours until next epoch:", hoursRemaining);
        }

        // Build array of all gauges for distributeFees
        uint256 poolCount = voter.length();
        address[] memory allGauges = new address[](poolCount);
        for (uint256 i = 0; i < poolCount; i++) {
            allGauges[i] = voter.gauges(voter.pools(i));
        }

        // 1. Distribute LP fees from PairFees into internal bribes
        //    Pre-check which gauges can claim fees using snapshot, since fee-on-transfer
        //    tokens can cause claimFees to revert on some gauges
        console2.log("\n--- Executing distributeFees() ---");
        uint256 snapshotId = vm.snapshotState();
        bool[] memory canClaim = new bool[](poolCount);
        uint256 safeCount;
        for (uint256 i = 0; i < poolCount; i++) {
            if (voter.isAlive(allGauges[i])) {
                try IGauge(allGauges[i]).claimFees() {
                    canClaim[i] = true;
                    safeCount++;
                } catch {
                    console2.log("  Gauge %d claimFees would revert, skipping", i);
                }
            }
        }
        vm.revertToState(snapshotId);

        // Build filtered array of safe gauges
        address[] memory safeGauges = new address[](safeCount);
        uint256 idx;
        for (uint256 i = 0; i < poolCount; i++) {
            if (canClaim[i]) {
                safeGauges[idx++] = allGauges[i];
            }
        }

        vm.startBroadcast();

        // Distribute fees only for gauges that won't revert
        if (safeCount > 0) {
            voter.distributeFees(safeGauges);
        }
        console2.log("distributeFees: %d/%d gauges succeeded", safeCount, poolCount);

        // 2. Distribute LITHOS emissions to all gauges
        console2.log("\n--- Executing distributeAll() ---");
        voter.distributeAll();
        console2.log("distributeAll() executed successfully!");

        vm.stopBroadcast();

        // Post-execution summary
        console2.log("\n=== Distribution Complete ===");
        console2.log("Weekly emissions:", minter.weekly() / 1e18, "LITH");
        console2.log("Circulating supply:", minter.circulating_supply() / 1e18, "LITH");
        console2.log("New active period:", minter.active_period());
    }

    function _loadState(string memory path) private {
        require(vm.exists(path), "State file not found");

        string memory json = vm.readFile(path);

        deployed["Voter"] = vm.parseJsonAddress(json, ".Voter");
        deployed["Minter"] = vm.parseJsonAddress(json, ".Minter");
    }
}
