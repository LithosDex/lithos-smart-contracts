// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";
import "../src/contracts/MinterUpgradeable.sol";

contract DeployMinter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address votingEscrow = vm.envAddress("VOTING_ESCROW");
        address rewardsDistributor = vm.envAddress("REWARDS_DISTRIBUTOR");

        // Use a temporary voter address (deployer) - will be updated after VoterV3 deployment
        address tempVoter = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MinterUpgradeable minter = new MinterUpgradeable();
        minter.initialize(tempVoter, votingEscrow, rewardsDistributor);

        vm.stopBroadcast();

        console.log("MinterUpgradeable deployed at:", address(minter));
        console.log("Initialized with:");
        console.log("  Temp Voter:", tempVoter);
        console.log("  Voting Escrow:", votingEscrow);
        console.log("  Rewards Distributor:", rewardsDistributor);
        console.log("\nAdd to .env:");
        console.log("MINTER=%s", address(minter));
    }
}
