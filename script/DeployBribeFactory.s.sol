// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";
import "../src/contracts/factories/BribeFactoryV3.sol";

contract DeployBribeFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address permissionsRegistry = vm.envAddress("PERMISSIONS_REGISTRY");

        // Use a temporary voter address (deployer) - will be updated after VoterV3 deployment
        address tempVoter = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        BribeFactoryV3 bribeFactory = new BribeFactoryV3();
        bribeFactory.initialize(tempVoter, permissionsRegistry);

        vm.stopBroadcast();

        console.log("BribeFactoryV3 deployed at:", address(bribeFactory));
        console.log("Initialized with:");
        console.log("  Temp Voter:", tempVoter);
        console.log("  Permissions Registry:", permissionsRegistry);
        console.log("\nAdd to .env:");
        console.log("BRIBE_FACTORY=%s", address(bribeFactory));
    }
}
