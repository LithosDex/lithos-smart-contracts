// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {DeploymentHelpers} from "./DeploymentHelpers.sol";
import {Lithos} from "../src/contracts/Lithos.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployAndInitVe33Script is Script {
    DeploymentHelpers.Ve33Contracts public ve33;
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory statePath = string.concat(
            "deployments/",
            env,
            "/state.json"
        );

        // Load existing state - DEX contracts should already be deployed
        require(
            vm.exists(statePath),
            "State file not found. Run DeployAndInitDex.s.sol first!"
        );
        _loadState(statePath);

        // Verify DEX contracts are deployed
        require(
            deployed["PairFactoryUpgradeable"] != address(0),
            "PairFactoryUpgradeable not deployed"
        );
        require(deployed["RouterV2"] != address(0), "RouterV2 not deployed");

        console2.log("=== Deploy & Initialize ve33 System ===");
        console2.log("Environment:", env);
        console2.log("Deployer:", deployer);
        console2.log("DEX PairFactory:", deployed["PairFactoryUpgradeable"]);
        console2.log("DEX RouterV2:", deployed["RouterV2"]);

        // Check gas price is reasonable
        uint256 gasPrice = vm.envOr("GAS_PRICE", uint256(1000000000)); // Default 1 gwei
        if (gasPrice < 1000000000) {
            console2.log("WARNING: Gas price too low:", gasPrice);
            console2.log("Recommended minimum: 1 gwei (1000000000)");
        }

        vm.startBroadcast(deployerKey);

        // Check if we should activate minter (Oct 9 step)
        bool activateMinter = vm.envOr("ACTIVATE_MINTER", false);

        if (activateMinter) {
            console2.log("\n=== PHASE 2: Activating Minter (Oct 9) ===");
            _loadVe33State(statePath);
            DeploymentHelpers.activateMinter(ve33.lithos, ve33.minter);
        } else {
            console2.log("\n=== PHASE 1: Deploying ve33 System (Oct 3) ===");

            // Deploy ve33 system using shared library
            address initialMintRecipient = vm.envAddress(
                "INITIAL_MINT_RECIPIENT"
            );
            ve33 = DeploymentHelpers.deployVe33System(
                deployer,
                initialMintRecipient
            );

            // Prepare whitelist tokens
            address[] memory tokens = new address[](2);
            tokens[0] = vm.envAddress("WXPL");
            tokens[1] = vm.envAddress("USDT");

            // Initialize all contracts
            DeploymentHelpers.initializeVe33(
                ve33,
                deployed["PairFactoryUpgradeable"],
                deployer,
                tokens
            );

            // Save state
            _saveVe33State(statePath);
        }

        vm.stopBroadcast();

        // Verify deployment
        if (activateMinter) {
            console2.log("\n=== Minter Activation Complete ===");
            console2.log(
                "System is now active. Airdrop can proceed on Oct 12."
            );
            console2.log("First emissions will occur on Oct 16 after voting.");
        } else {
            console2.log("\n=== ve33 Deployment Complete (Phase 1) ===");
            console2.log("Contracts deployed but NOT activated.");
            console2.log(
                "On Oct 9, run: ACTIVATE_MINTER=true forge script script/DeployAndInitVe33.s.sol"
            );
            console2.log("\nDeployed Addresses:");
            console2.log("  Lithos:", ve33.lithos);
            console2.log("  VeArtProxy (proxy):", ve33.veArtProxy);
            console2.log("  VeArtProxy (impl):", ve33.veArtProxyImpl);
            console2.log("  Minter (proxy):", ve33.minter);
            console2.log("  Minter (impl):", ve33.minterImpl);
            console2.log("  VotingEscrow:", ve33.votingEscrow);
            console2.log("  Voter:", ve33.voter);
            console2.log("  ProxyAdmin:", ve33.proxyAdmin);
            console2.log("  Timelock:", ve33.timelock);
        }
    }

    function _loadState(string memory path) private {
        string memory json = vm.readFile(path);

        // Load DEX contracts (required)
        deployed["PairFactoryUpgradeable"] = vm.parseJsonAddress(
            json,
            ".PairFactoryUpgradeable"
        );
        deployed["TradeHelper"] = vm.parseJsonAddress(json, ".TradeHelper");
        deployed["GlobalRouter"] = vm.parseJsonAddress(json, ".GlobalRouter");
        deployed["RouterV2"] = vm.parseJsonAddress(json, ".RouterV2");
    }

    function _loadVe33State(string memory path) private {
        string memory json = vm.readFile(path);

        // Load ve33 contracts from state
        ve33.lithos = vm.parseJsonAddress(json, ".Lithos");
        ve33.veArtProxy = vm.parseJsonAddress(json, ".VeArtProxy");
        ve33.veArtProxyImpl = vm.parseJsonAddress(json, ".VeArtProxyImpl");
        ve33.minter = vm.parseJsonAddress(json, ".Minter");
        ve33.minterImpl = vm.parseJsonAddress(json, ".MinterImpl");
        ve33.votingEscrow = vm.parseJsonAddress(json, ".VotingEscrow");
        ve33.gaugeFactory = vm.parseJsonAddress(json, ".GaugeFactory");
        ve33.permissionsRegistry = vm.parseJsonAddress(
            json,
            ".PermissionsRegistry"
        );
        ve33.bribeFactory = vm.parseJsonAddress(json, ".BribeFactory");
        ve33.voter = vm.parseJsonAddress(json, ".Voter");
        ve33.rewardsDistributor = vm.parseJsonAddress(
            json,
            ".RewardsDistributor"
        );
        ve33.proxyAdmin = vm.parseJsonAddress(json, ".ProxyAdmin");
        ve33.timelock = vm.parseJsonAddress(json, ".Timelock");
    }

    function _saveVe33State(string memory path) private {
        // Load existing DEX state
        _loadState(path);

        // Build JSON with DEX + ve33 contracts
        string memory json = "{";

        // DEX contracts (preserved from existing state)
        json = string.concat(
            json,
            '"PairFactoryUpgradeable":"',
            vm.toString(deployed["PairFactoryUpgradeable"]),
            '",'
        );
        json = string.concat(
            json,
            '"TradeHelper":"',
            vm.toString(deployed["TradeHelper"]),
            '",'
        );
        json = string.concat(
            json,
            '"GlobalRouter":"',
            vm.toString(deployed["GlobalRouter"]),
            '",'
        );
        json = string.concat(
            json,
            '"RouterV2":"',
            vm.toString(deployed["RouterV2"]),
            '",'
        );

        // ve33 contracts (proxies and implementations)
        json = string.concat(
            json,
            '"Lithos":"',
            vm.toString(ve33.lithos),
            '",'
        );
        json = string.concat(
            json,
            '"VeArtProxy":"',
            vm.toString(ve33.veArtProxy),
            '",'
        );
        json = string.concat(
            json,
            '"VeArtProxyImpl":"',
            vm.toString(ve33.veArtProxyImpl),
            '",'
        );
        json = string.concat(
            json,
            '"Minter":"',
            vm.toString(ve33.minter),
            '",'
        );
        json = string.concat(
            json,
            '"MinterImpl":"',
            vm.toString(ve33.minterImpl),
            '",'
        );
        json = string.concat(
            json,
            '"VotingEscrow":"',
            vm.toString(ve33.votingEscrow),
            '",'
        );
        json = string.concat(
            json,
            '"GaugeFactory":"',
            vm.toString(ve33.gaugeFactory),
            '",'
        );
        json = string.concat(
            json,
            '"PermissionsRegistry":"',
            vm.toString(ve33.permissionsRegistry),
            '",'
        );
        json = string.concat(
            json,
            '"BribeFactory":"',
            vm.toString(ve33.bribeFactory),
            '",'
        );
        json = string.concat(json, '"Voter":"', vm.toString(ve33.voter), '",');
        json = string.concat(
            json,
            '"RewardsDistributor":"',
            vm.toString(ve33.rewardsDistributor),
            '",'
        );
        json = string.concat(
            json,
            '"ProxyAdmin":"',
            vm.toString(ve33.proxyAdmin),
            '",'
        );
        json = string.concat(
            json,
            '"Timelock":"',
            vm.toString(ve33.timelock),
            '"'
        );

        json = string.concat(json, "}");
        vm.writeFile(path, json);
    }
}
