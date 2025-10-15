// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";

interface IPermissionsRegistryLite {
    function hasRole(
        bytes calldata role,
        address user
    ) external view returns (bool);

    function setRoleFor(address user, string calldata role) external;
}

contract GrantDeployerRolesScript is Script {
    // Deployer account to re-grant legacy roles to.
    address constant DEPLOYER = 0x18D14a96cfBD74a7d489d0f983995C82FA4A3AB1;

    // Roles required for rebuilding gauges/bribes.
    bytes constant ROLE_GOVERNANCE = bytes("GOVERNANCE");
    bytes constant ROLE_VOTER_ADMIN = bytes("VOTER_ADMIN");
    bytes constant ROLE_GAUGE_ADMIN = bytes("GAUGE_ADMIN");
    bytes constant ROLE_BRIBE_ADMIN = bytes("BRIBE_ADMIN");

    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 callerKey = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(callerKey);

        string memory statePath = string.concat(
            "deployments/",
            env,
            "/state.json"
        );
        require(vm.exists(statePath), "state file missing");

        _loadState(statePath);
        IPermissionsRegistryLite registry = IPermissionsRegistryLite(
            deployed["PermissionsRegistry"]
        );
        require(address(registry) != address(0), "registry missing");

        console2.log("=== Grant legacy roles to deployer ===");
        console2.log("Environment:", env);
        console2.log("PermissionsRegistry:", address(registry));
        console2.log("Caller:", caller);
        console2.log("Deployer (target):", DEPLOYER);

        vm.startBroadcast(callerKey);

        _ensureRole(registry, ROLE_GOVERNANCE, "GOVERNANCE");
        _ensureRole(registry, ROLE_VOTER_ADMIN, "VOTER_ADMIN");
        _ensureRole(registry, ROLE_GAUGE_ADMIN, "GAUGE_ADMIN");
        _ensureRole(registry, ROLE_BRIBE_ADMIN, "BRIBE_ADMIN");

        vm.stopBroadcast();
    }

    function _ensureRole(
        IPermissionsRegistryLite registry,
        bytes memory roleKey,
        string memory roleName
    ) internal {
        if (registry.hasRole(roleKey, DEPLOYER)) {
            console2.log(roleName, "already granted");
            return;
        }

        registry.setRoleFor(DEPLOYER, roleName);
        console2.log("Granted", roleName, "to deployer");
    }

    function _loadState(string memory path) internal {
        string memory json = vm.readFile(path);
        deployed["PermissionsRegistry"] = vm.parseJsonAddress(
            json,
            ".PermissionsRegistry"
        );
    }
}
