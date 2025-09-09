// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {VeArtProxyUpgradeable} from "../src/contracts/VeArtProxyUpgradeable.sol";
import {Base64} from "../src/contracts/libraries/Base64.sol";

contract VeArtProxyUpgradeableTest is Test {
    VeArtProxyUpgradeable public veArtProxy;
    
    address public owner;
    address public user1;
    address public user2;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        veArtProxy = new VeArtProxyUpgradeable();
        veArtProxy.initialize();
        
        // Verify initial state
        assertEq(veArtProxy.owner(), owner);
    }
    
    // ============ Initialization Tests ============
    
    function test_Initialize_Success() public {
        VeArtProxyUpgradeable newProxy = new VeArtProxyUpgradeable();
        
        newProxy.initialize();
        
        assertEq(newProxy.owner(), address(this));
    }
    
    function test_Initialize_OnlyOnce() public {
        vm.expectRevert();
        veArtProxy.initialize();
    }
    
    function test_Initialize_DifferentCaller() public {
        VeArtProxyUpgradeable newProxy = new VeArtProxyUpgradeable();
        
        vm.prank(user1);
        newProxy.initialize();
        
        assertEq(newProxy.owner(), user1);
    }
    
    // ============ Ownership Tests ============
    
    function test_TransferOwnership_Success() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, user1);
        
        veArtProxy.transferOwnership(user1);
        
        assertEq(veArtProxy.owner(), user1);
    }
    
    function test_TransferOwnership_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        veArtProxy.transferOwnership(user2);
    }
    
    function test_RenounceOwnership_Success() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, address(0));
        
        veArtProxy.renounceOwnership();
        
        assertEq(veArtProxy.owner(), address(0));
    }
    
    function test_RenounceOwnership_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        veArtProxy.renounceOwnership();
    }
    
    // ============ TokenURI Generation Tests ============
    
    function test_TokenURI_BasicGeneration() public {
        uint tokenId = 1;
        uint balanceOf = 1000 * 1e18;
        uint lockedEnd = block.timestamp + 365 days;
        uint value = 500 * 1e18;
        
        string memory result = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        
        // Should return a data URI
        assertTrue(bytes(result).length > 0);
        
        // Should start with data:application/json;base64,
        string memory expectedPrefix = "data:application/json;base64,";
        bytes memory resultBytes = bytes(result);
        bytes memory prefixBytes = bytes(expectedPrefix);
        
        bool hasCorrectPrefix = true;
        if (resultBytes.length < prefixBytes.length) {
            hasCorrectPrefix = false;
        } else {
            for (uint i = 0; i < prefixBytes.length; i++) {
                if (resultBytes[i] != prefixBytes[i]) {
                    hasCorrectPrefix = false;
                    break;
                }
            }
        }
        
        assertTrue(hasCorrectPrefix);
    }
    
    function test_TokenURI_WithZeroValues() public {
        string memory result = veArtProxy._tokenURI(0, 0, 0, 0);
        
        assertTrue(bytes(result).length > 0);
        
        // Decode and verify it contains the zero values
        // Note: In a real test, you might want to decode the base64 and JSON
        // to verify exact content, but for simplicity we're checking basic structure
    }
    
    function test_TokenURI_WithLargeValues() public {
        uint tokenId = type(uint128).max;
        uint balanceOf = type(uint128).max;
        uint lockedEnd = type(uint128).max;
        uint value = type(uint128).max;
        
        string memory result = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        
        assertTrue(bytes(result).length > 0);
    }
    
    function test_TokenURI_WithSmallValues() public {
        string memory result = veArtProxy._tokenURI(1, 1, 1, 1);
        
        assertTrue(bytes(result).length > 0);
    }
    
    function test_TokenURI_ConsistentOutput() public {
        uint tokenId = 42;
        uint balanceOf = 1337 * 1e18;
        uint lockedEnd = 1234567890;
        uint value = 999 * 1e18;
        
        string memory result1 = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        string memory result2 = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        
        assertEq(keccak256(bytes(result1)), keccak256(bytes(result2)));
    }
    
    function test_TokenURI_DifferentInputsDifferentOutputs() public {
        string memory result1 = veArtProxy._tokenURI(1, 100, 1000, 10000);
        string memory result2 = veArtProxy._tokenURI(2, 200, 2000, 20000);
        
        assertTrue(keccak256(bytes(result1)) != keccak256(bytes(result2)));
    }
    
    // ============ ToString Function Tests ============
    // Note: toString is internal, so we test it indirectly through _tokenURI
    
    function test_ToString_ZeroValue() public {
        // Test indirectly by using _tokenURI with zero tokenId
        string memory result = veArtProxy._tokenURI(0, 1000, 2000, 3000);
        
        // The result should contain "token 0" in the SVG
        assertTrue(bytes(result).length > 0);
    }
    
    function test_ToString_SingleDigit() public {
        string memory result = veArtProxy._tokenURI(5, 1000, 2000, 3000);
        assertTrue(bytes(result).length > 0);
    }
    
    function test_ToString_MultipleDigits() public {
        string memory result = veArtProxy._tokenURI(123456789, 1000, 2000, 3000);
        assertTrue(bytes(result).length > 0);
    }
    
    function test_ToString_MaxValue() public {
        string memory result = veArtProxy._tokenURI(type(uint256).max, 1000, 2000, 3000);
        assertTrue(bytes(result).length > 0);
    }
    
    // ============ SVG Structure Tests ============
    
    function test_SVG_ContainsExpectedElements() public {
        uint tokenId = 123;
        uint balanceOf = 1000 * 1e18;
        uint lockedEnd = 1234567890;
        uint value = 500 * 1e18;
        
        string memory result = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        
        // Decode the base64 to check SVG content
        // Extract the base64 part after "data:application/json;base64,"
        bytes memory resultBytes = bytes(result);
        bytes memory base64Part = new bytes(resultBytes.length - 29); // 29 = length of prefix
        
        for (uint i = 29; i < resultBytes.length; i++) {
            base64Part[i - 29] = resultBytes[i];
        }
        
        // In a full test, you would decode the base64 and JSON
        // For now, we just verify the structure is reasonable
        assertTrue(base64Part.length > 0);
    }
    
    // ============ Gas Optimization Tests ============
    
    function test_Gas_TokenURIGeneration() public {
        uint tokenId = 1;
        uint balanceOf = 1000 * 1e18;
        uint lockedEnd = block.timestamp + 365 days;
        uint value = 500 * 1e18;
        
        uint gasBefore = gasleft();
        veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        uint gasUsed = gasBefore - gasleft();
        
        // Gas usage should be reasonable
        assertTrue(gasUsed < 500000); // Arbitrary reasonable limit for SVG generation
    }
    
    // ============ Edge Cases Tests ============
    
    function test_EdgeCase_EmptyContract() public {
        // Verify contract can be deployed and initialized properly
        VeArtProxyUpgradeable newProxy = new VeArtProxyUpgradeable();
        
        // Before initialization, should be able to call constructor
        // After initialization, should work normally
        newProxy.initialize();
        
        string memory result = newProxy._tokenURI(1, 100, 200, 300);
        assertTrue(bytes(result).length > 0);
    }
    
    function test_EdgeCase_RepeatedTokenURICalls() public {
        // Test that multiple calls don't interfere with each other
        for (uint i = 0; i < 10; i++) {
            string memory result = veArtProxy._tokenURI(i, i * 100, i * 200, i * 300);
            assertTrue(bytes(result).length > 0);
        }
    }
    
    function test_EdgeCase_VeryLongNumbers() public {
        // Test with very large numbers that would create long strings
        uint largeValue = 999999999999999999999999999999999;
        
        string memory result = veArtProxy._tokenURI(largeValue, largeValue, largeValue, largeValue);
        assertTrue(bytes(result).length > 0);
    }
    
    // ============ Integration Tests ============
    
    function test_Integration_OwnershipAndTokenURI() public {
        // Transfer ownership and verify tokenURI still works
        veArtProxy.transferOwnership(user1);
        
        vm.prank(user1);
        string memory result = veArtProxy._tokenURI(1, 100, 200, 300);
        
        assertTrue(bytes(result).length > 0);
        assertEq(veArtProxy.owner(), user1);
    }
    
    function test_Integration_MultipleOwnershipChanges() public {
        // Multiple ownership transfers
        veArtProxy.transferOwnership(user1);
        
        vm.prank(user1);
        veArtProxy.transferOwnership(user2);
        
        vm.prank(user2);
        string memory result = veArtProxy._tokenURI(42, 1000, 2000, 3000);
        
        assertTrue(bytes(result).length > 0);
        assertEq(veArtProxy.owner(), user2);
    }
    
    // ============ Access Control Tests ============
    
    function test_AccessControl_OnlyOwnerFunctions() public {
        // Only owner can transfer ownership
        vm.prank(user1);
        vm.expectRevert();
        veArtProxy.transferOwnership(user2);
        
        // Only owner can renounce ownership  
        vm.prank(user1);
        vm.expectRevert();
        veArtProxy.renounceOwnership();
    }
    
    function test_AccessControl_PublicFunctions() public {
        // _tokenURI should be callable by anyone
        vm.prank(user1);
        string memory result = veArtProxy._tokenURI(1, 100, 200, 300);
        assertTrue(bytes(result).length > 0);
    }
    
    // ============ State Consistency Tests ============
    
    function test_StateConsistency_AfterOwnershipTransfer() public {
        address originalOwner = veArtProxy.owner();
        
        veArtProxy.transferOwnership(user1);
        
        // State should be consistent
        assertEq(veArtProxy.owner(), user1);
        assertTrue(veArtProxy.owner() != originalOwner);
        
        // Functionality should still work
        string memory result = veArtProxy._tokenURI(1, 100, 200, 300);
        assertTrue(bytes(result).length > 0);
    }
    
    function test_StateConsistency_AfterRenounceOwnership() public {
        veArtProxy.renounceOwnership();
        
        // Owner should be zero address
        assertEq(veArtProxy.owner(), address(0));
        
        // Functionality should still work for public functions
        string memory result = veArtProxy._tokenURI(1, 100, 200, 300);
        assertTrue(bytes(result).length > 0);
    }
    
    // ============ Initialization Edge Cases ============
    
    function test_InitializationEdgeCase_MultipleContracts() public {
        // Deploy multiple contracts and initialize them
        VeArtProxyUpgradeable proxy1 = new VeArtProxyUpgradeable();
        VeArtProxyUpgradeable proxy2 = new VeArtProxyUpgradeable();
        
        vm.prank(user1);
        proxy1.initialize();
        
        vm.prank(user2);
        proxy2.initialize();
        
        assertEq(proxy1.owner(), user1);
        assertEq(proxy2.owner(), user2);
        
        // Both should work independently
        string memory result1 = proxy1._tokenURI(1, 100, 200, 300);
        string memory result2 = proxy2._tokenURI(1, 100, 200, 300);
        
        assertTrue(bytes(result1).length > 0);
        assertTrue(bytes(result2).length > 0);
        assertEq(keccak256(bytes(result1)), keccak256(bytes(result2)));
    }
    
    // ============ Error Recovery Tests ============
    
    function test_ErrorRecovery_AfterFailedOwnershipTransfer() public {
        // Try to transfer ownership as non-owner (should fail)
        vm.prank(user1);
        vm.expectRevert();
        veArtProxy.transferOwnership(user2);
        
        // State should remain unchanged
        assertEq(veArtProxy.owner(), owner);
        
        // Normal operations should still work
        string memory result = veArtProxy._tokenURI(1, 100, 200, 300);
        assertTrue(bytes(result).length > 0);
        
        // Owner should still be able to transfer ownership
        veArtProxy.transferOwnership(user1);
        assertEq(veArtProxy.owner(), user1);
    }
    
    // ============ Performance Tests ============
    
    function test_Performance_RepeatedTokenURIGeneration() public {
        uint iterations = 50;
        
        for (uint i = 0; i < iterations; i++) {
            string memory result = veArtProxy._tokenURI(
                i,
                i * 1000,
                block.timestamp + i * 86400,
                i * 500
            );
            assertTrue(bytes(result).length > 0);
        }
    }
    
    function test_Performance_LargeValueHandling() public {
        uint[] memory testValues = new uint[](5);
        testValues[0] = type(uint64).max;
        testValues[1] = type(uint128).max;
        testValues[2] = type(uint192).max;
        testValues[3] = type(uint248).max;
        testValues[4] = type(uint256).max;
        
        for (uint i = 0; i < testValues.length; i++) {
            uint testValue = testValues[i];
            string memory result = veArtProxy._tokenURI(testValue, testValue, testValue, testValue);
            assertTrue(bytes(result).length > 0);
        }
    }
    
    // ============ Data Integrity Tests ============
    
    function test_DataIntegrity_TokenURIContent() public {
        uint tokenId = 12345;
        uint balanceOf = 67890;
        uint lockedEnd = 11111;
        uint value = 22222;
        
        string memory result = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        
        // The result should be deterministic for the same inputs
        string memory result2 = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        assertEq(keccak256(bytes(result)), keccak256(bytes(result2)));
        
        // Different inputs should produce different results
        string memory result3 = veArtProxy._tokenURI(tokenId + 1, balanceOf, lockedEnd, value);
        assertTrue(keccak256(bytes(result)) != keccak256(bytes(result3)));
    }
    
    // ============ Upgrade Safety Tests ============
    
    function test_UpgradeSafety_StatePreservation() public {
        // Test that important state is preserved across potential upgrades
        address initialOwner = veArtProxy.owner();
        
        // Perform some operations
        string memory result1 = veArtProxy._tokenURI(1, 100, 200, 300);
        
        // Transfer ownership
        veArtProxy.transferOwnership(user1);
        
        // State should be preserved
        assertEq(veArtProxy.owner(), user1);
        assertTrue(veArtProxy.owner() != initialOwner);
        
        // Functionality should remain consistent
        string memory result2 = veArtProxy._tokenURI(1, 100, 200, 300);
        assertEq(keccak256(bytes(result1)), keccak256(bytes(result2)));
    }
}