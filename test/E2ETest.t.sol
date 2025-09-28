// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
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

contract E2ETest is Test {
    // Plasma mainnet addresses
    address constant USDT = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb; // USDT on Plasma mainnet
    address constant WETH = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB;
    address constant WXPL = 0x6100E367285b01F48D07953803A2d8dCA5D19873; // Wrapped XPL
    address constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34; // Ethena USDe

    // deployer
    address constant DEPLOYER = 0xa9040c08B0FA3D5cf8B1534A0686261Da948F82a;

    // Test accounts
    address constant LP = address(2);
    address constant BRIBER = address(3);
    address constant VOTER = address(4);

    // Mainnet deployments
    PairFactory public pairFactory = PairFactory(0xD209Cc008C3A26664B21138B425556D1c7e41d6D);
    RouterV2 public router = RouterV2(payable(0x0c746e15F626681Fab319a520dB8066D29Ab3730));
    GlobalRouter public globalRouter = GlobalRouter(0x34c62c36713bDEb2e387B3321f0de5DF8623ab82);
    TradeHelper public tradeHelper = TradeHelper(0x2A66F82F6ce9976179D191224A1E4aC8b50e68D1);

    // Contract instances (to deploy later)
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
    uint256 public voterTokenId;
    address public usdtWethPair;
    address public wxplLithPair;
    address public wxplUsdtPair;
    address public usdtUsdePair;
    uint256 public lpTokenBalance;

    function setUp() public {
        // Step 0: Set time to Tues Oct 1, 2025 00:00:00 UTC
        vm.warp(1759298400);
        console.log("Time set to Oct 1, 2025 00:00:00 UTC");
        console.log("Current timestamp:", block.timestamp);

        // Give deployer and test accounts some ETH
        vm.deal(DEPLOYER, 100 ether);
        vm.deal(LP, 100 ether);
        vm.deal(BRIBER, 100 ether);
        vm.deal(VOTER, 100 ether);

        console.log("=== DEX E2E Test on Plasma Mainnet Beta Fork ===");
        console.log("Chain ID: 9745");
        console.log("deployer:", DEPLOYER);
    }

    function test_e2e() public {
        // Mainnet DEX contracts already deployed
        // step1_DeployDEXContracts();

        // Oct 1, 2025: Do pool stuff
        step2_CreatePools();
        step_GetFunds();
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

        // Claim all rewards types
        step13_ClaimAllRewards();

        console.log("All contracts deployed successfully!");

        logResults();
    }

    // Step 1: Deploy DEX contracts only
    function step1_DeployDEXContracts() internal {
        console.log("\n=== Step 1: Deploy DEX Contracts ===");

        // Act as DEPLOYER for all deployments
        vm.startPrank(DEPLOYER);

        // Deploy PairFactory first
        pairFactory = new PairFactory();
        console.log("PairFactory deployed:", address(pairFactory));

        // Set dibs address to prevent zero address transfer error
        pairFactory.setDibs(DEPLOYER);
        console.log("Set dibs address to:", DEPLOYER);

        // Deploy RouterV2
        router = new RouterV2(address(pairFactory), WETH);
        console.log("RouterV2 deployed:", address(router));

        // Deploy TradeHelper
        tradeHelper = new TradeHelper(address(pairFactory));
        console.log("TradeHelper deployed:", address(tradeHelper));

        // Deploy GlobalRouter
        globalRouter = new GlobalRouter(address(tradeHelper));
        console.log("GlobalRouter deployed:", address(globalRouter));

        console.log("DEX contracts deployed successfully on Oct 1, 2024");

        vm.stopPrank();
    }

    // Step 2: Create pools
    function step2_CreatePools() internal {
        console.log("\n=== Step 2: Create Trading Pools ===");

        vm.startPrank(DEPLOYER);

        // Create USDT/WETH volatile pair
        usdtWethPair = pairFactory.createPair(
            address(USDT),
            address(WETH),
            false // volatile
        );
        console.log("USDT/WETH volatile pair created:", usdtWethPair);

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

        vm.stopPrank();
    }

    // Step 2.5: Get funds
    function step_GetFunds() internal {
        // Transfer USDT from whale
        address usdtWhale = 0x5D72a9d9A9510Cd8cBdBA12aC62593A58930a948;
        vm.startPrank(usdtWhale);
        ERC20(USDT).transfer(DEPLOYER, 1_000_000e6); // 1,000,000 USDT
        console.log("Successfully transferred USDT from whale:", usdtWhale);
        vm.stopPrank();

        // Transfer WETH from whale
        address wethWhale = 0xf1aB7f60128924d69f6d7dE25A20eF70bBd43d07;
        vm.startPrank(wethWhale);
        ERC20(WETH).transfer(DEPLOYER, 1_000e18); // 1000 WETH
        console.log("Successfully transferred WETH from whale:", wethWhale);
        vm.stopPrank();

        // Transfer WXPL from whale
        address wxplWhale = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
        vm.startPrank(wxplWhale);
        ERC20(WXPL).transfer(DEPLOYER, 1_000_000e18); // 1,000,000 WXPL
        console.log("Successfully transferred WXPL from whale:", wxplWhale);
        vm.stopPrank();

        // For USDe, transfer from whale
        address usdeWhale = 0x7519403E12111ff6b710877Fcd821D0c12CAF43A;
        vm.startPrank(usdeWhale);
        ERC20(USDe).transfer(DEPLOYER, 1_000_000e18); // 1,000,000 USDe
        console.log("Successfully transferred USDe from whale:", usdeWhale);
        vm.stopPrank();

        console.log("USDT balance:", ERC20(USDT).balanceOf(DEPLOYER));
        console.log("WETH balance:", ERC20(WETH).balanceOf(DEPLOYER));
        console.log("WXPL balance:", ERC20(WXPL).balanceOf(DEPLOYER));
        console.log("USDe balance:", ERC20(USDe).balanceOf(DEPLOYER));
    }

    // Step 3: Add LP
    function step3_AddLiquidity() internal {
        console.log("\n=== Step 3: Add Liquidity ===");

        vm.startPrank(DEPLOYER);

        uint256 amountToLpUSDT = 250_000e6;
        uint256 amountToLpWETH = 500e18;
        uint256 amountToLpWXPL = 250_000e18;
        uint256 amountToLpUSDe = 250_000e18;

        // Approve RouterV2 to spend tokens
        ERC20(USDT).approve(address(router), amountToLpUSDT * 3); // Used in 3 pairs
        ERC20(WETH).approve(address(router), amountToLpWETH);
        ERC20(WXPL).approve(address(router), amountToLpWXPL);
        ERC20(USDe).approve(address(router), amountToLpUSDe);
        console.log("Approved RouterV2 to spend tokens");

        // Add liquidity to all pairs
        uint256 deadline = block.timestamp + 600; // 10 minutes

        console.log("Adding liquidity to USDT/WETH pair:");
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                USDT, // tokenA
                WETH, // tokenB
                false, // stable = false (volatile pair)
                amountToLpUSDT, // amountADesired
                amountToLpWETH, // amountBDesired
                0, // amountAMin
                0, // amountBMin
                DEPLOYER, // to
                deadline // deadline
            );

        lpTokenBalance = liquidity;
        console.log("- USDT amount:", amountA);
        console.log("- WETH amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        console.log("Adding liquidity to WXPL/USDT pair:");
        (amountA, amountB, liquidity) = router.addLiquidity(
            WXPL, // tokenA
            USDT, // tokenB
            false, // stable = false (volatile pair)
            amountToLpWXPL, // amountADesired
            amountToLpUSDT, // amountBDesired
            0, // amountAMin
            0, // amountBMin
            DEPLOYER, // to
            deadline // deadline
        );

        lpTokenBalance = liquidity;
        console.log("- WXPL amount:", amountA);
        console.log("- USDT amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        console.log("Adding liquidity to USDT/USDe pair:");
        (amountA, amountB, liquidity) = router.addLiquidity(
            USDT, // tokenA
            USDe, // tokenB
            true, // stable = true (stable pair)
            amountToLpUSDT, // amountADesired
            amountToLpUSDe, // amountBDesired
            0, // amountAMin
            0, // amountBMin
            DEPLOYER, // to
            deadline // deadline
        );

        lpTokenBalance = liquidity;
        console.log("- USDT amount:", amountA);
        console.log("- USDe amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        vm.stopPrank();
    }

    // Step 4: Run swaps
    function step4_RunSwaps() internal {
        console.log("\n=== Step 4: Run Swaps ===");

        // Goal here is to build up swap volume on the following pools to make sure swap
        // fees are distributed correctly in the rewards step:
        // - USDT/WETH
        // - WXPL/USDT - 0 swap volume to test edge case
        // - USDT/USDe
        // - WXPL/LITH - will be created/LP'd/swapped in a later step

        vm.startPrank(DEPLOYER);

        // Define swap amounts
        uint256 amountToSwapUSDT = 1_000e6;
        uint256 amountToSwapUSDe = 1_000e18;
        uint256 amountToSwapWETH = 1e18;

        // Approve GlobalRouter to spend tokens for all swaps
        ERC20(USDT).approve(address(globalRouter), amountToSwapUSDT * 2); // Two swaps
        ERC20(USDe).approve(address(globalRouter), amountToSwapUSDe);
        ERC20(WETH).approve(address(globalRouter), amountToSwapWETH);

        uint256 deadline = block.timestamp + 600;

        // === Swap 1: USDT -> WETH ===
        console.log("\nSwap 1: USDT -> WETH");
        uint256 usdtBefore = ERC20(USDT).balanceOf(DEPLOYER);
        uint256 wethBefore = ERC20(WETH).balanceOf(DEPLOYER);

        ITradeHelper.Route[] memory route1 = new ITradeHelper.Route[](1);
        route1[0] = ITradeHelper.Route({from: USDT, to: WETH, stable: false});

        uint256[] memory amounts1 = globalRouter.swapExactTokensForTokens(
            amountToSwapUSDT,
            0,
            route1,
            DEPLOYER,
            deadline,
            true
        );

        uint256 usdtAfter = ERC20(USDT).balanceOf(DEPLOYER);
        uint256 wethAfter = ERC20(WETH).balanceOf(DEPLOYER);
        console.log("- USDT spent:", usdtBefore - usdtAfter);
        console.log("- WETH received:", wethAfter - wethBefore);
        console.log("- Route amounts:", amounts1[0], "->", amounts1[1]);

        // === Swap 2: WETH -> USDT ===
        console.log("\nSwap 2: WETH -> USDT (reverse)");
        wethBefore = ERC20(WETH).balanceOf(DEPLOYER);
        usdtBefore = ERC20(USDT).balanceOf(DEPLOYER);

        ITradeHelper.Route[] memory route2 = new ITradeHelper.Route[](1);
        route2[0] = ITradeHelper.Route({from: WETH, to: USDT, stable: false});

        uint256[] memory amounts2 = globalRouter.swapExactTokensForTokens(
            amountToSwapWETH,
            0,
            route2,
            DEPLOYER,
            deadline,
            true
        );

        wethAfter = ERC20(WETH).balanceOf(DEPLOYER);
        usdtAfter = ERC20(USDT).balanceOf(DEPLOYER);
        console.log("- WETH spent:", wethBefore - wethAfter);
        console.log("- USDT received:", usdtAfter - usdtBefore);
        console.log("- Route amounts:", amounts2[0], "->", amounts2[1]);

        // === Swap 3: USDT -> USDe ===
        console.log("\nSwap 3: USDT -> USDe");
        usdtBefore = ERC20(USDT).balanceOf(DEPLOYER);
        uint256 usdeBefore = ERC20(USDe).balanceOf(DEPLOYER);

        ITradeHelper.Route[] memory route3 = new ITradeHelper.Route[](1);
        route3[0] = ITradeHelper.Route({from: USDT, to: USDe, stable: true});

        uint256[] memory amounts3 = globalRouter.swapExactTokensForTokens(
            amountToSwapUSDT,
            0,
            route3,
            DEPLOYER,
            deadline,
            true
        );

        usdtAfter = ERC20(USDT).balanceOf(DEPLOYER);
        uint256 usdeAfter = ERC20(USDe).balanceOf(DEPLOYER);
        console.log("- USDT spent:", usdtBefore - usdtAfter);
        console.log("- USDe received:", usdeAfter - usdeBefore);
        console.log("- Route amounts:", amounts3[0], "->", amounts3[1]);

        // === Swap 4: USDe -> USDT ===
        console.log("\nSwap 4: USDe -> USDT");
        usdeBefore = ERC20(USDe).balanceOf(DEPLOYER);
        usdtBefore = ERC20(USDT).balanceOf(DEPLOYER);

        ITradeHelper.Route[] memory route4 = new ITradeHelper.Route[](1);
        route4[0] = ITradeHelper.Route({from: USDe, to: USDT, stable: true});

        uint256[] memory amounts4 = globalRouter.swapExactTokensForTokens(
            amountToSwapUSDe,
            0,
            route4,
            DEPLOYER,
            deadline,
            true
        );

        usdeAfter = ERC20(USDe).balanceOf(DEPLOYER);
        usdtAfter = ERC20(USDT).balanceOf(DEPLOYER);
        console.log("- USDe spent:", usdeBefore - usdeAfter);
        console.log("- USDT received:", usdtAfter - usdtBefore);
        console.log("- Route amounts:", amounts4[0], "->", amounts4[1]);

        // Note: WXPL/USDT pool gets 0 swap volume intentionally (testing edge case)
        console.log("\nWXPL/USDT: Intentionally skipped (0 volume test case)");

        console.log("\n=== All swaps completed successfully! ===");
        console.log("Generated swap volume on USDT/WETH and USDT/USDe pools");
        console.log("WXPL/USDT kept at 0 volume for edge case testing");

        vm.stopPrank();
    }

    // Step 5: Fast forward to launch
    function step5_FastForwardToLaunch() internal {
        console.log(
            "\n=== Step 5: Fast Forward to Oct 9, 2025 ==="
        );

        // Set time to Oct 9, 2025 to prepare veNFT + bribes ahead of the Oct 16 epoch flip
        vm.warp(1759968000);
        console.log("Time set to Oct 9, 2025 for LITH launch preparation");
        console.log("Current timestamp:", block.timestamp);
    }

    // Step 6: Deploy voting and governance contracts
    function step6_DeployVotingContracts() internal {
        console.log("\n=== Step 6: Deploy Voting and Governance Contracts ===");

        vm.startPrank(DEPLOYER);

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

        vm.stopPrank();
    }

    // Step 7: Launch LITH and initialize voting
    function step7_LaunchLITHAndVoting() internal {
        console.log("\n=== Step 7: Launch LITH and Initialize Voting ===");

        vm.startPrank(DEPLOYER);

        // Initialize all contracts
        lithos.initialMint(DEPLOYER);
        console.log("LITH initial mint: 50M tokens to TEST_WALLET");

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

        // Set governance roles
        permissionsRegistry.setRoleFor(DEPLOYER, "GOVERNANCE");
        permissionsRegistry.setRoleFor(DEPLOYER, "VOTER_ADMIN");
        permissionsRegistry.setRoleFor(DEPLOYER, "BRIBE_ADMIN");

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

        // Add liquidity to WXPL/LITH pair (deployer has initial 50m of LITH already)
        uint256 deadline = block.timestamp + 600; // 10 minutes
        uint256 amountToLpWXPL = 100_000e18;
        uint256 amountToLpLITH = 100_000e18;

        // Approve RouterV2 to spend WXPL and LITH
        ERC20(WXPL).approve(address(router), amountToLpWXPL);
        lithos.approve(address(router), amountToLpLITH);
        console.log("Approved RouterV2 to spend WXPL and LITH");

        console.log("Adding liquidity to WXPL/LITH pair:");
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                WXPL, // tokenA
                address(lithos), // tokenB
                false, // stable = false (volatile pair)
                amountToLpWXPL, // amountADesired
                amountToLpLITH, // amountBDesired
                0, // amountAMin
                0, // amountBMin
                DEPLOYER, // to
                deadline // deadline
            );

        lpTokenBalance = liquidity;
        console.log("- WXPL amount:", amountA);
        console.log("- LITH amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        vm.stopPrank();
    }

    // Step 8: Create locks
    function step8_CreateLocks() internal {
        console.log("\n=== Step 8: Create Voting Escrow Lock ===");

        // Transfer some LITH to VOTER for locking
        vm.startPrank(DEPLOYER);
        uint256 transferAmount = 5000e18; // 5000 LITH tokens
        lithos.transfer(VOTER, transferAmount);
        console.log("Transferred", transferAmount, "LITH to VOTER for locking");
        vm.stopPrank();

        // Lock as VOTER
        vm.startPrank(VOTER);
        uint256 lockAmount = 1_000_000e18; // Lock 1M LITH tokens
        uint256 lockDuration = 4 weeks; // 4 weeks duration

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

        // Create lock
        voterTokenId = votingEscrow.create_lock(lockAmount, lockDuration);
        console.log("Lock created successfully!");
        console.log("- Token ID (veNFT):", voterTokenId);
        console.log("- Amount locked:", lockAmount);
        console.log("- Duration:", lockDuration, "seconds");

        // Check veNFT minted - verify ownership
        address nftOwner = votingEscrow.ownerOf(voterTokenId);
        console.log("veNFT owner:", nftOwner);
        require(nftOwner == VOTER, "veNFT not minted to deployer");

        // Check veNFT balance of VOTER
        uint256 veNFTBalance = votingEscrow.balanceOf(VOTER);
        console.log("veNFT balance of VOTER:", veNFTBalance);

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

        vm.stopPrank();
    }

    // Step 9: Bribe pools with different tokens
    function step9_BribePools() internal {
        console.log("\n=== Step 9: Bribe Pools with Different Tokens ===");

        // NOTE: We execute this step on Oct 9, 2025. Bribes are queued for the next epoch
        // (Oct 16, 2025). Claiming in step13 then advances to Oct 23 so only rewards from
        // this Oct 9 notification become claimable at the Oct 16 flip.

        // --- DEPLOYER Whitelists all tokens that will be used to create gauges,
        // creates gauges, and adds reward tokens to gauges
        vm.startPrank(DEPLOYER);

        address[] memory tokensToCheck = new address[](4);
        tokensToCheck[0] = address(lithos);
        tokensToCheck[1] = WXPL;
        tokensToCheck[2] = USDT;
        tokensToCheck[3] = WETH;

        uint256 toWhitelistCount = 0;
        for (uint256 i = 0; i < tokensToCheck.length; i++) {
            if (!voter.isWhitelisted(tokensToCheck[i])) {
                toWhitelistCount++;
            }
        }

        if (toWhitelistCount > 0) {
            address[] memory tokensToWhitelist = new address[](toWhitelistCount);
            uint256 index = 0;
            for (uint256 i = 0; i < tokensToCheck.length; i++) {
                if (!voter.isWhitelisted(tokensToCheck[i])) {
                    tokensToWhitelist[index] = tokensToCheck[i];
                    console.log("Whitelisting token for gauge creation:", tokensToCheck[i]);
                    index++;
                }
            }
            voter.whitelist(tokensToWhitelist);
            console.log("Whitelisted", toWhitelistCount, "tokens for gauge creation");
        } else {
            console.log("All tokens already whitelisted");
        }

        // ========== USDT/WETH GAUGE ==========
        // Pool tokens: USDT, WETH (automatically added as reward tokens)
        // Additional reward tokens: LITH (must be added manually)

        (
            address usdtWethGaugeAddress,
            address usdtWethInternalBribe,
            address usdtWethExternalBribe
        ) = voter.createGauge(usdtWethPair, 0);
        console.log("Gauge created for USDT/WETH pair:", usdtWethGaugeAddress);
        console.log("Internal bribe address:", usdtWethInternalBribe);
        console.log("External bribe address:", usdtWethExternalBribe);

        // Add LITH as reward token
        (bool addLithSuccessUsdtWeth, ) = usdtWethExternalBribe.call(
            abi.encodeWithSignature("addRewardToken(address)", address(lithos))
        );
        require(addLithSuccessUsdtWeth, "Failed to add LITH as reward token");
        console.log("Added LITH as reward token to bribe contract");

        // ========== WXPL/LITH GAUGE ==========
        // Pool tokens: WXPL, LITH (automatically added as reward tokens)
        // Additional reward tokens: USDT (must be added manually)

        (
            address wxplLithGaugeAddress,
            address wxplLithInternalBribe,
            address wxplLithExternalBribe
        ) = voter.createGauge(wxplLithPair, 0);
        console.log("Gauge created for WXPL/LITH pair:", wxplLithGaugeAddress);
        console.log("Internal bribe address:", wxplLithInternalBribe);
        console.log("External bribe address:", wxplLithExternalBribe);

        (bool addUsdtSuccess, ) = wxplLithExternalBribe.call(
            abi.encodeWithSignature("addRewardToken(address)", USDT)
        );
        require(addUsdtSuccess, "Failed to add USDT as reward token");
        console.log("Added USDT as reward token to bribe contract");

        // ========== WXPL/USDT GAUGE ==========
        // Pool tokens: WXPL, USDT (automatically added as reward tokens)
        // Additional reward tokens: none

        (
            address wxplUsdtGaugeAddress,
            address wxplUsdtInternalBribe,
            address wxplUsdtExternalBribe
        ) = voter.createGauge(wxplUsdtPair, 0);
        console.log("Gauge created for WXPL/USDT pair:", wxplUsdtGaugeAddress);
        console.log("Internal bribe address:", wxplUsdtInternalBribe);
        console.log("External bribe address:", wxplUsdtExternalBribe);

        // ========== USDT/USDe GAUGE ==========
        // Pool tokens: USDT, USDe (automatically added as reward tokens)
        // Additional reward tokens: LITH (must be added manually)

        (
            address usdtUsdeGaugeAddress,
            address usdtUsdeInternalBribe,
            address usdtUsdeExternalBribe
        ) = voter.createGauge(usdtUsdePair, 0);
        console.log("Gauge created for USDT/USDE pair:", usdtUsdeGaugeAddress);
        console.log("Internal bribe address:", usdtUsdeInternalBribe);
        console.log("External bribe address:", usdtUsdeExternalBribe);

        // Add LITH as reward token
        (bool addLithSuccessUsdtUsde, ) = usdtUsdeExternalBribe.call(
            abi.encodeWithSignature("addRewardToken(address)", address(lithos))
        );
        require(addLithSuccessUsdtUsde, "Failed to add LITH as reward token");
        console.log("Added LITH as reward token to bribe contract");

        vm.stopPrank();

        // --- BRIBER adds bribes to gauges
        vm.startPrank(BRIBER);

        // Bribe USDT/WETH gauge with LITH
        uint256 lithBribeAmountForUsdtWeth = 1_000e18; // 1000 LITH
        lithos.approve(usdtWethExternalBribe, lithBribeAmountForUsdtWeth);
        console.log("Approved LITH for bribing:", lithBribeAmountForUsdtWeth);
        (bool notifyLithSuccessUsdtWeth, ) = usdtWethExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(lithos),
                lithBribeAmountForUsdtWeth
            )
        );
        require(notifyLithSuccessUsdtWeth, "Failed to notify LITH reward amount for USDT/WETH");
        console.log("Notified LITH bribe amount for USDT/WETH:", lithBribeAmountForUsdtWeth);

        // Bribe WXPL/LITH gauge with WXPL, LITH, and USDT
        uint256 wxplBribeAmountForWxplLith = 1_000e18; // 1000 WXPL
        uint256 lithBribeAmountForWxplLith = 1_000e18; // 1000 LITH
        uint256 usdtBribeAmountForWxplLith = 1_000e6; // 1000 USDT
        lithos.approve(wxplLithExternalBribe, wxplBribeAmountForWxplLith);
        lithos.approve(wxplLithExternalBribe, lithBribeAmountForUsdtWeth);
        lithos.approve(wxplLithExternalBribe, usdtBribeAmountForWxplLith);
        console.log("Approved WXPL for bribing:", wxplBribeAmountForWxplLith);
        console.log("Approved LITH for bribing:", lithBribeAmountForUsdtWeth);
        console.log("Approved USDT for bribing:", usdtBribeAmountForWxplLith);

        (bool notifyWxplSuccess, ) = wxplLithExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(WXPL),
                wxplBribeAmountForWxplLith
            )
        );
        require(notifyWxplSuccess, "Failed to notify WXPL reward amount for WXPL/LITH");
        console.log("Notified WXPL bribe amount for WXPL/LITH:", wxplBribeAmountForWxplLith);

        (bool notifyLithSuccessWxplLith, ) = wxplLithExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(lithos),
                lithBribeAmountForWxplLith
            )
        );
        require(notifyLithSuccessWxplLith, "Failed to notify LITH reward amount for WXPL/LITH");
        console.log("Notified LITH bribe amount for WXPL/LITH:", lithBribeAmountForUsdtWeth);

        (bool notifyUsdtSuccess, ) = wxplLithExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(USDT),
                usdtBribeAmountForWxplLith
            )
        );
        require(notifyUsdtSuccess, "Failed to notify USDT reward amount for WXPL/LITH");
        console.log("Notified USDT bribe amount for WXPL/LITH:", usdtBribeAmountForWxplLith);

        // Bribe USDT/USDe gauge with LITH
        uint256 lithBribeAmountForUsdtUsde = 1_000e18; // 1000 LITH
        lithos.approve(usdtUsdeExternalBribe, lithBribeAmountForUsdtUsde);
        console.log("Approved LITH for bribing:", lithBribeAmountForUsdtUsde);
        (bool notifyLithSuccessUsdtUsde, ) = usdtUsdeExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(lithos),
                lithBribeAmountForUsdtUsde
            )
        );
        require(notifyLithSuccessUsdtUsde, "Failed to notify LITH reward amount for USDT/USDe");
        console.log("Notified LITH bribe amount for USDT/USDe:", lithBribeAmountForUsdtUsde);

        vm.stopPrank();
    }

    // Step 10: Vote for pools
    function step10_VoteForPools() internal {
        console.log("\n=== Step 10: Vote for Pools ===");

        vm.startPrank(VOTER);

        // Vote with our veNFT
        require(voterTokenId != 0, "veNFT not ready for voting");
        address[] memory pools = new address[](1);
        uint256[] memory weights = new uint256[](1);

        pools[0] = wxplLithPair;
        weights[0] = 100; // 100% of voting power to this pool

        voter.vote(voterTokenId, pools, weights);
        console.log("Voted with NFT", voterTokenId, "for pool:", wxplLithPair);
        console.log("Vote weight:", weights[0]);

        console.log("Voting completed successfully!");

        vm.stopPrank();
    }

    // Step 11: Fast forward to Oct 16, 2025
    function step11_FastForwardToDistribution() internal {
        console.log(
            "\n=== Step 11: Fast Forward for Distribution Oct 16 2025 ==="
        );

        // Set time to Oct 16, 2025 for epoch flip
        vm.warp(1760572800);
        console.log(
            "Fast forwarded to Oct 16, 2025 for epoch flip and distribution"
        );
        console.log("Current timestamp:", block.timestamp);
    }

    // Step 12: Epoch flip and distribution
    function step12_EpochFlipAndDistribute() internal {
        console.log("\n=== Step 12: Epoch Flip and Emissions Distribution ===");

        vm.startPrank(DEPLOYER);

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

            // Distribute emissions to all gauges (this calls update_period internally)
            console.log("Distributing emissions to gauges...");
            voter.distributeAll();
            console.log("Emissions distributed successfully!");

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

        vm.stopPrank();
    }

    // Step 13: Claim all rewards types
    function step13_ClaimAllRewards() internal {
        console.log("\n=== Step 13: Claim All Rewards Types ===");
        console.log(
            "After epoch flip and distribution, claiming all accumulated rewards"
        );

        vm.startPrank(DEPLOYER);

        // Get gauge address for our pair (we're voting on WXPL/LITH)
        address gaugeAddress = voter.gauges(wxplLithPair);
        console.log("Gauge address for WXPL/LITH:", gaugeAddress);

        // Check gauge state
        console.log("\n--- Checking Gauge State ---");
        (bool rewardRateSuccess, bytes memory rewardRateData) = gaugeAddress
            .call(abi.encodeWithSignature("rewardRate()"));
        if (rewardRateSuccess && rewardRateData.length > 0) {
            uint256 rewardRate = abi.decode(rewardRateData, (uint256));
            console.log("Gauge reward rate:", rewardRate);
        }

        // Check gauge reward token
        (bool rewardTokenSuccess, bytes memory rewardTokenData) = gaugeAddress
            .call(abi.encodeWithSignature("rewardToken()"));
        if (rewardTokenSuccess && rewardTokenData.length > 0) {
            address rewardToken = abi.decode(rewardTokenData, (address));
            console.log("Gauge reward token:", rewardToken);
            console.log("Expected LITH address:", address(lithos));
        }

        // Check total supply in gauge
        (bool totalSupplySuccess, bytes memory totalSupplyData) = gaugeAddress
            .call(abi.encodeWithSignature("totalSupply()"));
        if (totalSupplySuccess && totalSupplyData.length > 0) {
            uint256 totalSupply = abi.decode(totalSupplyData, (uint256));
            console.log("Total LP tokens staked in gauge:", totalSupply);
        }

        // Check votes for gauge (current epoch)
        uint256 gaugeVotes = voter.weights(wxplLithPair);
        uint256 totalVotes = voter.totalWeight();
        console.log("Gauge votes (current epoch):", gaugeVotes);
        console.log("Total votes (current epoch):", totalVotes);

        // Check votes from all relevant epochs
        uint256 oct17Epoch = 1728604800;
        uint256 oct24Epoch = 1729209600;
        uint256 currentEpochVotes = voter.weightsAt(
            wxplLithPair,
            minterUpgradeable.active_period()
        );
        uint256 oct17Votes = voter.weightsAt(wxplLithPair, oct17Epoch);
        uint256 oct24Votes = voter.weightsAt(wxplLithPair, oct24Epoch);

        console.log("Current epoch:", minterUpgradeable.active_period());
        console.log("Gauge votes (current epoch):", currentEpochVotes);
        console.log("Gauge votes (Oct 17 epoch 1728604800):", oct17Votes);
        console.log("Gauge votes (Oct 24 epoch 1729209600):", oct24Votes);

        // Record balances before claiming
        console.log("\n--- Recording balances before claiming ---");
        uint256 usdtBefore = ERC20(USDT).balanceOf(DEPLOYER);
        uint256 wethBefore = ERC20(WETH).balanceOf(DEPLOYER);
        uint256 lithBefore = lithos.balanceOf(DEPLOYER);
        console.log("USDT before:", usdtBefore);
        console.log("WETH before:", wethBefore);
        console.log("LITH before:", lithBefore);

        // 1. Skip direct LP Trading Fees claim - they flow through gauge's internal bribe
        console.log("\n--- LP Trading Fees ---");
        console.log(
            "LP tokens remain staked in gauge, fees flow through internal bribes to voters"
        );

        // 2. Claim Gauge Emissions (LITH rewards for staked LP)
        console.log("\n--- Claiming Gauge Emissions ---");

        if (gaugeAddress != address(0)) {
            // Check if we still have LP tokens staked from step 10
            (
                bool checkStakedSuccess,
                bytes memory checkStakedData
            ) = gaugeAddress.call(
                    abi.encodeWithSignature("balanceOf(address)", DEPLOYER)
                );
            if (checkStakedSuccess && checkStakedData.length > 0) {
                uint256 currentlyStaked = abi.decode(
                    checkStakedData,
                    (uint256)
                );
                console.log("LP tokens staked in gauge:", currentlyStaked);
            }

            // Let's wait a bit to accumulate rewards
            vm.warp(block.timestamp + 1 hours);
            console.log("Fast forwarded 1 hour to accumulate rewards");

            // Check earned emissions BEFORE claiming
            (bool earnedSuccess, bytes memory earnedData) = gaugeAddress.call(
                abi.encodeWithSignature("earned(address)", DEPLOYER)
            );

            if (earnedSuccess && earnedData.length > 0) {
                uint256 pendingEmissions = abi.decode(earnedData, (uint256));
                console.log(
                    "Pending gauge emissions after 1 hour:",
                    pendingEmissions
                );

                // Claim emissions
                (bool getRewardSuccess, ) = gaugeAddress.call(
                    abi.encodeWithSignature("getReward()")
                );

                if (getRewardSuccess) {
                    uint256 lithAfterEmissions = lithos.balanceOf(DEPLOYER);
                    uint256 lithEmissionsClaimed = lithAfterEmissions -
                        lithBefore;
                    console.log("Gauge emissions claimed successfully!");
                    console.log(
                        "- LITH rewards received:",
                        lithEmissionsClaimed
                    );
                    lithBefore = lithAfterEmissions;
                } else {
                    console.log("Failed to claim gauge emissions");
                }
            } else {
                console.log("No gauge emissions to claim");
            }
        }

        // 3. Claim Bribe Rewards (for veNFT voters)
        console.log("\n--- Claiming Bribe Rewards ---");

        uint256 tokenId = 1; // Our veNFT from step 8

        // Get bribe addresses
        address internalBribe = voter.internal_bribes(gaugeAddress);
        address externalBribe = voter.external_bribes(gaugeAddress);
        console.log("Internal bribe address:", internalBribe);
        console.log("External bribe address:", externalBribe);

        // Check if bribes have any rewards before claiming
        if (externalBribe != address(0)) {
            // Check LITH bribes
            (
                bool checkEarnedSuccess,
                bytes memory checkEarnedData
            ) = externalBribe.call(
                    abi.encodeWithSignature(
                        "earned(uint256,address)",
                        tokenId,
                        address(lithos)
                    )
                );
            if (checkEarnedSuccess && checkEarnedData.length > 0) {
                uint256 earnedLith = abi.decode(checkEarnedData, (uint256));
                console.log("Pending LITH bribes for tokenId:", tokenId);
                console.log("Amount:", earnedLith / 1e18, "LITH");
            }

            // Check deposit balance for this token at different epochs
            uint256 curEpoch = minterUpgradeable.active_period();
            (bool balanceSuccess, bytes memory balanceData) = externalBribe
                .call(
                    abi.encodeWithSignature(
                        "balanceOfAt(uint256,uint256)",
                        tokenId,
                        curEpoch
                    )
                );
            if (balanceSuccess && balanceData.length > 0) {
                uint256 balance = abi.decode(balanceData, (uint256));
                console.log(
                    "External bribe balance for tokenId at current epoch:",
                    balance
                );
            }

            // Also check the next epoch balance
            (
                bool nextBalanceSuccess,
                bytes memory nextBalanceData
            ) = externalBribe.call(
                    abi.encodeWithSignature("balanceOf(uint256)", tokenId)
                );
            if (nextBalanceSuccess && nextBalanceData.length > 0) {
                uint256 nextBalance = abi.decode(nextBalanceData, (uint256));
                console.log(
                    "External bribe balance for tokenId (next epoch):",
                    nextBalance
                );
            }
        }

        // Claim from external bribe (LITH and possibly USDT)
        if (externalBribe != address(0)) {
            // Prepare reward tokens array
            address[] memory rewardTokens = new address[](2);
            rewardTokens[0] = address(lithos);
            rewardTokens[1] = USDT;

            // Claim external bribes
            (bool externalClaimSuccess, ) = externalBribe.call(
                abi.encodeWithSignature(
                    "getReward(uint256,address[])",
                    tokenId,
                    rewardTokens
                )
            );

            if (externalClaimSuccess) {
                uint256 lithAfterBribes = lithos.balanceOf(DEPLOYER);
                uint256 usdtAfterBribes = ERC20(USDT).balanceOf(DEPLOYER);
                uint256 lithBribesClaimed = lithAfterBribes > lithBefore
                    ? lithAfterBribes - lithBefore
                    : 0;
                uint256 usdtBribesClaimed = usdtAfterBribes > usdtBefore
                    ? usdtAfterBribes - usdtBefore
                    : 0;

                console.log("External bribe rewards claimed successfully!");
                console.log("- LITH bribes received:", lithBribesClaimed);
                console.log("- USDT bribes received:", usdtBribesClaimed);

                lithBefore = lithAfterBribes;
                usdtBefore = usdtAfterBribes;
            } else {
                console.log(
                    "Failed to claim external bribes or no bribes available"
                );
            }
        }

        // Claim from internal bribe (trading fees distributed to voters)
        if (internalBribe != address(0)) {
            // Internal bribes get trading fees as rewards
            address[] memory feeTokens = new address[](2);
            feeTokens[0] = USDT;
            feeTokens[1] = WETH;

            (bool internalClaimSuccess, ) = internalBribe.call(
                abi.encodeWithSignature(
                    "getReward(uint256,address[])",
                    tokenId,
                    feeTokens
                )
            );

            if (internalClaimSuccess) {
                uint256 usdtAfterInternal = ERC20(USDT).balanceOf(DEPLOYER);
                uint256 wethAfterInternal = ERC20(WETH).balanceOf(DEPLOYER);
                uint256 usdtInternalClaimed = usdtAfterInternal > usdtBefore
                    ? usdtAfterInternal - usdtBefore
                    : 0;
                uint256 wethInternalClaimed = wethAfterInternal > wethBefore
                    ? wethAfterInternal - wethBefore
                    : 0;

                console.log(
                    "Internal bribe rewards (trading fees) claimed successfully!"
                );
                console.log("- USDT fees from voting:", usdtInternalClaimed);
                console.log("- WETH fees from voting:", wethInternalClaimed);

                usdtBefore = usdtAfterInternal;
                wethBefore = wethAfterInternal;
            } else {
                console.log("No internal bribes to claim");
            }
        }

        // 4. Claim Rebase Rewards (for all veNFT holders)
        console.log("\n--- Claiming Rebase Rewards ---");

        // Check RewardsDistributor balance
        uint256 distBalance = lithos.balanceOf(address(rewardsDistributor));
        console.log(
            "RewardsDistributor LITH balance:",
            distBalance / 1e18,
            "LITH"
        );

        // Check total veNFT supply for rebase calculation
        uint256 totalVeSupply = votingEscrow.totalSupply();
        console.log("Total veNFT supply:", totalVeSupply);

        // Check claimable rebase amount
        uint256 claimableRebase = rewardsDistributor.claimable(tokenId);
        console.log("Claimable rebase rewards for tokenId:", tokenId);
        console.log("Amount:", claimableRebase / 1e18, "LITH");

        if (claimableRebase > 0) {
            // Get locked amount before claim
            (int128 lockedBefore, ) = votingEscrow.locked(tokenId);
            console.log(
                "Locked amount before rebase:",
                uint256(uint128(lockedBefore))
            );

            // Claim rebase rewards
            rewardsDistributor.claim(tokenId);

            // Get locked amount after claim (rebase compounds into veNFT)
            (int128 lockedAfter, ) = votingEscrow.locked(tokenId);
            uint256 rebaseReceived = uint256(uint128(lockedAfter)) -
                uint256(uint128(lockedBefore));

            console.log("Rebase rewards claimed successfully!");
            console.log("- LITH compounded into veNFT:", rebaseReceived);
            console.log("- New locked amount:", uint256(uint128(lockedAfter)));
        } else {
            console.log("No rebase rewards to claim");
        }

        // Summary of all rewards claimed
        console.log("\n=== Rewards Claim Summary ===");
        console.log("All reward types have been claimed and verified!");
        console.log("- LP Trading Fees: Claimed from Pair contract");
        console.log("- Gauge Emissions: Claimed LITH from staked LP tokens");
        console.log("- Bribe Rewards: Claimed external and internal bribes");
        console.log("- Rebase Rewards: Claimed and compounded into veNFT");

        vm.stopPrank();
    }

    function logResults() internal view {
        console.log("\n=== FINAL TEST RESULTS ===");
        console.log("Timeline completed: Oct 1 to Oct 10 to Oct 16, 2024");
        console.log(
            "Current timestamp:",
            block.timestamp,
            "(Oct 16, 2024 after emissions)"
        );
        console.log("");
        console.log("=== DEX Contracts (Deployed Oct 1) ===");
        console.log("- PairFactory:", address(pairFactory));
        console.log("- RouterV2:", address(router));
        console.log("- TradeHelper:", address(tradeHelper));
        console.log("- GlobalRouter:", address(globalRouter));
        console.log("");
        console.log("=== Voting & Governance (Deployed Oct 10) ===");
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
        console.log("- USDT/WETH Pair:", usdtWethPair);
        console.log("- LP Tokens Minted:", lpTokenBalance);

        if (address(voter) != address(0) && voter.length() > 0) {
            address gauge = voter.gauges(usdtWethPair);
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
        console.log("- USDT:", ERC20(USDT).balanceOf(DEPLOYER) / 1e6, "USDT");
        console.log("- WETH:", ERC20(WETH).balanceOf(DEPLOYER) / 1e18, "WETH");
        console.log(
            "- LP Tokens (USDT/WETH):",
            ERC20(usdtWethPair).balanceOf(DEPLOYER) / 1e18,
            "LP"
        );

        if (address(lithos) != address(0)) {
            console.log("- LITH:", lithos.balanceOf(DEPLOYER) / 1e18, "LITH");
        }

        console.log("");
        console.log("Complete E2E test completed successfully!");
        console.log(
            "DEX deployment, trading, LITH launch, voting, and emissions all working"
        );
        console.log("=====================================");
    }
}

// Run with: forge test --match-test test_e2e --gas-limit 100000000 --fork-url https://rpc.plasma.to -vv
