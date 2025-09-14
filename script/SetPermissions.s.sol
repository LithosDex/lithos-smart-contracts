// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";

interface IPermissionsRegistry {
    function setRoleFor(address c, string memory role) external;
}

contract SetPermissions is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address permissionsRegistry = vm.envAddress("PERMISSIONS_REGISTRY");
        address deployer = vm.addr(deployerPrivateKey);

        // Contract addresses that need roles
        address voter = vm.envAddress("VOTER");

        vm.startBroadcast(deployerPrivateKey);

        IPermissionsRegistry registry = IPermissionsRegistry(
            permissionsRegistry
        );

        // Set VOTER_ADMIN role
        registry.setRoleFor(deployer, "VOTER_ADMIN");
        console.log("Set VOTER_ADMIN for deployer:", deployer);

        // Set GOVERNANCE role
        registry.setRoleFor(deployer, "GOVERNANCE");
        console.log("Set GOVERNANCE for deployer:", deployer);

        // Set GAUGE_ADMIN role
        registry.setRoleFor(deployer, "GAUGE_ADMIN");
        console.log("Set GAUGE_ADMIN for deployer:", deployer);

        // Set BRIBE_ADMIN role
        registry.setRoleFor(deployer, "BRIBE_ADMIN");
        console.log("Set BRIBE_ADMIN for deployer:", deployer);

        // Optionally set roles for VoterV3 contract itself
        registry.setRoleFor(voter, "GAUGE_ADMIN");
        console.log("Set GAUGE_ADMIN for VoterV3:", voter);

        vm.stopBroadcast();

        console.log("\nPermissions set successfully!");
        console.log("All admin roles assigned to:", deployer);
    }
}
