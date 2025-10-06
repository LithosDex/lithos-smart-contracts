// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";
import {PairFactoryUpgradeable} from "../src/contracts/factories/PairFactoryUpgradeable.sol";
import {GaugeFactoryV2} from "../src/contracts/factories/GaugeFactoryV2.sol";
import {BribeFactoryV3} from "../src/contracts/factories/BribeFactoryV3.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";
import {RewardsDistributor} from "../src/contracts/RewardsDistributor.sol";
import {VotingEscrow} from "../src/contracts/VotingEscrow.sol";

import {TransferOwnershipMainnetScript, IProxyAdmin} from "../script/TransferOwnershipMainnet.s.sol";

contract TransferOwnershipMainnetForkTest is Test {
    using stdJson for string;

    address internal constant GOVERNANCE_MULTISIG = 0x21F1c2F66d30e22DaC1e2D509228407ccEff4dBC;
    address internal constant OPERATIONS_MULTISIG = 0xbEe8e366fEeB999993841a17C1DCaaad9d4618F7;
    address internal constant EMERGENCY_MULTISIG = 0x771675A54f18816aC9CD71b07d3d6e6Be7a9D799;
    address internal constant TREASURY_MULTISIG = 0xe98c1e28805A06F23B41cf6d356dFC7709DB9385;
    address internal constant FOUNDATION_ADDRESS = 0xD333A0106DEfC9468C53B95779281B20475d7735;
    address internal constant TIMELOCK = 0x9f7d46cE1EA22859814e51E9D3Fe07a665f21794;

    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    bytes internal constant ROLE_GOVERNANCE = "GOVERNANCE";
    bytes internal constant ROLE_VOTER_ADMIN = "VOTER_ADMIN";
    bytes internal constant ROLE_GAUGE_ADMIN = "GAUGE_ADMIN";
    bytes internal constant ROLE_BRIBE_ADMIN = "BRIBE_ADMIN";

    function testTransferOwnershipMainnetFork() external {
        string memory rpcUrl = "";
        if (vm.envExists("RPC_URL")) {
            rpcUrl = vm.envString("RPC_URL");
        }
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true);
        }

        vm.createSelectFork(rpcUrl);

        uint256 deployerKey = 0xA11CE;
        address deployer = vm.addr(deployerKey);

        string memory json = vm.readFile("deployments/mainnet/state.json");

        address permissionsRegistryAddr = json.readAddress(".PermissionsRegistry");
        address pairFactoryAddr = json.readAddress(".PairFactoryUpgradeable");
        address gaugeFactoryAddr = json.readAddress(".GaugeFactory");
        address bribeFactoryAddr = json.readAddress(".BribeFactory");
        address minterProxyAddr = json.readAddress(".Minter");
        address veArtProxyAddr = json.readAddress(".VeArtProxy");
        address votingEscrowAddr = json.readAddress(".VotingEscrow");
        address rewardsDistributorAddr = json.readAddress(".RewardsDistributor");

        // Ensure deployer currently controls all governance levers prior to running the script
        _preparePermissionsRegistry(permissionsRegistryAddr, deployer);
        _prepareFactories(pairFactoryAddr, gaugeFactoryAddr, bribeFactoryAddr, deployer);
        _prepareMinter(minterProxyAddr, deployer);
        _prepareRewardsDistributor(rewardsDistributorAddr, deployer);
        _prepareVotingEscrow(votingEscrowAddr, deployer);
        _prepareProxyAdmins(minterProxyAddr, veArtProxyAddr, deployer);

        // Provide environment variables consumed by the script
        vm.setEnv("PRIVATE_KEY", vm.toString(deployerKey));
        vm.setEnv("DEPLOY_ENV", "mainnet");
        vm.setEnv("GOVERNANCE_MULTISIG", vm.toString(GOVERNANCE_MULTISIG));
        vm.setEnv("OPERATIONS_MULTISIG", vm.toString(OPERATIONS_MULTISIG));
        vm.setEnv("EMERGENCY_COUNCIL", vm.toString(EMERGENCY_MULTISIG));
        vm.setEnv("TREASURY_MULTISIG", vm.toString(TREASURY_MULTISIG));
        vm.setEnv("FOUNDATION_ADDRESS", vm.toString(FOUNDATION_ADDRESS));

        // Execute the script under test
        TransferOwnershipMainnetScript ownershipScript = new TransferOwnershipMainnetScript();
        ownershipScript.run();

        // Validate post-conditions
        PermissionsRegistry registry = PermissionsRegistry(permissionsRegistryAddr);
        PairFactoryUpgradeable pairFactory = PairFactoryUpgradeable(pairFactoryAddr);
        GaugeFactoryV2 gaugeFactory = GaugeFactoryV2(gaugeFactoryAddr);
        BribeFactoryV3 bribeFactory = BribeFactoryV3(bribeFactoryAddr);
        MinterUpgradeable minter = MinterUpgradeable(minterProxyAddr);
        RewardsDistributor rewardsDistributor = RewardsDistributor(rewardsDistributorAddr);
        VotingEscrow votingEscrow = VotingEscrow(votingEscrowAddr);

        assertEq(registry.lithosMultisig(), GOVERNANCE_MULTISIG, "lithosMultisig not handed to governance");
        assertEq(registry.lithosTeamMultisig(), OPERATIONS_MULTISIG, "Team multisig not handed to operations");
        assertEq(registry.emergencyCouncil(), EMERGENCY_MULTISIG, "Emergency council not rotated");

        assertTrue(registry.hasRole(ROLE_GOVERNANCE, GOVERNANCE_MULTISIG), "Governance role missing");
        assertTrue(registry.hasRole(ROLE_VOTER_ADMIN, GOVERNANCE_MULTISIG), "Voter admin role missing");
        assertTrue(registry.hasRole(ROLE_GAUGE_ADMIN, GOVERNANCE_MULTISIG), "Gauge admin role missing");
        assertTrue(registry.hasRole(ROLE_BRIBE_ADMIN, GOVERNANCE_MULTISIG), "Bribe admin role missing");

        assertFalse(registry.hasRole(ROLE_GOVERNANCE, deployer), "Deployer still has governance role");
        assertFalse(registry.hasRole(ROLE_VOTER_ADMIN, deployer), "Deployer still has voter admin role");
        assertFalse(registry.hasRole(ROLE_GAUGE_ADMIN, deployer), "Deployer still has gauge admin role");
        assertFalse(registry.hasRole(ROLE_BRIBE_ADMIN, deployer), "Deployer still has bribe admin role");

        assertEq(pairFactory.owner(), GOVERNANCE_MULTISIG, "PairFactory ownership");
        assertEq(pairFactory.pendingFeeManager(), GOVERNANCE_MULTISIG, "PairFactory pending fee manager");

        assertEq(gaugeFactory.owner(), GOVERNANCE_MULTISIG, "GaugeFactory ownership");
        assertEq(bribeFactory.owner(), GOVERNANCE_MULTISIG, "BribeFactory ownership");

        assertEq(minter.team(), deployer, "Minter team should remain deployer until acceptance");
        assertEq(minter.pendingTeam(), OPERATIONS_MULTISIG, "Minter pending team not set");

        assertEq(rewardsDistributor.owner(), OPERATIONS_MULTISIG, "RewardsDistributor ownership");
        assertEq(votingEscrow.team(), OPERATIONS_MULTISIG, "VotingEscrow team handoff");

        _assertProxyAdmin(minterProxyAddr);
        _assertProxyAdmin(veArtProxyAddr);
    }

    // --- Internal helpers -----------------------------------------------------

    function _preparePermissionsRegistry(address registryAddr, address deployer) internal {
        PermissionsRegistry registry = PermissionsRegistry(registryAddr);

        address currentLithosMultisig = registry.lithosMultisig();
        if (currentLithosMultisig != deployer) {
            vm.prank(currentLithosMultisig);
            registry.setLithosMultisig(deployer);
        }

        address currentTeamMultisig = registry.lithosTeamMultisig();
        if (currentTeamMultisig != deployer) {
            vm.prank(currentTeamMultisig);
            registry.setLithosTeamMultisig(deployer);
        }

        address currentEmergencyCouncil = registry.emergencyCouncil();
        if (currentEmergencyCouncil != deployer) {
            vm.prank(currentEmergencyCouncil);
            registry.setEmergencyCouncil(deployer);
        }

        vm.startPrank(deployer);
        if (!registry.hasRole(ROLE_GOVERNANCE, deployer)) {
            registry.setRoleFor(deployer, "GOVERNANCE");
        }
        if (!registry.hasRole(ROLE_VOTER_ADMIN, deployer)) {
            registry.setRoleFor(deployer, "VOTER_ADMIN");
        }
        if (!registry.hasRole(ROLE_GAUGE_ADMIN, deployer)) {
            registry.setRoleFor(deployer, "GAUGE_ADMIN");
        }
        if (!registry.hasRole(ROLE_BRIBE_ADMIN, deployer)) {
            registry.setRoleFor(deployer, "BRIBE_ADMIN");
        }
        vm.stopPrank();
    }

    function _prepareFactories(
        address pairFactoryAddr,
        address gaugeFactoryAddr,
        address bribeFactoryAddr,
        address deployer
    ) internal {
        PairFactoryUpgradeable pairFactory = PairFactoryUpgradeable(pairFactoryAddr);
        address pairOwner = pairFactory.owner();
        if (pairOwner != deployer) {
            vm.prank(pairOwner);
            pairFactory.transferOwnership(deployer);
        }
        address feeManager = pairFactory.feeManager();
        if (feeManager != deployer) {
            vm.prank(feeManager);
            pairFactory.setFeeManager(deployer);
            vm.prank(deployer);
            pairFactory.acceptFeeManager();
        }

        GaugeFactoryV2 gaugeFactory = GaugeFactoryV2(gaugeFactoryAddr);
        address gaugeOwner = gaugeFactory.owner();
        if (gaugeOwner != deployer) {
            vm.prank(gaugeOwner);
            gaugeFactory.transferOwnership(deployer);
        }

        BribeFactoryV3 bribeFactory = BribeFactoryV3(bribeFactoryAddr);
        address bribeOwner = bribeFactory.owner();
        if (bribeOwner != deployer) {
            vm.prank(bribeOwner);
            bribeFactory.transferOwnership(deployer);
        }
    }

    function _prepareMinter(address minterProxyAddr, address deployer) internal {
        MinterUpgradeable minter = MinterUpgradeable(minterProxyAddr);

        address pending = minter.pendingTeam();
        if (pending != address(0)) {
            address current = minter.team();
            if (pending != current) {
                vm.prank(pending);
                minter.acceptTeam();
            }
        }

        address latestTeam = minter.team();
        if (latestTeam != deployer) {
            vm.prank(latestTeam);
            minter.setTeam(deployer);
            vm.prank(deployer);
            minter.acceptTeam();
        }
    }

    function _prepareRewardsDistributor(address rewardsDistributorAddr, address deployer) internal {
        RewardsDistributor distributor = RewardsDistributor(rewardsDistributorAddr);
        address owner = distributor.owner();
        if (owner != deployer) {
            vm.prank(owner);
            distributor.setOwner(deployer);
        }
    }

    function _prepareVotingEscrow(address votingEscrowAddr, address deployer) internal {
        VotingEscrow votingEscrow = VotingEscrow(votingEscrowAddr);
        address team = votingEscrow.team();
        if (team != deployer) {
            vm.prank(team);
            votingEscrow.setTeam(deployer);
        }
    }

    function _prepareProxyAdmins(address minterProxyAddr, address veArtProxyAddr, address deployer) internal {
        _ensureProxyAdminOwnedBy(minterProxyAddr, deployer);
        _ensureProxyAdminOwnedBy(veArtProxyAddr, deployer);
    }

    function _proxyAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
    }

    function _ensureProxyAdminOwnedBy(address proxy, address deployer) internal {
        address adminAddr = _proxyAdmin(proxy);
        if (adminAddr == address(0) || adminAddr.code.length == 0) {
            return;
        }

        IProxyAdmin admin = IProxyAdmin(adminAddr);
        address owner = admin.owner();
        if (owner != deployer) {
            vm.prank(owner);
            admin.transferOwnership(deployer);
        }
    }

    function _assertProxyAdmin(address proxy) internal view {
        address adminAddr = _proxyAdmin(proxy);
        assertTrue(adminAddr != address(0), "Proxy admin slot empty");

        if (adminAddr.code.length == 0) {
            assertEq(adminAddr, TIMELOCK, "Direct proxy admin address mismatch");
            return;
        }

        IProxyAdmin admin = IProxyAdmin(adminAddr);
        assertEq(admin.owner(), TIMELOCK, "ProxyAdmin ownership not timelock");
    }
}
