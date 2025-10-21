// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {PairAPI} from "../src/contracts/APIHelper/PairAPI.sol";
import {RewardAPI} from "../src/contracts/APIHelper/RewardAPI.sol";
import {veNFTAPI} from "../src/contracts/APIHelper/veNFTAPI.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Deploys the read-only API helper contracts against an existing deployment.
contract DeployAPIHelpersScript is Script {
    using stdJson for string;

    string internal constant DEFAULT_ENV = "mainnet";

    struct DeploymentArtifacts {
        address pairProxy;
        address pairImplementation;
        address rewardProxy;
        address rewardImplementation;
        address venftProxy;
        address venftImplementation;
    }

    function run() external {
        string memory env = vm.envOr("DEPLOY_ENV", DEFAULT_ENV);
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory statePath = string.concat("deployments/", env, "/state.json");
        require(vm.exists(statePath), "state file missing");

        string memory json = vm.readFile(statePath);
        address voter = vm.parseJsonAddress(json, ".Voter");
        address rewardsDistributor = vm.parseJsonAddress(json, ".RewardsDistributor");
        require(voter != address(0) && rewardsDistributor != address(0), "core addresses missing");

        address existingPairApi = _readOptionalAddress(json, ".PairAPI");
        address existingPairApiImpl = _readOptionalAddress(json, ".PairAPIImpl");
        address existingRewardApi = _readOptionalAddress(json, ".RewardAPI");
        address existingRewardApiImpl = _readOptionalAddress(json, ".RewardAPIImpl");
        address existingVeNftApi = _readOptionalAddress(json, ".VeNFTAPI");
        address existingVeNftApiImpl = _readOptionalAddress(json, ".VeNFTAPIImpl");

        bool allowRedeploy = vm.envOr("REDEPLOY_API_HELPERS", false);

        if (!allowRedeploy) {
            bool helpersUnset = existingPairApi == address(0) && existingRewardApi == address(0)
                && existingVeNftApi == address(0) && existingPairApiImpl == address(0)
                && existingRewardApiImpl == address(0) && existingVeNftApiImpl == address(0);
            require(helpersUnset, "helpers already deployed; set REDEPLOY_API_HELPERS=true to overwrite");
        }

        console2.log("=== Deploy Lithos API Helpers ===");
        console2.log("Environment:", env);
        console2.log("State file:", statePath);
        console2.log("Deployer:", deployer);
        console2.log("Voter:", voter);
        console2.log("RewardsDistributor:", rewardsDistributor);

        DeploymentArtifacts memory artifacts = _deployApiHelpers(deployerKey, deployer, voter, rewardsDistributor);

        _persistDeploymentState(statePath, artifacts);
        _logDeploymentSummary(artifacts);

        bool shouldVerify = vm.envOr("VERIFY_API_HELPERS", false);
        if (shouldVerify) {
            string memory defaultVerifier = keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked("testnet"))
                ? "https://api.routescan.io/v2/network/testnet/evm/9746_5/etherscan"
                : "https://api.routescan.io/v2/network/mainnet/evm/9745/etherscan";
            string memory verifierUrl = vm.envOr("VERIFIER_URL", defaultVerifier);
            string memory apiKey = vm.envOr("ETHERSCAN_API_KEY", string("verifyContract"));

            _verifyArtifacts(artifacts, verifierUrl, apiKey, deployer, voter, rewardsDistributor);
        }
    }

    function _readOptionalAddress(string memory json, string memory key) internal view returns (address) {
        if (!json.keyExists(key)) {
            return address(0);
        }
        return json.readAddress(key);
    }

    function _deployApiHelpers(uint256 deployerKey, address deployer, address voter, address rewardsDistributor)
        internal
        returns (DeploymentArtifacts memory artifacts)
    {
        bytes memory pairInit = abi.encodeCall(PairAPI.initialize, (voter));
        bytes memory rewardInit = abi.encodeCall(RewardAPI.initialize, (voter));

        vm.startBroadcast(deployerKey);

        PairAPI pairImpl = new PairAPI();
        TransparentUpgradeableProxy pairProxy = new TransparentUpgradeableProxy(address(pairImpl), deployer, pairInit);

        RewardAPI rewardImpl = new RewardAPI();
        TransparentUpgradeableProxy rewardProxy =
            new TransparentUpgradeableProxy(address(rewardImpl), deployer, rewardInit);

        veNFTAPI venftImpl = new veNFTAPI();
        bytes memory venftInit = abi.encodeCall(veNFTAPI.initialize, (voter, rewardsDistributor, address(pairProxy)));
        TransparentUpgradeableProxy venftProxy =
            new TransparentUpgradeableProxy(address(venftImpl), deployer, venftInit);

        vm.stopBroadcast();

        artifacts.pairProxy = address(pairProxy);
        artifacts.pairImplementation = address(pairImpl);
        artifacts.rewardProxy = address(rewardProxy);
        artifacts.rewardImplementation = address(rewardImpl);
        artifacts.venftProxy = address(venftProxy);
        artifacts.venftImplementation = address(venftImpl);
    }

    function _persistDeploymentState(string memory statePath, DeploymentArtifacts memory artifacts) internal {
        _writeAddress(statePath, ".PairAPI", artifacts.pairProxy);
        _writeAddress(statePath, ".PairAPIImpl", artifacts.pairImplementation);
        _writeAddress(statePath, ".RewardAPI", artifacts.rewardProxy);
        _writeAddress(statePath, ".RewardAPIImpl", artifacts.rewardImplementation);
        _writeAddress(statePath, ".VeNFTAPI", artifacts.venftProxy);
        _writeAddress(statePath, ".VeNFTAPIImpl", artifacts.venftImplementation);
    }

    function _logDeploymentSummary(DeploymentArtifacts memory artifacts) internal pure {
        console2.log("PairAPI deployed to:", artifacts.pairProxy);
        console2.log("PairAPI implementation:", artifacts.pairImplementation);
        console2.log("RewardAPI deployed to:", artifacts.rewardProxy);
        console2.log("RewardAPI implementation:", artifacts.rewardImplementation);
        console2.log("veNFTAPI deployed to:", artifacts.venftProxy);
        console2.log("veNFTAPI implementation:", artifacts.venftImplementation);
        console2.log("Deployment state updated with API helper addresses.");
    }

    function _writeAddress(string memory path, string memory key, address value) internal {
        string memory wrapped = string.concat('"', vm.toString(value), '"');
        vm.writeJson(wrapped, path, key);
    }

    function _verifyImplementation(
        string memory label,
        address implementation,
        string memory contractPath,
        string memory verifierUrl,
        string memory apiKey
    ) internal {
        console2.log(string.concat("Verifying ", label, " implementation..."));

        string[] memory inputs = new string[](9);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(implementation);
        inputs[3] = contractPath;
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = string.concat("--etherscan-api-key=", apiKey);
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.29+commit.e719f8ab";
        inputs[8] = "--watch";

        try vm.ffi(inputs) {
            console2.log(string.concat("SUCCESS: ", label, " implementation verification submitted"));
        } catch {
            console2.log(string.concat("FAILED: ", label, " implementation verification errored"));
        }
    }

    function _verifyProxy(
        string memory label,
        address proxy,
        string memory verifierUrl,
        string memory apiKey,
        bytes memory constructorArgs
    ) internal {
        console2.log(string.concat("Verifying ", label, " proxy..."));

        bool hasArgs = constructorArgs.length > 0;
        uint256 length = hasArgs ? 10 : 9;
        string[] memory inputs = new string[](length);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(proxy);
        inputs[3] =
            "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy";
        inputs[4] = string.concat("--verifier-url=", verifierUrl);
        inputs[5] = string.concat("--etherscan-api-key=", apiKey);
        inputs[6] = "--num-of-optimizations=200";
        inputs[7] = "--compiler-version=v0.8.22+commit.4fc1097e";
        inputs[8] = "--watch";

        if (hasArgs) {
            inputs[9] = string.concat("--constructor-args=", vm.toString(constructorArgs));
        }

        try vm.ffi(inputs) {
            console2.log(string.concat("SUCCESS: ", label, " proxy verification submitted"));
        } catch {
            console2.log(string.concat("FAILED: ", label, " proxy verification errored"));
        }
    }

    function _verifyArtifacts(
        DeploymentArtifacts memory artifacts,
        string memory verifierUrl,
        string memory apiKey,
        address deployer,
        address voter,
        address rewardsDistributor
    ) internal {
        console2.log("\n=== Verifying API Helper Contracts ===");

        _verifyImplementation(
            "PairAPI", artifacts.pairImplementation, "src/contracts/APIHelper/PairAPI.sol:PairAPI", verifierUrl, apiKey
        );
        _verifyImplementation(
            "RewardAPI",
            artifacts.rewardImplementation,
            "src/contracts/APIHelper/RewardAPI.sol:RewardAPI",
            verifierUrl,
            apiKey
        );
        _verifyImplementation(
            "veNFTAPI",
            artifacts.venftImplementation,
            "src/contracts/APIHelper/veNFTAPI.sol:veNFTAPI",
            verifierUrl,
            apiKey
        );

        bytes memory pairInit = abi.encodeCall(PairAPI.initialize, (voter));
        bytes memory rewardInit = abi.encodeCall(RewardAPI.initialize, (voter));
        bytes memory venftInit = abi.encodeCall(veNFTAPI.initialize, (voter, rewardsDistributor, artifacts.pairProxy));

        _verifyProxy(
            "PairAPI",
            artifacts.pairProxy,
            verifierUrl,
            apiKey,
            abi.encode(artifacts.pairImplementation, deployer, pairInit)
        );
        _verifyProxy(
            "RewardAPI",
            artifacts.rewardProxy,
            verifierUrl,
            apiKey,
            abi.encode(artifacts.rewardImplementation, deployer, rewardInit)
        );
        _verifyProxy(
            "veNFTAPI",
            artifacts.venftProxy,
            verifierUrl,
            apiKey,
            abi.encode(artifacts.venftImplementation, deployer, venftInit)
        );

        console2.log("=== Verification attempts submitted (watch for async results) ===\n");
    }
}
