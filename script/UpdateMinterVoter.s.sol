// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";

interface IMinter {
    function setVoter(address _voter) external;
}

contract UpdateMinterVoter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address minter = vm.envAddress("MINTER");
        address voter = vm.envAddress("VOTER");

        vm.startBroadcast(deployerPrivateKey);

        IMinter(minter).setVoter(voter);

        vm.stopBroadcast();

        console.log("Minter voter updated:");
        console.log("  Minter:", minter);
        console.log("  New Voter:", voter);
    }
}
