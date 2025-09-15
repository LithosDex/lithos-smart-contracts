// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {VotingEscrow} from "../src/contracts/VotingEscrow.sol";
import {Lithos} from "../src/contracts/Lithos.sol";
import {VeArtProxyUpgradeable} from "../src/contracts/VeArtProxyUpgradeable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract VotingEscrowTest is Test, IERC721Receiver {
    VotingEscrow public votingEscrow;
    Lithos public lithos;
    VeArtProxyUpgradeable public artProxy;

    address public deployer;
    address public team;
    address public voter;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    uint256 constant MAXTIME = 2 * 365 * 86400; // 2 years
    uint256 constant WEEK = 1 weeks;
    uint256 constant LOCK_AMOUNT = 1000 * 1e18;
    uint256 constant LOCK_DURATION = 52 weeks; // 1 year

    event Deposit(
        address indexed provider,
        uint256 tokenId,
        uint256 value,
        uint256 indexed locktime,
        VotingEscrow.DepositType deposit_type,
        uint256 ts
    );
    event Withdraw(address indexed provider, uint256 tokenId, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    function setUp() public {
        deployer = address(this);
        team = makeAddr("team");
        voter = makeAddr("voter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

        // Deploy contracts
        lithos = new Lithos();
        artProxy = new VeArtProxyUpgradeable();
        artProxy.initialize();
        votingEscrow = new VotingEscrow(address(lithos), address(artProxy));

        // Setup initial state
        votingEscrow.setTeam(team);
        vm.prank(team);
        votingEscrow.setVoter(voter);

        // Mint tokens to users
        lithos.mint(user1, 10000 * 1e18);
        lithos.mint(user2, 10000 * 1e18);
        lithos.mint(user3, 10000 * 1e18);
        lithos.mint(user4, 10000 * 1e18);

        // Verify initial state
        assertEq(votingEscrow.token(), address(lithos));
        assertEq(votingEscrow.team(), team);
        assertEq(votingEscrow.voter(), voter);
        assertEq(votingEscrow.name(), "veLithos");
        assertEq(votingEscrow.symbol(), "veLITH");
        assertEq(votingEscrow.decimals(), 18);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // ============ Constructor and Setup Tests ============

    function test_Constructor_InitialState() public view {
        assertEq(votingEscrow.token(), address(lithos));
        assertEq(votingEscrow.voter(), address(voter)); // Initially set to deployer
        assertEq(votingEscrow.team(), address(team)); // Initially set to deployer
        assertEq(votingEscrow.artProxy(), address(artProxy));
        assertEq(votingEscrow.totalSupply(), 0);
        assertEq(votingEscrow.epoch(), 0);
        assertEq(votingEscrow.supply(), 0);
    }

    function test_SetTeam_Success() public {
        address newTeam = makeAddr("newTeam");

        vm.prank(team);
        votingEscrow.setTeam(newTeam);
        assertEq(votingEscrow.team(), newTeam);
    }

    function test_SetTeam_OnlyTeam() public {
        vm.prank(user1);
        vm.expectRevert();
        votingEscrow.setTeam(team);
    }

    function test_SetVoter_Success() public {
        vm.prank(team);
        votingEscrow.setVoter(voter);
        assertEq(votingEscrow.voter(), voter);
    }

    function test_SetVoter_OnlyTeam() public {
        vm.prank(user1);
        vm.expectRevert();
        votingEscrow.setVoter(voter);
    }

    function test_SetArtProxy_Success() public {
        VeArtProxyUpgradeable newProxy = new VeArtProxyUpgradeable();
        newProxy.initialize();

        vm.prank(team);
        votingEscrow.setArtProxy(address(newProxy));
        assertEq(votingEscrow.artProxy(), address(newProxy));
    }

    function test_SetArtProxy_OnlyTeam() public {
        vm.prank(user1);
        vm.expectRevert();
        votingEscrow.setArtProxy(address(artProxy));
    }

    // ============ veNFT Creation Tests ============

    function test_VeNFTCreation_TokenIdIncrement() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 3);

        uint256 tokenId1 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 tokenId2 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 tokenId3 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(tokenId3, 3);

        vm.stopPrank();
    }

    function test_VeNFTCreation_OwnershipAndBalance() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 initialBalance = votingEscrow.balanceOf(user1);
        assertEq(initialBalance, 0);

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), user1, 1);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        assertEq(votingEscrow.ownerOf(tokenId), user1);
        assertEq(votingEscrow.balanceOf(user1), 1);

        vm.stopPrank();
    }

    function test_VeNFTCreation_TokenProperties() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        // Check that token exists and has properties
        assertEq(votingEscrow.ownerOf(tokenId), user1);
        assertTrue(votingEscrow.balanceOfNFT(tokenId) > 0);

        // Check that token URI can be generated
        string memory uri = votingEscrow.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);

        // Check locked properties
        (int128 amount, uint256 end) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), LOCK_AMOUNT);
        assertGt(end, block.timestamp);

        vm.stopPrank();
    }

    function test_VeNFTCreation_MultipleUsers() public {
        // User1 creates veNFT
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId1 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        // User2 creates veNFT
        vm.startPrank(user2);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId2 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        // Verify ownership and balances
        assertEq(votingEscrow.ownerOf(tokenId1), user1);
        assertEq(votingEscrow.ownerOf(tokenId2), user2);
        assertEq(votingEscrow.balanceOf(user1), 1);
        assertEq(votingEscrow.balanceOf(user2), 1);

        // Verify they have different token IDs
        assertTrue(tokenId1 != tokenId2);
    }

    function test_VeNFTCreation_CreateLockFor() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), user2, 1);

        uint256 tokenId = votingEscrow.create_lock_for(LOCK_AMOUNT, LOCK_DURATION, user2);

        // Token should belong to user2, not user1 who paid
        assertEq(votingEscrow.ownerOf(tokenId), user2);
        assertEq(votingEscrow.balanceOf(user1), 0);
        assertEq(votingEscrow.balanceOf(user2), 1);

        vm.stopPrank();
    }

    function test_VeNFTCreation_VotingPowerCalculation() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 2);

        // Create two locks with different durations
        uint256 tokenId1 = votingEscrow.create_lock(LOCK_AMOUNT, WEEK);
        uint256 tokenId2 = votingEscrow.create_lock(LOCK_AMOUNT, MAXTIME);

        uint256 votingPower1 = votingEscrow.balanceOfNFT(tokenId1);
        uint256 votingPower2 = votingEscrow.balanceOfNFT(tokenId2);

        // Longer lock should have more voting power
        assertGt(votingPower2, votingPower1);

        // Both should have some voting power
        assertGt(votingPower1, 0);
        assertGt(votingPower2, 0);

        vm.stopPrank();
    }

    function test_VeNFTCreation_SupplyTracking() public {
        uint256 initialSupply = votingEscrow.totalSupply();
        uint256 initialTokenSupply = votingEscrow.supply();

        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        uint256 newTotalSupply = votingEscrow.totalSupply();
        uint256 newTokenSupply = votingEscrow.supply();

        // Total voting power supply should increase
        assertGt(newTotalSupply, initialSupply);

        // Token supply should increase by locked amount
        assertEq(newTokenSupply, initialTokenSupply + LOCK_AMOUNT);

        // Individual voting power should be less than locked amount (time decay)
        uint256 votingPower = votingEscrow.balanceOfNFT(tokenId);
        assertLt(votingPower, LOCK_AMOUNT);

        vm.stopPrank();
    }

    // ============ Lock Creation Tests ============

    function test_CreateLock_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit Deposit(
            user1,
            1,
            LOCK_AMOUNT,
            block.timestamp + LOCK_DURATION,
            VotingEscrow.DepositType.CREATE_LOCK_TYPE,
            block.timestamp
        );

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        assertEq(tokenId, 1);
        assertEq(votingEscrow.ownerOf(tokenId), user1);
        assertEq(votingEscrow.balanceOf(user1), 1);
        assertGt(votingEscrow.balanceOfNFT(tokenId), 0);

        (int128 amount, uint256 end) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), LOCK_AMOUNT);
        assertApproxEqAbs(end, block.timestamp + LOCK_DURATION, WEEK);

        vm.stopPrank();
    }

    function test_CreateLock_MinimumDuration() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, WEEK);

        (int128 amount, uint256 end) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), LOCK_AMOUNT);
        assertApproxEqAbs(end, block.timestamp + WEEK, WEEK);

        vm.stopPrank();
    }

    function test_CreateLock_MaximumDuration() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, MAXTIME);

        (int128 amount, uint256 end) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), LOCK_AMOUNT);
        assertApproxEqAbs(end, block.timestamp + MAXTIME, WEEK);

        vm.stopPrank();
    }

    function test_CreateLock_ZeroAmount() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), 0);

        vm.expectRevert();
        votingEscrow.create_lock(0, LOCK_DURATION);

        vm.stopPrank();
    }

    function test_CreateLock_TooLongDuration() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        vm.expectRevert("Voting lock can be 2 years max");
        votingEscrow.create_lock(LOCK_AMOUNT, MAXTIME + WEEK);

        vm.stopPrank();
    }

    function test_CreateLock_InsufficientApproval() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT - 1);

        vm.expectRevert();
        votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        vm.stopPrank();
    }

    function test_CreateLockFor_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock_for(LOCK_AMOUNT, LOCK_DURATION, user2);

        assertEq(tokenId, 1);
        assertEq(votingEscrow.ownerOf(tokenId), user2);
        assertEq(votingEscrow.balanceOf(user2), 1);
        assertEq(votingEscrow.balanceOf(user1), 0);

        vm.stopPrank();
    }

    // ============ Deposit and Increase Tests ============

    function test_DepositFor_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 2);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 initialBalance = votingEscrow.balanceOfNFT(tokenId);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, tokenId, LOCK_AMOUNT, 0, VotingEscrow.DepositType.DEPOSIT_FOR_TYPE, block.timestamp);

        votingEscrow.deposit_for(tokenId, LOCK_AMOUNT);

        (int128 amount,) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), LOCK_AMOUNT * 2);
        assertGt(votingEscrow.balanceOfNFT(tokenId), initialBalance);

        vm.stopPrank();
    }

    function test_DepositFor_AnyoneCanDeposit() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        // Anyone can deposit for any token - this is intentional design
        vm.startPrank(user2);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 initialBalance = votingEscrow.balanceOfNFT(tokenId);

        votingEscrow.deposit_for(tokenId, LOCK_AMOUNT);

        (int128 amount,) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), LOCK_AMOUNT * 2);
        assertGt(votingEscrow.balanceOfNFT(tokenId), initialBalance);

        vm.stopPrank();
    }

    function test_IncreaseAmount_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 2);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        votingEscrow.increase_amount(tokenId, LOCK_AMOUNT);

        (int128 amount,) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), LOCK_AMOUNT * 2);

        vm.stopPrank();
    }

    function test_IncreaseUnlockTime_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        (, uint256 initialEnd) = votingEscrow.locked(tokenId);

        votingEscrow.increase_unlock_time(tokenId, LOCK_DURATION * 2);

        (, uint256 newEnd) = votingEscrow.locked(tokenId);
        assertGt(newEnd, initialEnd);

        vm.stopPrank();
    }

    // ============ Withdraw Tests ============

    function test_Withdraw_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, WEEK);

        // Fast forward past lock expiration
        vm.warp(block.timestamp + WEEK + 1);

        uint256 balanceBefore = lithos.balanceOf(user1);

        vm.expectEmit(true, false, false, true);
        emit Withdraw(user1, tokenId, LOCK_AMOUNT, block.timestamp);

        votingEscrow.withdraw(tokenId);

        assertEq(lithos.balanceOf(user1), balanceBefore + LOCK_AMOUNT);
        assertEq(votingEscrow.balanceOf(user1), 0);

        // Check that token is burned - ownerOf returns address(0)
        assertEq(votingEscrow.ownerOf(tokenId), address(0));

        // Check that locked amount is zero
        (int128 amount, uint256 end) = votingEscrow.locked(tokenId);
        assertEq(uint256(int256(amount)), 0);
        assertEq(end, 0);

        vm.stopPrank();
    }

    function test_Withdraw_LockNotExpired() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        vm.expectRevert();
        votingEscrow.withdraw(tokenId);

        vm.stopPrank();
    }

    function test_Withdraw_NotOwner() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, WEEK);
        vm.stopPrank();

        vm.warp(block.timestamp + WEEK + 1);

        vm.startPrank(user2);
        vm.expectRevert();
        votingEscrow.withdraw(tokenId);

        vm.stopPrank();
    }

    // ============ Voting Power Tests ============

    function test_BalanceOfNFT_DecreasesOverTime() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, MAXTIME);

        uint256 initialBalance = votingEscrow.balanceOfNFT(tokenId);

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 laterBalance = votingEscrow.balanceOfNFT(tokenId);

        assertLt(laterBalance, initialBalance);
        assertGt(laterBalance, 0);

        vm.stopPrank();
    }

    function test_BalanceOfNFTAt_HistoricalQuery() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 timestamp1 = block.timestamp;
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, MAXTIME);
        uint256 balance1 = votingEscrow.balanceOfNFT(tokenId);

        vm.warp(timestamp1 + 365 days);
        uint256 balance2 = votingEscrow.balanceOfNFT(tokenId);

        // Query historical balance
        uint256 historicalBalance = votingEscrow.balanceOfNFTAt(tokenId, timestamp1);

        assertApproxEqAbs(historicalBalance, balance1, 1e15); // Small margin for rounding
        assertLt(balance2, balance1);

        vm.stopPrank();
    }

    function test_TotalSupply_TracksAllLocks() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId1 = votingEscrow.create_lock(LOCK_AMOUNT, MAXTIME);
        uint256 totalAfterFirst = votingEscrow.totalSupply();
        vm.stopPrank();

        vm.startPrank(user2);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId2 = votingEscrow.create_lock(LOCK_AMOUNT, MAXTIME);
        uint256 totalAfterSecond = votingEscrow.totalSupply();
        vm.stopPrank();

        assertGt(totalAfterFirst, 0);
        assertGt(totalAfterSecond, totalAfterFirst);

        // Verify individual balances sum approximately to total
        uint256 sum = votingEscrow.balanceOfNFT(tokenId1) + votingEscrow.balanceOfNFT(tokenId2);
        assertApproxEqAbs(sum, totalAfterSecond, 1e15);
    }

    // ============ ERC721 Tests ============

    function test_Transfer_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        vm.expectEmit(true, true, true, false);
        emit Transfer(user1, user2, tokenId);

        votingEscrow.transferFrom(user1, user2, tokenId);

        assertEq(votingEscrow.ownerOf(tokenId), user2);
        assertEq(votingEscrow.balanceOf(user1), 0);
        assertEq(votingEscrow.balanceOf(user2), 1);

        vm.stopPrank();
    }

    function test_Transfer_NotOwner() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert();
        votingEscrow.transferFrom(user1, user2, tokenId);
        vm.stopPrank();
    }

    function test_Approve_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        vm.expectEmit(true, true, true, false);
        emit Approval(user1, user2, tokenId);

        votingEscrow.approve(user2, tokenId);

        assertEq(votingEscrow.getApproved(tokenId), user2);

        vm.stopPrank();

        // User2 can now transfer
        vm.prank(user2);
        votingEscrow.transferFrom(user1, user2, tokenId);
        assertEq(votingEscrow.ownerOf(tokenId), user2);
    }

    function test_ApproveAll_Success() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(user1, user2, true);

        votingEscrow.setApprovalForAll(user2, true);

        assertTrue(votingEscrow.isApprovedForAll(user1, user2));

        vm.stopPrank();
    }

    // ============ Merge and Split Tests ============

    function test_Merge_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 2);

        uint256 tokenId1 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 tokenId2 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        (int128 amount1Before,) = votingEscrow.locked(tokenId1);
        (int128 amount2Before,) = votingEscrow.locked(tokenId2);

        assertEq(votingEscrow.balanceOf(user1), 2); // Two NFTs initially

        votingEscrow.merge(tokenId1, tokenId2);

        (int128 amount2After,) = votingEscrow.locked(tokenId2);

        // Check that amounts were combined
        assertEq(uint256(int256(amount2After)), uint256(int256(amount1Before)) + uint256(int256(amount2Before)));

        // Check that one NFT was burned
        assertEq(votingEscrow.balanceOf(user1), 1);

        // Check that the first token's locked amount is zero (burned)
        (int128 amount1After,) = votingEscrow.locked(tokenId1);
        assertEq(uint256(int256(amount1After)), 0);

        vm.stopPrank();
    }

    function test_Split_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LOCK_AMOUNT / 2;
        amounts[1] = LOCK_AMOUNT / 2;

        uint256 initialBalance = votingEscrow.balanceOf(user1);

        votingEscrow.split(amounts, tokenId);

        assertEq(votingEscrow.balanceOf(user1), initialBalance + 1); // One additional NFT

        vm.stopPrank();
    }

    // ============ Delegation Tests ============

    function test_Delegate_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        vm.expectEmit(true, true, true, false);
        emit DelegateChanged(user1, user1, user2); // Auto-delegation to self initially

        votingEscrow.delegate(user2);

        assertEq(votingEscrow.delegates(user1), user2);

        vm.stopPrank();
    }

    function test_GetVotes_AfterDelegation() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        uint256 votingPower = votingEscrow.balanceOfNFT(tokenId);

        // Initially self-delegated
        assertApproxEqAbs(votingEscrow.getVotes(user1), votingPower, 1e15);
        assertEq(votingEscrow.getVotes(user2), 0);

        // Delegate to user2
        votingEscrow.delegate(user2);

        assertEq(votingEscrow.getVotes(user1), 0);
        assertApproxEqAbs(votingEscrow.getVotes(user2), votingPower, 1e15);

        vm.stopPrank();
    }

    // ============ Voting and Attachment Tests ============

    function test_Voting_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        vm.prank(voter);
        votingEscrow.voting(tokenId);

        assertTrue(votingEscrow.voted(tokenId));
    }

    function test_Voting_OnlyVoter() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        vm.expectRevert();
        votingEscrow.voting(tokenId);

        vm.stopPrank();
    }

    function test_Abstain_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        vm.startPrank(voter);
        votingEscrow.voting(tokenId);
        assertTrue(votingEscrow.voted(tokenId));

        votingEscrow.abstain(tokenId);
        assertFalse(votingEscrow.voted(tokenId));

        vm.stopPrank();
    }

    function test_Attach_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        vm.prank(voter);
        votingEscrow.attach(tokenId);

        assertEq(votingEscrow.attachments(tokenId), 1);
    }

    function test_Transfer_BlockedWhenVoted() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        vm.prank(voter);
        votingEscrow.voting(tokenId);

        vm.startPrank(user1);
        vm.expectRevert();
        votingEscrow.transferFrom(user1, user2, tokenId);
        vm.stopPrank();
    }

    function test_Transfer_BlockedWhenAttached() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        vm.stopPrank();

        vm.prank(voter);
        votingEscrow.attach(tokenId);

        vm.startPrank(user1);
        vm.expectRevert();
        votingEscrow.transferFrom(user1, user2, tokenId);
        vm.stopPrank();
    }

    // ============ Token URI Tests ============

    function test_TokenURI_Success() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        string memory uri = votingEscrow.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);

        vm.stopPrank();
    }

    function test_TokenURI_NonExistentToken() public {
        vm.expectRevert();
        votingEscrow.tokenURI(999);
    }

    // ============ Supply and Checkpoint Tests ============

    function test_Supply_UpdatesOnDeposit() public {
        uint256 initialSupply = votingEscrow.supply();

        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        vm.expectEmit(false, false, false, true);
        emit Supply(initialSupply, LOCK_AMOUNT);

        votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        assertEq(votingEscrow.supply(), LOCK_AMOUNT);

        vm.stopPrank();
    }

    function test_Supply_UpdatesOnWithdraw() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, WEEK);

        assertEq(votingEscrow.supply(), LOCK_AMOUNT);

        vm.warp(block.timestamp + WEEK + 1);
        votingEscrow.withdraw(tokenId);

        assertEq(votingEscrow.supply(), 0);

        vm.stopPrank();
    }

    // ============ Edge Cases and Error Conditions ============

    function test_EdgeCase_ZeroLockDuration() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        vm.expectRevert();
        votingEscrow.create_lock(LOCK_AMOUNT, 0);

        vm.stopPrank();
    }

    function test_EdgeCase_PastLockTime() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        vm.expectRevert();
        votingEscrow.create_lock_for(LOCK_AMOUNT, block.timestamp - 1, user2);

        vm.stopPrank();
    }

    function test_EdgeCase_MultipleLocksPerUser() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 3);

        uint256 tokenId1 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 tokenId2 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION * 2);
        uint256 tokenId3 = votingEscrow.create_lock(LOCK_AMOUNT, WEEK);

        assertEq(votingEscrow.balanceOf(user1), 3);
        assertEq(votingEscrow.ownerOf(tokenId1), user1);
        assertEq(votingEscrow.ownerOf(tokenId2), user1);
        assertEq(votingEscrow.ownerOf(tokenId3), user1);

        vm.stopPrank();
    }

    // ============ Integration Tests ============

    function test_Integration_CompleteLifecycle() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 2);

        // Create lock
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 initialBalance = votingEscrow.balanceOfNFT(tokenId);

        // Increase amount
        votingEscrow.increase_amount(tokenId, LOCK_AMOUNT);
        assertGt(votingEscrow.balanceOfNFT(tokenId), initialBalance);

        // Delegate
        votingEscrow.delegate(user2);
        assertEq(votingEscrow.delegates(user1), user2);

        // Transfer
        votingEscrow.transferFrom(user1, user3, tokenId);
        assertEq(votingEscrow.ownerOf(tokenId), user3);

        vm.stopPrank();

        // Vote (as voter)
        vm.prank(voter);
        votingEscrow.voting(tokenId);
        assertTrue(votingEscrow.voted(tokenId));

        // Cannot transfer when voted
        vm.startPrank(user3);
        vm.expectRevert();
        votingEscrow.transferFrom(user3, user4, tokenId);
        vm.stopPrank();

        // Abstain
        vm.prank(voter);
        votingEscrow.abstain(tokenId);
        assertFalse(votingEscrow.voted(tokenId));

        // Can transfer again
        vm.prank(user3);
        votingEscrow.transferFrom(user3, user4, tokenId);
        assertEq(votingEscrow.ownerOf(tokenId), user4);
    }

    function test_Integration_MergeAndSplit() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT * 4);

        // Create multiple locks
        uint256 tokenId1 = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 tokenId2 = votingEscrow.create_lock(LOCK_AMOUNT * 2, LOCK_DURATION);

        assertEq(votingEscrow.balanceOf(user1), 2);

        // Merge
        votingEscrow.merge(tokenId1, tokenId2);
        assertEq(votingEscrow.balanceOf(user1), 1);

        (int128 mergedAmount,) = votingEscrow.locked(tokenId2);
        assertEq(uint256(int256(mergedAmount)), LOCK_AMOUNT * 3);

        // Split
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = LOCK_AMOUNT;
        amounts[1] = LOCK_AMOUNT * 2;

        votingEscrow.split(amounts, tokenId2);
        assertEq(votingEscrow.balanceOf(user1), 2);

        vm.stopPrank();
    }

    // ============ Gas Optimization Tests ============

    function test_Gas_CreateLock() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);

        uint256 gasBefore = gasleft();
        votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(gasUsed < 500000); // Reasonable gas limit

        vm.stopPrank();
    }

    function test_Gas_Transfer() public {
        vm.startPrank(user1);
        lithos.approve(address(votingEscrow), LOCK_AMOUNT);
        uint256 tokenId = votingEscrow.create_lock(LOCK_AMOUNT, LOCK_DURATION);

        uint256 gasBefore = gasleft();
        votingEscrow.transferFrom(user1, user2, tokenId);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(gasUsed < 200000); // Reasonable gas limit

        vm.stopPrank();
    }

    // ============ ERC165 Support Tests ============

    function test_SupportsInterface() public view {
        assertTrue(votingEscrow.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(votingEscrow.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(votingEscrow.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertFalse(votingEscrow.supportsInterface(0x12345678)); // Random interface
    }
}
