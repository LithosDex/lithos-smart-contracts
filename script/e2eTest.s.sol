// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

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

contract E2ETest is Script, Test {
    // Plasma mainnet beta addresses (using common token addresses as placeholders)
    address constant USDT = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb; // USDC (placeholder - update with actual Plasma USDC)
    address constant XPL = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB; // Using WETH instead
    address constant WETH = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB;

    // Test wallet
    address constant TEST_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

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
    uint256 public lpTokenBalance;
    uint256 public constant USDT_AMOUNT = 1000e6; // 1000 USDT (6 decimals)
    uint256 public constant XPL_AMOUNT = 1e18; // 1 WETH (18 decimals)
    uint256 public constant SWAP_AMOUNT = 100e6; // 100 USDT for swap

    function setUp() public {
        // Fork Plasma mainnet beta
        vm.createFork("https://rpc.plasma.to");

        // Step 0: Set time to Oct 1, 2024
        vm.warp(1727740800); // Oct 1, 2024 00:00:00 UTC
        console.log("Time set to Oct 1, 2024");
        console.log("Current timestamp:", block.timestamp);

        // Give test wallet some ETH
        vm.deal(TEST_WALLET, 100 ether);

        // vm.startBroadcast(TEST_WALLET);

        console.log("=== DEX E2E Test on Plasma Mainnet Beta Fork ===");
        console.log("Chain ID: 9745");
        console.log("Test wallet:", TEST_WALLET);
        console.log("USDT:", USDT);
        console.log("WETH:", XPL);
    }

    function run() public {
        setUp();

        step1_DeployDEXContracts();
        step2_CreatePools();
        step3_AddLiquidity();
        step4_RunSwaps();
        step5_createLocks();
        step6_createGaugesAndVote();
        step7_epochFlipAndDistribute();

        vm.stopBroadcast();
        console.log("All contracts deployed successfully!");

        logResults();
    }

    // Step 1: Deploy core contracts
    function step1_DeployDEXContracts() internal {
        console.log("\n=== Step 1: Deploy DEX Contracts ===");
        vm.startBroadcast(TEST_WALLET);

        // Deploy PairFactory first
        pairFactory = new PairFactory();
        console.log("PairFactory deployed:", address(pairFactory));

        // Set dibs address to prevent zero address transfer error
        pairFactory.setDibs(TEST_WALLET);
        console.log("Set dibs address to:", TEST_WALLET);

        // Stop and restart broadcast to manage gas better
        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Deploy RouterV2 with simple approach
        router = new RouterV2(address(pairFactory), WETH);
        console.log("RouterV2 deployed:", address(router));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Deploy TradeHelper
        tradeHelper = new TradeHelper(address(pairFactory));
        console.log("TradeHelper deployed:", address(tradeHelper));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Deploy GlobalRouter with simple approach
        globalRouter = new GlobalRouter(address(tradeHelper));
        console.log("GlobalRouter deployed:", address(globalRouter));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        //Deploy VeArtProxyUpgradable
        veArtProxyUpgradeable = new VeArtProxyUpgradeable();
        console.log(
            "VeArtProxyUpgradeable deployed:",
            address(veArtProxyUpgradeable)
        );

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        //Deploy Lithos token
        lithos = new Lithos();
        console.log("Lithos deployed:", address(lithos));

        // Call initial mint
        lithos.initialMint(TEST_WALLET);
        console.log("50M minted to:", address(TEST_WALLET));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        votingEscrow = new VotingEscrow(
            address(lithos),
            address(veArtProxyUpgradeable)
        );
        console.log("VotingEscrow deployed:", address(votingEscrow));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        permissionsRegistry = new PermissionsRegistry();
        console.log(
            "PermissionsRegistry deployed:",
            address(permissionsRegistry)
        );

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // set governance roles
        permissionsRegistry.setRoleFor(TEST_WALLET, "GOVERNANCE");
        permissionsRegistry.setRoleFor(TEST_WALLET, "VOTER_ADMIN");

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        gaugeFactory = new GaugeFactoryV2();
        console.log("GaugeFactoryV2 deployed:", address(gaugeFactory));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        gaugeFactory.initialize(address(permissionsRegistry));
        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        bribeFactory = new BribeFactoryV3();
        console.log("BribeFactoryV3 deployed:", address(bribeFactory));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        bribeFactory.initialize(TEST_WALLET, address(permissionsRegistry));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        voter = new VoterV3();
        console.log("VoterV3 deployed:", address(voter));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        voter.initialize(
            address(votingEscrow),
            address(pairFactory),
            address(gaugeFactory),
            address(bribeFactory)
        );
        console.log("VoterV3 initialized called");

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        rewardsDistributor = new RewardsDistributor(address(votingEscrow));
        console.log(
            "rewardsDistributor deployed:",
            address(rewardsDistributor)
        );

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        minterUpgradeable = new MinterUpgradeable();
        console.log("MinterUpgradeable deployed:", address(minterUpgradeable));

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);
        minterUpgradeable.initialize(
            address(voter),
            address(votingEscrow),
            address(rewardsDistributor)
        );

        console.log("minterUpgradeable initialize called");

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        minterUpgradeable._initialize(tokens, amounts, 0);

        console.log("minterUpgradeable _initialize called");

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        tokens[0] = address(lithos);
        voter._init(
            tokens,
            address(permissionsRegistry),
            address(minterUpgradeable)
        );

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Fix the voter address in BribeFactoryV3 - it was initialized with TEST_WALLET but should be the actual voter contract
        bribeFactory.setVoter(address(voter));
        console.log("Set voter address in BribeFactory to:", address(voter));

        // Set the voter address in VotingEscrow so it can call the voting function
        votingEscrow.setVoter(address(voter));
        console.log("Set voter address in VotingEscrow to:", address(voter));

        lithos.setMinter((address(minterUpgradeable)));
        console.log(
            "Set Minter address in Lithos to:",
            address(minterUpgradeable)
        );

        rewardsDistributor.setDepositor(address(minterUpgradeable));
        console.log(
            "Set Depositor address in rewardsDistributor to:",
            address(minterUpgradeable)
        );
    }

    // Step 2: Create pools
    function step2_CreatePools() internal {
        console.log("\n=== Step 2: Create USDT/WETH Pool ===");

        // Create USDT/XPL volatile pair
        pairAddress = pairFactory.createPair(
            address(USDT),
            address(XPL),
            false
        );
        console.log("USDT/WETH pair created:", pairAddress);

        // Verify pair creation
        bool isPair = pairFactory.isPair(pairAddress);
        console.log("Is valid pair:", isPair);
    }

    // Step 3: Add LP
    function step3_AddLiquidity() internal {
        console.log("\n=== Step 3: Add Liquidity ===");

        // Mint USDT and WETH to test wallet
        deal(USDT, TEST_WALLET, USDT_AMOUNT * 2); // Mint 2000 USDT
        deal(XPL, TEST_WALLET, XPL_AMOUNT * 2); // Mint 2 WETH

        console.log("USDT balance:", ERC20(USDT).balanceOf(TEST_WALLET));
        console.log("WETH balance:", ERC20(XPL).balanceOf(TEST_WALLET));

        // Approve RouterV2 to spend tokens
        ERC20(USDT).approve(address(router), USDT_AMOUNT);
        ERC20(XPL).approve(address(router), XPL_AMOUNT);
        console.log("Approved RouterV2 to spend tokens");

        // Add liquidity
        uint256 deadline = block.timestamp + 600; // 10 minutes
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                USDT, // tokenA
                XPL, // tokenB (WETH)
                false, // stable = false (volatile pair)
                USDT_AMOUNT, // amountADesired
                XPL_AMOUNT, // amountBDesired
                0, // amountAMin
                0, // amountBMin
                TEST_WALLET, // to
                deadline // deadline
            );

        lpTokenBalance = liquidity;
        console.log("Liquidity added successfully:");
        console.log("- USDT amount:", amountA);
        console.log("- WETH amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        // Verify LP balance
        uint256 pairBalance = ERC20(pairAddress).balanceOf(TEST_WALLET);
        console.log("LP token balance:", pairBalance);
    }

    // Step 4: Run swaps
    function step4_RunSwaps() internal {
        console.log("\n=== Step 4: Run Swaps ===");

        // Check balances before swap
        uint256 usdtBefore = ERC20(USDT).balanceOf(TEST_WALLET);
        uint256 wethBefore = ERC20(XPL).balanceOf(TEST_WALLET);
        console.log("Before swap - USDT:", usdtBefore, "WETH:", wethBefore);

        // Approve GlobalRouter to spend USDT for swap
        ERC20(USDT).approve(address(globalRouter), SWAP_AMOUNT);
        console.log("Approved GlobalRouter to spend USDT");

        // Create route for USDT -> WETH swap
        ITradeHelper.Route[] memory routes = new ITradeHelper.Route[](1);
        routes[0] = ITradeHelper.Route({from: USDT, to: XPL, stable: false});

        // Execute swap: 100 USDT -> WETH using GlobalRouter
        uint256 deadline = block.timestamp + 600;
        uint256[] memory amounts = globalRouter.swapExactTokensForTokens(
            SWAP_AMOUNT, // amountIn
            0, // amountOutMin
            routes, // routes
            TEST_WALLET, // to
            deadline, // deadline
            true // _type (true = V2 pools)
        );

        // Check balances after swap
        uint256 usdtAfter = ERC20(USDT).balanceOf(TEST_WALLET);
        uint256 wethAfter = ERC20(XPL).balanceOf(TEST_WALLET);
        console.log("After swap - USDT:", usdtAfter, "WETH:", wethAfter);

        // Calculate swap results
        uint256 usdtSpent = usdtBefore - usdtAfter;
        uint256 wethReceived = wethAfter - wethBefore;
        console.log("Swap results:");
        console.log("- USDT spent:", usdtSpent);
        console.log("- WETH received:", wethReceived);
        console.log("- Amounts from swap:", amounts[0], "->", amounts[1]);

        // Verify swap worked
        require(usdtSpent > 0, "No USDT spent");
        require(wethReceived > 0, "No WETH received");
        console.log("Swap executed successfully!");
    }

    function step5_createLocks() internal {
        console.log("\n=== Step 5: Create Voting Escrow Lock ===");

        // Set time to Oct 10, 2024 before creating locks
        vm.warp(1728518400); // Oct 10, 2024 00:00:00 UTC
        console.log("Time set to Oct 10, 2024");
        console.log("Current timestamp:", block.timestamp);

        uint256 lockAmount = 1000e18; // Lock 1000 LITH tokens
        uint256 lockDuration = 1 weeks; // 1 week duration

        // Check LITH balance before lock
        uint256 lithBalanceBefore = lithos.balanceOf(TEST_WALLET);
        console.log("LITH balance before lock:", lithBalanceBefore);
        require(
            lithBalanceBefore >= lockAmount,
            "Insufficient LITH balance for lock"
        );

        // Approve VotingEscrow contract to spend LITH tokens
        lithos.approve(address(votingEscrow), lockAmount);
        console.log("Approved VotingEscrow to spend LITH:", lockAmount);

        // Create lock for 1 week duration
        uint256 tokenId = votingEscrow.create_lock(lockAmount, lockDuration);
        console.log("Lock created successfully!");
        console.log("- Token ID (veNFT):", tokenId);
        console.log("- Amount locked:", lockAmount);
        console.log("- Duration:", lockDuration, "seconds (1 week)");

        // Check veNFT minted - verify ownership
        address nftOwner = votingEscrow.ownerOf(tokenId);
        console.log("veNFT owner:", nftOwner);
        require(nftOwner == TEST_WALLET, "veNFT not minted to test wallet");

        // Check veNFT balance of test wallet
        uint256 veNFTBalance = votingEscrow.balanceOf(TEST_WALLET);
        console.log("veNFT balance of test wallet:", veNFTBalance);

        // Check LITH balance after lock
        uint256 lithBalanceAfter = lithos.balanceOf(TEST_WALLET);
        console.log("LITH balance after lock:", lithBalanceAfter);
        console.log(
            "LITH tokens locked:",
            lithBalanceBefore - lithBalanceAfter
        );

        // Check voting power
        uint256 votingPower = votingEscrow.balanceOfNFT(tokenId);
        console.log("Voting power for NFT", tokenId, ":", votingPower);

        // Get lock details
        (int128 amount, uint256 end) = votingEscrow.locked(tokenId);
        console.log("Lock details:");
        console.log("- Locked amount:", uint256(uint128(amount)));
        console.log("- Lock end timestamp:", end);

        console.log("Lock creation completed successfully!");
    }

    function step6_createGaugesAndVote() internal {
        console.log("\n=== Step 6: Create Gauges and Vote ===");

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Whitelist tokens before creating gauge
        address[] memory pairTokens = new address[](2);
        pairTokens[0] = address(USDT);
        pairTokens[1] = address(WETH);

        voter.whitelist(pairTokens);

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        address owner = bribeFactory.owner();
        address voterBribe = bribeFactory.voter();
        console.log("Logging owner:", address(owner));
        console.log("Logging voterBribe:", address(voterBribe));

        // Create gauge for the USDT/WETH pair using VoterV3
        (
            address gaugeAddress,
            address internalBribe,
            address externalBribe
        ) = voter.createGauge(pairAddress, 0); // gaugeType 0 for standard gauge
        console.log("Gauge created for pair:", pairAddress);
        console.log("Gauge address:", gaugeAddress);
        console.log("Internal bribe address:", internalBribe);
        console.log("External bribe address:", externalBribe);

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Amount to deposit as bribe reward
        uint256 bribeAmount = 1000e18; // 1000 LITH tokens

        // Check LITH balance before bribe operations
        uint256 lithBalance = lithos.balanceOf(TEST_WALLET);
        console.log("LITH balance before bribe:", lithBalance);
        require(
            lithBalance >= bribeAmount,
            "Insufficient LITH balance for bribe"
        );

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Add LITH token as reward to the bribe contract using the correct function name
        (bool addRewardSuccess, ) = externalBribe.call(
            abi.encodeWithSignature("addRewardToken(address)", address(lithos))
        );
        require(addRewardSuccess, "Failed to add LITH as reward token");
        console.log("Added LITH as reward token to bribe contract");

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Approve bribe contract to spend LITH tokens
        lithos.approve(externalBribe, bribeAmount);
        console.log("Approved bribe contract to spend LITH:", bribeAmount);

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Notify reward amount to distribute the bribe
        (bool notifySuccess, ) = externalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(lithos),
                bribeAmount
            )
        );
        require(notifySuccess, "Failed to notify reward amount");
        console.log("Notified bribe contract of reward amount:", bribeAmount);

        // Check LITH balance after bribe operations
        uint256 lithBalanceAfter = lithos.balanceOf(TEST_WALLET);
        console.log("LITH balance after bribe operations:", lithBalanceAfter);
        console.log(
            "LITH tokens used for bribe:",
            lithBalance - lithBalanceAfter
        );

        // Now vote with our veNFT (assuming we have tokenId 1 from step5)
        uint256 tokenId = 1; // This should be the NFT from step5
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);

        pools[0] = pairAddress;
        weights[0] = 100; // 100% of voting power to this pool

        voter.vote(tokenId, pools, weights);
        console.log("Voted with NFT", tokenId, "for pool:", pairAddress);
        console.log("Vote weight:", weights[0]);

        console.log("Gauge creation and voting completed successfully!");
    }

    // Step 7: Epoch flip and emissions distribution
    function step7_epochFlipAndDistribute() internal {
        console.log("\n=== Step 7: Epoch Flip and Emissions Distribution ===");

        // We're currently at Oct 10, 2024 from step5
        // The minter was initialized on Oct 1, which sets active_period to that Friday
        // Oct 1, 2024 is a Tuesday, so Friday would be Oct 4, 2024
        // We need to be at least Oct 11, 2024 (Oct 4 + 7 days) to trigger the epoch
        // Since we're at Oct 10, we need to advance by at least 1 day

        // Roll time forward to Oct 11, 2024 to trigger epoch flip (1 day forward)
        vm.warp(block.timestamp + 86400); // Add 1 day
        console.log("Time rolled forward to Oct 11, 2024");
        console.log("Current timestamp:", block.timestamp);

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Check if we can update period
        console.log("\n--- Checking emission period ---");
        bool canUpdate = minterUpgradeable.check();

        if (canUpdate) {
            console.log("New emission period available!");

            // Get emissions info before distribution
            uint256 weeklyBefore = minterUpgradeable.weekly();
            uint256 circulatingBefore = minterUpgradeable.circulating_supply();
            uint256 activePeriodBefore = minterUpgradeable.active_period();

            console.log("Before distribution:");
            console.log("- Weekly emissions:", weeklyBefore / 1e18, "LITHOS");
            console.log(
                "- Circulating supply:",
                circulatingBefore / 1e18,
                "LITHOS"
            );
            console.log("- Active period:", activePeriodBefore);

            vm.stopBroadcast();
            vm.startBroadcast(TEST_WALLET);

            // Distribute emissions to all gauges (this calls update_period internally)
            console.log("\n--- Distributing emissions to gauges ---");
            voter.distributeAll();
            console.log("Emissions distributed successfully!");

            vm.stopBroadcast();
            vm.startBroadcast(TEST_WALLET);

            // Get emissions info after distribution
            uint256 weeklyAfter = minterUpgradeable.weekly();
            uint256 circulatingAfter = minterUpgradeable.circulating_supply();
            uint256 activePeriodAfter = minterUpgradeable.active_period();

            console.log("\nAfter distribution:");
            console.log("- Weekly emissions:", weeklyAfter / 1e18, "LITHOS");
            console.log(
                "- Circulating supply:",
                circulatingAfter / 1e18,
                "LITHOS"
            );
            console.log("- Active period:", activePeriodAfter);
            console.log("- Next period:", activePeriodAfter + 604800);
        } else {
            console.log("Not time for new emission period yet.");
            console.log(
                "Next period starts at:",
                minterUpgradeable.active_period() + 604800
            );
        }

        vm.stopBroadcast();
        vm.startBroadcast(TEST_WALLET);

        // Distribute fees for active gauges
        console.log("\n--- Distributing fees to gauges ---");

        // Get all pools and their gauges
        uint256 poolCount = voter.length();
        uint256 activeGaugeCount = 0;

        // First pass: count active gauges
        for (uint256 i = 0; i < poolCount; i++) {
            address pool = voter.pools(i);
            address gauge = voter.gauges(pool);
            if (gauge != address(0) && voter.isAlive(gauge)) {
                activeGaugeCount++;
            }
        }

        if (activeGaugeCount > 0) {
            // Create array of only active gauges
            address[] memory activeGauges = new address[](activeGaugeCount);
            uint256 j = 0;

            // Second pass: collect active gauges
            for (uint256 i = 0; i < poolCount; i++) {
                address pool = voter.pools(i);
                address gauge = voter.gauges(pool);
                if (gauge != address(0) && voter.isAlive(gauge)) {
                    activeGauges[j] = gauge;
                    console.log("  - Gauge:", gauge, "for pool:", pool);
                    j++;
                }
            }

            console.log(
                "Distributing fees for",
                activeGaugeCount,
                "active gauges..."
            );
            voter.distributeFees(activeGauges);
            console.log("Fees distributed successfully!");
        } else {
            console.log("No active gauges found.");
        }

        // Log summary
        console.log("\n--- Emission Distribution Summary ---");
        console.log(
            "Weekly emissions:",
            minterUpgradeable.weekly() / 1e18,
            "LITHOS"
        );
        console.log(
            "Current circulating supply:",
            minterUpgradeable.circulating_supply() / 1e18,
            "LITHOS"
        );
        console.log("Active period:", minterUpgradeable.active_period());
        console.log("Next period:", minterUpgradeable.active_period() + 604800);

        uint256 timeToNext = (minterUpgradeable.active_period() + 604800) >
            block.timestamp
            ? (minterUpgradeable.active_period() + 604800 - block.timestamp) /
                3600
            : 0;
        console.log("Hours until next period:", timeToNext);

        console.log("\nEpoch flip and distribution completed successfully!");
    }

    function logResults() internal view {
        console.log("\n=== FINAL TEST RESULTS ===");
        console.log(
            "Timestamp:",
            block.timestamp,
            "(Oct 11, 2024 after epoch flip)"
        );
        console.log("");
        console.log("Deployed Contracts:");
        console.log("- PairFactory:", address(pairFactory));
        console.log("- RouterV2:", address(router));
        console.log("- GlobalRouter:", address(globalRouter));
        console.log("- Lithos:", address(lithos));
        console.log("- VotingEscrow:", address(votingEscrow));
        console.log("- VoterV3:", address(voter));
        console.log("- MinterUpgradeable:", address(minterUpgradeable));
        console.log("- RewardsDistributor:", address(rewardsDistributor));
        console.log("");
        console.log("Pool Created:");
        console.log("- USDT/WETH Pair:", pairAddress);
        console.log("- LP Tokens Minted:", lpTokenBalance);
        console.log("");
        console.log("Gauge Information:");
        address gauge = voter.gauges(pairAddress);
        console.log("- Gauge for USDT/WETH:", gauge);
        console.log("- Gauge is alive:", voter.isAlive(gauge));
        console.log("");
        console.log("Emissions Data:");
        console.log(
            "- Weekly emissions:",
            minterUpgradeable.weekly() / 1e18,
            "LITHOS"
        );
        console.log(
            "- Circulating supply:",
            minterUpgradeable.circulating_supply() / 1e18,
            "LITHOS"
        );
        console.log("- Active period:", minterUpgradeable.active_period());
        console.log(
            "- Next period:",
            minterUpgradeable.active_period() + 604800
        );
        console.log("");
        console.log("Final Balances:");
        console.log("- USDT:", ERC20(USDT).balanceOf(TEST_WALLET));
        console.log("- WETH:", ERC20(XPL).balanceOf(TEST_WALLET));
        console.log("- LP Tokens:", ERC20(pairAddress).balanceOf(TEST_WALLET));
        console.log("- LITH:", lithos.balanceOf(TEST_WALLET));
        console.log("- veNFTs:", votingEscrow.balanceOf(TEST_WALLET));
        console.log("");
        console.log("All tests completed successfully!");
        console.log("=====================================");
    }
}

// Run with: forge script script/e2eTest.s.sol:E2ETest --fork-url https://rpc.plasma.to --gas-limit 30000000 -vvv
