// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";

interface IBribeFactory {
    function setVoter(address _voter) external;
}

contract UpdateBribeFactoryVoter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address bribeFactory = vm.envAddress("BRIBE_FACTORY");
        address voter = vm.envAddress("VOTER");

        vm.startBroadcast(deployerPrivateKey);

        IBribeFactory(bribeFactory).setVoter(voter);

        vm.stopBroadcast();

        console.log("BribeFactory voter updated:");
        console.log("  BribeFactory:", bribeFactory);
        console.log("  New Voter:", voter);
    }
}
