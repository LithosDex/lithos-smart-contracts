// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";
import "../src/contracts/VoterV3.sol";

contract DeployVoter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address votingEscrow = vm.envAddress("VOTING_ESCROW");
        address pairFactory = vm.envAddress("PAIR_FACTORY");
        address gaugeFactory = vm.envAddress("GAUGE_FACTORY");
        address bribeFactory = vm.envAddress("BRIBE_FACTORY");

        vm.startBroadcast(deployerPrivateKey);

        VoterV3 voter = new VoterV3();
        voter.initialize(votingEscrow, pairFactory, gaugeFactory, bribeFactory);

        vm.stopBroadcast();

        console.log("VoterV3 deployed at:", address(voter));
        console.log("Initialized with:");
        console.log("  Voting Escrow:", votingEscrow);
        console.log("  Pair Factory:", pairFactory);
        console.log("  Gauge Factory:", gaugeFactory);
        console.log("  Bribe Factory:", bribeFactory);
        console.log("\nAdd to .env:");
        console.log("VOTER=%s", address(voter));
    }
}
