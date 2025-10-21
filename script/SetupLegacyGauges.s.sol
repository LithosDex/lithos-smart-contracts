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

contract SetupLegacyGaugesScript is Script {
    struct PairConfig {
        address pool;
        uint256 gaugeType;
        string label;
    }

    address[] internal tokensToWhitelist;
    PairConfig[] internal pairConfigs;
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
        require(address(voter) != address(0), "voter missing");

        _initTokens();
        _initPairs();

        console2.log("=== Whitelist & Gauge Setup ===");
        console2.log("Environment:", env);
        console2.log("Voter:", deployed["VoterV3"]);
        console2.log("Executor:", deployer);

        vm.startBroadcast(deployerKey);

        _whitelistTokens(voter);
        _createGauges(voter);

        vm.stopBroadcast();
    }

    function _whitelistTokens(IVoterLite voter) internal {
        address[] memory pending = new address[](tokensToWhitelist.length);
        uint256 count = 0;

        for (uint256 i = 0; i < tokensToWhitelist.length; i++) {
            address token = tokensToWhitelist[i];
            if (!voter.isWhitelisted(token)) {
                pending[count++] = token;
            }
        }

        if (count == 0) {
            console2.log("All tokens already whitelisted");
            return;
        }

        address[] memory trimmed = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            trimmed[i] = pending[i];
        }

        voter.whitelist(trimmed);
        console2.log("Whitelisted", count, "tokens");
    }

    function _createGauges(IVoterLite voter) internal {
        for (uint256 i = 0; i < pairConfigs.length; i++) {
            PairConfig memory cfg = pairConfigs[i];
            address existing = voter.gauges(cfg.pool);
            if (existing != address(0)) {
                console2.log("Gauge already exists for", cfg.label, existing);
                continue;
            }

            (
                address gauge,
                address internalBribe,
                address externalBribe
            ) = voter.createGauge(cfg.pool, cfg.gaugeType);
            console2.log("Created gauge for", cfg.label);
            console2.log("  Gauge:", gauge);
            console2.log("  Internal bribe:", internalBribe);
            console2.log("  External bribe:", externalBribe);
        }
    }

    function _loadState(string memory path) internal {
        string memory json = vm.readFile(path);
        deployed["VoterV3"] = vm.parseJsonAddress(json, ".Voter");
    }

    function _initPairs() internal {
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0xA0926801a2abC718822A60D8fA1Bc2A51fA09F1e"
                ),
                gaugeType: 0,
                label: "WXPL/USDT0 (volatile)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x01B968C1b663C3921da5Be3c99EE3C9B89A40B54"
                ),
                gaugeType: 0,
                label: "USDe/USDT0 (stable)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x7483eD877A1423F34DC5E46cf463eA4A0783D165"
                ),
                gaugeType: 0,
                label: "WETH/weETH (volatile)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0xaa1605FBd9C2CD3854337DB654471A45B2276c12"
                ),
                gaugeType: 0,
                label: "msUSD/USDT0 (stable)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x0d6F93EdFf269656dfac82E8992AFa9E719b137E"
                ),
                gaugeType: 0,
                label: "xUSD/tcUSDT0 (stable)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x7C735D31f0E77D430648c368b7B61196E13F9e23"
                ),
                gaugeType: 0,
                label: "USDT0/plUSD (stable)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x82862237F37E8495D88287d72A4C0073250487E0"
                ),
                gaugeType: 0,
                label: "WETH/weETH (stable)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x548064DF5e0C2d7F9076F75dE0a4C6C3d72A5aCC"
                ),
                gaugeType: 0,
                label: "USDai/USDT0 (stable)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x55078dEfe265a66451fD9Da109E7362A70b3fDaC"
                ),
                gaugeType: 0,
                label: "splUSD/plUSD (stable)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0x05F10BE187252B2858B9592714376787cE01Bb76"
                ),
                gaugeType: 0,
                label: "WXPL/trillions (volatile)"
            })
        );
        pairConfigs.push(
            PairConfig({
                pool: vm.parseAddress(
                    "0xB1F2724482D8DcCbDCc5480A70622F93d0A66ae8"
                ),
                gaugeType: 0,
                label: "xAUT0/USDT0 (volatile)"
            })
        );
    }

    function _initTokens() internal {
        tokensToWhitelist.push(
            vm.parseAddress("0x6100E367285B01F48D07953803A2D8DCA5D19873")
        ); // WXPL
        tokensToWhitelist.push(
            vm.parseAddress("0xB8CE59FC3717ADA4C02EADF9682A9E934F625EBB")
        ); // USDT0
        tokensToWhitelist.push(
            vm.parseAddress("0x5D3A1FF2B6BAB83B63CD9AD0787074081A52EF34")
        ); // USDe
        tokensToWhitelist.push(
            vm.parseAddress("0x9895D81BB462A195B4922ED7DE0E3ACD007C32CB")
        ); // WETH
        tokensToWhitelist.push(
            vm.parseAddress("0xA3D68B74BF0528FDD07263C60D6488749044914B")
        ); // weETH
        tokensToWhitelist.push(
            vm.parseAddress("0x29AD7FE4516909B9E498B5A65339E54791293234")
        ); // msUSD
        tokensToWhitelist.push(
            vm.parseAddress("0x6EAF19B2FC24552925DB245F9FF613157A7DBB4C")
        ); // xUSD
        tokensToWhitelist.push(
            vm.parseAddress("0xA9C251F8304B1B3FC2B9E8FCAE78D94EFF82AC66")
        ); // tcUSDT0
        tokensToWhitelist.push(
            vm.parseAddress("0xF91C31299E998C5127BC5F11E4A657FC0CF358CD")
        ); // plUSD
        tokensToWhitelist.push(
            vm.parseAddress("0x616185600989BF8339B58AC9E539D49536598343")
        ); // splUSD
        tokensToWhitelist.push(
            vm.parseAddress("0x0A1A1A107E45B7CED86833863F482BC5F4ED82EF")
        ); // USDai
        tokensToWhitelist.push(
            vm.parseAddress("0x92A01AB7317AC318B39B00EB6704BA56F0245D7A")
        ); // trillions
        tokensToWhitelist.push(
            vm.parseAddress("0x1B64B9025EEBb9A6239575DF9EA4B9AC46D4D193")
        ); // XAUt0
    }
}
