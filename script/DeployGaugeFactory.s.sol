// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";
import "../src/contracts/factories/GaugeFactoryV2.sol";

contract DeployGaugeFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address permissionsRegistry = vm.envAddress("PERMISSIONS_REGISTRY");

        vm.startBroadcast(deployerPrivateKey);

        GaugeFactoryV2 gaugeFactory = new GaugeFactoryV2();
        gaugeFactory.initialize(permissionsRegistry);

        vm.stopBroadcast();

        console.log("GaugeFactoryV2 deployed at:", address(gaugeFactory));
        console.log("Initialized with:");
        console.log("  Permissions Registry:", permissionsRegistry);
        console.log("\nAdd to .env:");
        console.log("GAUGE_FACTORY=%s", address(gaugeFactory));
    }
}
