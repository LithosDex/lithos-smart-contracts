// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console} from "forge-std/Script.sol";

interface IPairFactory {
    function allPairsLength() external view returns (uint);

    function allPairs(uint index) external view returns (address);
}

interface IPair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function stable() external view returns (bool);
}

interface IVoter {
    function createGauge(
        address _pool,
        uint256 _gaugeType
    ) external returns (address);

    function gauges(address _pool) external view returns (address);
}

contract CreateSingleGauge is Script {
    function run(uint256 pairIndex) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address pairFactory = vm.envAddress("PAIR_FACTORY");
        address voter = vm.envAddress("VOTER");

        vm.startBroadcast(deployerPrivateKey);

        IPairFactory factory = IPairFactory(pairFactory);
        IVoter voterContract = IVoter(voter);

        uint256 pairsLength = factory.allPairsLength();
        require(pairIndex < pairsLength, "Invalid pair index");

        address pair = factory.allPairs(pairIndex);

        // Check if gauge already exists
        address existingGauge = voterContract.gauges(pair);

        if (existingGauge == address(0)) {
            // Get pair details for logging
            IPair pairContract = IPair(pair);
            address token0 = pairContract.token0();
            address token1 = pairContract.token1();
            bool stable = pairContract.stable();

            console.log("Creating gauge for pair:", pair);
            console.log("  Token0:", token0);
            console.log("  Token1:", token1);
            console.log("  Stable:", stable);

            // Create gauge (type 0 for regular gauges)
            address gauge = voterContract.createGauge(pair, 0);

            console.log("  Gauge created:", gauge);
        } else {
            console.log("Gauge already exists for pair:", pair);
            console.log("  Existing gauge:", existingGauge);
        }

        vm.stopBroadcast();
    }
}
