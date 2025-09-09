// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {Lithos} from "../src/contracts/Lithos.sol";

contract LithosTest is Test {
    Lithos public lithos;

    address public deployer;
    address public minter;
    address public user1;
    address public user2;
    address public user3;
    address public recipient;

    uint256 constant INITIAL_MINT_AMOUNT = 50 * 1e6 * 1e18; // 50M tokens

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        deployer = address(this);
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        recipient = makeAddr("recipient");

        lithos = new Lithos();

        // Verify initial state
        assertEq(lithos.name(), "Lithos");
        assertEq(lithos.symbol(), "LITHOS");
        assertEq(lithos.decimals(), 18);
        assertEq(lithos.totalSupply(), 0);
        assertEq(lithos.minter(), deployer);
        assertFalse(lithos.initialMinted());
    }

    // ============ Constructor Tests ============

    function test_Constructor_InitialState() public {
        assertEq(lithos.name(), "Lithos");
        assertEq(lithos.symbol(), "LITHOS");
        assertEq(lithos.decimals(), 18);
        assertEq(lithos.totalSupply(), 0);
        assertEq(lithos.minter(), deployer);
        assertFalse(lithos.initialMinted());
        assertEq(lithos.balanceOf(deployer), 0);
    }

    // ============ Minter Management Tests ============

    function test_SetMinter_Success() public {
        lithos.setMinter(minter);

        assertEq(lithos.minter(), minter);
    }

    function test_SetMinter_OnlyCurrentMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        lithos.setMinter(minter);
    }

    function test_SetMinter_CanSetMultipleTimes() public {
        lithos.setMinter(minter);
        assertEq(lithos.minter(), minter);

        vm.prank(minter);
        lithos.setMinter(user1);
        assertEq(lithos.minter(), user1);
    }

    function test_SetMinter_ZeroAddress() public {
        lithos.setMinter(address(0));
        assertEq(lithos.minter(), address(0));
    }

    // ============ Initial Mint Tests ============

    function test_InitialMint_Success() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), recipient, INITIAL_MINT_AMOUNT);

        lithos.initialMint(recipient);

        assertTrue(lithos.initialMinted());
        assertEq(lithos.totalSupply(), INITIAL_MINT_AMOUNT);
        assertEq(lithos.balanceOf(recipient), INITIAL_MINT_AMOUNT);
    }

    function test_InitialMint_OnlyMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        lithos.initialMint(recipient);
    }

    function test_InitialMint_OnlyOnce() public {
        lithos.initialMint(recipient);

        vm.expectRevert();
        lithos.initialMint(user1);
    }

    function test_InitialMint_ToZeroAddress() public {
        lithos.initialMint(address(0));

        assertTrue(lithos.initialMinted());
        assertEq(lithos.totalSupply(), INITIAL_MINT_AMOUNT);
        assertEq(lithos.balanceOf(address(0)), INITIAL_MINT_AMOUNT);
    }

    function test_InitialMint_AfterMinterChange() public {
        lithos.setMinter(minter);

        vm.prank(deployer);
        vm.expectRevert();
        lithos.initialMint(recipient);

        vm.prank(minter);
        lithos.initialMint(recipient);

        assertTrue(lithos.initialMinted());
        assertEq(lithos.balanceOf(recipient), INITIAL_MINT_AMOUNT);
    }

    // ============ Regular Mint Tests ============

    function test_Mint_Success() public {
        uint256 amount = 1000 * 1e18;

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, amount);

        assertTrue(lithos.mint(user1, amount));

        assertEq(lithos.totalSupply(), amount);
        assertEq(lithos.balanceOf(user1), amount);
    }

    function test_Mint_OnlyMinter() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(user1);
        vm.expectRevert("not allowed");
        lithos.mint(user1, amount);
    }

    function test_Mint_MultipleAmounts() public {
        uint256 amount1 = 1000 * 1e18;
        uint256 amount2 = 500 * 1e18;

        lithos.mint(user1, amount1);
        lithos.mint(user2, amount2);

        assertEq(lithos.totalSupply(), amount1 + amount2);
        assertEq(lithos.balanceOf(user1), amount1);
        assertEq(lithos.balanceOf(user2), amount2);
    }

    function test_Mint_ToSameAddress() public {
        uint256 amount1 = 1000 * 1e18;
        uint256 amount2 = 500 * 1e18;

        lithos.mint(user1, amount1);
        lithos.mint(user1, amount2);

        assertEq(lithos.totalSupply(), amount1 + amount2);
        assertEq(lithos.balanceOf(user1), amount1 + amount2);
    }

    function test_Mint_ZeroAmount() public {
        assertTrue(lithos.mint(user1, 0));

        assertEq(lithos.totalSupply(), 0);
        assertEq(lithos.balanceOf(user1), 0);
    }

    function test_Mint_MaxAmount() public {
        // First mint a small amount to set totalSupply > 0
        lithos.mint(user1, 1);

        uint256 maxAmount = type(uint256).max;

        vm.expectRevert(); // Should overflow when adding to totalSupply
        lithos.mint(user2, maxAmount);
    }

    function test_Mint_AfterMinterChange() public {
        lithos.setMinter(minter);
        uint256 amount = 1000 * 1e18;

        vm.prank(deployer);
        vm.expectRevert("not allowed");
        lithos.mint(user1, amount);

        vm.prank(minter);
        assertTrue(lithos.mint(user1, amount));
        assertEq(lithos.balanceOf(user1), amount);
    }

    // ============ Transfer Tests ============

    function test_Transfer_Success() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.startPrank(user1);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 500 * 1e18);

        assertTrue(lithos.transfer(user2, 500 * 1e18));

        assertEq(lithos.balanceOf(user1), 500 * 1e18);
        assertEq(lithos.balanceOf(user2), 500 * 1e18);

        vm.stopPrank();
    }

    function test_Transfer_InsufficientBalance() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        vm.expectRevert(); // Underflow
        lithos.transfer(user2, amount + 1);
    }

    function test_Transfer_ZeroAmount() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        assertTrue(lithos.transfer(user2, 0));

        assertEq(lithos.balanceOf(user1), amount);
        assertEq(lithos.balanceOf(user2), 0);
    }

    function test_Transfer_ToSelf() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        assertTrue(lithos.transfer(user1, 500 * 1e18));

        assertEq(lithos.balanceOf(user1), amount);
    }

    function test_Transfer_ToZeroAddress() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        assertTrue(lithos.transfer(address(0), 500 * 1e18));

        assertEq(lithos.balanceOf(user1), 500 * 1e18);
        assertEq(lithos.balanceOf(address(0)), 500 * 1e18);
    }

    function test_Transfer_EntireBalance() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        assertTrue(lithos.transfer(user2, amount));

        assertEq(lithos.balanceOf(user1), 0);
        assertEq(lithos.balanceOf(user2), amount);
    }

    // ============ Approval Tests ============

    function test_Approve_Success() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(user1);

        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, amount);

        assertTrue(lithos.approve(user2, amount));

        assertEq(lithos.allowance(user1, user2), amount);
    }

    function test_Approve_ZeroAmount() public {
        vm.prank(user1);
        assertTrue(lithos.approve(user2, 0));

        assertEq(lithos.allowance(user1, user2), 0);
    }

    function test_Approve_MaxAmount() public {
        uint256 maxAmount = type(uint256).max;

        vm.prank(user1);
        assertTrue(lithos.approve(user2, maxAmount));

        assertEq(lithos.allowance(user1, user2), maxAmount);
    }

    function test_Approve_OverwriteAllowance() public {
        vm.startPrank(user1);

        lithos.approve(user2, 1000 * 1e18);
        assertEq(lithos.allowance(user1, user2), 1000 * 1e18);

        lithos.approve(user2, 500 * 1e18);
        assertEq(lithos.allowance(user1, user2), 500 * 1e18);

        vm.stopPrank();
    }

    function test_Approve_MultipleSpenders() public {
        vm.startPrank(user1);

        lithos.approve(user2, 1000 * 1e18);
        lithos.approve(user3, 500 * 1e18);

        assertEq(lithos.allowance(user1, user2), 1000 * 1e18);
        assertEq(lithos.allowance(user1, user3), 500 * 1e18);

        vm.stopPrank();
    }

    // ============ TransferFrom Tests ============

    function test_TransferFrom_Success() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        lithos.approve(user2, 500 * 1e18);

        vm.prank(user2);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user3, 300 * 1e18);

        assertTrue(lithos.transferFrom(user1, user3, 300 * 1e18));

        assertEq(lithos.balanceOf(user1), 700 * 1e18);
        assertEq(lithos.balanceOf(user3), 300 * 1e18);
        assertEq(lithos.allowance(user1, user2), 200 * 1e18);
    }

    function test_TransferFrom_InsufficientAllowance() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        lithos.approve(user2, 500 * 1e18);

        vm.prank(user2);
        vm.expectRevert(); // Underflow
        lithos.transferFrom(user1, user3, 600 * 1e18);
    }

    function test_TransferFrom_InsufficientBalance() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        lithos.approve(user2, 1500 * 1e18);

        vm.prank(user2);
        vm.expectRevert(); // Underflow on balance
        lithos.transferFrom(user1, user3, 1200 * 1e18);
    }

    function test_TransferFrom_MaxAllowance() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        lithos.approve(user2, type(uint256).max);

        vm.prank(user2);
        assertTrue(lithos.transferFrom(user1, user3, 500 * 1e18));

        assertEq(lithos.balanceOf(user1), 500 * 1e18);
        assertEq(lithos.balanceOf(user3), 500 * 1e18);
        assertEq(lithos.allowance(user1, user2), type(uint256).max); // Should not decrease
    }

    function test_TransferFrom_ZeroAmount() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        lithos.approve(user2, 500 * 1e18);

        vm.prank(user2);
        assertTrue(lithos.transferFrom(user1, user3, 0));

        assertEq(lithos.balanceOf(user1), amount);
        assertEq(lithos.balanceOf(user3), 0);
        assertEq(lithos.allowance(user1, user2), 500 * 1e18);
    }

    function test_TransferFrom_NoAllowance() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user2);
        vm.expectRevert(); // Underflow on allowance
        lithos.transferFrom(user1, user3, 100 * 1e18);
    }

    function test_TransferFrom_ToSelf() public {
        uint256 amount = 1000 * 1e18;
        lithos.mint(user1, amount);

        vm.prank(user1);
        lithos.approve(user2, 500 * 1e18);

        vm.prank(user2);
        assertTrue(lithos.transferFrom(user1, user1, 300 * 1e18));

        assertEq(lithos.balanceOf(user1), amount);
        assertEq(lithos.allowance(user1, user2), 200 * 1e18);
    }

    // ============ Integration Tests ============

    function test_Integration_InitialMintAndTransfer() public {
        lithos.initialMint(recipient);

        vm.startPrank(recipient);

        // Transfer some tokens
        lithos.transfer(user1, 1000 * 1e18);

        // Approve and transferFrom
        lithos.approve(user1, 2000 * 1e18);

        vm.stopPrank();
        vm.prank(user1);

        lithos.transferFrom(recipient, user2, 1500 * 1e18);

        assertEq(lithos.balanceOf(recipient), INITIAL_MINT_AMOUNT - 1000 * 1e18 - 1500 * 1e18);
        assertEq(lithos.balanceOf(user1), 1000 * 1e18);
        assertEq(lithos.balanceOf(user2), 1500 * 1e18);
        assertEq(lithos.allowance(recipient, user1), 500 * 1e18);
    }

    function test_Integration_MinterChangeAndMint() public {
        // Set new minter
        lithos.setMinter(minter);

        // Initial mint with new minter
        vm.prank(minter);
        lithos.initialMint(recipient);

        // Regular mint with new minter
        vm.prank(minter);
        lithos.mint(user1, 1000 * 1e18);

        assertEq(lithos.totalSupply(), INITIAL_MINT_AMOUNT + 1000 * 1e18);
        assertEq(lithos.balanceOf(recipient), INITIAL_MINT_AMOUNT);
        assertEq(lithos.balanceOf(user1), 1000 * 1e18);
    }

    function test_Integration_ComplexTransferScenario() public {
        // Setup: mint to multiple users
        lithos.mint(user1, 2000 * 1e18);
        lithos.mint(user2, 1500 * 1e18);

        // User1 approves user2 and user3
        vm.startPrank(user1);
        lithos.approve(user2, 800 * 1e18);
        lithos.approve(user3, 500 * 1e18);
        vm.stopPrank();

        // User2 transfers from user1
        vm.prank(user2);
        lithos.transferFrom(user1, recipient, 600 * 1e18);

        // User3 transfers from user1
        vm.prank(user3);
        lithos.transferFrom(user1, recipient, 300 * 1e18);

        // Direct transfers
        vm.prank(user2);
        lithos.transfer(recipient, 500 * 1e18);

        assertEq(lithos.balanceOf(user1), 1100 * 1e18); // 2000 - 600 - 300
        assertEq(lithos.balanceOf(user2), 1000 * 1e18); // 1500 - 500
        assertEq(lithos.balanceOf(recipient), 1400 * 1e18); // 600 + 300 + 500
        assertEq(lithos.allowance(user1, user2), 200 * 1e18); // 800 - 600
        assertEq(lithos.allowance(user1, user3), 200 * 1e18); // 500 - 300
    }

    // ============ Edge Cases and Error Conditions ============

    function test_EdgeCase_ZeroValueOperations() public {
        // All zero value operations should succeed
        assertTrue(lithos.approve(user1, 0));
        assertTrue(lithos.transfer(user1, 0));
        assertTrue(lithos.mint(user1, 0));

        vm.prank(user1);
        assertTrue(lithos.transferFrom(deployer, user2, 0));
    }

    function test_EdgeCase_SelfOperations() public {
        lithos.mint(user1, 1000 * 1e18);

        vm.startPrank(user1);

        // Self approval
        lithos.approve(user1, 500 * 1e18);
        assertEq(lithos.allowance(user1, user1), 500 * 1e18);

        // Self transfer
        lithos.transfer(user1, 200 * 1e18);
        assertEq(lithos.balanceOf(user1), 1000 * 1e18);

        // Self transferFrom
        lithos.transferFrom(user1, user1, 100 * 1e18);
        assertEq(lithos.balanceOf(user1), 1000 * 1e18);
        assertEq(lithos.allowance(user1, user1), 400 * 1e18);

        vm.stopPrank();
    }

    function test_EdgeCase_ZeroAddressOperations() public {
        // Mint to zero address
        lithos.mint(address(0), 1000 * 1e18);
        assertEq(lithos.balanceOf(address(0)), 1000 * 1e18);

        // Approve from zero address
        vm.prank(address(0));
        lithos.approve(user1, 500 * 1e18);
        assertEq(lithos.allowance(address(0), user1), 500 * 1e18);

        // Transfer from zero address
        vm.prank(address(0));
        lithos.transfer(user1, 300 * 1e18);
        assertEq(lithos.balanceOf(address(0)), 700 * 1e18);
        assertEq(lithos.balanceOf(user1), 300 * 1e18);

        // TransferFrom involving zero address
        vm.prank(user1);
        lithos.transferFrom(address(0), user2, 200 * 1e18);
        assertEq(lithos.balanceOf(address(0)), 500 * 1e18);
        assertEq(lithos.balanceOf(user2), 200 * 1e18);
    }

    // ============ State Consistency Tests ============

    function test_StateConsistency_TotalSupplyTracking() public {
        uint256 amount1 = 1000 * 1e18;
        uint256 amount2 = 500 * 1e18;

        // Initial state
        assertEq(lithos.totalSupply(), 0);

        // After mints
        lithos.mint(user1, amount1);
        assertEq(lithos.totalSupply(), amount1);

        lithos.mint(user2, amount2);
        assertEq(lithos.totalSupply(), amount1 + amount2);

        // After initial mint
        lithos.initialMint(recipient);
        assertEq(lithos.totalSupply(), amount1 + amount2 + INITIAL_MINT_AMOUNT);

        // Total supply should equal sum of all balances
        uint256 totalBalance = lithos.balanceOf(user1) + lithos.balanceOf(user2) + lithos.balanceOf(recipient);
        assertEq(lithos.totalSupply(), totalBalance);
    }

    function test_StateConsistency_BalanceConservation() public {
        lithos.mint(user1, 2000 * 1e18);
        lithos.mint(user2, 1000 * 1e18);

        uint256 initialTotal = lithos.balanceOf(user1) + lithos.balanceOf(user2) + lithos.balanceOf(user3);

        // Transfer between users
        vm.prank(user1);
        lithos.transfer(user3, 500 * 1e18);

        vm.prank(user2);
        lithos.transfer(user1, 300 * 1e18);

        uint256 finalTotal = lithos.balanceOf(user1) + lithos.balanceOf(user2) + lithos.balanceOf(user3);

        assertEq(initialTotal, finalTotal);
        assertEq(lithos.totalSupply(), finalTotal);
    }

    // ============ Gas Optimization Tests ============

    function test_Gas_TransferOptimization() public {
        lithos.mint(user1, 1000 * 1e18);

        vm.prank(user1);
        uint256 gasBefore = gasleft();
        lithos.transfer(user2, 500 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas usage should be reasonable for a transfer
        assertTrue(gasUsed < 100000); // Arbitrary reasonable limit
    }

    function test_Gas_ApprovalOptimization() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        lithos.approve(user2, 1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas usage should be reasonable for an approval
        assertTrue(gasUsed < 100000); // Arbitrary reasonable limit
    }
}
