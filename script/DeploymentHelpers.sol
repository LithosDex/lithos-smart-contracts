// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Lithos} from "../src/contracts/Lithos.sol";
import {VeArtProxyUpgradeable} from "../src/contracts/VeArtProxyUpgradeable.sol";
import {VotingEscrow} from "../src/contracts/VotingEscrow.sol";
import {GaugeFactoryV2} from "../src/contracts/factories/GaugeFactoryV2.sol";
import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";
import {BribeFactoryV3} from "../src/contracts/factories/BribeFactoryV3.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {RewardsDistributor} from "../src/contracts/RewardsDistributor.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/// @title DeploymentHelpers
/// @notice Shared deployment library for ve(3,3) system with proxy support
/// @dev Used by both deployment scripts and tests to ensure consistency
library DeploymentHelpers {
    /// @notice Struct containing all deployed ve33 contract addresses
    struct Ve33Contracts {
        // Core token
        address lithos;
        // Proxies
        address veArtProxy;
        address minter;
        // Implementations
        address veArtProxyImpl;
        address minterImpl;
        // Non-upgradeable contracts
        address votingEscrow;
        address gaugeFactory;
        address permissionsRegistry;
        address bribeFactory;
        address voter;
        address rewardsDistributor;
        // Governance
        address proxyAdmin;
        address timelock;
    }

    /// @notice Deploy all ve33 contracts with proxy pattern
    /// @param deployer Address of the deployer (gets initial roles)
    /// @return contracts Struct containing all deployed contract addresses
    function deployVe33System(
        address deployer
    ) internal returns (Ve33Contracts memory contracts) {
        // 1. Deploy TimelockController (48 hour delay for governance actions)
        address[] memory proposers = new address[](1);
        proposers[0] = deployer; // Deployer can propose initially

        address[] memory executors = new address[](1);
        executors[0] = deployer; // Deployer can execute initially

        // Setting deployer as admin for initial flexibility
        // Should renounce after first distribution succeeds (Oct 16+)
        TimelockController timelock = new TimelockController(
            48 hours,
            proposers,
            executors,
            deployer
        );
        contracts.timelock = address(timelock);

        // 2. Deploy Lithos token (not upgradeable)
        Lithos lithos = new Lithos();
        contracts.lithos = address(lithos);

        // 3. Deploy VeArtProxy with TransparentUpgradeableProxy
        // NOTE: OZ v5 creates ProxyAdmin internally, deployer becomes its owner
        VeArtProxyUpgradeable veArtImpl = new VeArtProxyUpgradeable();
        contracts.veArtProxyImpl = address(veArtImpl);

        bytes memory veArtInitData = abi.encodeWithSelector(
            VeArtProxyUpgradeable.initialize.selector
        );
        TransparentUpgradeableProxy veArtProxy = new TransparentUpgradeableProxy(
            address(veArtImpl),
            deployer, // initialOwner of the ProxyAdmin created internally
            veArtInitData
        );
        contracts.veArtProxy = address(veArtProxy);

        // 5. Deploy VotingEscrow (not upgradeable)
        VotingEscrow votingEscrow = new VotingEscrow(
            address(lithos),
            contracts.veArtProxy
        );
        contracts.votingEscrow = address(votingEscrow);

        // 6. Deploy Gauge System (not upgradeable)
        GaugeFactoryV2 gaugeFactory = new GaugeFactoryV2();
        contracts.gaugeFactory = address(gaugeFactory);

        PermissionsRegistry permissionsRegistry = new PermissionsRegistry();
        contracts.permissionsRegistry = address(permissionsRegistry);

        BribeFactoryV3 bribeFactory = new BribeFactoryV3();
        contracts.bribeFactory = address(bribeFactory);

        VoterV3 voter = new VoterV3();
        contracts.voter = address(voter);

        RewardsDistributor rewardsDistributor = new RewardsDistributor(
            contracts.votingEscrow
        );
        contracts.rewardsDistributor = address(rewardsDistributor);

        // 7. Deploy Minter with TransparentUpgradeableProxy
        // NOTE: OZ v5 creates ProxyAdmin internally, deployer becomes its owner
        MinterUpgradeable minterImpl = new MinterUpgradeable();
        contracts.minterImpl = address(minterImpl);

        bytes memory minterInitData = abi.encodeWithSelector(
            MinterUpgradeable.initialize.selector,
            contracts.voter,
            contracts.votingEscrow,
            contracts.rewardsDistributor
        );
        TransparentUpgradeableProxy minterProxy = new TransparentUpgradeableProxy(
            address(minterImpl),
            deployer, // initialOwner of the ProxyAdmin created internally
            minterInitData
        );
        contracts.minter = address(minterProxy);

        // NOTE: In OZ v5, each proxy creates its own internal ProxyAdmin
        // The ProxyAdmin address is stored in the _admin slot but not easily accessible
        // For upgrades, use: address(uint160(uint256(vm.load(proxyAddress, ERC1967Utils.ADMIN_SLOT))))
        // Or store the ProxyAdmin address separately during deployment
        // For now, we leave this empty and handle it in upgrade scripts
        contracts.proxyAdmin = address(0);

        return contracts;
    }

    /// @notice Initialize non-proxy contracts and setup permissions
    /// @param contracts Struct containing deployed contract addresses
    /// @param pairFactory Address of the DEX PairFactory
    /// @param deployer Address of the deployer
    /// @param whitelistTokens Array of tokens to whitelist in Voter
    function initializeVe33(
        Ve33Contracts memory contracts,
        address pairFactory,
        address deployer,
        address[] memory whitelistTokens
    ) internal {
        // Initialize contracts that weren't initialized during proxy deployment
        GaugeFactoryV2(contracts.gaugeFactory).initialize(
            contracts.permissionsRegistry
        );
        BribeFactoryV3(contracts.bribeFactory).initialize(
            deployer,
            contracts.permissionsRegistry
        );

        // Initialize Voter
        VoterV3(contracts.voter).initialize(
            contracts.votingEscrow,
            pairFactory,
            contracts.gaugeFactory,
            contracts.bribeFactory
        );

        // Setup initial roles BEFORE calling _init (required for authorization)
        PermissionsRegistry registry = PermissionsRegistry(
            contracts.permissionsRegistry
        );
        registry.setRoleFor(deployer, "GOVERNANCE");
        registry.setRoleFor(deployer, "VOTER_ADMIN");

        // Initialize Voter with whitelist tokens and permissions
        // NOTE: _init will set permissionRegistry = _permissionsRegistry
        VoterV3(contracts.voter)._init(
            whitelistTokens,
            contracts.permissionsRegistry,
            contracts.minter
        );

        // Set up cross-references
        VotingEscrow(contracts.votingEscrow).setVoter(contracts.voter);
        BribeFactoryV3(contracts.bribeFactory).setVoter(contracts.voter);

        // Set Minter as depositor for RewardsDistributor
        RewardsDistributor(contracts.rewardsDistributor).setDepositor(
            contracts.minter
        );

        // Note: Minter and VeArtProxy already initialized via proxy deployment
    }

    /// @notice Activate minter with initial supply (Oct 9)
    /// @param lithos Address of Lithos token
    /// @param minter Address of Minter proxy
    /// @param deployer Address of deployer (receives initial LITH)
    function activateMinter(
        address lithos,
        address minter,
        address deployer
    ) internal {
        // 1. Mint initial 50M LITH to deployer
        Lithos(lithos).initialMint(deployer);

        // 2. Set minter role on Lithos token
        Lithos(lithos).setMinter(minter);

        // 3. Activate minter (no additional minting needed)
        address[] memory claimants = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        MinterUpgradeable(minter)._initialize(claimants, amounts, 0);
    }

    /// @notice Upgrade a contract (governance function)
    /// @param proxyAdmin Address of ProxyAdmin contract
    /// @param proxy Address of proxy to upgrade
    /// @param newImplementation Address of new implementation
    function upgradeContract(
        address proxyAdmin,
        address proxy,
        address newImplementation
    ) internal {
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(proxy),
            newImplementation,
            "" // No initialization call
        );
    }

    /// @notice Upgrade a contract with initialization call
    /// @param proxyAdmin Address of ProxyAdmin contract
    /// @param proxy Address of proxy to upgrade
    /// @param newImplementation Address of new implementation
    /// @param data Initialization call data
    function upgradeContractAndCall(
        address proxyAdmin,
        address proxy,
        address newImplementation,
        bytes memory data
    ) internal {
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(proxy),
            newImplementation,
            data
        );
    }
}
