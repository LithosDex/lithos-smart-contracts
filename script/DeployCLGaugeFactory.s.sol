// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../src/contracts/factories/GaugeFactoryV2_CL.sol";

contract DeployCLGaugeFactory is Script {
    function run() external {
        vm.startBroadcast();

        console.log("Deploying CL Gauge Factory to Plasma mainnet...");

        // Load PermissionsRegistry address from state.json
        string memory statePath = string.concat(vm.projectRoot(), "/deployments/mainnet/state.json");
        string memory stateJson = vm.readFile(statePath);
        address permissionsRegistry = vm.parseJsonAddress(stateJson, ".PermissionsRegistry");

        console.log("Using PermissionsRegistry:", permissionsRegistry);

        // Deploy factory
        GaugeFactoryV2_CL factory = new GaugeFactoryV2_CL();
        factory.initialize(permissionsRegistry);

        console.log("CL Gauge Factory deployed at:", address(factory));

        // Update state.json
        string memory key = "CLGaugeFactory";
        string memory jsonObj = string.concat('{"', key, '":"', vm.toString(address(factory)), '"}');

        // Save to file
        vm.writeFile(string.concat(vm.projectRoot(), "/deployments/mainnet/cl_gauge_factory.json"), jsonObj);

        console.log("\nDeployment completed successfully!");
        console.log("Next step: Register this factory with VoterV3");

        vm.stopBroadcast();
    }
}

