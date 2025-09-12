// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";

interface ILithos {
    function setMinter(address _minter) external;
}

contract UpdateLithosMinter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address lithosToken = vm.envAddress("LITHOS_TOKEN");
        address minter = vm.envAddress("MINTER");

        vm.startBroadcast(deployerPrivateKey);

        ILithos(lithosToken).setMinter(minter);

        vm.stopBroadcast();

        console.log("LITHOS minter updated:");
        console.log("  LITHOS Token:", lithosToken);
        console.log("  New Minter:", minter);
    }
}
