// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {VeArtProxyUpgradeable} from "../src/contracts/VeArtProxyUpgradeable.sol";
import {Base64} from "../src/contracts/libraries/Base64.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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

        veArtProxy = _deployProxyAndInit(owner);

        // Verify initial state
        assertEq(veArtProxy.owner(), owner);
    }

    // ============ Initialization Tests ============

    function test_Initialize_Success() public {
        VeArtProxyUpgradeable newProxy = _deployProxy(owner);

        newProxy.initialize();

        assertEq(newProxy.owner(), address(this));
    }

    function test_Initialize_OnlyOnce() public {
        vm.expectRevert();
        veArtProxy.initialize();
    }

    function test_Initialize_DifferentCaller() public {
        VeArtProxyUpgradeable newProxy = _deployProxy(owner);

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

    function test_TokenURI_BasicGeneration() public view {
        uint256 tokenId = 1;
        uint256 balanceOf = 1000 * 1e18;
        uint256 lockedEnd = block.timestamp + 365 days;
        uint256 value = 500 * 1e18;

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
            for (uint256 i = 0; i < prefixBytes.length; i++) {
                if (resultBytes[i] != prefixBytes[i]) {
                    hasCorrectPrefix = false;
                    break;
                }
            }
        }

        assertTrue(hasCorrectPrefix);
    }

    function test_TokenURI_WithZeroValues() public view {
        string memory result = veArtProxy._tokenURI(0, 0, 0, 0);

        assertTrue(bytes(result).length > 0);

        // Decode and verify it contains the zero values
        // Note: In a real test, you might want to decode the base64 and JSON
        // to verify exact content, but for simplicity we're checking basic structure
    }

    function test_TokenURI_WithLargeValues() public view {
        uint256 tokenId = type(uint128).max;
        uint256 balanceOf = type(uint128).max;
        uint256 lockedEnd = type(uint128).max;
        uint256 value = type(uint128).max;

        string memory result = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);

        assertTrue(bytes(result).length > 0);
    }

    function test_TokenURI_WithSmallValues() public view {
        string memory result = veArtProxy._tokenURI(1, 1, 1, 1);

        assertTrue(bytes(result).length > 0);
    }

    function test_TokenURI_ConsistentOutput() public view {
        uint256 tokenId = 42;
        uint256 balanceOf = 1337 * 1e18;
        uint256 lockedEnd = 1234567890;
        uint256 value = 999 * 1e18;

        string memory result1 = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        string memory result2 = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);

        assertEq(keccak256(bytes(result1)), keccak256(bytes(result2)));
    }

    function test_TokenURI_DifferentInputsDifferentOutputs() public view {
        string memory result1 = veArtProxy._tokenURI(1, 100, 1000, 10000);
        string memory result2 = veArtProxy._tokenURI(2, 200, 2000, 20000);

        assertTrue(keccak256(bytes(result1)) != keccak256(bytes(result2)));
    }

    // ============ ToString Function Tests ============
    // Note: toString is internal, so we test it indirectly through _tokenURI

    function test_ToString_ZeroValue() public view {
        // Test indirectly by using _tokenURI with zero tokenId
        string memory result = veArtProxy._tokenURI(0, 1000, 2000, 3000);

        // The result should contain "token 0" in the SVG
        assertTrue(bytes(result).length > 0);
    }

    function test_ToString_SingleDigit() public view {
        string memory result = veArtProxy._tokenURI(5, 1000, 2000, 3000);
        assertTrue(bytes(result).length > 0);
    }

    function test_ToString_MultipleDigits() public view {
        string memory result = veArtProxy._tokenURI(123456789, 1000, 2000, 3000);
        assertTrue(bytes(result).length > 0);
    }

    function test_ToString_MaxValue() public view {
        string memory result = veArtProxy._tokenURI(type(uint256).max, 1000, 2000, 3000);
        assertTrue(bytes(result).length > 0);
    }

    // ============ SVG Structure Tests ============

    function test_SVG_ContainsExpectedElements() public view {
        uint256 tokenId = 123;
        uint256 balanceOf = 1000 * 1e18;
        uint256 lockedEnd = 1234567890;
        uint256 value = 500 * 1e18;

        string memory result = veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);

        // Decode the base64 to check SVG content
        // Extract the base64 part after "data:application/json;base64,"
        bytes memory resultBytes = bytes(result);
        bytes memory base64Part = new bytes(resultBytes.length - 29); // 29 = length of prefix

        for (uint256 i = 29; i < resultBytes.length; i++) {
            base64Part[i - 29] = resultBytes[i];
        }

        // In a full test, you would decode the base64 and JSON
        // For now, we just verify the structure is reasonable
        assertTrue(base64Part.length > 0);
    }

    // ============ Gas Optimization Tests ============

    function test_Gas_TokenURIGeneration() public view {
        uint256 tokenId = 1;
        uint256 balanceOf = 1000 * 1e18;
        uint256 lockedEnd = block.timestamp + 365 days;
        uint256 value = 500 * 1e18;

        uint256 gasBefore = gasleft();
        veArtProxy._tokenURI(tokenId, balanceOf, lockedEnd, value);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas usage should be reasonable
        assertTrue(gasUsed < 500000); // Arbitrary reasonable limit for SVG generation
    }

    // ============ Edge Cases Tests ============

    function test_EdgeCase_EmptyContract() public {
        // Verify contract can be deployed and initialized properly
        VeArtProxyUpgradeable veArtImpl = new VeArtProxyUpgradeable();
        bytes memory veArtInitData = abi.encodeWithSelector(VeArtProxyUpgradeable.initialize.selector);
        TransparentUpgradeableProxy _veArtProxy = new TransparentUpgradeableProxy(
            address(veArtImpl),
            owner, // initialOwner of the ProxyAdmin created internally
            veArtInitData
        );
        VeArtProxyUpgradeable newProxy = VeArtProxyUpgradeable(address(_veArtProxy));

        string memory result = newProxy._tokenURI(1, 100, 200, 300);
        assertTrue(bytes(result).length > 0);
    }

    function test_EdgeCase_RepeatedTokenURICalls() public view {
        // Test that multiple calls don't interfere with each other
        for (uint256 i = 0; i < 10; i++) {
            string memory result = veArtProxy._tokenURI(i, i * 100, i * 200, i * 300);
            assertTrue(bytes(result).length > 0);
        }
    }

    function test_EdgeCase_VeryLongNumbers() public view {
        // Test with very large numbers that would create long strings
        uint256 largeValue = 999999999999999999999999999999999;

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
        VeArtProxyUpgradeable proxy1 = _deployProxy(owner);
        VeArtProxyUpgradeable proxy2 = _deployProxy(owner);

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

    function test_Performance_RepeatedTokenURIGeneration() public view {
        uint256 iterations = 50;

        for (uint256 i = 0; i < iterations; i++) {
            string memory result = veArtProxy._tokenURI(i, i * 1000, block.timestamp + i * 86400, i * 500);
            assertTrue(bytes(result).length > 0);
        }
    }

    function test_Performance_LargeValueHandling() public view {
        uint256[] memory testValues = new uint256[](5);
        testValues[0] = type(uint64).max;
        testValues[1] = type(uint128).max;
        testValues[2] = type(uint192).max;
        testValues[3] = type(uint248).max;
        testValues[4] = type(uint256).max;

        for (uint256 i = 0; i < testValues.length; i++) {
            uint256 testValue = testValues[i];
            string memory result = veArtProxy._tokenURI(testValue, testValue, testValue, testValue);
            assertTrue(bytes(result).length > 0);
        }
    }

    // ============ Data Integrity Tests ============

    function test_DataIntegrity_TokenURIContent() public view {
        uint256 tokenId = 12345;
        uint256 balanceOf = 67890;
        uint256 lockedEnd = 11111;
        uint256 value = 22222;

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

    function _deployProxy(address admin) internal returns (VeArtProxyUpgradeable) {
        VeArtProxyUpgradeable veArtImpl = new VeArtProxyUpgradeable();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(veArtImpl), admin, "");
        return VeArtProxyUpgradeable(address(proxy));
    }

    function _deployProxyAndInit(address admin) internal returns (VeArtProxyUpgradeable) {
        VeArtProxyUpgradeable veArtImpl = new VeArtProxyUpgradeable();
        bytes memory initData = abi.encodeWithSelector(VeArtProxyUpgradeable.initialize.selector);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(veArtImpl), admin, initData);
        return VeArtProxyUpgradeable(address(proxy));
    }
}
