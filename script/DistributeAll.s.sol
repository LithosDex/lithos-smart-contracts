// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";

/// @title DistributeAll Script
/// @notice Run this script every epoch flip to distribute emissions to all gauges
/// @dev Calls distributeAll() on VoterV3 which triggers update_period() and distributes to all gauges
contract DistributeAllScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory statePath = string.concat("deployments/", env, "/state.json");
        _loadState(statePath);

        VoterV3 voter = VoterV3(deployed["Voter"]);
        MinterUpgradeable minter = MinterUpgradeable(deployed["Minter"]);

        console2.log("=== Distribute All Emissions ===");
        console2.log("Environment:", env);
        console2.log("Executor:", deployer);
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

        vm.startBroadcast(deployerKey);

        // Call distributeAll() - this internally calls minter.update_period()
        // and distributes emissions to all gauges
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
