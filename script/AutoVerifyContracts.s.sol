// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script, console2} from "forge-std/Script.sol";

contract AutoVerifyContractsScript is Script {
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

        string memory verifierUrl = keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked("testnet"))
            ? "https://api.routescan.io/v2/network/testnet/evm/9746_5/etherscan"
            : "https://api.routescan.io/v2/network/mainnet/evm/9746/etherscan";

        console2.log("=== Auto-Verifying Contracts ===");
        console2.log("Environment:", env);
        console2.log("Verifier URL:", verifierUrl);
        console2.log("");

        // Verify contracts one by one
        _verifyLithos(verifierUrl);
        _verifyVeArtProxyImpl(verifierUrl);
        _verifyMinterImpl(verifierUrl);
        _verifyVotingEscrow(verifierUrl);
        _verifyGaugeFactory(verifierUrl);
        _verifyPermissionsRegistry(verifierUrl);
        _verifyBribeFactory(verifierUrl);
        _verifyVoter(verifierUrl);
        _verifyRewardsDistributor(verifierUrl);
        _verifyTimelock(verifierUrl);

        console2.log("=== Verification Complete ===");
        console2.log(
            "Note: Proxy contracts may need manual verification with proper constructor args"
        );
    }

    function _verifyLithos(string memory verifierUrl) private {
        console2.log("1. Verifying Lithos...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["Lithos"]);
        inputs[3] = "src/contracts/Lithos.sol:Lithos";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: Lithos verified successfully");
        } catch {
            console2.log("FAILED: Lithos verification failed");
        }
    }

    function _verifyVeArtProxyImpl(string memory verifierUrl) private {
        console2.log("2. Verifying VeArtProxy Implementation...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["VeArtProxyImpl"]);
        inputs[
            3
        ] = "src/contracts/VeArtProxyUpgradeable.sol:VeArtProxyUpgradeable";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: VeArtProxy Implementation verified successfully");
        } catch {
            console2.log("FAILED: VeArtProxy Implementation verification failed");
        }
    }

    function _verifyMinterImpl(string memory verifierUrl) private {
        console2.log("3. Verifying Minter Implementation...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["MinterImpl"]);
        inputs[3] = "src/contracts/MinterUpgradeable.sol:MinterUpgradeable";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: Minter Implementation verified successfully");
        } catch {
            console2.log("FAILED: Minter Implementation verification failed");
        }
    }

    function _verifyVotingEscrow(string memory verifierUrl) private {
        console2.log("4. Verifying VotingEscrow...");

        // Encode constructor args
        string[] memory castInputs = new string[](4);
        castInputs[0] = "cast";
        castInputs[1] = "abi-encode";
        castInputs[2] = "constructor(address,address)";
        castInputs[3] = string.concat(
            vm.toString(deployed["Lithos"]),
            " ",
            vm.toString(deployed["VeArtProxy"])
        );

        bytes memory constructorArgs = vm.ffi(castInputs);

        string[] memory inputs = new string[](10);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["VotingEscrow"]);
        inputs[3] = "src/contracts/VotingEscrow.sol:VotingEscrow";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";
        inputs[9] = string.concat(
            "--constructor-args=",
            string(constructorArgs)
        );

        try vm.ffi(inputs) {
            console2.log("SUCCESS: VotingEscrow verified successfully");
        } catch {
            console2.log("FAILED: VotingEscrow verification failed");
        }
    }

    function _verifyGaugeFactory(string memory verifierUrl) private {
        console2.log("5. Verifying GaugeFactory...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["GaugeFactory"]);
        inputs[3] = "src/contracts/factories/GaugeFactoryV2.sol:GaugeFactoryV2";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: GaugeFactory verified successfully");
        } catch {
            console2.log("FAILED: GaugeFactory verification failed");
        }
    }

    function _verifyPermissionsRegistry(string memory verifierUrl) private {
        console2.log("6. Verifying PermissionsRegistry...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["PermissionsRegistry"]);
        inputs[3] = "src/contracts/PermissionsRegistry.sol:PermissionsRegistry";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: PermissionsRegistry verified successfully");
        } catch {
            console2.log("FAILED: PermissionsRegistry verification failed");
        }
    }

    function _verifyBribeFactory(string memory verifierUrl) private {
        console2.log("7. Verifying BribeFactory...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["BribeFactory"]);
        inputs[3] = "src/contracts/factories/BribeFactoryV3.sol:BribeFactoryV3";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: BribeFactory verified successfully");
        } catch {
            console2.log("FAILED: BribeFactory verification failed");
        }
    }

    function _verifyVoter(string memory verifierUrl) private {
        console2.log("8. Verifying Voter...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["Voter"]);
        inputs[3] = "src/contracts/VoterV3.sol:VoterV3";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: Voter verified successfully");
        } catch {
            console2.log("FAILED: Voter verification failed");
        }
    }

    function _verifyRewardsDistributor(string memory verifierUrl) private {
        console2.log("9. Verifying RewardsDistributor...");

        // Encode constructor args
        string[] memory castInputs = new string[](4);
        castInputs[0] = "cast";
        castInputs[1] = "abi-encode";
        castInputs[2] = "constructor(address)";
        castInputs[3] = vm.toString(deployed["VotingEscrow"]);

        bytes memory constructorArgs = vm.ffi(castInputs);

        string[] memory inputs = new string[](10);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["RewardsDistributor"]);
        inputs[3] = "src/contracts/RewardsDistributor.sol:RewardsDistributor";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";
        inputs[9] = string.concat(
            "--constructor-args=",
            string(constructorArgs)
        );

        try vm.ffi(inputs) {
            console2.log("SUCCESS: RewardsDistributor verified successfully");
        } catch {
            console2.log("FAILED: RewardsDistributor verification failed");
        }
    }

    function _verifyTimelock(string memory verifierUrl) private {
        console2.log("10. Verifying Timelock...");
        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployed["Timelock"]);
        inputs[
            3
        ] = "@openzeppelin/contracts/governance/TimelockController.sol:TimelockController";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = "--etherscan-api-key=verifyContract";
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log("SUCCESS: Timelock verified successfully");
        } catch {
            console2.log(
                "FAILED: Timelock verification failed (constructor args needed)"
            );
        }
    }

    function _loadState(string memory path) private {
        string memory json = vm.readFile(path);

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
