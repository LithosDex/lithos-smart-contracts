// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";
import {IGauge} from "../src/contracts/interfaces/IGauge.sol";

/// @title DistributeAll Script
/// @notice Run this script every epoch flip to distribute emissions AND trading fees to all gauges
/// @dev Calls distributeAll() on VoterV3 which triggers update_period() and distributes to all gauges,
///      then calls distributeFees() to flush accumulated trading fees from PairFees into internal bribes
contract DistributeAllScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");

        string memory statePath = string.concat("deployments/", env, "/state.json");
        _loadState(statePath);

        VoterV3 voter = VoterV3(deployed["Voter"]);
        MinterUpgradeable minter = MinterUpgradeable(deployed["Minter"]);

        console2.log("=== Distribute All Emissions ===");
        console2.log("Environment:", env);
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

        vm.startBroadcast();

        // Call distributeAll() - this internally calls minter.update_period()
        // and distributes emissions to all gauges
        console2.log("\n--- Executing distributeAll() ---");
        voter.distributeAll();
        console2.log("distributeAll() executed successfully!");

        // Distribute trading fees from PairFees contracts into internal bribes.
        // Collects all active gauges, skipping known broken ones (fee-on-transfer
        // tokens with insufficient PairFees balance), then batch-calls distributeFees.
        console2.log("\n--- Distributing trading fees ---");

        uint256 poolCount = voter.length();
        uint256 activeCount = 0;
        uint256 skippedCount = 0;

        // First pass: count active gauges (excluding broken ones)
        for (uint256 i = 0; i < poolCount; i++) {
            address pool = voter.pools(i);
            address gauge = voter.gauges(pool);
            if (gauge == address(0) || !voter.isAlive(gauge)) continue;
            if (_isSkipped(gauge)) {
                skippedCount++;
                continue;
            }
            activeCount++;
        }

        if (activeCount > 0) {
            address[] memory gauges = new address[](activeCount);
            uint256 j = 0;

            // Second pass: collect gauges
            for (uint256 i = 0; i < poolCount; i++) {
                address pool = voter.pools(i);
                address gauge = voter.gauges(pool);
                if (gauge == address(0) || !voter.isAlive(gauge)) continue;
                if (_isSkipped(gauge)) continue;
                gauges[j++] = gauge;
            }

            console2.log("Distributing fees for", activeCount, "active gauges...");
            if (skippedCount > 0) {
                console2.log("Skipped", skippedCount, "gauges (fee-on-transfer tokens)");
            }
            voter.distributeFees(gauges);
            console2.log("Fees distributed successfully!");
        } else {
            console2.log("No active gauges found.");
        }

        vm.stopBroadcast();

        // Post-execution summary
        console2.log("\n=== Distribution Complete ===");
        console2.log("Weekly emissions:", minter.weekly() / 1e18, "LITH");
        console2.log("Circulating supply:", minter.circulating_supply() / 1e18, "LITH");
        console2.log("New active period:", minter.active_period());
    }

    /// @dev Gauges whose claimFees() reverts due to broken tokens (e.g. fee-on-transfer
    ///      tokens where PairFees balance < recorded fees). These must be skipped to
    ///      prevent the entire distributeFees batch from reverting.
    function _isSkipped(address gauge) private pure returns (bool) {
        return gauge == 0x69e4CeCE94cD707A0bb5DCeB450D4A3f121747Ee  // sUSDe/ELITE vAMM
            || gauge == 0xa10F495bB7C1Ee69dF11be9258E4F24f2D99DEc1; // ELITE/WXPL vAMM
    }

    function _loadState(string memory path) private {
        require(vm.exists(path), "State file not found");

        string memory json = vm.readFile(path);

        deployed["Voter"] = vm.parseJsonAddress(json, ".Voter");
        deployed["Minter"] = vm.parseJsonAddress(json, ".Minter");
    }
}
