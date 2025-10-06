// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";

/// @title TransferToTimelockScript
/// @notice Transfer ProxyAdmin and governance roles from deployer to Timelock
/// @dev Run this after system is stable and ready for timelocked governance
contract TransferToTimelockScript is Script {
    function run() external {
        address proxyAdmin = vm.envAddress("PROXY_ADMIN");
        address permissionsRegistry = vm.envAddress("PERMISSIONS_REGISTRY");
        address timelock = vm.envAddress("TIMELOCK");
        address deployer = vm.envAddress("DEPLOYER");

        console2.log("=== Transfer Ownership to Timelock ===");
        console2.log("ProxyAdmin:", proxyAdmin);
        console2.log("PermissionsRegistry:", permissionsRegistry);
        console2.log("Timelock:", timelock);
        console2.log("Deployer:", deployer);

        vm.startBroadcast();

        // 1. Transfer ProxyAdmin ownership to Timelock
        console2.log("\n1. Transferring ProxyAdmin ownership to Timelock...");
        ProxyAdmin(proxyAdmin).transferOwnership(timelock);

        // 2. Grant roles to Timelock
        console2.log("\n2. Granting GOVERNANCE role to Timelock...");
        PermissionsRegistry(permissionsRegistry).setRoleFor(timelock, "GOVERNANCE");

        console2.log("\n3. Granting VOTER_ADMIN role to Timelock...");
        PermissionsRegistry(permissionsRegistry).setRoleFor(timelock, "VOTER_ADMIN");

        // 3. Revoke deployer roles (optional, for security)
        console2.log("\n4. Revoking deployer roles (optional)...");
        PermissionsRegistry(permissionsRegistry).removeRoleFrom(deployer, "GOVERNANCE");
        PermissionsRegistry(permissionsRegistry).removeRoleFrom(deployer, "VOTER_ADMIN");

        console2.log("\n=== Ownership Transfer Complete ===");
        console2.log("All governance actions now require 48-hour timelock.");

        vm.stopBroadcast();
    }
}
