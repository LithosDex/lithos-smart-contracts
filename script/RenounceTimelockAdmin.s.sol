// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title RenounceTimelockAdmin
/// @notice Script to renounce TIMELOCK_ADMIN_ROLE after deployment verification
/// @dev Run this after Oct 16 first distribution succeeds to fully decentralize
contract RenounceTimelockAdminScript is Script {
    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // Load timelock address from state
        string memory statePath = string.concat("deployments/", env, "/state.json");
        require(vm.exists(statePath), "State file not found. Deploy contracts first.");

        string memory json = vm.readFile(statePath);
        address timelockAddr = vm.parseJsonAddress(json, ".Timelock");

        require(timelockAddr != address(0), "Timelock not found in state");

        TimelockController timelock = TimelockController(payable(timelockAddr));

        console2.log("=== Renounce Timelock Admin Role ===");
        console2.log("Environment:", env);
        console2.log("Deployer:", deployer);
        console2.log("Timelock:", timelockAddr);

        // Check if deployer has admin role (DEFAULT_ADMIN_ROLE = bytes32(0))
        bytes32 adminRole = bytes32(0); // TimelockController uses DEFAULT_ADMIN_ROLE
        bool hasAdminRole = timelock.hasRole(adminRole, deployer);

        if (!hasAdminRole) {
            console2.log("\nDeployer does NOT have TIMELOCK_ADMIN_ROLE");
            console2.log("Admin role already renounced or never granted");
            return;
        }

        console2.log("\nDeployer has TIMELOCK_ADMIN_ROLE");
        console2.log("\nWARNING: This action is IRREVERSIBLE!");
        console2.log("After renouncing:");
        console2.log("  - ALL role changes require 48-hour timelock process");
        console2.log("  - Cannot quickly add/remove proposers or executors");
        console2.log("  - Full decentralization - no admin backdoor");
        console2.log("\nOnly proceed if:");
        console2.log("  1. First distribution (Oct 16) succeeded");
        console2.log("  2. System verified stable for several days");
        console2.log("  3. All necessary roles properly configured");
        console2.log("  4. Emergency procedures documented");

        // Require explicit confirmation via env var
        bool confirmed = vm.envOr("CONFIRM_RENOUNCE", false);
        require(confirmed, "Set CONFIRM_RENOUNCE=true to proceed");

        console2.log("\nProceeding with renunciation...");

        vm.startBroadcast(deployerKey);

        // Renounce TIMELOCK_ADMIN_ROLE
        timelock.renounceRole(adminRole, deployer);

        vm.stopBroadcast();

        // Verify renunciation succeeded
        bool stillHasRole = timelock.hasRole(adminRole, deployer);
        require(!stillHasRole, "Failed to renounce admin role");

        console2.log("\n=== Admin Role Renounced Successfully ===");
        console2.log("Deployer no longer has TIMELOCK_ADMIN_ROLE");
        console2.log("System is now fully decentralized");
        console2.log("\nAll future role changes must go through:");
        console2.log("  1. timelock.schedule() - propose change");
        console2.log("  2. Wait 48 hours");
        console2.log("  3. timelock.execute() - execute change");
    }
}
