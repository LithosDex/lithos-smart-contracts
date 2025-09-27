// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {PairFactory} from "../src/contracts/factories/PairFactory.sol";
import {RouterV2} from "../src/contracts/RouterV2.sol";
import {GlobalRouter, ITradeHelper} from "../src/contracts/GlobalRouter.sol";
import {TradeHelper} from "../src/contracts/TradeHelper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {VeArtProxyUpgradeable} from "../src/contracts/VeArtProxyUpgradeable.sol";
import {Lithos} from "../src/contracts/Lithos.sol";
import {VotingEscrow} from "../src/contracts/VotingEscrow.sol";
import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";
import {GaugeFactoryV2} from "../src/contracts/factories/GaugeFactoryV2.sol";
import {BribeFactoryV3} from "../src/contracts/factories/BribeFactoryV3.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";
import {MinterUpgradeable} from "../src/contracts/MinterUpgradeable.sol";
import {RewardsDistributor} from "../src/contracts/RewardsDistributor.sol";

contract E2EScript is Script {
    // Plasma mainnet addresses
    address constant USDT = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb; // USDT on Plasma mainnet
    address constant WETH = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB;
    address constant WXPL = 0x6100E367285b01F48D07953803A2d8dCA5D19873; // Wrapped XPL
    address constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34; // Ethena USDe

    // Test wallet - in production this should be the deployer wallet
    address constant DEPLOYER_WALLET =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // DEX Contract instances
    PairFactory public pairFactory;
    RouterV2 public router;
    GlobalRouter public globalRouter;
    TradeHelper public tradeHelper;
    VeArtProxyUpgradeable public veArtProxyUpgradeable;
    Lithos public lithos;
    VotingEscrow public votingEscrow;
    PermissionsRegistry public permissionsRegistry;
    GaugeFactoryV2 public gaugeFactory;
    BribeFactoryV3 public bribeFactory;
    VoterV3 public voter;
    RewardsDistributor public rewardsDistributor;
    MinterUpgradeable public minterUpgradeable;

    // Test data
    address public pairAddress;
    address public wxplLithPair;
    address public wxplUsdtPair;
    address public usdtUsdePair;
    uint256 public lpTokenBalance;
    uint256 public constant USDT_AMOUNT = 1000e6; // 1000 USDT (6 decimals)
    uint256 public constant WETH_AMOUNT = 1e18; // 1 WETH (18 decimals)
    uint256 public constant WXPL_AMOUNT = 10e18; // 10 WXPL (18 decimals)
    uint256 public constant USDE_AMOUNT = 1000e18; // 1000 USDe (18 decimals)
    uint256 public constant LITH_AMOUNT = 1000e18; // 1000 LITH for liquidity
    uint256 public constant SWAP_AMOUNT = 100e6; // 100 USDT for swap

    function setUp() public {
        // Setup is done in run() for scripts
    }

    function run() public {
        // Start broadcasting transactions
        vm.startBroadcast();

        console.log("=== DEX E2E Script on Plasma Mainnet Fork ===");
        console.log("Chain ID: 9745");
        console.log("Deployer wallet:", DEPLOYER_WALLET);
        console.log("USDT:", USDT);
        console.log("WETH:", WETH);

        // Oct 1, 2024: Deploy DEX contracts
        step1_DeployDEXContracts();
        step2_CreatePools();
        step3_AddLiquidity();
        step4_RunSwaps();

        // Fast forward to Oct 10, 2024: Launch LITH and voting
        // Note: Fast forwarding time only works in tests, not in scripts on real networks
        // In production, these would be separate deployments on different dates
        console.log(
            "\n=== Note: Time-based operations would occur on actual dates in production ==="
        );

        step6_DeployVotingContracts();
        step7_LaunchLITHAndVoting();
        step8_CreateLocks();
        step9_BribePools();
        step10_VoteForPools();

        console.log("\nAll contracts deployed successfully!");

        logResults();

        vm.stopBroadcast();
    }

    // Step 1: Deploy DEX contracts only
    function step1_DeployDEXContracts() internal {
        console.log("\n=== Step 1: Deploy DEX Contracts ===");

        // Deploy PairFactory first
        pairFactory = new PairFactory();
        console.log("PairFactory deployed:", address(pairFactory));

        // Set dibs address to prevent zero address transfer error
        pairFactory.setDibs(DEPLOYER_WALLET);
        console.log("Set dibs address to:", DEPLOYER_WALLET);

        // Deploy RouterV2
        router = new RouterV2(address(pairFactory), WETH);
        console.log("RouterV2 deployed:", address(router));

        // Deploy TradeHelper
        tradeHelper = new TradeHelper(address(pairFactory));
        console.log("TradeHelper deployed:", address(tradeHelper));

        // Deploy GlobalRouter
        globalRouter = new GlobalRouter(address(tradeHelper));
        console.log("GlobalRouter deployed:", address(globalRouter));

        console.log("DEX contracts deployed successfully");
    }

    // Step 2: Create pools
    function step2_CreatePools() internal {
        console.log("\n=== Step 2: Create Trading Pools ===");

        // Create USDT/WETH volatile pair
        pairAddress = pairFactory.createPair(
            address(USDT),
            address(WETH),
            false // volatile
        );
        console.log("USDT/WETH volatile pair created:", pairAddress);

        // Create WXPL/USDT volatile pair
        wxplUsdtPair = pairFactory.createPair(
            address(WXPL),
            address(USDT),
            false // volatile
        );
        console.log("WXPL/USDT volatile pair created:", wxplUsdtPair);

        // Create USDT/USDe stable pair
        usdtUsdePair = pairFactory.createPair(
            address(USDT),
            address(USDe),
            true // stable
        );
        console.log("USDT/USDe stable pair created:", usdtUsdePair);

        // Note: WXPL/LITH pair will be created after LITH is deployed in step 7
    }

    // Step 3: Add LP (simplified for script - assumes deployer has tokens)
    function step3_AddLiquidity() internal {
        console.log("\n=== Step 3: Add Liquidity ===");

        // In production, the deployer would need to have these tokens
        // For the script, we'll check balances and only add liquidity if possible

        uint256 usdtBalance = ERC20(USDT).balanceOf(DEPLOYER_WALLET);
        uint256 wethBalance = ERC20(WETH).balanceOf(DEPLOYER_WALLET);

        console.log("USDT balance:", usdtBalance);
        console.log("WETH balance:", wethBalance);

        if (usdtBalance >= USDT_AMOUNT && wethBalance >= WETH_AMOUNT) {
            // Approve RouterV2 to spend tokens
            ERC20(USDT).approve(address(router), USDT_AMOUNT);
            ERC20(WETH).approve(address(router), WETH_AMOUNT);
            console.log("Approved RouterV2 to spend tokens");

            // Add liquidity
            uint256 deadline = block.timestamp + 600; // 10 minutes
            (uint256 amountA, uint256 amountB, uint256 liquidity) = router
                .addLiquidity(
                    USDT, // tokenA
                    WETH, // tokenB
                    false, // stable = false (volatile pair)
                    USDT_AMOUNT, // amountADesired
                    WETH_AMOUNT, // amountBDesired
                    0, // amountAMin
                    0, // amountBMin
                    DEPLOYER_WALLET, // to
                    deadline // deadline
                );

            lpTokenBalance = liquidity;
            console.log("Liquidity added successfully:");
            console.log("- USDT amount:", amountA);
            console.log("- WETH amount:", amountB);
            console.log("- LP tokens minted:", liquidity);
        } else {
            console.log("Insufficient balance to add liquidity");
            console.log("Required: 1000 USDT and 1 WETH");
        }
    }

    // Step 4: Run swaps (simplified for script)
    function step4_RunSwaps() internal {
        console.log("\n=== Step 4: Run Swaps ===");

        uint256 usdtBalance = ERC20(USDT).balanceOf(DEPLOYER_WALLET);

        if (usdtBalance >= SWAP_AMOUNT) {
            // Check balances before swap
            uint256 usdtBefore = ERC20(USDT).balanceOf(DEPLOYER_WALLET);
            uint256 wethBefore = ERC20(WETH).balanceOf(DEPLOYER_WALLET);
            console.log("Before swap - USDT:", usdtBefore, "WETH:", wethBefore);

            // Approve GlobalRouter to spend USDT for swap
            ERC20(USDT).approve(address(globalRouter), SWAP_AMOUNT);
            console.log("Approved GlobalRouter to spend USDT");

            // Create route for USDT -> WETH swap
            ITradeHelper.Route[] memory routes = new ITradeHelper.Route[](1);
            routes[0] = ITradeHelper.Route({
                from: USDT,
                to: WETH,
                stable: false
            });

            // Execute swap: 100 USDT -> WETH using GlobalRouter
            uint256 deadline = block.timestamp + 600;
            uint256[] memory amounts = globalRouter.swapExactTokensForTokens(
                SWAP_AMOUNT, // amountIn
                0, // amountOutMin
                routes, // routes
                DEPLOYER_WALLET, // to
                deadline, // deadline
                true // _type (true = V2 pools)
            );

            // Check balances after swap
            uint256 usdtAfter = ERC20(USDT).balanceOf(DEPLOYER_WALLET);
            uint256 wethAfter = ERC20(WETH).balanceOf(DEPLOYER_WALLET);
            console.log("After swap - USDT:", usdtAfter, "WETH:", wethAfter);

            console.log("Swap executed successfully!");
        } else {
            console.log("Insufficient USDT balance to perform swap");
        }
    }

    // Step 6: Deploy voting and governance contracts
    function step6_DeployVotingContracts() internal {
        console.log("\n=== Step 6: Deploy Voting and Governance Contracts ===");

        // Deploy VeArtProxyUpgradeable
        veArtProxyUpgradeable = new VeArtProxyUpgradeable();
        console.log(
            "VeArtProxyUpgradeable deployed:",
            address(veArtProxyUpgradeable)
        );

        // Deploy Lithos token
        lithos = new Lithos();
        console.log("Lithos deployed:", address(lithos));

        // Deploy VotingEscrow
        votingEscrow = new VotingEscrow(
            address(lithos),
            address(veArtProxyUpgradeable)
        );
        console.log("VotingEscrow deployed:", address(votingEscrow));

        // Deploy PermissionsRegistry
        permissionsRegistry = new PermissionsRegistry();
        console.log(
            "PermissionsRegistry deployed:",
            address(permissionsRegistry)
        );

        // Deploy GaugeFactoryV2
        gaugeFactory = new GaugeFactoryV2();
        console.log("GaugeFactoryV2 deployed:", address(gaugeFactory));

        // Deploy BribeFactoryV3
        bribeFactory = new BribeFactoryV3();
        console.log("BribeFactoryV3 deployed:", address(bribeFactory));

        // Deploy VoterV3
        voter = new VoterV3();
        console.log("VoterV3 deployed:", address(voter));

        // Deploy RewardsDistributor
        rewardsDistributor = new RewardsDistributor(address(votingEscrow));
        console.log(
            "RewardsDistributor deployed:",
            address(rewardsDistributor)
        );

        // Deploy MinterUpgradeable
        minterUpgradeable = new MinterUpgradeable();
        console.log("MinterUpgradeable deployed:", address(minterUpgradeable));
    }

    // Step 7: Launch LITH and initialize voting
    function step7_LaunchLITHAndVoting() internal {
        console.log("\n=== Step 7: Launch LITH and Initialize Voting ===");

        // Initialize all contracts
        lithos.initialMint(DEPLOYER_WALLET);
        console.log("LITH initial mint: 50M tokens to DEPLOYER_WALLET");

        gaugeFactory.initialize(address(permissionsRegistry));
        bribeFactory.initialize(DEPLOYER_WALLET, address(permissionsRegistry));

        voter.initialize(
            address(votingEscrow),
            address(pairFactory),
            address(gaugeFactory),
            address(bribeFactory)
        );

        minterUpgradeable.initialize(
            DEPLOYER_WALLET, // will be updated later
            address(votingEscrow),
            address(rewardsDistributor)
        );

        // Set governance roles
        permissionsRegistry.setRoleFor(DEPLOYER_WALLET, "GOVERNANCE");
        permissionsRegistry.setRoleFor(DEPLOYER_WALLET, "VOTER_ADMIN");

        // Initialize minter with empty distribution
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        minterUpgradeable._initialize(tokens, amounts, 0);

        // Initialize voter
        tokens[0] = address(lithos);
        voter._init(
            tokens,
            address(permissionsRegistry),
            address(minterUpgradeable)
        );

        // Set up all the cross-references
        bribeFactory.setVoter(address(voter));
        votingEscrow.setVoter(address(voter));
        lithos.setMinter(address(minterUpgradeable));
        rewardsDistributor.setDepositor(address(minterUpgradeable));
        minterUpgradeable.setVoter(address(voter));

        console.log("LITH launched and voting system initialized!");

        // Now that LITH is deployed, create WXPL/LITH pair
        wxplLithPair = pairFactory.createPair(
            address(WXPL),
            address(lithos),
            false // volatile
        );
        console.log("WXPL/LITH volatile pair created:", wxplLithPair);
    }

    // Step 8: Create locks
    function step8_CreateLocks() internal {
        console.log("\n=== Step 8: Create Voting Escrow Lock ===");

        uint256 lockAmount = 1000e18; // Lock 1000 LITH tokens
        uint256 lockDuration = 1 weeks; // 1 week duration

        // Check LITH balance before lock
        uint256 lithBalanceBefore = lithos.balanceOf(DEPLOYER_WALLET);
        console.log("LITH balance before lock:", lithBalanceBefore);

        if (lithBalanceBefore >= lockAmount) {
            // Approve VotingEscrow contract to spend LITH tokens
            lithos.approve(address(votingEscrow), lockAmount);
            console.log("Approved VotingEscrow to spend LITH:", lockAmount);

            // Create lock for 1 week duration
            uint256 tokenId = votingEscrow.create_lock(
                lockAmount,
                lockDuration
            );
            console.log("Lock created successfully!");
            console.log("- Token ID (veNFT):", tokenId);
            console.log("- Amount locked:", lockAmount);
            console.log("- Duration:", lockDuration, "seconds (1 week)");

            // Check voting power
            uint256 votingPower = votingEscrow.balanceOfNFT(tokenId);
            console.log("Voting power for NFT", tokenId, ":", votingPower);

            console.log("Lock creation completed successfully!");
        } else {
            console.log("Insufficient LITH balance for lock");
        }
    }

    // Step 9: Bribe pools with different tokens
    function step9_BribePools() internal {
        console.log("\n=== Step 9: Bribe Pools with Different Tokens ===");

        // Create gauge first
        (
            address gaugeAddress,
            address internalBribe,
            address externalBribe
        ) = voter.createGauge(pairAddress, 0);
        console.log("Gauge created for pair:", pairAddress);
        console.log("Gauge address:", gaugeAddress);
        console.log("External bribe address:", externalBribe);

        // Bribe with LITH tokens
        uint256 lithBribeAmount = 1000e18;
        uint256 lithBalance = lithos.balanceOf(DEPLOYER_WALLET);

        if (lithBalance >= lithBribeAmount) {
            lithos.approve(externalBribe, lithBribeAmount);
            console.log("Approved LITH for bribing:", lithBribeAmount);

            // Add LITH as reward token
            (bool addLithSuccess, ) = externalBribe.call(
                abi.encodeWithSignature(
                    "addRewardToken(address)",
                    address(lithos)
                )
            );
            if (addLithSuccess) {
                console.log("Added LITH as reward token to bribe contract");

                // Notify LITH reward amount
                (bool notifyLithSuccess, ) = externalBribe.call(
                    abi.encodeWithSignature(
                        "notifyRewardAmount(address,uint256)",
                        address(lithos),
                        lithBribeAmount
                    )
                );
                if (notifyLithSuccess) {
                    console.log("Notified LITH bribe amount:", lithBribeAmount);
                } else {
                    console.log("Failed to notify LITH reward amount");
                }
            } else {
                console.log("Failed to add LITH as reward token");
            }
        } else {
            console.log("Insufficient LITH balance for bribing");
        }

        console.log("Pool bribing completed!");
    }

    // Step 10: Vote for pools
    function step10_VoteForPools() internal {
        console.log("\n=== Step 10: Vote for Pools ===");

        // Whitelist tokens before voting
        address[] memory pairTokens = new address[](2);
        pairTokens[0] = address(USDT);
        pairTokens[1] = address(WETH);
        voter.whitelist(pairTokens);

        // Check if we have a veNFT
        uint256 veNFTBalance = votingEscrow.balanceOf(DEPLOYER_WALLET);

        if (veNFTBalance > 0) {
            // Vote with our veNFT
            uint256 tokenId = 1; // First NFT
            address[] memory pools = new address[](1);
            uint256[] memory weights = new uint256[](1);

            pools[0] = pairAddress;
            weights[0] = 100; // 100% of voting power to this pool

            voter.vote(tokenId, pools, weights);
            console.log("Voted with NFT", tokenId, "for pool:", pairAddress);
            console.log("Vote weight:", weights[0]);

            console.log("Voting completed successfully!");
        } else {
            console.log("No veNFT to vote with");
        }
    }

    function logResults() internal view {
        console.log("\n=== DEPLOYMENT RESULTS ===");
        console.log("");
        console.log("=== DEX Contracts ===");
        console.log("- PairFactory:", address(pairFactory));
        console.log("- RouterV2:", address(router));
        console.log("- TradeHelper:", address(tradeHelper));
        console.log("- GlobalRouter:", address(globalRouter));
        console.log("");
        console.log("=== Voting & Governance ===");
        console.log("- Lithos:", address(lithos));
        console.log("- VotingEscrow:", address(votingEscrow));
        console.log("- PermissionsRegistry:", address(permissionsRegistry));
        console.log("- VoterV3:", address(voter));
        console.log("- MinterUpgradeable:", address(minterUpgradeable));
        console.log("- RewardsDistributor:", address(rewardsDistributor));
        console.log("- GaugeFactoryV2:", address(gaugeFactory));
        console.log("- BribeFactoryV3:", address(bribeFactory));
        console.log("");
        console.log("=== Pool & Trading Data ===");
        console.log("- USDT/WETH Pair:", pairAddress);
        console.log("- WXPL/USDT Pair:", wxplUsdtPair);
        console.log("- USDT/USDe Pair:", usdtUsdePair);
        console.log("- WXPL/LITH Pair:", wxplLithPair);
        console.log("");
        console.log("Complete E2E deployment completed successfully!");
        console.log("=====================================");
    }
}

// Run with: forge script script/e2eTest.s.sol:E2EScript --fork-url https://rpc.plasma.to --gas-limit 100000000 -vvv
