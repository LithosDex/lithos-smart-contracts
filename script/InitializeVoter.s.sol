// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";

interface IVoter {
    function _init(
        address[] memory _tokens,
        address _permissionsRegistry,
        address _minter
    ) external;
}

contract InitializeVoter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address voter = vm.envAddress("VOTER");
        address minter = vm.envAddress("MINTER");
        address permissionsRegistry = vm.envAddress("PERMISSIONS_REGISTRY");

        // Get whitelisted tokens from env or use defaults
        address[] memory tokens = new address[](3);
        tokens[0] = vm.envAddress("LITHOS_TOKEN");
        tokens[1] = 0x6100E367285b01F48D07953803A2d8dCA5D19873; // WXPL
        tokens[2] = 0xb89cdFf170b45797BF93536773113861EBEABAfa; // TEST

        vm.startBroadcast(deployerPrivateKey);

        IVoter(voter)._init(tokens, permissionsRegistry, minter);

        vm.stopBroadcast();

        console.log("VoterV3 initialized:");
        console.log("  Permissions Registry:", permissionsRegistry);
        console.log("  Minter:", minter);
        console.log("  Whitelisted tokens:", tokens.length);
    }
}
