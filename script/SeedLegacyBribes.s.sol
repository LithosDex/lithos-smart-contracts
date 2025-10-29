// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBribe {
    function notifyRewardAmount(address token, uint256 amount) external;
}

contract SeedLegacyBribesScript is Script {
    struct BribeDeposit {
        address bribe;
        address token;
        uint256 amount;
        string label;
    }

    BribeDeposit[] public deposits;

    function run() external {
        string memory env = vm.envString("DEPLOY_ENV");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Seed legacy external bribes ===");
        console2.log("Environment:", env);
        console2.log("Executor:", deployer);

        _initDeposits();

        vm.startBroadcast(deployerKey);

        for (uint256 i = 0; i < deposits.length; i++) {
            BribeDeposit memory dep = deposits[i];

            console2.log("Bribe target:", dep.label);
            console2.log("  Bribe:", dep.bribe);
            console2.log("  Token:", dep.token);
            console2.log("  Amount:", dep.amount);

            // ensure allowance
            address token = dep.token;
            IERC20 erc20 = IERC20(token);

            uint256 currentAllowance = erc20.allowance(deployer, dep.bribe);
            if (currentAllowance < dep.amount) {
                console2.log("  Approving token spend");
                erc20.approve(dep.bribe, 0);
                erc20.approve(dep.bribe, dep.amount);
            }

            // transfer to bribe (notify pulls from allowance)
            console2.log("  Notifying reward amount");
            IBribe(dep.bribe).notifyRewardAmount(dep.token, dep.amount);
        }

        vm.stopBroadcast();
    }

    function _initDeposits() internal {
        // msUSD/USDT0 - external bribe
        deposits.push(
            BribeDeposit({
                bribe: 0x4Bd6b1b2988d997b31873DBdAf3bC76bDd35EA82,
                token: vm.parseAddress("0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb"), // USDT0
                amount: 5_988_000_000, // raw 6 decimals
                label: "msUSD/USDT0"
            })
        );

        // splUSD/plUSD - external bribe
        deposits.push(
            BribeDeposit({
                bribe: 0x7141aD2824e1767A3d25BB66842cA5A61D91D7AD,
                token: vm.parseAddress("0xf91c31299E998C5127Bc5F11e4a657FC0cF358CD"), // plUSD
                amount: 2_000_000_000_000_000_000_000, // 2000 plUSD (18d)
                label: "splUSD/plUSD"
            })
        );

        // USDT0/plUSD - external bribe (two tokens)
        deposits.push(
            BribeDeposit({
                bribe: 0x1D638bBc91Ae1C86823A25956b55d57434e3E23C,
                token: vm.parseAddress("0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb"), // USDT0
                amount: 1_000_000, // 1 USDT0 (6d)
                label: "USDT0/plUSD (USDT0 leg)"
            })
        );
        deposits.push(
            BribeDeposit({
                bribe: 0x1D638bBc91Ae1C86823A25956b55d57434e3E23C,
                token: vm.parseAddress("0xf91c31299E998C5127Bc5F11e4a657FC0cF358CD"), // plUSD
                amount: 1_000_000_000_000_000_000_000, // 1000 plUSD (18d)
                label: "USDT0/plUSD (plUSD leg)"
            })
        );
    }
}
