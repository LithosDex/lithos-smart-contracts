// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";

contract VerifyContractsScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");

        string memory statePath = string.concat(
            "deployments/",
            env,
            "/state.json"
        );

        // Load deployed contract addresses
        require(
            vm.exists(statePath),
            "State file not found. Deploy contracts first!"
        );
        _loadState(statePath);

        string memory verifierUrl = keccak256(abi.encodePacked(env)) ==
            keccak256(abi.encodePacked("testnet"))
            ? "https://api.routescan.io/v2/network/testnet/evm/9746_5/etherscan"
            : "https://api.routescan.io/v2/network/mainnet/evm/9746/etherscan";

        console2.log("=== Contract Verification Commands ===");
        console2.log("Environment:", env);
        console2.log("Verifier URL:", verifierUrl);
        console2.log("");

        // Verify Lithos token (no constructor args)
        console2.log("1. Verify Lithos:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["Lithos"]),
                " src/contracts/Lithos.sol:Lithos",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
            )
        );
        console2.log("");

        // Verify VeArtProxy Implementation
        console2.log("2. Verify VeArtProxy Implementation:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["VeArtProxyImpl"]),
                " src/contracts/VeArtProxyUpgradeable.sol:VeArtProxyUpgradeable",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
            )
        );
        console2.log("");

        // Verify VeArtProxy (Proxy)
        console2.log("3. Verify VeArtProxy (Proxy):");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["VeArtProxy"]),
                " @openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab",
                ' --constructor-args $(cast abi-encode "constructor(address,address,bytes)" ',
                vm.toString(deployed["VeArtProxyImpl"]),
                " ",
                "0x0000000000000000000000000000000000000000",
                " ", // Will need actual deployer address
                "0x8129fc1c)" // initialize() selector
            )
        );
        console2.log("");

        // Verify Minter Implementation
        console2.log("4. Verify Minter Implementation:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["MinterImpl"]),
                " src/contracts/MinterUpgradeable.sol:MinterUpgradeable",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
            )
        );
        console2.log("");

        // Verify VotingEscrow
        console2.log("5. Verify VotingEscrow:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["VotingEscrow"]),
                " src/contracts/VotingEscrow.sol:VotingEscrow",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab",
                ' --constructor-args $(cast abi-encode "constructor(address,address)" ',
                vm.toString(deployed["Lithos"]),
                " ",
                vm.toString(deployed["VeArtProxy"]),
                ")"
            )
        );
        console2.log("");

        // Verify GaugeFactory
        console2.log("6. Verify GaugeFactory:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["GaugeFactory"]),
                " src/contracts/factories/GaugeFactoryV2.sol:GaugeFactoryV2",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
            )
        );
        console2.log("");

        // Verify PermissionsRegistry
        console2.log("7. Verify PermissionsRegistry:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["PermissionsRegistry"]),
                " src/contracts/PermissionsRegistry.sol:PermissionsRegistry",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
            )
        );
        console2.log("");

        // Verify BribeFactory
        console2.log("8. Verify BribeFactory:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["BribeFactory"]),
                " src/contracts/factories/BribeFactoryV3.sol:BribeFactoryV3",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
            )
        );
        console2.log("");

        // Verify Voter
        console2.log("9. Verify Voter:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["Voter"]),
                " src/contracts/VoterV3.sol:VoterV3",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
            )
        );
        console2.log("");

        // Verify RewardsDistributor
        console2.log("10. Verify RewardsDistributor:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["RewardsDistributor"]),
                " src/contracts/RewardsDistributor.sol:RewardsDistributor",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab",
                ' --constructor-args $(cast abi-encode "constructor(address)" ',
                vm.toString(deployed["VotingEscrow"]),
                ")"
            )
        );
        console2.log("");

        // Verify Timelock
        console2.log("11. Verify Timelock:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(deployed["Timelock"]),
                " @openzeppelin/contracts/governance/TimelockController.sol:TimelockController",
                " --verifier-url '",
                verifierUrl,
                "'",
                " --etherscan-api-key 'verifyContract'",
                " --num-of-optimizations 200",
                " --compiler-version v0.8.29+commit.e719f8ab"
                // Note: Constructor args for Timelock are complex, will need manual verification
            )
        );
        console2.log("");

        console2.log("=== Notes ===");
        console2.log("- Copy and paste each command individually");
        console2.log(
            "- Some contracts (like proxies and Timelock) may need manual constructor args"
        );
        console2.log("- Check the actual deployer address for proxy contracts");
        console2.log("- Ensure you're using the correct compiler version");
    }

    function _loadState(string memory path) private {
        string memory json = vm.readFile(path);

        // Load all deployed contract addresses
        deployed["Lithos"] = vm.parseJsonAddress(json, ".Lithos");
        deployed["VeArtProxy"] = vm.parseJsonAddress(json, ".VeArtProxy");
        deployed["VeArtProxyImpl"] = vm.parseJsonAddress(
            json,
            ".VeArtProxyImpl"
        );
        deployed["Minter"] = vm.parseJsonAddress(json, ".Minter");
        deployed["MinterImpl"] = vm.parseJsonAddress(json, ".MinterImpl");
        deployed["VotingEscrow"] = vm.parseJsonAddress(json, ".VotingEscrow");
        deployed["GaugeFactory"] = vm.parseJsonAddress(json, ".GaugeFactory");
        deployed["PermissionsRegistry"] = vm.parseJsonAddress(
            json,
            ".PermissionsRegistry"
        );
        deployed["BribeFactory"] = vm.parseJsonAddress(json, ".BribeFactory");
        deployed["Voter"] = vm.parseJsonAddress(json, ".Voter");
        deployed["RewardsDistributor"] = vm.parseJsonAddress(
            json,
            ".RewardsDistributor"
        );
        deployed["Timelock"] = vm.parseJsonAddress(json, ".Timelock");
    }
}
