// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";

interface IVotingEscrow {
    function setVoter(address _voter) external;
}

contract UpdateVotingEscrowVoter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address votingEscrow = vm.envAddress("VOTING_ESCROW");
        address voter = vm.envAddress("VOTER");

        vm.startBroadcast(deployerPrivateKey);

        IVotingEscrow(votingEscrow).setVoter(voter);

        vm.stopBroadcast();

        console.log("VotingEscrow voter updated:");
        console.log("  VotingEscrow:", votingEscrow);
        console.log("  New Voter:", voter);
    }
}
