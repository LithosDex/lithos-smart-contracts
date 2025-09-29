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
import {GaugeV2} from "../src/contracts/GaugeV2.sol";
import {RewardsDistributor} from "../src/contracts/RewardsDistributor.sol";
import {Bribe} from "../src/contracts/Bribes.sol";

contract E2ETest is Script, Test {
    // Plasma mainnet beta addresses (using common token addresses as placeholders)
    address constant USDT = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb; // USDC (placeholder - update with actual Plasma USDC)
    address constant XPL = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB; // Using WETH instead
    address constant WETH = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB;

    // Test wallet
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant LP = address(2);
    address constant BRIBER = address(3);
    address constant VOTER = address(4);

    // DEX Contract instances
    // real mainnet deployments
    PairFactory public pairFactory = PairFactory(0xD209Cc008C3A26664B21138B425556D1c7e41d6D);
    RouterV2 public router = RouterV2(payable(0x0c746e15F626681Fab319a520dB8066D29Ab3730));
    GlobalRouter public globalRouter = GlobalRouter(0x34c62c36713bDEb2e387B3321f0de5DF8623ab82);
    TradeHelper public tradeHelper = TradeHelper(0x2A66F82F6ce9976179D191224A1E4aC8b50e68D1);

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
    address public gaugeAddress;
    address public internalBribeAddress;
    address public externalBribeAddress;
    uint256 public voterTokenId;
    uint256 public lpTokenBalance;
    uint256 public constant USDT_AMOUNT = 1000e6; // 1000 USDT (6 decimals)
    uint256 public constant XPL_AMOUNT = 1e18; // 1 WETH (18 decimals)
    uint256 public constant SWAP_AMOUNT = 100e6; // 100 USDT for swap

    function setUp() public {
        // Fork Plasma mainnet beta
        vm.createFork("https://rpc.plasma.to");

        // Step 0: Set time to Oct 1, 2025
        vm.warp(1759276800); // Oct 1, 2025 00:00:00 UTC
        console.log("Time set to Oct 1, 2025");
        console.log("Current timestamp:", block.timestamp);

        // Give test wallet some ETH
        vm.deal(DEPLOYER, 100 ether);
        vm.deal(LP, 100 ether);
        vm.deal(BRIBER, 100 ether);
        vm.deal(VOTER, 100 ether);

        // vm.startBroadcast(DEPLOYER);

        console.log("=== DEX E2E Test on Plasma Mainnet Beta Fork ===");
        console.log("Chain ID: 9745");
        console.log("Test wallet (DEPLOYER):", DEPLOYER);
        console.log("LP wallet:", LP);
        console.log("Briber wallet:", BRIBER);
        console.log("Voter wallet:", VOTER);
        console.log("USDT:", USDT);
        console.log("WETH:", XPL);
    }

    function run() public {
        setUp();

        // Oct 1, 2025: Deploy DEX contracts

        // use mainnet versions
        // step1_DeployDEXContracts();
        step2_CreatePools();
        step3_AddLiquidity();
        step4_RunSwaps();

        // Fast forward to Oct 9, 2025: Launch LITH and voting prep
        step5_FastForwardToLaunch();
        step6_DeployVotingContracts();
        step7_LaunchLITHAndVoting();
        step8_CreateLocks();
        step9_BribePools();
        step10_VoteForPools();

        // Fast forward to Oct 16, 2025: Epoch flip and distribution
        step11_FastForwardToDistribution();
        step12_EpochFlipAndDistribute();
        step13_ClaimRewards();
        console.log("All contracts deployed successfully!");

        logResults();
    }

    // Step 1: Deploy DEX contracts only (Oct 1, 2025)
    function step1_DeployDEXContracts() internal {
        console.log("\n=== Step 1: Deploy DEX Contracts (Oct 1, 2025) ===");
        vm.startBroadcast(DEPLOYER);

        // Deploy PairFactory first
        pairFactory = new PairFactory();
        console.log("PairFactory deployed:", address(pairFactory));

        // Set dibs address to prevent zero address transfer error
        pairFactory.setDibs(DEPLOYER);
        console.log("Set dibs address to:", DEPLOYER);

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy RouterV2
        router = new RouterV2(address(pairFactory), WETH);
        console.log("RouterV2 deployed:", address(router));

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy TradeHelper
        tradeHelper = new TradeHelper(address(pairFactory));
        console.log("TradeHelper deployed:", address(tradeHelper));

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy GlobalRouter
        globalRouter = new GlobalRouter(address(tradeHelper));
        console.log("GlobalRouter deployed:", address(globalRouter));

        console.log("DEX contracts deployed successfully on Oct 1, 2025");
        vm.stopBroadcast();
    }

    // Step 2: Create pools
    function step2_CreatePools() internal {
        vm.startBroadcast(DEPLOYER);
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
        vm.stopBroadcast();
    }

    // Step 3: Add LP
    function step3_AddLiquidity() internal {
        console.log("\n=== Step 3: Add Liquidity ===");

        // Mint USDT and WETH to test wallet
        deal(USDT, LP, USDT_AMOUNT * 2); // Mint 2000 USDT
        deal(XPL, LP, XPL_AMOUNT * 2); // Mint 2 WETH

        console.log("USDT balance:", ERC20(USDT).balanceOf(LP));
        console.log("WETH balance:", ERC20(XPL).balanceOf(LP));

        vm.startBroadcast(LP);
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
                LP, // to
                deadline // deadline
            );

        lpTokenBalance = liquidity;
        console.log("Liquidity added successfully:");
        console.log("- USDT amount:", amountA);
        console.log("- WETH amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        // Verify LP balance
        uint256 pairBalance = ERC20(pairAddress).balanceOf(LP);
        console.log("LP token balance:", pairBalance);
        vm.stopBroadcast();
    }

    // Step 4: Run swaps
    function step4_RunSwaps() internal {
        console.log("\n=== Step 4: Run Swaps ===");

        // Mint USDT and WETH to test wallet
        deal(USDT, DEPLOYER, USDT_AMOUNT); // Mint 1000 USDT
        deal(XPL, DEPLOYER, XPL_AMOUNT); // Mint 1 WETH

        // Check balances before swap
        uint256 usdtBefore = ERC20(USDT).balanceOf(DEPLOYER);
        uint256 wethBefore = ERC20(XPL).balanceOf(DEPLOYER);
        console.log("Before swap - USDT:", usdtBefore, "WETH:", wethBefore);

        vm.startBroadcast(DEPLOYER);
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
            DEPLOYER, // to
            deadline, // deadline
            true // _type (true = V2 pools)
        );

        // Check balances after swap
        uint256 usdtAfter = ERC20(USDT).balanceOf(DEPLOYER);
        uint256 wethAfter = ERC20(XPL).balanceOf(DEPLOYER);
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
        vm.stopBroadcast();
    }

    // Step 5: Fast forward to Oct 9, 2025
    function step5_FastForwardToLaunch() internal {
        console.log("\n=== Step 5: Fast Forward to Oct 9, 2025 ===");

        // Set time to Oct 9, 2025 to prepare veNFT + bribes ahead of the Oct 16 epoch flip
        vm.warp(1759968000); // Oct 9, 2025 00:00:00 UTC
        console.log("Time set to Oct 9, 2025 for LITH launch preparation");
        console.log("Current timestamp:", block.timestamp);
    }

    // Step 6: Deploy voting and governance contracts
    function step6_DeployVotingContracts() internal {
        console.log("\n=== Step 6: Deploy Voting and Governance Contracts ===");
        vm.startBroadcast(DEPLOYER);

        // Deploy VeArtProxyUpgradeable
        veArtProxyUpgradeable = new VeArtProxyUpgradeable();
        console.log(
            "VeArtProxyUpgradeable deployed:",
            address(veArtProxyUpgradeable)
        );

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy Lithos token
        lithos = new Lithos();
        console.log("Lithos deployed:", address(lithos));

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy VotingEscrow
        votingEscrow = new VotingEscrow(
            address(lithos),
            address(veArtProxyUpgradeable)
        );
        console.log("VotingEscrow deployed:", address(votingEscrow));

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy PermissionsRegistry
        permissionsRegistry = new PermissionsRegistry();
        console.log(
            "PermissionsRegistry deployed:",
            address(permissionsRegistry)
        );

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy GaugeFactoryV2
        gaugeFactory = new GaugeFactoryV2();
        console.log("GaugeFactoryV2 deployed:", address(gaugeFactory));

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy BribeFactoryV3
        bribeFactory = new BribeFactoryV3();
        console.log("BribeFactoryV3 deployed:", address(bribeFactory));

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy VoterV3
        voter = new VoterV3();
        console.log("VoterV3 deployed:", address(voter));

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy RewardsDistributor
        rewardsDistributor = new RewardsDistributor(address(votingEscrow));
        console.log(
            "RewardsDistributor deployed:",
            address(rewardsDistributor)
        );

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Deploy MinterUpgradeable
        minterUpgradeable = new MinterUpgradeable();
        console.log("MinterUpgradeable deployed:", address(minterUpgradeable));
    }

    // Step 7: Launch LITH and initialize voting
    function step7_LaunchLITHAndVoting() internal {
        console.log("\n=== Step 7: Launch LITH and Initialize Voting (Oct 9 prep) ===");
        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Initialize all contracts
        lithos.initialMint(DEPLOYER);
        console.log("LITH initial mint: 50M tokens to DEPLOYER");

        gaugeFactory.initialize(address(permissionsRegistry));
        bribeFactory.initialize(DEPLOYER, address(permissionsRegistry));

        voter.initialize(
            address(votingEscrow),
            address(pairFactory),
            address(gaugeFactory),
            address(bribeFactory)
        );

        minterUpgradeable.initialize(
            DEPLOYER, // will be updated later
            address(votingEscrow),
            address(rewardsDistributor)
        );

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Set governance roles
        permissionsRegistry.setRoleFor(DEPLOYER, "GOVERNANCE");
        permissionsRegistry.setRoleFor(DEPLOYER, "VOTER_ADMIN");

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

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

        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Set up all the cross-references
        bribeFactory.setVoter(address(voter));
        votingEscrow.setVoter(address(voter));
        lithos.setMinter(address(minterUpgradeable));
        rewardsDistributor.setDepositor(address(minterUpgradeable));
        minterUpgradeable.setVoter(address(voter));

        console.log("LITH launched and voting system initialized!");
        vm.stopBroadcast();
    }

    // Step 8: Create locks
    function step8_CreateLocks() internal {
        console.log("\n=== Step 8: Create Voting Escrow Lock ===");
        vm.startBroadcast(DEPLOYER);
        // Transfer some LITH to test wallet for locking
        uint256 transferAmount = 5000e18; // 5000 LITH tokens
        lithos.transfer(VOTER, transferAmount);
        console.log("Transferred", transferAmount, "LITH to VOTER for locking");
        vm.stopBroadcast();
        vm.startBroadcast(VOTER);

        uint256 lockAmount = 1000e18; // Lock 1000 LITH tokens
        uint256 lockDuration = 1 weeks; // 1 week duration

        // Check LITH balance before lock
        uint256 lithBalanceBefore = lithos.balanceOf(VOTER);
        console.log("LITH balance before lock:", lithBalanceBefore);
        require(
            lithBalanceBefore >= lockAmount,
            "Insufficient LITH balance for lock"
        );

        // Approve VotingEscrow contract to spend LITH tokens
        lithos.approve(address(votingEscrow), lockAmount);
        console.log("Approved VotingEscrow to spend LITH:", lockAmount);

        // Create lock for 1 week duration
        voterTokenId = votingEscrow.create_lock(lockAmount, lockDuration);
        console.log("Lock created successfully!");
        console.log("- Token ID (veNFT):", voterTokenId);
        console.log("- Amount locked:", lockAmount);
        console.log("- Duration:", lockDuration, "seconds (1 week)");

        // Check veNFT minted - verify ownership
        address nftOwner = votingEscrow.ownerOf(voterTokenId);
        console.log("veNFT owner:", nftOwner);
        require(nftOwner == VOTER, "veNFT not minted to test wallet");

        // Check veNFT balance of test wallet
        uint256 veNFTBalance = votingEscrow.balanceOf(VOTER);
        console.log("veNFT balance of test wallet:", veNFTBalance);

        // Check LITH balance after lock
        uint256 lithBalanceAfter = lithos.balanceOf(VOTER);
        console.log("LITH balance after lock:", lithBalanceAfter);
        console.log(
            "LITH tokens locked:",
            lithBalanceBefore - lithBalanceAfter
        );

        // Check voting power
        uint256 votingPower = votingEscrow.balanceOfNFT(voterTokenId);
        console.log("Voting power for NFT", voterTokenId, ":", votingPower);

        // Get lock details
        (int128 amount, uint256 end) = votingEscrow.locked(voterTokenId);
        console.log("Lock details:");
        console.log("- Locked amount:", uint256(uint128(amount)));
        console.log("- Lock end timestamp:", end);

        console.log("Lock creation completed successfully!");
        vm.stopBroadcast();
    }

    // Step 9: Bribe pools with different tokens
    function step9_BribePools() internal {
        console.log("\n=== Step 9: Bribe Pools with Different Tokens ===");
        vm.startBroadcast(DEPLOYER);

        // NOTE: We execute this step on Oct 9, 2025. Bribes are queued for the next epoch
        // (Oct 16, 2025). Claiming in step13 then advances to Oct 23 so only rewards from
        // this Oct 9 notification become claimable at the Oct 16 flip.

        // Create gauge first
        (
            address createdGauge,
            address createdInternalBribe,
            address createdExternalBribe
        ) = voter.createGauge(pairAddress, 0);

        gaugeAddress = createdGauge;
        internalBribeAddress = createdInternalBribe;
        externalBribeAddress = createdExternalBribe;

        console.log("Gauge created for pair:", pairAddress);
        console.log("Gauge address:", gaugeAddress);
        console.log("Internal bribe address:", internalBribeAddress);
        console.log("External bribe address:", externalBribeAddress);

        // Add LITH as reward token
        (bool addLithSuccess, ) = externalBribeAddress.call(
            abi.encodeWithSignature("addRewardToken(address)", address(lithos))
        );
        require(addLithSuccess, "Failed to add LITH as reward token");
        console.log("Added LITH as reward token to bribe contract");

        // Add USDT as reward token
        (bool addUsdtSuccess, ) = externalBribeAddress.call(
            abi.encodeWithSignature("addRewardToken(address)", USDT)
        );
        require(addUsdtSuccess, "Failed to add USDT as reward token");
        console.log("Added USDT as reward token to bribe contract");

        // Mint some LITH to BRIBER for bribing
        uint256 lithBribeAmount = 1000e18; // 1000 LITH
        lithos.transfer(BRIBER, lithBribeAmount);
        console.log("Transferred", lithBribeAmount, "LITH to BRIBER for bribing");

        vm.stopBroadcast();

        vm.startBroadcast(LP);
        ERC20(pairAddress).approve(gaugeAddress, lpTokenBalance);
        GaugeV2(gaugeAddress).deposit(lpTokenBalance);
        console.log("Deposited tokens into gauge: ", lpTokenBalance);
        vm.stopBroadcast();

        vm.startBroadcast(BRIBER);

        // Bribe with LITH tokens
        lithos.approve(externalBribeAddress, lithBribeAmount);
        console.log("Approved LITH for bribing:", lithBribeAmount);

        // Notify LITH reward amount
        (bool notifyLithSuccess, ) = externalBribeAddress.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(lithos),
                lithBribeAmount
            )
        );
        require(notifyLithSuccess, "Failed to notify LITH reward amount");
        console.log("Notified LITH bribe amount:", lithBribeAmount);

        vm.stopBroadcast();
        vm.startBroadcast(BRIBER);

        // Also bribe with USDT (different token)
        uint256 usdtBribeAmount = 500e6; // 500 USDT

        // Get some USDT for bribing
        deal(USDT, BRIBER, usdtBribeAmount);
        ERC20(USDT).approve(externalBribeAddress, usdtBribeAmount);
        console.log("Approved USDT for bribing:", usdtBribeAmount);

        // Notify USDT reward amount
        (bool notifyUsdtSuccess, ) = externalBribeAddress.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                USDT,
                usdtBribeAmount
            )
        );
        require(notifyUsdtSuccess, "Failed to notify USDT reward amount");
        console.log("Notified USDT bribe amount:", usdtBribeAmount);

        console.log("Pool bribing completed successfully!");
    }

    // Step 10: Vote for pools
    function step10_VoteForPools() internal {
        console.log("\n=== Step 10: Vote for Pools ===");
        vm.stopBroadcast();
        vm.startBroadcast(DEPLOYER);

        // Whitelist tokens before voting
        address[] memory pairTokens = new address[](2);
        pairTokens[0] = address(USDT);
        pairTokens[1] = address(WETH);
        voter.whitelist(pairTokens);

        vm.stopBroadcast();
        vm.startBroadcast(VOTER);

        // Vote with the veNFT created in step 8
        require(voterTokenId != 0, "veNFT not ready for voting");
        uint256 tokenId = voterTokenId;
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);

        pools[0] = pairAddress;
        weights[0] = 100; // 100% of voting power to this pool

        voter.vote(tokenId, pools, weights);
        console.log("Voted with NFT", tokenId, "for pool:", pairAddress);
        console.log("Vote weight:", weights[0]);

        console.log("Voting completed successfully!");
        vm.stopBroadcast();
    }

    // Step 11: Fast forward to Oct 16, 2025
    function step11_FastForwardToDistribution() internal {
        console.log("\n=== Step 11: Fast Forward to Oct 16, 2025 ===");

        // Set time to Oct 16, 2025 for epoch flip
        vm.warp(1760572800); // Oct 16, 2025 00:00:00 UTC
        console.log("Time set to Oct 16, 2025 for epoch flip and distribution");
        console.log("Current timestamp:", block.timestamp);
    }

    // Step 12: Epoch flip and distribution
    function step12_EpochFlipAndDistribute() internal {
        console.log("\n=== Step 12: Epoch Flip and Emissions Distribution ===");
        vm.startBroadcast(DEPLOYER);

        // Check if we can update period
        console.log("Checking emission period...");
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
            vm.startBroadcast(DEPLOYER);

            // Distribute emissions to all gauges (this calls update_period internally)
            console.log("Distributing emissions to gauges...");
            voter.distributeAll();
            console.log("Emissions distributed successfully!");

            vm.stopBroadcast();
            vm.startBroadcast(DEPLOYER);

            // Get emissions info after distribution
            uint256 weeklyAfter = minterUpgradeable.weekly();
            uint256 circulatingAfter = minterUpgradeable.circulating_supply();
            uint256 activePeriodAfter = minterUpgradeable.active_period();

            console.log("After distribution:");
            console.log("- Weekly emissions:", weeklyAfter / 1e18, "LITHOS");
            console.log(
                "- Circulating supply:",
                circulatingAfter / 1e18,
                "LITHOS"
            );
            console.log("- Active period:", activePeriodAfter);
            console.log("- Next period:", activePeriodAfter + 604800);

            // Distribute fees for active gauges
            console.log("Distributing fees to gauges...");
            uint256 poolCount = voter.length();
            address[] memory activeGauges = new address[](poolCount);
            uint256 activeCount = 0;

            // Collect active gauges
            for (uint256 i = 0; i < poolCount; i++) {
                address pool = voter.pools(i);
                address gauge = voter.gauges(pool);
                if (gauge != address(0) && voter.isAlive(gauge)) {
                    activeGauges[activeCount] = gauge;
                    activeCount++;
                    console.log("  - Active gauge:", gauge, "for pool:", pool);
                }
            }

            if (activeCount > 0) {
                // Create correctly sized array
                address[] memory finalGauges = new address[](activeCount);
                for (uint256 i = 0; i < activeCount; i++) {
                    finalGauges[i] = activeGauges[i];
                }

                voter.distributeFees(finalGauges);
                console.log(
                    "Fees distributed to",
                    activeCount,
                    "active gauges"
                );
            }
        } else {
            console.log("Not time for new emission period yet.");
            console.log(
                "Next period starts at:",
                minterUpgradeable.active_period() + 604800
            );
        }

        console.log("Epoch flip and distribution completed successfully!");
        vm.stopBroadcast();
    }



    function step13_ClaimRewards() internal {
        console.log("\n=== Step 13: Claim Rewards ===");

        require(gaugeAddress != address(0), "Gauge not configured");
        require(externalBribeAddress != address(0), "Bribes not configured");
        require(voterTokenId != 0, "veNFT not created");

        // Allow emissions and bribes to accrue after distribution
        // Rewards notified on Oct 9 unlock at the Oct 16 epoch boundary. We advance to the
        // first full epoch after distribution (>= Oct 23) so the bribes we queued become claimable.
        uint256 nextEpochStart = minterUpgradeable.active_period() + 604800;
        if (block.timestamp <= nextEpochStart) {
            vm.warp(nextEpochStart + 1 hours);
            console.log("Advanced time to next epoch (+1h) for reward accrual");
        } else {
            vm.warp(block.timestamp + 1 hours);
            console.log("Already past next epoch, advanced an extra hour");
        }

        console.log("\n--- Claiming Gauge Emissions (LP Rewards) ---");
        vm.startBroadcast(LP);
        uint256 pendingEmissions = GaugeV2(gaugeAddress).earned(LP);
        console.log("Pending LITH emissions for LP:", pendingEmissions);
        require(pendingEmissions > 0, "No gauge emissions available");

        uint256 lithBefore = lithos.balanceOf(LP);
        GaugeV2(gaugeAddress).getReward();
        uint256 lithAfter = lithos.balanceOf(LP);
        require(lithAfter > lithBefore, "Gauge emission claim failed");
        uint256 lithClaimed = lithAfter - lithBefore;
        console.log("LITH claimed from gauge:", lithClaimed);

        uint256 stakedLp = GaugeV2(gaugeAddress).balanceOf(LP);
        console.log("LP tokens still staked:", stakedLp);
        vm.stopBroadcast();

        console.log("\n--- Claiming External Bribes (Voter Rewards) ---");
        vm.startBroadcast(VOTER);
        address[] memory externalTokens = new address[](2);
        externalTokens[0] = address(lithos);
        externalTokens[1] = USDT;
        uint256 voterLithBefore = lithos.balanceOf(VOTER);
        uint256 voterUsdtBefore = ERC20(USDT).balanceOf(VOTER);
        Bribe(externalBribeAddress).getReward(voterTokenId, externalTokens);
        uint256 voterLithAfter = lithos.balanceOf(VOTER);
        uint256 voterUsdtAfter = ERC20(USDT).balanceOf(VOTER);

        uint256 externalLithClaimed = voterLithAfter > voterLithBefore
            ? voterLithAfter - voterLithBefore
            : 0;
        uint256 externalUsdtClaimed = voterUsdtAfter > voterUsdtBefore
            ? voterUsdtAfter - voterUsdtBefore
            : 0;

        require(
            externalLithClaimed > 0 || externalUsdtClaimed > 0,
            "No external bribes claimed"
        );
        console.log("External LITH bribes claimed:", externalLithClaimed);
        console.log("External USDT bribes claimed:", externalUsdtClaimed);

        console.log("\n--- Claiming Trading Fees (Internal Bribe) ---");
        address[] memory feeTokens = new address[](2);
        feeTokens[0] = USDT;
        feeTokens[1] = XPL;
        uint256 voterUsdtBeforeFees = ERC20(USDT).balanceOf(VOTER);
        uint256 voterXplBeforeFees = ERC20(XPL).balanceOf(VOTER);
        Bribe(internalBribeAddress).getReward(voterTokenId, feeTokens);
        uint256 voterUsdtAfterFees = ERC20(USDT).balanceOf(VOTER);
        uint256 voterXplAfterFees = ERC20(XPL).balanceOf(VOTER);

        uint256 internalUsdtClaimed = voterUsdtAfterFees > voterUsdtBeforeFees
            ? voterUsdtAfterFees - voterUsdtBeforeFees
            : 0;
        uint256 internalXplClaimed = voterXplAfterFees > voterXplBeforeFees
            ? voterXplAfterFees - voterXplBeforeFees
            : 0;

        require(
            internalUsdtClaimed > 0 || internalXplClaimed > 0,
            "No trading fees claimed"
        );
        console.log("Internal USDT fees claimed:", internalUsdtClaimed);
        console.log("Internal WETH fees claimed:", internalXplClaimed);

        console.log("\n--- Claiming Rebase Rewards ---");
        uint256 claimableRebase = rewardsDistributor.claimable(voterTokenId);
        console.log("Claimable rebase before claim:", claimableRebase);
        require(claimableRebase > 0, "No rebase rewards claimable");

        (int128 lockedBefore, ) = votingEscrow.locked(voterTokenId);
        rewardsDistributor.claim(voterTokenId);
        (int128 lockedAfterRebase, ) = votingEscrow.locked(voterTokenId);

        uint256 lockedBeforeUint = uint256(uint128(lockedBefore));
        uint256 lockedAfterUint = uint256(uint128(lockedAfterRebase));
        require(lockedAfterUint > lockedBeforeUint, "No rebase compounded");
        uint256 rebaseClaimed = lockedAfterUint - lockedBeforeUint;
        console.log("Rebase compounded into veNFT:", rebaseClaimed);
        console.log("New locked amount:", lockedAfterUint);

        vm.stopBroadcast();
    }


    function logResults() internal view {
        console.log("\n=== FINAL TEST RESULTS ===");
        console.log("Timeline completed: Oct 1 to Oct 9 to Oct 16/23, 2025");
        console.log(
            "Current timestamp:",
            block.timestamp,
            "(Oct 16, 2025 after emissions)"
        );
        console.log("");
        console.log("=== DEX Contracts (Deployed Oct 1) ===");
        console.log("- PairFactory:", address(pairFactory));
        console.log("- RouterV2:", address(router));
        console.log("- TradeHelper:", address(tradeHelper));
        console.log("- GlobalRouter:", address(globalRouter));
        console.log("");
        console.log("=== Voting & Governance (Prepared Oct 9) ===");
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
        console.log("- LP Tokens Minted:", lpTokenBalance);

        if (address(voter) != address(0) && voter.length() > 0) {
            address gauge = voter.gauges(pairAddress);
            console.log("- Gauge for USDT/WETH:", gauge);
            if (gauge != address(0)) {
                console.log("- Gauge is alive:", voter.isAlive(gauge));
            }
        }

        console.log("");
        console.log("=== Emissions & Governance ===");
        if (address(minterUpgradeable) != address(0)) {
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
        }

        if (address(votingEscrow) != address(0)) {
            console.log("- veNFTs owned:", votingEscrow.balanceOf(DEPLOYER));
        }

        console.log("");
        console.log("=== Final Balances ===");
        console.log(
            "- USDT:",
            ERC20(USDT).balanceOf(DEPLOYER) / 1e6,
            "USDT"
        );
        console.log(
            "- WETH:",
            ERC20(XPL).balanceOf(DEPLOYER) / 1e18,
            "WETH"
        );
        console.log(
            "- LP Tokens:",
            ERC20(pairAddress).balanceOf(LP) / 1e18,
            "LP"
        );

        if (address(lithos) != address(0)) {
            console.log(
                "- LITH:",
                lithos.balanceOf(DEPLOYER) / 1e18,
                "LITH"
            );
        }

        console.log("");
        console.log("Complete E2E test completed successfully!");
        console.log(
            "DEX deployment, trading, LITH launch, voting, and emissions all working"
        );
        console.log("=====================================");
    }
}

// Run with: forge script script/e2eTest.s.sol:E2ETest --fork-url https://rpc.plasma.to --gas-limit 30000000 -vvv
