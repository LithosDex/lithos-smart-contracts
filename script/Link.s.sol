// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {BribeFactoryV3} from "../src/contracts/factories/BribeFactoryV3.sol";
import {PairFactoryUpgradeable} from "../src/contracts/factories/PairFactoryUpgradeable.sol";
import {VotingEscrow} from "../src/contracts/VotingEscrow.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {Lithos} from "../src/contracts/Lithos.sol";
import {RewardsDistributor} from "../src/contracts/RewardsDistributor.sol";
import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";

contract LinkScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        string memory statePath = string.concat("deployments/", env, "/state.json");

        // Load deployed addresses
        _loadState(statePath);

        console2.log("=== Linking Lithos Protocol ===");
        console2.log("Environment:", env);
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerKey);

        // Configure PairFactory fees
        PairFactoryUpgradeable pairFactory = PairFactoryUpgradeable(deployed["PairFactoryUpgradeable"]);
        console2.log("Configuring PairFactoryUpgradeable fees...");
        if (pairFactory.getFee(true) != 4) {
            pairFactory.setFee(true, 4); // 0.04% stable
        }
        if (pairFactory.getFee(false) != 18) {
            pairFactory.setFee(false, 18); // 0.18% volatile
        }
        if (pairFactory.stakingFeeHandler() != deployer) {
            console2.log("Setting staking fee handler to deployer...");
            pairFactory.setStakingFeeAddress(deployer);
        } else {
            console2.log("Staking fee handler already set to deployer");
        }

        // Set referral fee to 0 (disable referral system)
        if (pairFactory.MAX_REFERRAL_FEE() != 0) {
            console2.log("Setting referral fee to 0...");
            pairFactory.setReferralFee(0);
        } else {
            console2.log("Referral fee already set to 0");
        }

        // Set dibs to deployer (required to be non-zero address)
        if (pairFactory.dibs() != deployer) {
            console2.log("Setting dibs to deployer...");
            pairFactory.setDibs(deployer);
        } else {
            console2.log("Dibs already set to deployer");
        }

        // Grant GOVERNANCE role to deployer for Phase 3 operations
        PermissionsRegistry permissions = PermissionsRegistry(deployed["PermissionsRegistry"]);
        if (!permissions.hasRole("GOVERNANCE", deployer)) {
            console2.log("Granting GOVERNANCE role to deployer...");
            permissions.setRoleFor(deployer, "GOVERNANCE");
        } else {
            console2.log("Deployer already has GOVERNANCE role");
        }

        // Link BribeFactoryV3 to VoterV3
        BribeFactoryV3 bribeFactory = BribeFactoryV3(deployed["BribeFactoryV3"]);
        if (bribeFactory.voter() != deployed["VoterV3"]) {
            console2.log("Setting BribeFactoryV3 voter...");
            bribeFactory.setVoter(deployed["VoterV3"]);
        } else {
            console2.log("BribeFactoryV3 already linked to VoterV3");
        }

        // Link VotingEscrow to VoterV3
        VotingEscrow votingEscrow = VotingEscrow(deployed["VotingEscrow"]);
        if (votingEscrow.voter() != deployed["VoterV3"]) {
            console2.log("Setting VotingEscrow voter...");
            votingEscrow.setVoter(deployed["VoterV3"]);
        } else {
            console2.log("VotingEscrow already points to VoterV3");
        }

        // Link VoterV3 to MinterUpgradeable
        VoterV3 voterV3 = VoterV3(deployed["VoterV3"]);
        if (
            voterV3.permissionRegistry() != deployed["PermissionsRegistry"]
                || voterV3.minter() != deployed["MinterUpgradeable"]
        ) {
            console2.log("Running VoterV3._init to set registry and minter...");
            address[] memory tokens = new address[](0);
            voterV3._init(tokens, deployed["PermissionsRegistry"], deployed["MinterUpgradeable"]);
        } else {
            console2.log("VoterV3 already wired to registry and minter");
        }

        // Handle initial mint before setting MinterUpgradeable as minter
        Lithos lithos = Lithos(deployed["Lithos"]);

        // First, perform initial mint if not done yet
        if (!lithos.initialMinted()) {
            console2.log("Performing initial mint of 50M LITHOS to deployer...");
            lithos.initialMint(deployer);
            console2.log("Initial mint complete. Deployer balance:", lithos.balanceOf(deployer) / 1e18, "LITHOS");
        } else {
            console2.log("Initial mint already completed");
        }

        // Then set Lithos minter to the Minter contract
        if (lithos.minter() != deployed["MinterUpgradeable"]) {
            console2.log("Setting Lithos minter to MinterUpgradeable...");
            lithos.setMinter(deployed["MinterUpgradeable"]);
        } else {
            console2.log("Lithos minter already set to MinterUpgradeable");
        }

        // Allow the minter to checkpoint RewardsDistributor emissions
        RewardsDistributor rewardsDistributor = RewardsDistributor(deployed["RewardsDistributor"]);
        if (rewardsDistributor.depositor() != deployed["MinterUpgradeable"]) {
            console2.log("Assigning RewardsDistributor depositor to MinterUpgradeable...");
            rewardsDistributor.setDepositor(deployed["MinterUpgradeable"]);
        } else {
            console2.log("RewardsDistributor depositor already set to MinterUpgradeable");
        }

        vm.stopBroadcast();

        console2.log("\n=== Linking Complete ===");
        console2.log("Run 'forge script script/Ownership.s.sol' to transfer ownership");
    }

    function _loadState(string memory path) private {
        require(vm.exists(path), "State file not found. Run DeployAndInit.s.sol first!");

        string memory json = vm.readFile(path);

        deployed["Lithos"] = vm.parseJsonAddress(json, ".Lithos");
        deployed["VeArtProxyUpgradeable"] = vm.parseJsonAddress(json, ".VeArtProxyUpgradeable");
        deployed["VotingEscrow"] = vm.parseJsonAddress(json, ".VotingEscrow");
        deployed["PairFactoryUpgradeable"] = vm.parseJsonAddress(json, ".PairFactoryUpgradeable");
        deployed["TradeHelper"] = vm.parseJsonAddress(json, ".TradeHelper");
        deployed["GlobalRouter"] = vm.parseJsonAddress(json, ".GlobalRouter");
        deployed["RouterV2"] = vm.parseJsonAddress(json, ".RouterV2");
        deployed["GaugeFactoryV2"] = vm.parseJsonAddress(json, ".GaugeFactoryV2");
        deployed["PermissionsRegistry"] = vm.parseJsonAddress(json, ".PermissionsRegistry");
        deployed["BribeFactoryV3"] = vm.parseJsonAddress(json, ".BribeFactoryV3");
        deployed["VoterV3"] = vm.parseJsonAddress(json, ".VoterV3");
        deployed["RewardsDistributor"] = vm.parseJsonAddress(json, ".RewardsDistributor");
        deployed["MinterUpgradeable"] = vm.parseJsonAddress(json, ".MinterUpgradeable");
    }
}
