// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";

contract DistributeGaugeFeesScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory statePath = string.concat("deployments/", env, "/state.json");
        _loadState(statePath);

        VoterV3 voter = VoterV3(deployed["VoterV3"]);
        require(address(voter) != address(0), "voter not configured");

        console2.log("=== Gauge Fee Distribution ===");
        console2.log("Environment:", env);
        console2.log("Executor:", deployer);
        console2.log("Voter:", address(voter));

        uint256 poolCount = voter.length();
        console2.log("Pools discovered:", poolCount);

        address[] memory scratch = new address[](poolCount);
        uint256 activeGaugeCount = 0;

        for (uint256 i = 0; i < poolCount; i++) {
            address pool = voter.pools(i);
            address gauge = voter.gauges(pool);
            if (gauge != address(0) && voter.isAlive(gauge)) {
                scratch[activeGaugeCount] = gauge;
                activeGaugeCount++;
                console2.log("  - Active gauge:", gauge, "pool:", pool);
            }
        }

        if (activeGaugeCount == 0) {
            console2.log("No active gauges detected; fee distribution skipped.");
            return;
        }

        address[] memory activeGauges = new address[](activeGaugeCount);
        for (uint256 i = 0; i < activeGaugeCount; i++) {
            activeGauges[i] = scratch[i];
        }

        vm.startBroadcast(deployerKey);

        console2.log("Distributing fees for", activeGaugeCount, "gauges...");
        voter.distributeFees(activeGauges);

        vm.stopBroadcast();

        console2.log("Fee distribution complete.");
    }

    function _loadState(string memory path) internal {
        require(vm.exists(path), "state file missing");

        string memory json = vm.readFile(path);
        address voterAddr;

        try vm.parseJsonAddress(json, ".VoterV3") returns (address parsed) {
            voterAddr = parsed;
        } catch {
            try vm.parseJsonAddress(json, ".Voter") returns (address parsed) {
                voterAddr = parsed;
            } catch {
                revert("voter address missing in state file");
            }
        }

        deployed["VoterV3"] = voterAddr;
    }
}
