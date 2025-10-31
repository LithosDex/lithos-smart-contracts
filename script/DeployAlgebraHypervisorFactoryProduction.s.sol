// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "../src/contracts/AlgebraHypervisorFactory.sol";

contract DeployAlgebraHypervisorFactoryProduction is Script {
    function run() external {
        vm.startBroadcast();

        console.log("Deploying AlgebraHypervisorFactory for Production...\n");

        // Algebra Factory address
        address algebraFactory = 0x10253594A832f967994b44f33411940533302ACb;
        
        AlgebraHypervisorFactory factory = new AlgebraHypervisorFactory(algebraFactory);

        console.log("AlgebraHypervisorFactory deployed at:", address(factory));
        console.log("Algebra Factory:", algebraFactory);
        console.log("Owner:", factory.owner());

        // Save address
        string memory jsonObj = string.concat('{"AlgebraHypervisorFactory":"', vm.toString(address(factory)), '"}');
        vm.writeFile(
            string.concat(vm.projectRoot(), "/deployments/mainnet/hypervisor_factory_production.json"),
            jsonObj
        );

        console.log("\nSaved to deployments/mainnet/hypervisor_factory_production.json");
        console.log("Production Factory Ready!");

        vm.stopBroadcast();
    }
}

