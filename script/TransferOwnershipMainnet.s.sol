// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";
import {PairFactoryUpgradeable} from "../src/contracts/factories/PairFactoryUpgradeable.sol";
import {GaugeFactoryV2} from "../src/contracts/factories/GaugeFactoryV2.sol";
import {BribeFactoryV3} from "../src/contracts/factories/BribeFactoryV3.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";
import {RewardsDistributor} from "../src/contracts/RewardsDistributor.sol";
import {VotingEscrow} from "../src/contracts/VotingEscrow.sol";

interface IProxyAdmin {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @notice Transfers ownership, roles, and proxy admin rights for the Lithos mainnet deployment.
contract TransferOwnershipMainnetScript is Script {
    using stdJson for string;

    // --- Constants & defaults -------------------------------------------------

    address internal constant DEFAULT_GOVERNANCE_MULTISIG = 0x21F1c2F66d30e22DaC1e2D509228407ccEff4dBC; // 4/6 governance
    address internal constant DEFAULT_OPERATIONS_MULTISIG = 0xbEe8e366fEeB999993841a17C1DCaaad9d4618F7; // 3/4 operations
    address internal constant DEFAULT_EMERGENCY_COUNCIL = 0x771675A54f18816aC9CD71b07d3d6e6Be7a9D799; // 2/3 emergency
    address internal constant DEFAULT_TREASURY_MULTISIG = 0xe98c1e28805A06F23B41cf6d356dFC7709DB9385; // 4/6 treasury
    address internal constant DEFAULT_FOUNDATION = 0xD333A0106DEfC9468C53B95779281B20475d7735; // foundation veNFT steward

    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103; // ERC1967 admin slot

    // --- Data containers ------------------------------------------------------

    struct DeploymentAddresses {
        address permissionsRegistry;
        address pairFactory;
        address gaugeFactory;
        address bribeFactory;
        address minterProxy;
        address veArtProxy;
        address votingEscrow;
        address rewardsDistributor;
        address timelock;
    }

    struct MultisigConfig {
        address governance;
        address operations;
        address emergency;
        address treasury;
        address foundation;
        address timelock;
        address deployer;
    }

    // --- Entry point ----------------------------------------------------------

    function run() external {
        string memory env = _envStringOr("DEPLOY_ENV", "mainnet");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        MultisigConfig memory cfg = MultisigConfig({
            governance: _envAddressOr("GOVERNANCE_MULTISIG", DEFAULT_GOVERNANCE_MULTISIG),
            operations: _envAddressOr("OPERATIONS_MULTISIG", DEFAULT_OPERATIONS_MULTISIG),
            emergency: _envAddressOr("EMERGENCY_COUNCIL", DEFAULT_EMERGENCY_COUNCIL),
            treasury: _envAddressOr("TREASURY_MULTISIG", DEFAULT_TREASURY_MULTISIG),
            foundation: _envAddressOr("FOUNDATION_ADDRESS", DEFAULT_FOUNDATION),
            timelock: address(0),
            deployer: deployer
        });

        DeploymentAddresses memory addrs = _loadDeployment(env);
        require(addrs.timelock != address(0), "Timelock address missing in state file");
        cfg.timelock = addrs.timelock;

        console2.log("=== Lithos Mainnet Ownership Handover ===");
        console2.log("Environment:", env);
        console2.log("Deployer EOA:", deployer);
        console2.log("PermissionsRegistry:", addrs.permissionsRegistry);
        console2.log("Timelock:", addrs.timelock);
        console2.log("Governance multisig:", cfg.governance);
        console2.log("Operations multisig:", cfg.operations);
        console2.log("Emergency council:", cfg.emergency);
        console2.log("Treasury:", cfg.treasury);
        console2.log("Foundation:", cfg.foundation);

        vm.startBroadcast(deployerKey);

        _transferPermissionsRegistry(addrs.permissionsRegistry, cfg);
        _handoffFactories(addrs, cfg);
        _handoffEmissionsContracts(addrs, cfg);
        _handoffProxyAdmins(addrs, cfg);

        vm.stopBroadcast();

        console2.log("\n=== Handover complete ===");
        console2.log("Action items for multisigs:");
        console2.log("- Governance multisig: call PairFactory.acceptFeeManager()");
        console2.log("- Operations multisig: call MinterUpgradeable.acceptTeam()");
        console2.log("- Confirm Timelock is admin for VeArtProxy & Minter proxies before scheduling upgrades");
    }

    // --- Permissions registry -------------------------------------------------

    function _transferPermissionsRegistry(address registryAddr, MultisigConfig memory cfg) internal {
        require(registryAddr != address(0), "PermissionsRegistry missing");

        PermissionsRegistry registry = PermissionsRegistry(registryAddr);

        console2.log("\n[PermissionsRegistry]");

        // Ensure caller can manage roles before proceeding
        require(registry.lithosMultisig() == cfg.deployer, "Deployer is not current lithosMultisig");

        _grantRole(registry, cfg.governance, "GOVERNANCE");
        _grantRole(registry, cfg.governance, "VOTER_ADMIN");
        _grantRole(registry, cfg.governance, "GAUGE_ADMIN");
        _grantRole(registry, cfg.governance, "BRIBE_ADMIN");

        _revokeRoleIfPresent(registry, cfg.deployer, "GOVERNANCE");
        _revokeRoleIfPresent(registry, cfg.deployer, "VOTER_ADMIN");
        _revokeRoleIfPresent(registry, cfg.deployer, "GAUGE_ADMIN");
        _revokeRoleIfPresent(registry, cfg.deployer, "BRIBE_ADMIN");

        address currentTeamMultisig = registry.lithosTeamMultisig();
        if (currentTeamMultisig == cfg.deployer && currentTeamMultisig != cfg.operations) {
            registry.setLithosTeamMultisig(cfg.operations);
            console2.log(" - Set lithosTeamMultisig to operations multisig");
        } else if (currentTeamMultisig == cfg.operations) {
            console2.log(" - lithosTeamMultisig already handed off");
        } else {
            console2.log(" - Skipped lithosTeamMultisig update (deployer not current team multisig)");
        }

        address currentEmergencyCouncil = registry.emergencyCouncil();
        bool canRotateEmergency = currentEmergencyCouncil == cfg.deployer || registry.lithosMultisig() == cfg.deployer;
        if (canRotateEmergency && currentEmergencyCouncil != cfg.emergency) {
            registry.setEmergencyCouncil(cfg.emergency);
            console2.log(" - Set emergency council multisig");
        } else if (currentEmergencyCouncil == cfg.emergency) {
            console2.log(" - Emergency council already set");
        } else {
            console2.log(" - Skipped emergency council update (no authority)");
        }

        if (registry.lithosMultisig() != cfg.governance) {
            registry.setLithosMultisig(cfg.governance);
            console2.log(" - Transferred lithosMultisig to governance multisig");
        } else {
            console2.log(" - Governance multisig already controls lithosMultisig");
        }
    }

    function _grantRole(PermissionsRegistry registry, address target, string memory role) internal {
        if (target == address(0)) return;
        if (!registry.hasRole(bytes(role), target)) {
            registry.setRoleFor(target, role);
            console2.log(string.concat(" - Granted ", role, " to"), target);
        } else {
            console2.log(string.concat(" - ", role, " already granted to"), target);
        }
    }

    function _revokeRoleIfPresent(PermissionsRegistry registry, address target, string memory role) internal {
        if (target == address(0)) return;
        if (registry.hasRole(bytes(role), target)) {
            registry.removeRoleFrom(target, role);
            console2.log(string.concat(" - Removed ", role, " from"), target);
        }
    }

    // --- Factory ownership ----------------------------------------------------

    function _handoffFactories(DeploymentAddresses memory addrs, MultisigConfig memory cfg) internal {
        console2.log("\n[Factories]");

        if (addrs.pairFactory != address(0)) {
            PairFactoryUpgradeable pairFactory = PairFactoryUpgradeable(addrs.pairFactory);

            if (pairFactory.owner() == cfg.deployer && pairFactory.owner() != cfg.governance) {
                pairFactory.transferOwnership(cfg.governance);
                console2.log(" - PairFactory ownership -> governance multisig");
            } else if (pairFactory.owner() == cfg.governance) {
                console2.log(" - PairFactory ownership already handed off");
            } else {
                console2.log(" - Skipped PairFactory ownership transfer (deployer not owner)");
            }

            if (pairFactory.feeManager() == cfg.deployer && cfg.governance != address(0)) {
                pairFactory.setFeeManager(cfg.governance);
                console2.log(" - PairFactory feeManager pending -> governance multisig");
            } else if (pairFactory.feeManager() == cfg.governance) {
                console2.log(" - PairFactory feeManager already governance multisig");
            } else {
                console2.log(" - Skipped PairFactory feeManager update (not current fee manager)");
            }
        }

        if (addrs.gaugeFactory != address(0)) {
            GaugeFactoryV2 gaugeFactory = GaugeFactoryV2(addrs.gaugeFactory);
            if (gaugeFactory.owner() == cfg.deployer && gaugeFactory.owner() != cfg.governance) {
                gaugeFactory.transferOwnership(cfg.governance);
                console2.log(" - GaugeFactory ownership -> governance multisig");
            } else if (gaugeFactory.owner() == cfg.governance) {
                console2.log(" - GaugeFactory ownership already handed off");
            } else {
                console2.log(" - Skipped GaugeFactory ownership transfer (deployer not owner)");
            }
        }

        if (addrs.bribeFactory != address(0)) {
            BribeFactoryV3 bribeFactory = BribeFactoryV3(addrs.bribeFactory);
            if (bribeFactory.owner() == cfg.deployer && bribeFactory.owner() != cfg.governance) {
                bribeFactory.transferOwnership(cfg.governance);
                console2.log(" - BribeFactory ownership -> governance multisig");
            } else if (bribeFactory.owner() == cfg.governance) {
                console2.log(" - BribeFactory ownership already handed off");
            } else {
                console2.log(" - Skipped BribeFactory ownership transfer (deployer not owner)");
            }
        }
    }

    // --- Emissions & voting contracts ----------------------------------------

    function _handoffEmissionsContracts(DeploymentAddresses memory addrs, MultisigConfig memory cfg) internal {
        console2.log("\n[Emissions & Voting]");

        if (addrs.minterProxy != address(0)) {
            MinterUpgradeable minter = MinterUpgradeable(addrs.minterProxy);
            address currentTeam = minter.team();
            if (currentTeam == cfg.deployer && currentTeam != cfg.operations) {
                minter.setTeam(cfg.operations);
                console2.log(" - Minter team pending -> operations multisig");
            } else if (minter.team() == cfg.operations) {
                console2.log(" - Minter team already operations multisig");
            } else {
                console2.log(" - Skipped Minter team update (deployer not current team)");
            }
        }

        if (addrs.rewardsDistributor != address(0)) {
            RewardsDistributor distributor = RewardsDistributor(addrs.rewardsDistributor);
            if (distributor.owner() == cfg.deployer && distributor.owner() != cfg.operations) {
                distributor.setOwner(cfg.operations);
                console2.log(" - RewardsDistributor owner -> operations multisig");
            } else if (distributor.owner() == cfg.operations) {
                console2.log(" - RewardsDistributor ownership already handed off");
            } else {
                console2.log(" - Skipped RewardsDistributor ownership transfer (deployer not owner)");
            }
        }

        if (addrs.votingEscrow != address(0)) {
            VotingEscrow votingEscrow = VotingEscrow(addrs.votingEscrow);
            address currentTeam = votingEscrow.team();
            if (currentTeam == cfg.deployer && currentTeam != cfg.operations) {
                votingEscrow.setTeam(cfg.operations);
                console2.log(" - VotingEscrow team -> operations multisig");
            } else if (currentTeam == cfg.operations) {
                console2.log(" - VotingEscrow team already operations multisig");
            } else {
                console2.log(" - Skipped VotingEscrow team update (deployer not current team)");
            }
        }
    }

    // --- Proxy admin handoff --------------------------------------------------

    function _handoffProxyAdmins(DeploymentAddresses memory addrs, MultisigConfig memory cfg) internal {
        console2.log("\n[Proxy Admins]");

        _changeProxyAdminIfNeeded(addrs.minterProxy, cfg);
        _changeProxyAdminIfNeeded(addrs.veArtProxy, cfg);
    }

    function _changeProxyAdminIfNeeded(address proxy, MultisigConfig memory cfg) internal {
        if (proxy == address(0)) return;

        address adminAddress = _loadProxyAdmin(proxy);
        if (adminAddress == address(0)) {
            console2.log(" - Proxy admin slot unset:", proxy);
            return;
        }

        if (adminAddress.code.length == 0) {
            if (adminAddress == cfg.timelock) {
                console2.log(" - Timelock already direct admin for proxy:", proxy);
            } else if (adminAddress == cfg.deployer) {
                console2.log(" - Proxy uses EOA admin. Manual timelock transfer required:", proxy);
            } else {
                console2.log(" - Skipped proxy admin update (admin not recognized):", proxy);
            }
            return;
        }

        IProxyAdmin admin = IProxyAdmin(adminAddress);
        address adminOwner = admin.owner();

        if (adminOwner == cfg.deployer && adminOwner != cfg.timelock) {
            admin.transferOwnership(cfg.timelock);
            console2.log(" - ProxyAdmin ownership -> timelock:", proxy);
        } else if (adminOwner == cfg.timelock) {
            console2.log(" - Timelock already owns ProxyAdmin for proxy:", proxy);
        } else {
            console2.log(" - Skipped ProxyAdmin ownership update (deployer not owner):", proxy);
        }
    }

    function _loadProxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
    }

