// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPairFactory} from "../src/contracts/interfaces/IPairFactory.sol";
import {IPair} from "../src/contracts/interfaces/IPair.sol";
import {IVoter} from "../src/contracts/interfaces/IVoter.sol";
import {RouterV2} from "../src/contracts/RouterV2.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";

contract InitialPairAndGaugeScript is Script {
    mapping(string => address) public deployed;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address wxpl = vm.envAddress("WXPL");

        // Load initial liquidity amounts
        uint256 initialLithosAmount = vm.envUint("INITIAL_LITHOS_AMOUNT");
        uint256 initialWxplAmount = vm.envUint("INITIAL_WXPL_AMOUNT");

        string memory statePath = string.concat(
            "deployments/",
            env,
            "/state.json"
        );

        require(
            vm.exists(statePath),
            "State file not found - run DeployAndInit first"
        );
        _loadState(statePath);

        console2.log("=== Phase 3: Initial Pair & Gauge Setup ===");
        console2.log("Environment:", env);
        console2.log("Deployer:", deployer);
        console2.log("Initial LITHOS amount:", initialLithosAmount);
        console2.log("Initial WXPL amount:", initialWxplAmount);

        vm.startBroadcast(deployerKey);

        // 1. Create LITHOS/WXPL pair
        address pair = _createPair();

        // 2. Add initial liquidity
        _addLiquidity(
            pair,
            initialLithosAmount,
            initialWxplAmount,
            wxpl,
            deployer
        );

        // 3. Whitelist the pair
        _whitelistPair(pair);

        // 4. Create gauge for the pair
        (
            address gauge,
            address internalBribe,
            address externalBribe
        ) = _createGauge(pair);

        vm.stopBroadcast();

        // Save new addresses to state
        deployed["LITHOS_WXPL_Pair"] = pair;
        deployed["LITHOS_WXPL_Gauge"] = gauge;
        deployed["LITHOS_WXPL_InternalBribe"] = internalBribe;
        deployed["LITHOS_WXPL_ExternalBribe"] = externalBribe;
        _saveState(statePath);

        console2.log("\n=== Initial Pair & Gauge Complete ===");
        console2.log("Pair:", pair);
        console2.log("Gauge:", gauge);
        console2.log("Internal Bribe:", internalBribe);
        console2.log("External Bribe:", externalBribe);
        console2.log(
            "\nRun 'forge script script/Ownership.s.sol' to transfer ownership"
        );
    }

    function _createPair() private returns (address pair) {
        IPairFactory pairFactory = IPairFactory(
            deployed["PairFactoryUpgradeable"]
        );
        address lithos = deployed["Lithos"];
        address wxpl = vm.envAddress("WXPL");

        // Check if pair already exists
        pair = pairFactory.getPair(lithos, wxpl, false);

        if (pair == address(0)) {
            // Create volatile pair (stable = false)
            pair = pairFactory.createPair(lithos, wxpl, false);
            console2.log("Created LITHOS/WXPL pair:", pair);
        } else {
            console2.log("LITHOS/WXPL pair already exists:", pair);
        }
    }

    function _addLiquidity(
        address pair,
        uint256 lithosAmount,
        uint256 wxplAmount,
        address wxpl,
        address to
    ) private {
        RouterV2 router = RouterV2(payable(deployed["RouterV2"]));
        address lithos = deployed["Lithos"];

        // Check current reserves
        (uint256 reserve0, uint256 reserve1, ) = IPair(pair).getReserves();

        if (reserve0 > 0 || reserve1 > 0) {
            console2.log("Pair already has liquidity");
            console2.log("Reserve0:", reserve0);
            console2.log("Reserve1:", reserve1);
            return;
        }

        // Approve tokens
        IERC20(lithos).approve(address(router), lithosAmount);
        IERC20(wxpl).approve(address(router), wxplAmount);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                lithos,
                wxpl,
                false, // stable = false
                lithosAmount,
                wxplAmount,
                0, // amountAMin
                0, // amountBMin
                to,
                block.timestamp + 1800
            );

        console2.log("Added liquidity:");
        console2.log("  LITHOS added:", amountA);
        console2.log("  WXPL added:", amountB);
        console2.log("  LP tokens received:", liquidity);
    }

    function _whitelistPair(address pair) private {
        VoterV3 voter = VoterV3(deployed["VoterV3"]);

        // Check if already whitelisted
        if (voter.isWhitelisted(pair)) {
            console2.log("Pair already whitelisted");
            return;
        }

        address[] memory tokens = new address[](1);
        tokens[0] = pair;
        voter.whitelist(tokens);
        console2.log("Whitelisted pair:", pair);
    }

    function _createGauge(
        address pair
    )
        private
        returns (address gauge, address internalBribe, address externalBribe)
    {
        VoterV3 voter = VoterV3(deployed["VoterV3"]);

        // Check if gauge already exists
        gauge = voter.gauges(pair);
        if (gauge != address(0)) {
            console2.log("Gauge already exists:", gauge);
            internalBribe = voter.internal_bribes(gauge);
            externalBribe = voter.external_bribes(gauge);
            return (gauge, internalBribe, externalBribe);
        }

        // Create gauge (type 0 for regular gauge)
        (gauge, internalBribe, externalBribe) = voter.createGauge(pair, 0);
        console2.log("Created gauge:", gauge);
        console2.log("  Internal bribe:", internalBribe);
        console2.log("  External bribe:", externalBribe);
    }

    function _loadState(string memory path) private {
        string memory json = vm.readFile(path);

        deployed["Lithos"] = vm.parseJsonAddress(json, ".Lithos");
        deployed["VeArtProxyUpgradeable"] = vm.parseJsonAddress(
            json,
            ".VeArtProxyUpgradeable"
        );
        deployed["VotingEscrow"] = vm.parseJsonAddress(json, ".VotingEscrow");
        deployed["PairFactoryUpgradeable"] = vm.parseJsonAddress(
            json,
            ".PairFactoryUpgradeable"
        );
        deployed["TradeHelper"] = vm.parseJsonAddress(json, ".TradeHelper");
        deployed["GlobalRouter"] = vm.parseJsonAddress(json, ".GlobalRouter");
        deployed["RouterV2"] = vm.parseJsonAddress(json, ".RouterV2");
        deployed["GaugeFactoryV2"] = vm.parseJsonAddress(
            json,
            ".GaugeFactoryV2"
        );
        deployed["PermissionsRegistry"] = vm.parseJsonAddress(
            json,
            ".PermissionsRegistry"
        );
        deployed["BribeFactoryV3"] = vm.parseJsonAddress(
            json,
            ".BribeFactoryV3"
        );
        deployed["VoterV3"] = vm.parseJsonAddress(json, ".VoterV3");
        deployed["RewardsDistributor"] = vm.parseJsonAddress(
            json,
            ".RewardsDistributor"
        );
        deployed["MinterUpgradeable"] = vm.parseJsonAddress(
            json,
            ".MinterUpgradeable"
        );

        // Load pair and gauge if they exist
        try vm.parseJsonAddress(json, ".LITHOS_WXPL_Pair") returns (
            address addr
        ) {
            deployed["LITHOS_WXPL_Pair"] = addr;
        } catch {}

        try vm.parseJsonAddress(json, ".LITHOS_WXPL_Gauge") returns (
            address addr
        ) {
            deployed["LITHOS_WXPL_Gauge"] = addr;
        } catch {}
    }

    function _saveState(string memory path) private {
        string memory json = "{";

        // Core contracts
        json = string.concat(
            json,
            '"Lithos":"',
            vm.toString(deployed["Lithos"]),
            '",'
        );
        json = string.concat(
            json,
            '"VeArtProxyUpgradeable":"',
            vm.toString(deployed["VeArtProxyUpgradeable"]),
            '",'
        );
        json = string.concat(
            json,
            '"VotingEscrow":"',
            vm.toString(deployed["VotingEscrow"]),
            '",'
        );
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
        json = string.concat(
            json,
            '"GaugeFactoryV2":"',
            vm.toString(deployed["GaugeFactoryV2"]),
            '",'
        );
        json = string.concat(
            json,
            '"PermissionsRegistry":"',
            vm.toString(deployed["PermissionsRegistry"]),
            '",'
        );
        json = string.concat(
            json,
            '"BribeFactoryV3":"',
            vm.toString(deployed["BribeFactoryV3"]),
            '",'
        );
        json = string.concat(
            json,
            '"VoterV3":"',
            vm.toString(deployed["VoterV3"]),
            '",'
        );
        json = string.concat(
            json,
            '"RewardsDistributor":"',
            vm.toString(deployed["RewardsDistributor"]),
            '",'
        );
        json = string.concat(
            json,
            '"MinterUpgradeable":"',
            vm.toString(deployed["MinterUpgradeable"]),
            '",'
        );

        // Pair and gauge
        json = string.concat(
            json,
            '"LITHOS_WXPL_Pair":"',
            vm.toString(deployed["LITHOS_WXPL_Pair"]),
            '",'
        );
        json = string.concat(
            json,
            '"LITHOS_WXPL_Gauge":"',
            vm.toString(deployed["LITHOS_WXPL_Gauge"]),
            '",'
        );
        json = string.concat(
            json,
            '"LITHOS_WXPL_InternalBribe":"',
            vm.toString(deployed["LITHOS_WXPL_InternalBribe"]),
            '",'
        );
        json = string.concat(
            json,
            '"LITHOS_WXPL_ExternalBribe":"',
            vm.toString(deployed["LITHOS_WXPL_ExternalBribe"]),
            '"'
        );

        json = string.concat(json, "}");
        vm.writeFile(path, json);
    }
}
