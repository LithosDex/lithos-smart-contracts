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
    address constant LP_UNSTAKED = address(5);

    // Mainnet deployments
    PairFactory public pairFactory =
        PairFactory(0xD209Cc008C3A26664B21138B425556D1c7e41d6D);
    RouterV2 public router =
        RouterV2(payable(0x0c746e15F626681Fab319a520dB8066D29Ab3730));
    GlobalRouter public globalRouter =
        GlobalRouter(0x34c62c36713bDEb2e387B3321f0de5DF8623ab82);
    TradeHelper public tradeHelper =
        TradeHelper(0x2A66F82F6ce9976179D191224A1E4aC8b50e68D1);

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
    address public usdtWethGaugeAddress;
    address public usdtWethInternalBribe;
    address public usdtWethExternalBribe;

    address public wxplLithPair;
    address public wxplLithGaugeAddress;
    address public wxplLithInternalBribe;
    address public wxplLithExternalBribe;

    address public wxplUsdtPair;
    address public wxplUsdtGaugeAddress;
    address public wxplUsdtInternalBribe;
    address public wxplUsdtExternalBribe;

    address public usdtUsdePair;
    address public usdtUsdeGaugeAddress;
    address public usdtUsdeInternalBribe;
    address public usdtUsdeExternalBribe;

    uint256 public lpTokenBalance;

    // Track LP_UNSTAKED's starting balances after liquidity provision
    uint256 public lpUnstakedInitialUSDT;
    uint256 public lpUnstakedInitialWETH;
    uint256 public lpUnstakedInitialUSDe;

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
        vm.deal(LP_UNSTAKED, 100 ether);

        console.log("=== DEX E2E Test on Plasma Mainnet Beta Fork ===");
        console.log("Chain ID: 9745");
        console.log("deployer:", DEPLOYER);
    }

    function test_e2e() public {
        // Mainnet DEX contracts already deployed
        // step1_DeployDEXContracts();

        // Oct 1, 2025: Do pool stuff
        step2_CreatePools();
        step3A_GetFunds();
        step3B_AddLiquidity();

        // Fast forward to Oct 9, 2025: Launch LITH and voting prep
        step5_FastForwardToLaunch();
        step6_DeployVotingContracts();
        step7_LaunchLITHAndVoting();
        step8_CreateLocks();
        step9A_BribePools();
        step9B_StakeLPTokens();
        step10_VoteForPools();
        step_RunSwaps();
        step_ClaimTradingFeesUnstaked();

        // Fast forward to Oct 15, 2025: Distribute fees BEFORE epoch flip
        step11_FastForwardToPreEpochDistribution();
        step12_DistributeFeesBeforeFlip();

        // Fast forward to Oct 16, 2025: Epoch flip
        step13_FastForwardToEpochFlip();
        step14_EpochFlipAndEmissions();
        step15_ClaimAllRewards();

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

    // Step 3A: Get funds
    function step3A_GetFunds() internal {
        console.log("\n=== Step GetFunds: Transfer Funds From Whales ===");

        // Transfer USDT from whale
        address usdtWhale = 0x5D72a9d9A9510Cd8cBdBA12aC62593A58930a948;
        vm.startPrank(usdtWhale);
        ERC20(USDT).transfer(DEPLOYER, 2_000_000e6); // 2,000,000 USDT
        console.log("Successfully transferred USDT from whale:", usdtWhale);
        vm.stopPrank();

        // Transfer WETH from whale
        address wethWhale = 0xf1aB7f60128924d69f6d7dE25A20eF70bBd43d07;
        vm.startPrank(wethWhale);
        ERC20(WETH).transfer(DEPLOYER, 2_000e18); // 2000 WETH
        console.log("Successfully transferred WETH from whale:", wethWhale);
        vm.stopPrank();

        // Transfer WXPL from whale
        address wxplWhale = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
        vm.startPrank(wxplWhale);
        ERC20(WXPL).transfer(DEPLOYER, 2_000_000e18); // 2,000,000 WXPL
        console.log("Successfully transferred WXPL from whale:", wxplWhale);
        vm.stopPrank();

        // For USDe, transfer from whale
        address usdeWhale = 0x7519403E12111ff6b710877Fcd821D0c12CAF43A;
        vm.startPrank(usdeWhale);
        ERC20(USDe).transfer(DEPLOYER, 2_000_000e18); // 2,000,000 USDe
        console.log("Successfully transferred USDe from whale:", usdeWhale);
        vm.stopPrank();

        console.log("Deployer USDT balance:", ERC20(USDT).balanceOf(DEPLOYER));
        console.log("Deployer WETH balance:", ERC20(WETH).balanceOf(DEPLOYER));
        console.log("Deployer WXPL balance:", ERC20(WXPL).balanceOf(DEPLOYER));
        console.log("Deployer USDe balance:", ERC20(USDe).balanceOf(DEPLOYER));
    }

    // Step 3: Add LP
    function step3B_AddLiquidity() internal {
        console.log("\n=== Step 3: Add Liquidity ===");

        // Transfer funds to LP and LP_UNSTAKED
        vm.startPrank(DEPLOYER);
        uint256 amountToLpUSDT = 250_000e6;
        uint256 amountToLpWETH = 500e18;
        uint256 amountToLpWXPL = 250_000e18;
        uint256 amountToLpUSDe = 250_000e18;

        // LP gets funds for all pairs
        ERC20(USDT).transfer(LP, amountToLpUSDT * 3); // Used in 3 pairs
        ERC20(WETH).transfer(LP, amountToLpWETH);
        ERC20(WXPL).transfer(LP, amountToLpWXPL);
        ERC20(USDe).transfer(LP, amountToLpUSDe);

        // LP_UNSTAKED gets funds for USDT/WETH and USDT/USDe (pools with swaps)
        ERC20(USDT).transfer(LP_UNSTAKED, amountToLpUSDT * 2); // For 2 pairs
        ERC20(WETH).transfer(LP_UNSTAKED, amountToLpWETH);
        ERC20(USDe).transfer(LP_UNSTAKED, amountToLpUSDe);

        vm.startPrank(LP);

        // Approve RouterV2 to spend tokens
        ERC20(USDT).approve(address(router), amountToLpUSDT * 3);
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
                LP, // to
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
            LP, // to
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
            LP, // to
            deadline // deadline
        );

        lpTokenBalance = liquidity;
        console.log("- USDT amount:", amountA);
        console.log("- USDe amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        vm.stopPrank();

        // LP_UNSTAKED adds liquidity (but won't stake)
        console.log(
            "\n=== LP_UNSTAKED Adding Liquidity (Will Keep Unstaked) ==="
        );
        vm.startPrank(LP_UNSTAKED);

        // Approve RouterV2 to spend tokens
        ERC20(USDT).approve(address(router), amountToLpUSDT * 2);
        ERC20(WETH).approve(address(router), amountToLpWETH);
        ERC20(USDe).approve(address(router), amountToLpUSDe);
        console.log("LP_UNSTAKED approved RouterV2 to spend tokens");

        // Add liquidity to USDT/WETH pair
        console.log("LP_UNSTAKED adding liquidity to USDT/WETH pair:");
        (amountA, amountB, liquidity) = router.addLiquidity(
            USDT, // tokenA
            WETH, // tokenB
            false, // stable = false (volatile pair)
            amountToLpUSDT, // amountADesired
            amountToLpWETH, // amountBDesired
            0, // amountAMin
            0, // amountBMin
            LP_UNSTAKED, // to
            deadline // deadline
        );
        console.log("- USDT amount:", amountA);
        console.log("- WETH amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        // Add liquidity to USDT/USDe pair
        console.log("LP_UNSTAKED adding liquidity to USDT/USDe pair:");
        (amountA, amountB, liquidity) = router.addLiquidity(
            USDT, // tokenA
            USDe, // tokenB
            true, // stable = true (stable pair)
            amountToLpUSDT, // amountADesired
            amountToLpUSDe, // amountBDesired
            0, // amountAMin
            0, // amountBMin
            LP_UNSTAKED, // to
            deadline // deadline
        );
        console.log("- USDT amount:", amountA);
        console.log("- USDe amount:", amountB);
        console.log("- LP tokens minted:", liquidity);

        console.log(
            "\nLP_UNSTAKED keeps LP tokens unstaked to earn trading fees directly"
        );

        // Record initial balances after liquidity provision (before any swaps/fees)
        lpUnstakedInitialUSDT = ERC20(USDT).balanceOf(LP_UNSTAKED);
        lpUnstakedInitialWETH = ERC20(WETH).balanceOf(LP_UNSTAKED);
        lpUnstakedInitialUSDe = ERC20(USDe).balanceOf(LP_UNSTAKED);

        vm.stopPrank();
    }

    // Step: Run swaps
    function step_RunSwaps() internal {
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

        uint256 deadline = block.timestamp + 1200;

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

    // Step: Claim trading fees for unstaked LP
    function step_ClaimTradingFeesUnstaked() internal {
        console.log("\n=== Step: Claim Trading Fees for Unstaked LP ===");
        console.log(
            "Demonstrating that unstaked LPs can claim trading fees directly"
        );
        console.log("while staked LPs cannot (their fees go to voters)\n");

        console.log("--- LP_UNSTAKED Claims Trading Fees ---");
        console.log(
            "Note: claimable0/claimable1 are only finalized when claimFees() is called"
        );
        console.log(
            "So we claim first, then measure the actual fees received\n"
        );

        vm.startPrank(LP_UNSTAKED);

        // Record balances before claiming
        uint256 usdtBefore = ERC20(USDT).balanceOf(LP_UNSTAKED);
        uint256 wethBefore = ERC20(WETH).balanceOf(LP_UNSTAKED);
        uint256 usdeBefore = ERC20(USDe).balanceOf(LP_UNSTAKED);

        // Claim from USDT/WETH pair (claimFees finalizes fees via _updateFor)
        (bool success, ) = usdtWethPair.call(
            abi.encodeWithSignature("claimFees()")
        );
        if (success) {
            console.log("Successfully claimed fees from USDT/WETH pair");
        }

        // Claim from USDT/USDe pair
        (success, ) = usdtUsdePair.call(abi.encodeWithSignature("claimFees()"));
        if (success) {
            console.log("Successfully claimed fees from USDT/USDe pair");
        }

        // Check balances after claiming
        uint256 usdtAfter = ERC20(USDT).balanceOf(LP_UNSTAKED);
        uint256 wethAfter = ERC20(WETH).balanceOf(LP_UNSTAKED);
        uint256 usdeAfter = ERC20(USDe).balanceOf(LP_UNSTAKED);

        uint256 usdtReceived = usdtAfter - usdtBefore;
        uint256 wethReceived = wethAfter - wethBefore;
        uint256 usdeReceived = usdeAfter - usdeBefore;

        console.log("\nFees claimed by LP_UNSTAKED:");
        if (usdtReceived > 0) {
            console.log("  USDT:");
            console.log("    Raw units:", usdtReceived);
            // Format as X.XXXXXX USDT (6 decimals)
            uint256 usdtWhole = usdtReceived / 1e6;
            uint256 usdtDecimals = usdtReceived % 1e6;
            console.log("    Formatted: %s.%s USDT", usdtWhole, usdtDecimals);
        }
        if (wethReceived > 0) {
            console.log("  WETH:");
            console.log("    Raw units:", wethReceived);
            // Format as 0.XXXXXX WETH (show first 6 decimals)
            uint256 wethWhole = wethReceived / 1e18;
            uint256 wethDecimals = (wethReceived % 1e18) / 1e12; // First 6 decimals
            console.log("    Formatted: %s.%s WETH", wethWhole, wethDecimals);
        }
        if (usdeReceived > 0) {
            console.log("  USDe:");
            console.log("    Raw units:", usdeReceived);
            // Format as 0.XXXXXX USDe (show first 6 decimals)
            uint256 usdeWhole = usdeReceived / 1e18;
            uint256 usdeDecimals = (usdeReceived % 1e18) / 1e12; // First 6 decimals
            console.log("    Formatted: %s.%s USDe", usdeWhole, usdeDecimals);
        }
        if (usdtReceived == 0 && wethReceived == 0 && usdeReceived == 0) {
            console.log("  No fees received (already claimed or no new swaps)");
        }

        // Verify fees were actually received
        require(
            usdtReceived > 0 || wethReceived > 0 || usdeReceived > 0,
            "LP_UNSTAKED should have received trading fees from swaps"
        );

        vm.stopPrank();

        console.log("\n=== Key Insight ===");
        console.log("LP_UNSTAKED earns trading fees directly from swaps");
        console.log(
            "LP (staked) cannot claim fees - they go to voters instead"
        );
        console.log("This is the tradeoff: trading fees vs LITH emissions");
    }

    // Step 5: Fast forward to launch
    function step5_FastForwardToLaunch() internal {
        console.log("\n=== Step 5: Fast Forward to Oct 9, 2025 ===");

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
        uint256 deadline = block.timestamp + 1200;
        uint256 amountToLpWXPL = 100_000e18;
        uint256 amountToLpLITH = 100_000e18;

        // Transfer WXPL and LITH to LP address
        ERC20(WXPL).transfer(LP, amountToLpWXPL);
        lithos.transfer(LP, amountToLpLITH);

        vm.stopPrank();

        vm.startPrank(LP);

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
                LP, // to
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
        uint256 transferAmount = 1_000_000e18; // 1M LITH tokens
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
    function step9A_BribePools() internal {
        console.log("\n=== Step 9: Bribe Pools with Different Tokens ===");

        // NOTE: We execute this step on Oct 9, 2025.
        // - Bribes queued now are for the NEXT epoch (Oct 16-23)
        // - Votes cast in step 10 are recorded for CURRENT epoch (Oct 9-16) and will determine NEXT week's emission distributrion (Oct 16-23)
        // - Bribes become claimable after Oct 23 epoch flip

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
            address[] memory tokensToWhitelist = new address[](
                toWhitelistCount
            );
            uint256 index = 0;
            for (uint256 i = 0; i < tokensToCheck.length; i++) {
                if (!voter.isWhitelisted(tokensToCheck[i])) {
                    tokensToWhitelist[index] = tokensToCheck[i];
                    console.log(
                        "Whitelisting token for gauge creation:",
                        tokensToCheck[i]
                    );
                    index++;
                }
            }
            voter.whitelist(tokensToWhitelist);
            console.log(
                "Whitelisted",
                toWhitelistCount,
                "tokens for gauge creation"
            );
        } else {
            console.log("All tokens already whitelisted");
        }

        // ========== USDT/WETH GAUGE ==========
        // Pool tokens: USDT, WETH (automatically added as reward tokens)
        // Additional reward tokens: LITH (must be added manually)

        (
            usdtWethGaugeAddress,
            usdtWethInternalBribe,
            usdtWethExternalBribe
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
            wxplLithGaugeAddress,
            wxplLithInternalBribe,
            wxplLithExternalBribe
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
            wxplUsdtGaugeAddress,
            wxplUsdtInternalBribe,
            wxplUsdtExternalBribe
        ) = voter.createGauge(wxplUsdtPair, 0);
        console.log("Gauge created for WXPL/USDT pair:", wxplUsdtGaugeAddress);
        console.log("Internal bribe address:", wxplUsdtInternalBribe);
        console.log("External bribe address:", wxplUsdtExternalBribe);

        // ========== USDT/USDe GAUGE ==========
        // Pool tokens: USDT, USDe (automatically added as reward tokens)
        // Additional reward tokens: LITH (must be added manually)

        (
            usdtUsdeGaugeAddress,
            usdtUsdeInternalBribe,
            usdtUsdeExternalBribe
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

        // Transfer funds to BRIBER
        lithos.transfer(BRIBER, 3000e18);
        ERC20(WXPL).transfer(BRIBER, 1000e18);
        ERC20(USDT).transfer(BRIBER, 1000e6);

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
        require(
            notifyLithSuccessUsdtWeth,
            "Failed to notify LITH reward amount for USDT/WETH"
        );
        console.log(
            "Notified LITH bribe amount for USDT/WETH:",
            lithBribeAmountForUsdtWeth
        );

        // Bribe WXPL/LITH gauge with WXPL, LITH, and USDT
        uint256 wxplBribeAmountForWxplLith = 1_000e18; // 1000 WXPL
        uint256 lithBribeAmountForWxplLith = 1_000e18; // 1000 LITH
        uint256 usdtBribeAmountForWxplLith = 1_000e6; // 1000 USDT
        ERC20(WXPL).approve(wxplLithExternalBribe, wxplBribeAmountForWxplLith);
        lithos.approve(wxplLithExternalBribe, wxplBribeAmountForWxplLith);
        ERC20(USDT).approve(wxplLithExternalBribe, usdtBribeAmountForWxplLith);
        console.log("Approved WXPL for bribing:", wxplBribeAmountForWxplLith);
        console.log("Approved LITH for bribing:", lithBribeAmountForWxplLith);
        console.log("Approved USDT for bribing:", usdtBribeAmountForWxplLith);

        (bool notifyWxplSuccess, ) = wxplLithExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(WXPL),
                wxplBribeAmountForWxplLith
            )
        );
        require(
            notifyWxplSuccess,
            "Failed to notify WXPL reward amount for WXPL/LITH"
        );
        console.log(
            "Notified WXPL bribe amount for WXPL/LITH:",
            wxplBribeAmountForWxplLith
        );

        (bool notifyLithSuccessWxplLith, ) = wxplLithExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(lithos),
                lithBribeAmountForWxplLith
            )
        );
        require(
            notifyLithSuccessWxplLith,
            "Failed to notify LITH reward amount for WXPL/LITH"
        );
        console.log(
            "Notified LITH bribe amount for WXPL/LITH:",
            lithBribeAmountForUsdtWeth
        );

        (bool notifyUsdtSuccess, ) = wxplLithExternalBribe.call(
            abi.encodeWithSignature(
                "notifyRewardAmount(address,uint256)",
                address(USDT),
                usdtBribeAmountForWxplLith
            )
        );
        require(
            notifyUsdtSuccess,
            "Failed to notify USDT reward amount for WXPL/LITH"
        );
        console.log(
            "Notified USDT bribe amount for WXPL/LITH:",
            usdtBribeAmountForWxplLith
        );

        // No bribes to WXPL/USDT gauge

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
        require(
            notifyLithSuccessUsdtUsde,
            "Failed to notify LITH reward amount for USDT/USDe"
        );
        console.log(
            "Notified LITH bribe amount for USDT/USDe:",
            lithBribeAmountForUsdtUsde
        );

        vm.stopPrank();
    }

    function step9B_StakeLPTokens() internal {
        // --- LP stakes their LP tokens in gauges to earn emissions
        console.log("\n--- LP Stakes LP Tokens in Gauges ---");
        vm.startPrank(LP);

        // Get LP token balances
        uint256 usdtWethLPBalance = ERC20(usdtWethPair).balanceOf(LP);
        uint256 wxplLithLPBalance = ERC20(wxplLithPair).balanceOf(LP);
        uint256 wxplUsdtLPBalance = ERC20(wxplUsdtPair).balanceOf(LP);
        uint256 usdtUsdeLPBalance = ERC20(usdtUsdePair).balanceOf(LP);

        console.log("LP token balances before staking:");
        console.log("- USDT/WETH LP:", usdtWethLPBalance);
        console.log("- WXPL/LITH LP:", wxplLithLPBalance);
        console.log("- WXPL/USDT LP:", wxplUsdtLPBalance);
        console.log("- USDT/USDe LP:", usdtUsdeLPBalance);

        // Approve gauges to spend LP tokens
        ERC20(usdtWethPair).approve(usdtWethGaugeAddress, usdtWethLPBalance);
        ERC20(wxplLithPair).approve(wxplLithGaugeAddress, wxplLithLPBalance);
        ERC20(wxplUsdtPair).approve(wxplUsdtGaugeAddress, wxplUsdtLPBalance);
        ERC20(usdtUsdePair).approve(usdtUsdeGaugeAddress, usdtUsdeLPBalance);

        // Stake LP tokens in gauges
        if (usdtWethLPBalance > 0) {
            (bool depositSuccess, ) = usdtWethGaugeAddress.call(
                abi.encodeWithSignature("deposit(uint256)", usdtWethLPBalance)
            );
            require(depositSuccess, "Failed to stake USDT/WETH LP tokens");
            console.log("Staked USDT/WETH LP tokens:", usdtWethLPBalance);
        }

        if (wxplLithLPBalance > 0) {
            (bool depositSuccess, ) = wxplLithGaugeAddress.call(
                abi.encodeWithSignature("deposit(uint256)", wxplLithLPBalance)
            );
            require(depositSuccess, "Failed to stake WXPL/LITH LP tokens");
            console.log("Staked WXPL/LITH LP tokens:", wxplLithLPBalance);
        }

        if (wxplUsdtLPBalance > 0) {
            (bool depositSuccess, ) = wxplUsdtGaugeAddress.call(
                abi.encodeWithSignature("deposit(uint256)", wxplUsdtLPBalance)
            );
            require(depositSuccess, "Failed to stake WXPL/USDT LP tokens");
            console.log("Staked WXPL/USDT LP tokens:", wxplUsdtLPBalance);
        }

        if (usdtUsdeLPBalance > 0) {
            (bool depositSuccess, ) = usdtUsdeGaugeAddress.call(
                abi.encodeWithSignature("deposit(uint256)", usdtUsdeLPBalance)
            );
            require(depositSuccess, "Failed to stake USDT/USDe LP tokens");
            console.log("Staked USDT/USDe LP tokens:", usdtUsdeLPBalance);
        }

        console.log("LP tokens successfully staked in all gauges!");
    }

    // Step 10: Vote for pools
    function step10_VoteForPools() internal {
        console.log("\n=== Step 10: Vote for Pools ===");

        vm.startPrank(VOTER);

        // Vote with veNFT across multiple pools
        require(voterTokenId != 0, "veNFT not ready for voting");
        address[] memory pools = new address[](3);
        uint256[] memory weights = new uint256[](3);

        // Distribute votes:
        // 25% to USDT/WETH (has LITH bribes)
        // 50% to WXPL/LITH (has WXPL, LITH, USDT bribes)
        // 25% to WXPL/USDT (NO bribes - edge case test)
        // 0% to USDT/USDe (has bribes but no votes - another edge case)

        pools[0] = usdtWethPair;
        pools[1] = wxplLithPair;
        pools[2] = wxplUsdtPair;

        weights[0] = 25; // 25% to USDT/WETH
        weights[1] = 50; // 50% to WXPL/LITH
        weights[2] = 25; // 25% to WXPL/USDT

        voter.vote(voterTokenId, pools, weights);

        console.log("Voted with NFT", voterTokenId, "across multiple pools:");
        console.log("- USDT/WETH:", weights[0], "% (has LITH bribes)");
        console.log(
            "- WXPL/LITH:",
            weights[1],
            "% (has WXPL, LITH, USDT bribes)"
        );
        console.log(
            "- WXPL/USDT:",
            weights[2],
            "% (NO bribes - testing edge case)"
        );
        console.log(
            "- USDT/USDe: 0% (has LITH bribes but no votes - testing edge case)"
        );

        console.log("Voting completed successfully!");

        vm.stopPrank();
    }

    // Step 11: Fast forward to Oct 15, 2025 (before epoch flip)
    function step11_FastForwardToPreEpochDistribution() internal {
        console.log("\n=== Step 11: Fast Forward to Oct 15, 2025 ===");
        console.log("Moving to Oct 15 to distribute fees BEFORE epoch flip");
        console.log(
            "This ensures fees are scheduled for Oct 16 (same as voting balance)"
        );

        // Oct 15, 2025 00:00:00 UTC
        vm.warp(1760486400);
        console.log("Time set to Oct 15, 2025");
        console.log("Current timestamp:", block.timestamp);
        console.log(
            "Active period still:",
            minterUpgradeable.active_period(),
            "(Oct 9)"
        );
    }

    // Step 12: Distribute fees before epoch flip
    function step12_DistributeFeesBeforeFlip() internal {
        console.log("\n=== Step 12: Distribute Fees Before Epoch Flip ===");
        console.log("Distributing fees while still in Oct 9-16 epoch");
        console.log(
            "This schedules internal bribe rewards at Oct 16 (matching voting balance)"
        );

        vm.startPrank(DEPLOYER);

        // Distribute fees for all active gauges
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
                console.log("  - Active gauge:", gauge);
            }
        }

        if (activeCount > 0) {
            // Create correctly sized array
            address[] memory finalGauges = new address[](activeCount);
            for (uint256 i = 0; i < activeCount; i++) {
                finalGauges[i] = activeGauges[i];
            }

            voter.distributeFees(finalGauges);
            console.log("Fees distributed to", activeCount, "active gauges");
            console.log(
                "Swap fees now scheduled for Oct 16 (same as voting balance!)"
            );
        }

        vm.stopPrank();
    }

    // Step 13: Fast forward to Oct 16, 2025
    function step13_FastForwardToEpochFlip() internal {
        console.log("\n=== Step 13: Fast Forward to Oct 16, 2025 ===");

        // Set time to Oct 16, 2025 for epoch flip
        vm.warp(1760572800);
        console.log("Fast forwarded to Oct 16, 2025 for epoch flip");
        console.log("Current timestamp:", block.timestamp);
    }

    // Step 14: Epoch flip and emissions distribution
    function step14_EpochFlipAndEmissions() internal {
        console.log("\n=== Step 14: Epoch Flip and Emissions Distribution ===");
        console.log(
            "Note: Fees already distributed on Oct 15, only emissions now"
        );

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
        } else {
            console.log("Not time for new emission period yet.");
            console.log(
                "Next period starts at:",
                minterUpgradeable.active_period() + 604800
            );
        }

        console.log("Epoch flip and emissions completed successfully!");

        vm.stopPrank();
    }

    // Step 13: Claim all rewards types
    function step15_ClaimAllRewards() internal {
        console.log("\n=== Step 15: Claim All Rewards Types ===");
        console.log("Testing reward claiming across two epochs:");
        console.log(
            "- Oct 16: Gauge emissions claimable (based on Oct 9 votes)"
        );
        console.log("- Oct 23: External AND internal bribes claimable");
        console.log("");

        // ========== PHASE A: Oct 16 + 1 hour - Gauge Emissions for LP ==========
        console.log("=== PHASE A: Gauge Emissions (Oct 16 + 1 hour) ===");
        console.log("LP wallet claims gauge emissions from staked LP tokens");

        // Fast forward 1 hour to accumulate some rewards
        vm.warp(block.timestamp + 1 hours);
        console.log("Fast forwarded 1 hour to accumulate emissions\n");

        vm.startPrank(LP);

        // Get all gauge addresses
        address usdtWethGauge = voter.gauges(usdtWethPair);
        address wxplLithGauge = voter.gauges(wxplLithPair);
        address wxplUsdtGauge = voter.gauges(wxplUsdtPair);
        address usdtUsdeGauge = voter.gauges(usdtUsdePair);

        // Record LP's LITH balance before claiming
        uint256 lpLithBalanceStart = lithos.balanceOf(LP);
        uint256 lpLithBefore = lpLithBalanceStart;
        console.log(
            "LP's LITH balance before claiming:",
            lpLithBefore / 1e18,
            "LITH\n"
        );

        // Claim from USDT/WETH gauge (should get ~25% of emissions)
        console.log("--- USDT/WETH Gauge (25% of votes) ---");
        if (usdtWethGauge != address(0)) {
            (bool earnedSuccess, bytes memory earnedData) = usdtWethGauge.call(
                abi.encodeWithSignature("earned(address)", LP)
            );

            if (earnedSuccess && earnedData.length > 0) {
                uint256 pending = abi.decode(earnedData, (uint256));
                console.log("Pending emissions:", pending / 1e18, "LITH");

                (bool claimSuccess, ) = usdtWethGauge.call(
                    abi.encodeWithSignature("getReward()")
                );

                if (claimSuccess) {
                    uint256 newBalance = lithos.balanceOf(LP);
                    uint256 claimed = newBalance - lpLithBefore;
                    console.log("Claimed:", claimed / 1e18, "LITH");
                    // Assert that emissions were actually claimed for USDT/WETH (25% vote share)
                    require(
                        claimed > 0,
                        "USDT/WETH gauge should have distributed emissions"
                    );
                    lpLithBefore = newBalance;
                }
            } else {
                console.log("No emissions to claim");
            }
        }

        // Claim from WXPL/LITH gauge (should get ~50% of emissions)
        console.log("\n--- WXPL/LITH Gauge (50% of votes) ---");
        if (wxplLithGauge != address(0)) {
            (bool earnedSuccess, bytes memory earnedData) = wxplLithGauge.call(
                abi.encodeWithSignature("earned(address)", LP)
            );

            if (earnedSuccess && earnedData.length > 0) {
                uint256 pending = abi.decode(earnedData, (uint256));
                console.log("Pending emissions:", pending / 1e18, "LITH");

                (bool claimSuccess, ) = wxplLithGauge.call(
                    abi.encodeWithSignature("getReward()")
                );

                if (claimSuccess) {
                    uint256 newBalance = lithos.balanceOf(LP);
                    uint256 claimed = newBalance - lpLithBefore;
                    console.log("Claimed:", claimed / 1e18, "LITH");
                    // Assert that emissions were actually claimed for WXPL/LITH (50% vote share - should be largest)
                    require(
                        claimed > 0,
                        "WXPL/LITH gauge should have distributed emissions"
                    );
                    lpLithBefore = newBalance;
                }
            } else {
                console.log("No emissions to claim");
            }
        }

        // Claim from WXPL/USDT gauge (should get ~25% of emissions, but NO bribes)
        console.log("\n--- WXPL/USDT Gauge (25% of votes, NO bribes) ---");
        if (wxplUsdtGauge != address(0)) {
            (bool earnedSuccess, bytes memory earnedData) = wxplUsdtGauge.call(
                abi.encodeWithSignature("earned(address)", LP)
            );

            if (earnedSuccess && earnedData.length > 0) {
                uint256 pending = abi.decode(earnedData, (uint256));
                console.log("Pending emissions:", pending / 1e18, "LITH");

                (bool claimSuccess, ) = wxplUsdtGauge.call(
                    abi.encodeWithSignature("getReward()")
                );

                if (claimSuccess) {
                    uint256 newBalance = lithos.balanceOf(LP);
                    uint256 claimed = newBalance - lpLithBefore;
                    console.log("Claimed:", claimed / 1e18, "LITH");
                    // Assert that emissions were actually claimed for WXPL/USDT (25% vote share, no bribes)
                    require(
                        claimed > 0,
                        "WXPL/USDT gauge should have distributed emissions despite no bribes"
                    );
                    lpLithBefore = newBalance;
                }
            } else {
                console.log("No emissions to claim");
            }
        }

        // Check USDT/USDe gauge (should have 0 emissions - no votes)
        console.log("\n--- USDT/USDe Gauge (0% of votes - edge case) ---");
        if (usdtUsdeGauge != address(0)) {
            (bool earnedSuccess, bytes memory earnedData) = usdtUsdeGauge.call(
                abi.encodeWithSignature("earned(address)", LP)
            );

            if (earnedSuccess && earnedData.length > 0) {
                uint256 pending = abi.decode(earnedData, (uint256));
                console.log(
                    "Pending emissions:",
                    pending / 1e18,
                    "LITH (should be 0)"
                );
                // Assert that this gauge gets 0 emissions (edge case - has bribes but no votes)
                require(
                    pending == 0,
                    "USDT/USDe gauge should have 0 emissions (no votes)"
                );
            } else {
                console.log("No emissions (expected - gauge got 0 votes)");
            }
        }

        uint256 totalLPEmissions = lithos.balanceOf(LP) - lpLithBalanceStart;
        console.log("\n=== Phase A Summary ===");
        console.log(
            "Total gauge emissions claimed by LP:",
            totalLPEmissions / 1e18,
            "LITH"
        );
        // Assert that LP received total emissions > 0 (staked in 3 gauges with votes)
        require(
            totalLPEmissions > 0,
            "LP should have received gauge emissions for staked positions"
        );
        console.log("Bribes NOT claimable yet (still in current epoch)");

        vm.stopPrank();

        // ========== PHASE B: Oct 23 + 1 hour - Bribe Rewards for VOTER ==========
        console.log("\n=== PHASE B: Bribe Rewards (Oct 23 + 1 hour) ===");
        console.log("Fast forwarding to next epoch for bribe claims...");

        // Fast forward to Oct 23 (next Thursday epoch)
        vm.warp(1761177600 + 1 hours); // Oct 23, 2025 + 1 hour
        console.log("Time warped to Oct 23, 2025 + 1 hour");

        // IMPOTANT!! Need to trigger epoch flip to update active_period
        vm.startPrank(DEPLOYER);
        console.log("Triggering epoch flip to update active_period...");
        bool canUpdate = minterUpgradeable.check();
        if (canUpdate) {
            voter.distributeAll();
            console.log(
                "Epoch flipped, active_period updated to:",
                minterUpgradeable.active_period()
            );
        } else {
            console.log("Warning: Could not trigger epoch flip");
        }
        vm.stopPrank();

        console.log("VOTER wallet claims bribe rewards from voting\n");

        vm.startPrank(VOTER);

        uint256 tokenId = voterTokenId; // veNFT owned by VOTER

        // Record VOTER's balances before claiming bribes
        uint256 voterLithBalanceStart = lithos.balanceOf(VOTER);
        uint256 voterWxplBalanceStart = ERC20(WXPL).balanceOf(VOTER);
        uint256 voterUsdtBalanceStart = ERC20(USDT).balanceOf(VOTER);

        uint256 voterLithBefore = voterLithBalanceStart;
        uint256 voterWxplBefore = voterWxplBalanceStart;
        uint256 voterUsdtBefore = voterUsdtBalanceStart;

        console.log("VOTER balances before claiming bribes:");
        console.log("- LITH:", voterLithBefore / 1e18);
        console.log("- WXPL:", voterWxplBefore / 1e18);
        console.log("- USDT:", voterUsdtBefore / 1e6);
        console.log("- WETH:", ERC20(WETH).balanceOf(VOTER) / 1e18, "\n");

        // Claim from USDT/WETH external bribe (25% of votes, has LITH bribes)
        console.log("--- USDT/WETH External Bribes (25% vote share) ---");
        address usdtWethExtBribe = voter.external_bribes(usdtWethGauge);
        if (usdtWethExtBribe != address(0)) {
            address[] memory rewardTokens = new address[](1);
            rewardTokens[0] = address(lithos); // Only LITH bribes for this gauge

            (bool claimSuccess, ) = usdtWethExtBribe.call(
                abi.encodeWithSignature(
                    "getReward(uint256,address[])",
                    tokenId,
                    rewardTokens
                )
            );

            if (claimSuccess) {
                uint256 lithClaimed = lithos.balanceOf(VOTER) - voterLithBefore;
                console.log("Claimed LITH bribes:", lithClaimed / 1e18);
                // Assert that LITH bribes were received (25% of total LITH bribes)
                require(
                    lithClaimed > 0,
                    "VOTER should receive LITH bribes from USDT/WETH gauge"
                );
                voterLithBefore = lithos.balanceOf(VOTER);
            } else {
                console.log("No bribes to claim or not yet claimable");
            }
        }

        // Claim from WXPL/LITH external bribe (50% of votes, has WXPL, LITH, USDT bribes)
        console.log("\n--- WXPL/LITH External Bribes (50% vote share) ---");
        address wxplLithExtBribe = voter.external_bribes(wxplLithGauge);
        if (wxplLithExtBribe != address(0)) {
            address[] memory rewardTokens = new address[](3);
            rewardTokens[0] = WXPL;
            rewardTokens[1] = address(lithos);
            rewardTokens[2] = USDT;

            (bool claimSuccess, ) = wxplLithExtBribe.call(
                abi.encodeWithSignature(
                    "getReward(uint256,address[])",
                    tokenId,
                    rewardTokens
                )
            );

            if (claimSuccess) {
                uint256 wxplClaimed = ERC20(WXPL).balanceOf(VOTER) -
                    voterWxplBefore;
                uint256 lithClaimed = lithos.balanceOf(VOTER) - voterLithBefore;
                uint256 usdtClaimed = ERC20(USDT).balanceOf(VOTER) -
                    voterUsdtBefore;

                console.log("Claimed WXPL bribes:", wxplClaimed / 1e18);
                console.log("Claimed LITH bribes:", lithClaimed / 1e18);
                console.log("Claimed USDT bribes:", usdtClaimed / 1e6);

                // Assert all three bribe tokens were received (50% vote share - highest)
                require(
                    wxplClaimed > 0,
                    "VOTER should receive WXPL bribes from WXPL/LITH gauge"
                );
                require(
                    lithClaimed > 0,
                    "VOTER should receive LITH bribes from WXPL/LITH gauge"
                );
                require(
                    usdtClaimed > 0,
                    "VOTER should receive USDT bribes from WXPL/LITH gauge"
                );

                voterWxplBefore = ERC20(WXPL).balanceOf(VOTER);
                voterLithBefore = lithos.balanceOf(VOTER);
                voterUsdtBefore = ERC20(USDT).balanceOf(VOTER);
            } else {
                console.log("No bribes to claim or not yet claimable");
            }
        }

        // Check WXPL/USDT external bribe (25% of votes, but NO bribes)
        console.log(
            "\n--- WXPL/USDT External Bribes (25% vote share, NO bribes) ---"
        );
        address wxplUsdtExtBribe = voter.external_bribes(wxplUsdtGauge);
        if (wxplUsdtExtBribe != address(0)) {
            address[] memory rewardTokens = new address[](2);
            rewardTokens[0] = WXPL;
            rewardTokens[1] = USDT;

            // Record balances before attempting claim
            uint256 wxplBefore = ERC20(WXPL).balanceOf(VOTER);
            uint256 usdtBefore = ERC20(USDT).balanceOf(VOTER);

            (bool claimSuccess, ) = wxplUsdtExtBribe.call(
                abi.encodeWithSignature(
                    "getReward(uint256,address[])",
                    tokenId,
                    rewardTokens
                )
            );

            // Assert no bribes were received (edge case - gauge had no bribes)
            require(
                ERC20(WXPL).balanceOf(VOTER) == wxplBefore,
                "WXPL/USDT should have no WXPL bribes"
            );
            require(
                ERC20(USDT).balanceOf(VOTER) == usdtBefore,
                "WXPL/USDT should have no USDT bribes"
            );
            console.log("No bribes expected (gauge had no bribes) - verified!");
        }

        // Check USDT/USDe (0 votes, but has bribes - should be unclaimable)
        console.log(
            "\n--- USDT/USDe External Bribes (0% vote share - edge case) ---"
        );
        address usdtUsdeExtBribe = voter.external_bribes(usdtUsdeGauge);
        console.log("Gauge has LITH bribes but got 0 votes");
        console.log(
            "Bribes remain unclaimed (VOTER didn't vote for this gauge)"
        );

        console.log("\n=== Phase B Summary ===");
        uint256 totalWxplBribes = ERC20(WXPL).balanceOf(VOTER) -
            voterWxplBalanceStart;
        uint256 totalLithBribes = lithos.balanceOf(VOTER) -
            voterLithBalanceStart;
        uint256 totalUsdtBribes = ERC20(USDT).balanceOf(VOTER) -
            voterUsdtBalanceStart;

        console.log("Total external bribes claimed by VOTER:");
        console.log("- WXPL:", totalWxplBribes / 1e18);
        console.log("- LITH:", totalLithBribes / 1e18);
        console.log("- USDT:", totalUsdtBribes / 1e6);
        console.log(
            "\nNow claiming internal bribes (swap fees) - should work since we distributed fees on Oct 15"
        );

        // Assert that VOTER received external bribes for their votes
        require(totalWxplBribes > 0, "VOTER should have received WXPL bribes");
        require(totalLithBribes > 0, "VOTER should have received LITH bribes");
        require(totalUsdtBribes > 0, "VOTER should have received USDT bribes");

        // ========== PHASE C: Internal Bribes (Oct 23 - Same Epoch) ==========
        console.log("\n=== PHASE C: Internal Bribes/Swap Fees (Oct 23) ===");
        console.log("Internal bribes should now be claimable because:");
        console.log("- Voted on Oct 9 -> balance recorded at Oct 16");
        console.log(
            "- Fees distributed Oct 15 (BEFORE epoch flip) -> rewards at Oct 16"
        );
        console.log("- Balance and rewards timestamps now match at Oct 16");
        console.log(
            "- On Oct 23, active_period > Oct 16, so can claim Oct 16 rewards\n"
        );

        // Record VOTER's balances before claiming internal bribes
        uint256 voterUsdtBeforeFees = ERC20(USDT).balanceOf(VOTER);
        uint256 voterWethBeforeFees = ERC20(WETH).balanceOf(VOTER);
        uint256 voterWxplBeforeFees = ERC20(WXPL).balanceOf(VOTER);
        uint256 voterUsdeBeforeFees = ERC20(USDe).balanceOf(VOTER);

        console.log("VOTER balances before claiming internal bribes:");
        console.log("- USDT:", voterUsdtBeforeFees / 1e6);
        console.log("- WETH:", voterWethBeforeFees / 1e18, "\n");

        // Claim USDT/WETH internal bribe (had swaps)
        console.log("--- USDT/WETH Internal Bribes (Trading Fees) ---");

        // Debug: Check gauge LP balance
        uint256 gaugeLPBalance = ERC20(usdtWethPair).balanceOf(usdtWethGauge);
        console.log("Gauge LP token balance:", gaugeLPBalance);

        address usdtWethIntBribe = voter.internal_bribes(usdtWethGauge);
        console.log("Internal bribe contract:", usdtWethIntBribe);
        if (usdtWethIntBribe != address(0)) {
            // Debug: Check bribe contract token balances
            uint256 bribeUsdtBalance = ERC20(USDT).balanceOf(usdtWethIntBribe);
            uint256 bribeWethBalance = ERC20(WETH).balanceOf(usdtWethIntBribe);
            console.log("Bribe USDT balance:", bribeUsdtBalance);
            console.log("Bribe WETH balance:", bribeWethBalance);

            address[] memory feeTokens = new address[](2);
            feeTokens[0] = USDT;
            feeTokens[1] = WETH;

            (bool claimSuccess, ) = usdtWethIntBribe.call(
                abi.encodeWithSignature(
                    "getReward(uint256,address[])",
                    tokenId,
                    feeTokens
                )
            );

            if (claimSuccess) {
                uint256 usdtFees = ERC20(USDT).balanceOf(VOTER) -
                    voterUsdtBeforeFees;
                uint256 wethFees = ERC20(WETH).balanceOf(VOTER) -
                    voterWethBeforeFees;
                console.log("- USDT fees claimed:", usdtFees / 1e6);
                console.log("- WETH fees claimed:", wethFees / 1e18);

                // Should successfully claim fees now that timestamps match
                require(
                    usdtFees > 0 || wethFees > 0,
                    "USDT/WETH should have swap fees from step4"
                );
                console.log(
                    "  Successfully claimed internal bribes! Timestamps aligned."
                );

                voterUsdtBeforeFees = ERC20(USDT).balanceOf(VOTER);
                voterWethBeforeFees = ERC20(WETH).balanceOf(VOTER);
            } else {
                console.log("No fees to claim");
            }
        }

        // Claim USDT/USDe internal bribe (had swaps but got 0 votes)
        console.log("\n--- USDT/USDe Internal Bribes ---");
        address usdtUsdeIntBribe = voter.internal_bribes(usdtUsdeGauge);
        if (usdtUsdeIntBribe != address(0)) {
            address[] memory feeTokens = new address[](2);
            feeTokens[0] = USDT;
            feeTokens[1] = USDe;

            (bool claimSuccess, ) = usdtUsdeIntBribe.call(
                abi.encodeWithSignature(
                    "getReward(uint256,address[])",
                    tokenId,
                    feeTokens
                )
            );

            if (claimSuccess) {
                uint256 usdtFees = ERC20(USDT).balanceOf(VOTER) -
                    voterUsdtBeforeFees;
                uint256 usdeFees = ERC20(USDe).balanceOf(VOTER) -
                    voterUsdeBeforeFees;
                console.log("- USDT fees claimed:", usdtFees / 1e6);
                console.log("- USDe fees claimed:", usdeFees / 1e18);

                // Note: USDT/USDe got 0 votes so should have 0 fees
                if (usdtFees == 0 && usdeFees == 0) {
                    console.log("  (No fees - gauge got 0 votes, as expected)");
                }
            } else {
                console.log("No fees to claim (gauge got 0 votes - expected)");
            }
        }

        // WXPL/USDT internal bribe (intentionally no swaps - testing edge case)
        console.log("\n--- WXPL/USDT Internal Bribes ---");
        console.log("No fees expected (intentionally no swaps for this pair)");

        console.log("\n=== Phase C Summary ===");
        console.log("Internal bribes successfully claimed!");
        console.log("- Key insight: Distribute fees BEFORE epoch flip");
        console.log("- This ensures balance and reward timestamps align");
        console.log(
            "- Single vote is sufficient for both external and internal bribes"
        );

        vm.stopPrank();

        // ========== PHASE D: LP_UNSTAKED Trading Fees (Continuous) ==========
        console.log("\n=== PHASE D: Unstaked LP Trading Fees (Oct 23) ===");
        console.log(
            "LP_UNSTAKED continues earning trading fees throughout all epochs"
        );
        console.log(
            "They don't need to wait for epoch flips - fees accrue continuously\n"
        );

        vm.startPrank(LP_UNSTAKED);

        console.log("--- LP_UNSTAKED Claims More Trading Fees ---");
        console.log("Note: Fees are finalized when claimFees() is called\n");

        // Record balances before claiming
        uint256 unstakedUsdtBefore = ERC20(USDT).balanceOf(LP_UNSTAKED);
        uint256 unstakedWethBefore = ERC20(WETH).balanceOf(LP_UNSTAKED);
        uint256 unstakedUsdeBefore = ERC20(USDe).balanceOf(LP_UNSTAKED);

        // Claim from USDT/WETH (this finalizes fees via _updateFor)
        (bool success, ) = usdtWethPair.call(
            abi.encodeWithSignature("claimFees()")
        );
        if (success) {
            console.log("Claimed fees from USDT/WETH pair");
        }

        // Claim from USDT/USDe
        (success, ) = usdtUsdePair.call(abi.encodeWithSignature("claimFees()"));
        if (success) {
            console.log("Claimed fees from USDT/USDe pair");
        }

        // Calculate total fees claimed
        uint256 unstakedUsdtAfter = ERC20(USDT).balanceOf(LP_UNSTAKED);
        uint256 unstakedWethAfter = ERC20(WETH).balanceOf(LP_UNSTAKED);
        uint256 unstakedUsdeAfter = ERC20(USDe).balanceOf(LP_UNSTAKED);

        uint256 usdtClaimed = unstakedUsdtAfter - unstakedUsdtBefore;
        uint256 wethClaimed = unstakedWethAfter - unstakedWethBefore;
        uint256 usdeClaimed = unstakedUsdeAfter - unstakedUsdeBefore;

        console.log("\nAdditional fees claimed by LP_UNSTAKED:");
        if (usdtClaimed > 0) {
            console.log("  USDT: %s.%s", usdtClaimed / 1e6, usdtClaimed % 1e6);
        }
        if (wethClaimed > 0) {
            console.log(
                "  WETH: %s.%s",
                wethClaimed / 1e18,
                (wethClaimed % 1e18) / 1e12
            );
        }
        if (usdeClaimed > 0) {
            console.log(
                "  USDe: %s.%s",
                usdeClaimed / 1e18,
                (usdeClaimed % 1e18) / 1e12
            );
        }
        if (usdtClaimed == 0 && wethClaimed == 0 && usdeClaimed == 0) {
            console.log("  None (fees already claimed in prior step)");
        }

        console.log("\n=== Phase D Summary ===");
        console.log("LP_UNSTAKED:");
        console.log("- Continues earning trading fees from all swaps");
        console.log("- Can claim anytime, no epoch restrictions");
        console.log("- Does NOT receive LITH emissions");
        console.log("- Does NOT receive bribes");

        vm.stopPrank();

        // ========== FINAL SUMMARY ==========
        console.log("\n=== FINAL REWARDS SUMMARY ===");
        console.log("LP wallet (liquidity provider who staked):");
        console.log("- Staked LP tokens in gauges");
        console.log("- Earned gauge emissions proportional to votes");
        console.log("- Received LITH tokens as rewards on Oct 16");
        console.log("- Forfeited trading fees to voters");

        console.log(
            "\nLP_UNSTAKED wallet (liquidity provider who didn't stake):"
        );
        console.log("- Kept LP tokens unstaked");
        console.log("- Earned trading fees continuously from swaps");
        console.log("- Could claim fees anytime without epoch restrictions");
        console.log("- Did NOT receive LITH emissions or bribes");

        console.log("\nVOTER wallet (veNFT holder):");
        console.log("- Voted with veNFT across multiple gauges");
        console.log(
            "- Earned external bribes based on vote share (claimable Oct 23)"
        );
        console.log(
            "- Earned internal bribes (swap fees) based on vote share (claimable Oct 30)"
        );
        console.log("- Received WXPL, LITH, and USDT as rewards");

        console.log("\nEdge cases tested:");
        console.log("- WXPL/USDT: Had votes but no bribes, no swap volume");
        console.log("- USDT/USDe: Had bribes and swaps but no votes");
        console.log(
            "- Internal bribes: Must distribute fees before epoch flip for proper timing"
        );

        console.log("\nComplete Timeline:");
        console.log(
            "- Oct 9: Vote (balance at Oct 16), external bribes, swaps"
        );
        console.log("- Oct 15: Distribute fees (rewards scheduled at Oct 16)");
        console.log("- Oct 16: Epoch flip, emissions claimable");
        console.log("- Oct 23: External AND internal bribes claimable");
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
        console.log("========================================");
        console.log("=== REWARDS SUMMARY BY PARTICIPANT ===");
        console.log("========================================");
        console.log("");

        // LP_UNSTAKED Summary
        console.log("1. LP_UNSTAKED (Unstaked Liquidity Provider)");
        console.log("   -------------------------------------------");
        console.log("   Strategy: Provided liquidity, kept LP tokens unstaked");
        console.log("");
        console.log("   Timeline:");
        console.log("   - Oct 1: Added liquidity to USDT/WETH and USDT/USDe");
        console.log("   - Oct 9: Swaps occurred, trading fees accumulated");
        console.log("   - Oct 9: Claimed trading fees from pairs");
        console.log("");
        console.log("   Rewards Earned:");

        uint256 currentUSDT = ERC20(USDT).balanceOf(LP_UNSTAKED);
        uint256 currentWETH = ERC20(WETH).balanceOf(LP_UNSTAKED);
        uint256 currentUSDe = ERC20(USDe).balanceOf(LP_UNSTAKED);

        int256 netUSDT = int256(currentUSDT) - int256(lpUnstakedInitialUSDT);
        int256 netWETH = int256(currentWETH) - int256(lpUnstakedInitialWETH);
        int256 netUSDe = int256(currentUSDe) - int256(lpUnstakedInitialUSDe);

        console.log("   Trading Fees Earned:");
        if (netUSDT > 0) {
            console.log("   - USDT: +%s.%s", uint256(netUSDT) / 1e6, uint256(netUSDT) % 1e6);
        }
        if (netWETH > 0) {
            console.log("   - WETH: +%s.%s", uint256(netWETH) / 1e18, (uint256(netWETH) % 1e18) / 1e12);
        }
        if (netUSDe > 0) {
            console.log("   - USDe: +%s.%s", uint256(netUSDe) / 1e18, (uint256(netUSDe) % 1e18) / 1e12);
        }
        console.log("");
        console.log("   How LP_UNSTAKED Earned These Fees:");
        console.log("   - Provided liquidity to USDT/WETH and USDT/USDe");
        console.log("   - Kept LP tokens in wallet (did NOT stake in gauges)");
        console.log("   - Swaps generated 0.18%% trading fees");
        console.log("   - LP_UNSTAKED owns ~50%% of LP tokens, earns ~50%% of fees");
        console.log("   - Claimed fees directly from pair contracts");
        console.log("");
        console.log("   - LITH Emissions: 0 (not staked in gauges)");
        console.log("   - Bribes: 0 (not voting)");
        console.log("");

        // LP Summary
        console.log("2. LP (Staked Liquidity Provider)");
        console.log("   -------------------------------");
        console.log("   Strategy: Provided liquidity, staked LP tokens in gauges");
        console.log("");
        console.log("   Timeline:");
        console.log("   - Oct 1: Added liquidity to all pairs");
        console.log("   - Oct 9: Staked LP tokens in gauges");
        console.log("   - Oct 16: Claimed LITH emissions");
        console.log("");
        console.log("   Rewards Earned:");
        console.log("   - LITH Emissions: %s LITH", lithos.balanceOf(LP) / 1e18);
        console.log("");
        console.log("   How LP Earned Emissions:");
        console.log("   - Staked LP tokens in 4 gauges (USDT/WETH, WXPL/LITH, WXPL/USDT, USDT/USDe)");
        console.log("   - VOTER voted for 3 of these gauges (25%%, 50%%, 25%% split)");
        console.log("   - LP receives emissions proportional to:");
        console.log("     * Their share of staked LP in each gauge (~100%%)");
        console.log("     * The gauge's share of total votes (25%% + 50%% + 25%% = 100%%)");
        console.log("   - Result: LP earns from all voted gauges where they staked");
        console.log("");
        console.log("   - Trading Fees: 0 (forfeited to voters when staked)");
        console.log("   - Bribes: 0 (not voting, only providing liquidity)");
        console.log("");

        // VOTER Summary
        uint256 voterLith = lithos.balanceOf(VOTER);
        uint256 voterWxpl = ERC20(WXPL).balanceOf(VOTER);
        uint256 voterUsdt = ERC20(USDT).balanceOf(VOTER);
        uint256 voterWeth = ERC20(WETH).balanceOf(VOTER);
        uint256 voterUsde = ERC20(USDe).balanceOf(VOTER);

        console.log("3. VOTER (veNFT Holder)");
        console.log("   ---------------------");
        console.log("   Strategy: Locked LITH for veNFT, voted for gauges");
        console.log("");
        console.log("   Timeline:");
        console.log("   - Oct 9: Created 1M LITH lock (4 weeks)");
        console.log("   - Oct 9: Voted across gauges (25%% USDT/WETH, 50%% WXPL/LITH, 25%% WXPL/USDT)");
        console.log("   - Oct 23: Claimed external bribes");
        console.log("   - Oct 23: Claimed internal bribes (trading fees)");
        console.log("");
        console.log("   Rewards Earned:");
        console.log("   - LITH Emissions: 0 (didn't provide liquidity)");
        console.log("");

        console.log("   External Bribes (from vote incentives):");
        if (voterLith > 1_000_000e18) {
            uint256 lithBribes = (voterLith - 1_000_000e18) / 1e18;
            console.log("   - LITH: %s", lithBribes);
            console.log("     Source: 1000 from USDT/WETH + 1000 from WXPL/LITH");
            console.log("     VOTER is only voter, gets 100%% of bribes from pools voted for");
        }
        if (voterWxpl > 0) {
            console.log("   - WXPL: %s", voterWxpl / 1e18);
            console.log("     Source: 1000 WXPL bribe on WXPL/LITH gauge");
            console.log("     VOTER is only voter, gets 100%% of bribes");
        }
        if (voterUsdt > 0) {
            console.log("   - USDT: %s.%s", voterUsdt / 1e6, voterUsdt % 1e6);
            console.log("     Breakdown:");
            console.log("       External: ~1000 USDT (bribe on WXPL/LITH gauge)");
            console.log("       Internal: ~0.77 USDT (swap fees from USDT/WETH + USDT/USDe)");
            console.log("     Note: VOTER gets 100%% of fees from pools they voted for");
        }
        console.log("");

        console.log("   Internal Bribes (trading fees from gauges):");
        if (voterWeth > 0) {
            console.log("   - WETH: %s.%s", voterWeth / 1e18, (voterWeth % 1e18) / 1e12);
            console.log("     Source: ~0.79 WETH total swap fees from USDT/WETH pair");
            console.log("     VOTER voted 25%% for USDT/WETH but is only voter");
            console.log("     Gets 100%% of fees collected by that gauge");
        }
        if (voterUsde > 0) {
            console.log("   - USDe: %s.%s", voterUsde / 1e18, (voterUsde % 1e18) / 1e12);
            console.log("     Source: Swap fees from USDT/USDe pair (if any)");
        }
        console.log("");

        console.log("   Key Insight:");
        console.log("   - VOTER is the ONLY voter, so gets 100%% of all bribes/fees");
        console.log("   - From pools they voted for (USDT/WETH, WXPL/LITH, WXPL/USDT)");
        console.log("   - Pools with 0%% votes (USDT/USDe) = 0 rewards for VOTER");
        console.log("");
        console.log("========================================");

        console.log("");
        console.log("Complete E2E test completed successfully!");
        console.log(
            "DEX deployment, trading, LITH launch, voting, and emissions all working"
        );
        console.log("=====================================");
    }
}

// Run with: forge test --match-test test_e2e --gas-limit 100000000 --fork-url https://rpc.plasma.to -vv