    // --- Helpers --------------------------------------------------------------

    function _loadDeployment(string memory env) internal view returns (DeploymentAddresses memory addrs) {
        string memory statePath = string.concat("deployments/", env, "/state.json");
        require(vm.exists(statePath), "State file not found. Run deployments first.");

        string memory json = vm.readFile(statePath);

        addrs.permissionsRegistry = json.readAddress(".PermissionsRegistry");
        addrs.pairFactory = json.readAddress(".PairFactoryUpgradeable");
        addrs.gaugeFactory = json.readAddress(".GaugeFactory");
        addrs.bribeFactory = json.readAddress(".BribeFactory");
        addrs.minterProxy = json.readAddress(".Minter");
        addrs.veArtProxy = json.readAddress(".VeArtProxy");
        addrs.votingEscrow = json.readAddress(".VotingEscrow");
        addrs.rewardsDistributor = json.readAddress(".RewardsDistributor");
        addrs.timelock = json.readAddress(".Timelock");

        return addrs;
    }

    function _envStringOr(string memory key, string memory fallbackValue) internal view returns (string memory) {
        return vm.envExists(key) ? vm.envString(key) : fallbackValue;
    }

    function _envAddressOr(string memory key, address fallbackValue) internal view returns (address) {
        return vm.envExists(key) ? vm.envAddress(key) : fallbackValue;
    }
}
