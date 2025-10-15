// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";

interface IVoterLite {
    function isWhitelisted(address token) external view returns (bool);

    function whitelist(address[] calldata tokens) external;

    function gauges(address pool) external view returns (address);

    function createGauge(
        address pool,
        uint256 gaugeType
    )
        external
        returns (address gauge, address internalBribe, address externalBribe);
}

interface IPairFactoryLite {
    function getPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address);
}

contract CreateLithGaugeScript is Script {
    address constant LITH = 0xAbB48792A3161E81B47cA084c0b7A22a50324A44;
    address constant WXPL = 0x6100E367285b01F48D07953803A2d8dCA5D19873;

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
        require(vm.exists(statePath), "state file missing");
        _loadState(statePath);

        IVoterLite voter = IVoterLite(deployed["VoterV3"]);
        IPairFactoryLite pairFactory = IPairFactoryLite(
            deployed["PairFactoryUpgradeable"]
        );

        require(address(voter) != address(0), "voter missing");
        require(address(pairFactory) != address(0), "pair factory missing");

        address pair = pairFactory.getPair(LITH, WXPL, false);
        require(pair != address(0), "LITH/WXPL pair missing");

        console2.log("=== Create LITH/WXPL gauge ===");
        console2.log("Environment:", env);
        console2.log("Executor:", deployer);
        console2.log("Pair:", pair);

        vm.startBroadcast(deployerKey);

        _ensureWhitelisted(voter, LITH, "LITH");
        _ensureWhitelisted(voter, WXPL, "WXPL");

        address existingGauge = voter.gauges(pair);
        if (existingGauge != address(0)) {
            console2.log("Gauge already exists:", existingGauge);
        } else {
            (
                address gauge,
                address internalBribe,
                address externalBribe
            ) = voter.createGauge(pair, 0);
            console2.log("Created gauge:", gauge);
            console2.log("  Internal bribe:", internalBribe);
            console2.log("  External bribe:", externalBribe);
        }

        vm.stopBroadcast();
    }

    function _ensureWhitelisted(
        IVoterLite voter,
        address token,
        string memory label
    ) internal {
        if (voter.isWhitelisted(token)) {
            console2.log(label, "already whitelisted");
            return;
        }

        address[] memory tokens = new address[](1);
        tokens[0] = token;
        voter.whitelist(tokens);
        console2.log("Whitelisted", label);
    }

    function _loadState(string memory path) internal {
        string memory json = vm.readFile(path);
        deployed["VoterV3"] = vm.parseJsonAddress(json, ".Voter");
        deployed["PairFactoryUpgradeable"] = vm.parseJsonAddress(
            json,
            ".PairFactoryUpgradeable"
        );
    }
}
