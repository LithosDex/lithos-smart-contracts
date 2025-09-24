// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {Lithos} from "../src/contracts/Lithos.sol";
import {VeArtProxyUpgradeable} from "../src/contracts/VeArtProxyUpgradeable.sol";
import {VotingEscrow} from "../src/contracts/VotingEscrow.sol";
import {PairFactoryUpgradeable} from "../src/contracts/factories/PairFactoryUpgradeable.sol";
import {TradeHelper} from "../src/contracts/TradeHelper.sol";
import {GlobalRouter} from "../src/contracts/GlobalRouter.sol";
import {RouterV2} from "../src/contracts/RouterV2.sol";
import {GaugeFactoryV2} from "../src/contracts/factories/GaugeFactoryV2.sol";
import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";
import {BribeFactoryV3} from "../src/contracts/factories/BribeFactoryV3.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {RewardsDistributor} from "../src/contracts/RewardsDistributor.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";

contract DeployAndInitScript is Script {
    mapping(string => address) public deployed;

    // Add deployment phase tracking
    enum Phase {
        NotStarted,
        CoreDeployed,
        DexDeployed,
        GaugeDeployed,
        Initialized,
        Complete
    }

    Phase public currentPhase = Phase.NotStarted;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address wxpl = vm.envAddress("WXPL");

        string memory statePath = string.concat("deployments/", env, "/state.json");

        // Load existing state and determine phase
        if (vm.exists(statePath)) {
            _loadState(statePath);
            _determinePhase();
        }

        console2.log("=== Deploy & Initialize Lithos Protocol ===");
        console2.log("Environment:", env);
        console2.log("Deployer:", deployer);
        console2.log("WXPL:", wxpl);
        console2.log("Current Phase:", uint256(currentPhase));

        // Check gas price is reasonable
        uint256 gasPrice = vm.envOr("GAS_PRICE", uint256(1000000000)); // Default 1 gwei
        if (gasPrice < 1000000000) {
            console2.log("WARNING: Gas price too low:", gasPrice);
            console2.log("Recommended minimum: 1 gwei (1000000000)");
        }

        vm.startBroadcast(deployerKey);

        // Deploy in phases based on current progress
        if (currentPhase < Phase.CoreDeployed) {
            _deployCore(statePath, wxpl);
            currentPhase = Phase.CoreDeployed;
        }

        if (currentPhase < Phase.DexDeployed) {
            _deployDex(statePath, wxpl);
            currentPhase = Phase.DexDeployed;
        }

        if (currentPhase < Phase.GaugeDeployed) {
            _deployGauge(statePath);
            currentPhase = Phase.GaugeDeployed;
        }

        if (currentPhase < Phase.Initialized) {
            _initializeAll(deployer);
            currentPhase = Phase.Initialized;
        }

        vm.stopBroadcast();

        // Final verification
        if (_verifyDeployment()) {
            currentPhase = Phase.Complete;
            console2.log("\n=== Deploy & Initialize Complete ===");
            console2.log("Run 'forge script script/Link.s.sol' to wire contracts");
        } else {
            console2.log("\n=== Deployment Verification Failed ===");
            console2.log("Please check the deployment and try again with --resume");
        }
    }

    function _determinePhase() private {
        // Determine current phase based on what's deployed
        if (deployed["MinterUpgradeable"] != address(0)) {
            // Check if initialized
            if (_isInitialized()) {
                currentPhase = Phase.Initialized;
            } else {
                currentPhase = Phase.GaugeDeployed;
            }
        } else if (deployed["RouterV2"] != address(0)) {
            currentPhase = Phase.DexDeployed;
        } else if (deployed["VotingEscrow"] != address(0)) {
            currentPhase = Phase.CoreDeployed;
        }
    }

    function _isInitialized() private view returns (bool) {
        if (deployed["VeArtProxyUpgradeable"] == address(0)) return false;
        try VeArtProxyUpgradeable(deployed["VeArtProxyUpgradeable"]).owner() returns (address owner) {
            return owner != address(0);
        } catch {
            return false;
        }
    }

    function _verifyDeployment() private view returns (bool) {
        // Verify all contracts are deployed and initialized
        string[] memory requiredContracts = new string[](13);
        requiredContracts[0] = "Lithos";
        requiredContracts[1] = "VeArtProxyUpgradeable";
        requiredContracts[2] = "VotingEscrow";
        requiredContracts[3] = "PairFactoryUpgradeable";
        requiredContracts[4] = "TradeHelper";
        requiredContracts[5] = "GlobalRouter";
        requiredContracts[6] = "RouterV2";
        requiredContracts[7] = "GaugeFactoryV2";
        requiredContracts[8] = "PermissionsRegistry";
        requiredContracts[9] = "BribeFactoryV3";
        requiredContracts[10] = "VoterV3";
        requiredContracts[11] = "RewardsDistributor";
        requiredContracts[12] = "MinterUpgradeable";

        for (uint256 i = 0; i < requiredContracts.length; i++) {
            if (deployed[requiredContracts[i]] == address(0)) {
                console2.log("Missing:", requiredContracts[i]);
                return false;
            }

            // Verify contract exists on chain
            if (deployed[requiredContracts[i]].code.length == 0) {
                console2.log("Not deployed on chain:", requiredContracts[i]);
                return false;
            }
        }

        return true;
    }

    function _deployCore(string memory statePath, address wxpl) private {
        if (deployed["Lithos"] == address(0)) {
            Lithos lithos = new Lithos();
            deployed["Lithos"] = address(lithos);
            console2.log("Lithos deployed:", address(lithos));
            _saveState(statePath);
        } else {
            console2.log("Lithos already deployed:", deployed["Lithos"]);
        }

        if (deployed["VeArtProxyUpgradeable"] == address(0)) {
            VeArtProxyUpgradeable veArtProxy = new VeArtProxyUpgradeable();
            deployed["VeArtProxyUpgradeable"] = address(veArtProxy);
            console2.log("VeArtProxyUpgradeable deployed:", address(veArtProxy));
            _saveState(statePath);
        } else {
            console2.log("VeArtProxyUpgradeable already deployed:", deployed["VeArtProxyUpgradeable"]);
        }

        if (deployed["VotingEscrow"] == address(0)) {
            VotingEscrow votingEscrow = new VotingEscrow(deployed["Lithos"], deployed["VeArtProxyUpgradeable"]);
            deployed["VotingEscrow"] = address(votingEscrow);
            console2.log("VotingEscrow deployed:", address(votingEscrow));
            _saveState(statePath);
        } else {
            console2.log("VotingEscrow already deployed:", deployed["VotingEscrow"]);
        }
    }

    function _deployDex(string memory statePath, address wxpl) private {
        console2.log("\n--- Deploying DEX Infrastructure ---");

        if (deployed["PairFactoryUpgradeable"] == address(0)) {
            PairFactoryUpgradeable pairFactory = new PairFactoryUpgradeable();
            deployed["PairFactoryUpgradeable"] = address(pairFactory);
            console2.log("PairFactoryUpgradeable deployed:", address(pairFactory));
            _saveState(statePath);
        } else {
            console2.log("PairFactoryUpgradeable already deployed:", deployed["PairFactoryUpgradeable"]);
        }

        if (deployed["TradeHelper"] == address(0)) {
            TradeHelper tradeHelper = new TradeHelper(deployed["PairFactoryUpgradeable"]);
            deployed["TradeHelper"] = address(tradeHelper);
            console2.log("TradeHelper deployed:", address(tradeHelper));
            _saveState(statePath);
        } else {
            console2.log("TradeHelper already deployed:", deployed["TradeHelper"]);
        }

        if (deployed["GlobalRouter"] == address(0)) {
            GlobalRouter globalRouter = new GlobalRouter(deployed["TradeHelper"]);
            deployed["GlobalRouter"] = address(globalRouter);
            console2.log("GlobalRouter deployed:", address(globalRouter));
            _saveState(statePath);
        } else {
            console2.log("GlobalRouter already deployed:", deployed["GlobalRouter"]);
        }

        if (deployed["RouterV2"] == address(0)) {
            RouterV2 routerV2 = new RouterV2(deployed["PairFactoryUpgradeable"], wxpl);
            deployed["RouterV2"] = address(routerV2);
            console2.log("RouterV2 deployed:", address(routerV2));
            _saveState(statePath);
        } else {
            console2.log("RouterV2 already deployed:", deployed["RouterV2"]);
        }
    }

    function _deployGauge(string memory statePath) private {
        console2.log("\n--- Deploying Gauge System ---");

        if (deployed["GaugeFactoryV2"] == address(0)) {
            GaugeFactoryV2 gaugeFactory = new GaugeFactoryV2();
            deployed["GaugeFactoryV2"] = address(gaugeFactory);
            console2.log("GaugeFactoryV2 deployed:", address(gaugeFactory));
            _saveState(statePath);
        } else {
            console2.log("GaugeFactoryV2 already deployed:", deployed["GaugeFactoryV2"]);
        }

        if (deployed["PermissionsRegistry"] == address(0)) {
            PermissionsRegistry permissionsRegistry = new PermissionsRegistry();
            deployed["PermissionsRegistry"] = address(permissionsRegistry);
            console2.log("PermissionsRegistry deployed:", address(permissionsRegistry));
            _saveState(statePath);
        } else {
            console2.log("PermissionsRegistry already deployed:", deployed["PermissionsRegistry"]);
        }

        if (deployed["BribeFactoryV3"] == address(0)) {
            BribeFactoryV3 bribeFactory = new BribeFactoryV3();
            deployed["BribeFactoryV3"] = address(bribeFactory);
            console2.log("BribeFactoryV3 deployed:", address(bribeFactory));
            _saveState(statePath);
        } else {
            console2.log("BribeFactoryV3 already deployed:", deployed["BribeFactoryV3"]);
        }

        if (deployed["VoterV3"] == address(0)) {
            VoterV3 voterV3 = new VoterV3();
            deployed["VoterV3"] = address(voterV3);
            console2.log("VoterV3 deployed:", address(voterV3));
            _saveState(statePath);
        } else {
            console2.log("VoterV3 already deployed:", deployed["VoterV3"]);
        }

        if (deployed["RewardsDistributor"] == address(0)) {
            RewardsDistributor rewardsDistributor = new RewardsDistributor(deployed["VotingEscrow"]);
            deployed["RewardsDistributor"] = address(rewardsDistributor);
            console2.log("RewardsDistributor deployed:", address(rewardsDistributor));
            _saveState(statePath);
        } else {
            console2.log("RewardsDistributor already deployed:", deployed["RewardsDistributor"]);
        }

        if (deployed["MinterUpgradeable"] == address(0)) {
            MinterUpgradeable minter = new MinterUpgradeable();
            deployed["MinterUpgradeable"] = address(minter);
            console2.log("MinterUpgradeable deployed:", address(minter));
            _saveState(statePath);
        } else {
            console2.log("MinterUpgradeable already deployed:", deployed["MinterUpgradeable"]);
        }
    }

    function _initializeAll(address deployer) private {
        console2.log("\n--- Initializing All Contracts ---");

        // Initialize in dependency order
        _initializeVeArtProxy();
        _initializePairFactory();
        _initializeGaugeFactory();
        _initializeBribeFactory(deployer);
        _initializeVoter();
        _initializeMinter();

        console2.log("All contracts initialized successfully");
    }

    function _initializeVeArtProxy() private {
        address proxyAddr = deployed["VeArtProxyUpgradeable"];
        if (proxyAddr == address(0)) return;

        VeArtProxyUpgradeable veArtProxy = VeArtProxyUpgradeable(proxyAddr);
        if (veArtProxy.owner() == address(0)) {
            console2.log("Initializing VeArtProxyUpgradeable...");
            veArtProxy.initialize();
        } else {
            console2.log("VeArtProxyUpgradeable already initialized (owner:", veArtProxy.owner(), ")");
        }
    }

    function _initializePairFactory() private {
        address factoryAddr = deployed["PairFactoryUpgradeable"];
        if (factoryAddr == address(0)) return;

        PairFactoryUpgradeable pairFactory = PairFactoryUpgradeable(factoryAddr);
        if (pairFactory.owner() == address(0)) {
            console2.log("Initializing PairFactoryUpgradeable...");
            pairFactory.initialize();
        } else {
            console2.log("PairFactoryUpgradeable already initialized (owner:", pairFactory.owner(), ")");
        }
    }

    function _initializeGaugeFactory() private {
        address gaugeAddr = deployed["GaugeFactoryV2"];
        if (gaugeAddr == address(0)) return;

        GaugeFactoryV2 gaugeFactory = GaugeFactoryV2(gaugeAddr);
        if (gaugeFactory.owner() == address(0)) {
            console2.log("Initializing GaugeFactoryV2...");
            gaugeFactory.initialize(deployed["PermissionsRegistry"]);
        } else {
            console2.log("GaugeFactoryV2 already initialized (owner:", gaugeFactory.owner(), ")");
        }
    }

    function _initializeBribeFactory(address deployer) private {
        address bribeAddr = deployed["BribeFactoryV3"];
        if (bribeAddr == address(0)) return;

        BribeFactoryV3 bribeFactory = BribeFactoryV3(bribeAddr);
        if (bribeFactory.owner() == address(0)) {
            console2.log("Initializing BribeFactoryV3...");
            bribeFactory.initialize(deployer, deployed["PermissionsRegistry"]);
        } else {
            console2.log("BribeFactoryV3 already initialized (owner:", bribeFactory.owner(), ")");
        }
    }

    function _initializeVoter() private {
        address voterAddr = deployed["VoterV3"];
        if (voterAddr == address(0)) return;

        VoterV3 voterV3 = VoterV3(voterAddr);
        if (voterV3.owner() == address(0)) {
            console2.log("Initializing VoterV3...");
            voterV3.initialize(
                deployed["VotingEscrow"],
                deployed["PairFactoryUpgradeable"],
                deployed["GaugeFactoryV2"],
                deployed["BribeFactoryV3"]
            );
        } else {
            console2.log("VoterV3 already initialized (owner:", voterV3.owner(), ")");
        }
    }

    function _initializeMinter() private {
        address minterAddr = deployed["MinterUpgradeable"];
        if (minterAddr == address(0)) return;

        MinterUpgradeable minter = MinterUpgradeable(minterAddr);
        if (minter.owner() == address(0)) {
            console2.log("Initializing MinterUpgradeable...");
            minter.initialize(deployed["VoterV3"], deployed["VotingEscrow"], deployed["RewardsDistributor"]);
        } else {
            console2.log("MinterUpgradeable already initialized (owner:", minter.owner(), ")");
        }
    }

    function _loadState(string memory path) private {
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

    function _saveState(string memory path) private {
        string memory json = "{";

        json = string.concat(json, '"Lithos":"', vm.toString(deployed["Lithos"]), '",');
        json = string.concat(json, '"VeArtProxyUpgradeable":"', vm.toString(deployed["VeArtProxyUpgradeable"]), '",');
        json = string.concat(json, '"VotingEscrow":"', vm.toString(deployed["VotingEscrow"]), '",');
        json = string.concat(json, '"PairFactoryUpgradeable":"', vm.toString(deployed["PairFactoryUpgradeable"]), '",');
        json = string.concat(json, '"TradeHelper":"', vm.toString(deployed["TradeHelper"]), '",');
        json = string.concat(json, '"GlobalRouter":"', vm.toString(deployed["GlobalRouter"]), '",');
        json = string.concat(json, '"RouterV2":"', vm.toString(deployed["RouterV2"]), '",');
        json = string.concat(json, '"GaugeFactoryV2":"', vm.toString(deployed["GaugeFactoryV2"]), '",');
        json = string.concat(json, '"PermissionsRegistry":"', vm.toString(deployed["PermissionsRegistry"]), '",');
        json = string.concat(json, '"BribeFactoryV3":"', vm.toString(deployed["BribeFactoryV3"]), '",');
        json = string.concat(json, '"VoterV3":"', vm.toString(deployed["VoterV3"]), '",');
        json = string.concat(json, '"RewardsDistributor":"', vm.toString(deployed["RewardsDistributor"]), '",');
        json = string.concat(json, '"MinterUpgradeable":"', vm.toString(deployed["MinterUpgradeable"]), '"');

        json = string.concat(json, "}");
        vm.writeFile(path, json);
    }
}
