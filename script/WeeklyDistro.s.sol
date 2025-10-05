// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";
import {IGauge} from "../src/contracts/interfaces/IGauge.sol";

contract WeeklyDistroScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory statePath = string.concat("deployments/", env, "/state.json");

        // Load deployed addresses
        _loadState(statePath);

        console2.log("=== Weekly Protocol Maintenance ===");
        console2.log("Environment:", env);
        console2.log("Executor:", deployer);
        console2.log("Timestamp:", block.timestamp);

        VoterV3 voter = VoterV3(deployed["VoterV3"]);
        MinterUpgradeable minter = MinterUpgradeable(deployed["MinterUpgradeable"]);

        vm.startBroadcast(deployerKey);

        // Step 1: Check if we can update period
        console2.log("\n--- Step 1: Checking emission period ---");
        if (minter.check()) {
            console2.log("New emission period available!");

            // Step 2: Distribute emissions to all gauges (this calls update_period internally)
            console2.log("\n--- Step 2: Distributing emissions to all gauges ---");
            console2.log("Calling distributeAll() which triggers update_period() and distributes to gauges...");
            voter.distributeAll();
            console2.log("Emissions distributed successfully!");
        } else {
            console2.log("Not time for new emission period yet.");
            console2.log("Next period starts at:", minter.active_period() + 604800);

            // Still try to distribute in case there are pending distributions
            console2.log("\n--- Checking for pending distributions ---");
            voter.distributeAll();
        }

        // Step 3: Distribute fees for active gauges
        console2.log("\n--- Step 3: Distributing fees to gauges ---");

        // Get all pools and their gauges
        uint256 poolCount = voter.length();
        uint256 activeGaugeCount = 0;

        // First pass: count active gauges
        for (uint256 i = 0; i < poolCount; i++) {
            address pool = voter.pools(i);
            address gauge = voter.gauges(pool);
            if (gauge != address(0) && voter.isAlive(gauge)) {
                activeGaugeCount++;
            }
        }

        if (activeGaugeCount > 0) {
            // Create array of only active gauges
            address[] memory activeGauges = new address[](activeGaugeCount);
            uint256 j = 0;

            // Second pass: collect active gauges
            for (uint256 i = 0; i < poolCount; i++) {
                address pool = voter.pools(i);
                address gauge = voter.gauges(pool);
                if (gauge != address(0) && voter.isAlive(gauge)) {
                    activeGauges[j] = gauge;
                    console2.log("  - Gauge:", gauge, "for pool:", pool);
                    j++;
                }
            }

            console2.log("Distributing fees for", activeGaugeCount, "active gauges...");
            voter.distributeFees(activeGauges);
            console2.log("Fees distributed successfully!");
        } else {
            console2.log("No active gauges found.");
        }

        vm.stopBroadcast();

        // Summary
        console2.log("\n=== Weekly Maintenance Complete ===");
        console2.log("Weekly emissions:", minter.weekly() / 1e18, "LITHOS");
        console2.log("Current circulating supply:", minter.circulating_supply() / 1e18, "LITHOS");
        console2.log("Active period:", minter.active_period());
        console2.log("Next period:", minter.active_period() + 604800);

        uint256 timeToNext = (minter.active_period() + 604800) > block.timestamp
            ? (minter.active_period() + 604800 - block.timestamp) / 3600
            : 0;
        console2.log("Hours until next period:", timeToNext);
    }

    function _loadState(string memory path) private {
        require(vm.exists(path), "State file not found. Run DeployAndInit.s.sol first!");

        string memory json = vm.readFile(path);

        deployed["Lithos"] = vm.parseJsonAddress(json, ".Lithos");
        deployed["VeArtProxyUpgradeable"] = vm.parseJsonAddress(json, ".VeArtProxyUpgradeable");
        deployed["VotingEscrow"] = vm.parseJsonAddress(json, ".VotingEscrow");
        deployed["PairFactoryUpgradeable"] = vm.parseJsonAddress(json, ".PairFactoryUpgradeable");
        deployed["TradeHelper"] = vm.parseJsonAddress(json, ".TradeHelper");
        deployed["GlobalRouter"] = vm.parseJsonAddress(json, ".GlobalRouter");
        deployed["RouterV2"] = vm.parseJsonAddress(json, ".RouterV2");
        deployed["GaugeFactoryV2"] = vm.parseJsonAddress(json, ".GaugeFactoryV2");
        deployed["PermissionsRegistry"] = vm.parseJsonAddress(json, ".PermissionsRegistry");
        deployed["BribeFactoryV3"] = vm.parseJsonAddress(json, ".BribeFactoryV3");
        deployed["VoterV3"] = vm.parseJsonAddress(json, ".VoterV3");
        deployed["RewardsDistributor"] = vm.parseJsonAddress(json, ".RewardsDistributor");
        deployed["MinterUpgradeable"] = vm.parseJsonAddress(json, ".MinterUpgradeable");

        // Optional: Load gauge addresses if they exist
        try vm.parseJsonAddress(json, ".LITHOS_WXPL_Gauge") returns (address gauge) {
            deployed["LITHOS_WXPL_Gauge"] = gauge;
        } catch {}
    }
}
