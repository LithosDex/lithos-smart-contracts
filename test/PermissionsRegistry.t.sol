// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";

import {PermissionsRegistry} from "../src/contracts/PermissionsRegistry.sol";

contract PermissionsRegistryTest is Test {
    PermissionsRegistry public registry;

    address public lithosMultisig;
    address public lithosTeamMultisig;
    address public emergencyCouncil;
    address public user1;
    address public user2;
    address public user3;

    string constant GOVERNANCE = "GOVERNANCE";
    string constant VOTER_ADMIN = "VOTER_ADMIN";
    string constant GAUGE_ADMIN = "GAUGE_ADMIN";
    string constant BRIBE_ADMIN = "BRIBE_ADMIN";
    string constant FEE_MANAGER = "FEE_MANAGER";
    string constant CL_FEES_VAULT_ADMIN = "CL_FEES_VAULT_ADMIN";
    string constant NEW_ROLE = "NEW_ROLE";

    event RoleAdded(bytes role);
    event RoleRemoved(bytes role);
    event RoleSetFor(address indexed user, bytes indexed role);
    event RoleRemovedFor(address indexed user, bytes indexed role);
    event SetEmergencyCouncil(address indexed council);
    event SetLithosTeamMultisig(address indexed multisig);
    event SetLithosMultisig(address indexed multisig);

    function setUp() public {
        lithosMultisig = makeAddr("lithosMultisig");
        lithosTeamMultisig = makeAddr("lithosTeamMultisig");
        emergencyCouncil = makeAddr("emergencyCouncil");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.startPrank(lithosMultisig);
        registry = new PermissionsRegistry();
        vm.stopPrank();

        assertEq(registry.lithosMultisig(), lithosMultisig);
        assertEq(registry.lithosTeamMultisig(), lithosMultisig);
        assertEq(registry.emergencyCouncil(), lithosMultisig);
    }

    // ============ Role Assignment and Revocation Tests ============

    function test_SetRoleFor_Success() public {
        vm.startPrank(lithosMultisig);

        vm.expectEmit(true, true, false, true);
        emit RoleSetFor(user1, bytes(GOVERNANCE));

        registry.setRoleFor(user1, GOVERNANCE);

        assertTrue(registry.hasRole(bytes(GOVERNANCE), user1));

        address[] memory addresses = registry.roleToAddresses(GOVERNANCE);
        assertEq(addresses.length, 1);
        assertEq(addresses[0], user1);

        string[] memory roles = registry.addressToRole(user1);
        assertEq(roles.length, 1);
        assertEq(roles[0], GOVERNANCE);

        vm.stopPrank();
    }

    function test_SetRoleFor_MultipleUsers() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);
        registry.setRoleFor(user2, GOVERNANCE);
        registry.setRoleFor(user3, VOTER_ADMIN);

        assertTrue(registry.hasRole(bytes(GOVERNANCE), user1));
        assertTrue(registry.hasRole(bytes(GOVERNANCE), user2));
        assertTrue(registry.hasRole(bytes(VOTER_ADMIN), user3));

        address[] memory governanceAddresses = registry.roleToAddresses(
            GOVERNANCE
        );
        assertEq(governanceAddresses.length, 2);

        vm.stopPrank();
    }

    function test_RemoveRoleFrom_Success() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);
        assertTrue(registry.hasRole(bytes(GOVERNANCE), user1));

        vm.expectEmit(true, true, false, true);
        emit RoleRemovedFor(user1, bytes(GOVERNANCE));

        registry.removeRoleFrom(user1, GOVERNANCE);

        assertFalse(registry.hasRole(bytes(GOVERNANCE), user1));

        address[] memory addresses = registry.roleToAddresses(GOVERNANCE);
        assertEq(addresses.length, 0);

        string[] memory roles = registry.addressToRole(user1);
        assertEq(roles.length, 0);

        vm.stopPrank();
    }

    function test_RemoveRoleFrom_MultipleUsers() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);
        registry.setRoleFor(user2, GOVERNANCE);
        registry.setRoleFor(user1, VOTER_ADMIN);

        registry.removeRoleFrom(user1, GOVERNANCE);

        assertFalse(registry.hasRole(bytes(GOVERNANCE), user1));
        assertTrue(registry.hasRole(bytes(GOVERNANCE), user2));
        assertTrue(registry.hasRole(bytes(VOTER_ADMIN), user1));

        address[] memory governanceAddresses = registry.roleToAddresses(
            GOVERNANCE
        );
        assertEq(governanceAddresses.length, 1);
        assertEq(governanceAddresses[0], user2);

        vm.stopPrank();
    }

    // // ============ Access Control Modifier Tests ============

    function test_SetRoleFor_OnlyLithosMultisig() public {
        vm.prank(user1);
        vm.expectRevert("!lithosMultisig");
        registry.setRoleFor(user2, GOVERNANCE);
    }

    function test_RemoveRoleFrom_OnlyLithosMultisig() public {
        vm.prank(lithosMultisig);
        registry.setRoleFor(user1, GOVERNANCE);

        vm.prank(user2);
        vm.expectRevert("!lithosMultisig");
        registry.removeRoleFrom(user1, GOVERNANCE);
    }

    function test_AddRole_OnlyLithosMultisig() public {
        vm.prank(user1);
        vm.expectRevert("!lithosMultisig");
        registry.addRole(NEW_ROLE);
    }

    function test_RemoveRole_OnlyLithosMultisig() public {
        vm.prank(user1);
        vm.expectRevert("!lithosMultisig");
        registry.removeRole(GOVERNANCE);
    }

    function test_SetLithosMultisig_OnlyCurrentMultisig() public {
        vm.prank(user1);
        vm.expectRevert("not allowed");
        registry.setLithosMultisig(user2);
    }

    function test_SetLithosTeamMultisig_OnlyCurrentTeamMultisig() public {
        vm.prank(user1);
        vm.expectRevert("not allowed");
        registry.setLithosTeamMultisig(user2);
    }

    function test_SetEmergencyCouncil_OnlyAuthorized() public {
        vm.prank(user1);
        vm.expectRevert("not allowed");
        registry.setEmergencyCouncil(user2);
    }

    // // ============ Multi-Role Scenarios Tests ============

    function test_MultipleRolesPerUser() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);
        registry.setRoleFor(user1, VOTER_ADMIN);
        registry.setRoleFor(user1, GAUGE_ADMIN);

        assertTrue(registry.hasRole(bytes(GOVERNANCE), user1));
        assertTrue(registry.hasRole(bytes(VOTER_ADMIN), user1));
        assertTrue(registry.hasRole(bytes(GAUGE_ADMIN), user1));

        string[] memory roles = registry.addressToRole(user1);
        assertEq(roles.length, 3);

        vm.stopPrank();
    }

    function test_RemoveOneRoleFromMultipleRoles() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);
        registry.setRoleFor(user1, VOTER_ADMIN);
        registry.setRoleFor(user1, GAUGE_ADMIN);

        registry.removeRoleFrom(user1, VOTER_ADMIN);

        assertTrue(registry.hasRole(bytes(GOVERNANCE), user1));
        assertFalse(registry.hasRole(bytes(VOTER_ADMIN), user1));
        assertTrue(registry.hasRole(bytes(GAUGE_ADMIN), user1));

        string[] memory roles = registry.addressToRole(user1);
        assertEq(roles.length, 2);

        vm.stopPrank();
    }

    function test_MultipleUsersMultipleRoles() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);
        registry.setRoleFor(user1, VOTER_ADMIN);
        registry.setRoleFor(user2, GOVERNANCE);
        registry.setRoleFor(user2, GAUGE_ADMIN);
        registry.setRoleFor(user3, BRIBE_ADMIN);

        assertTrue(registry.hasRole(bytes(GOVERNANCE), user1));
        assertTrue(registry.hasRole(bytes(VOTER_ADMIN), user1));
        assertTrue(registry.hasRole(bytes(GOVERNANCE), user2));
        assertTrue(registry.hasRole(bytes(GAUGE_ADMIN), user2));
        assertTrue(registry.hasRole(bytes(BRIBE_ADMIN), user3));

        address[] memory governanceAddresses = registry.roleToAddresses(
            GOVERNANCE
        );
        assertEq(governanceAddresses.length, 2);

        vm.stopPrank();
    }

    // // ============ Edge Cases Tests ============

    function test_SetRoleFor_ZeroAddress() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(address(0), GOVERNANCE);

        assertTrue(registry.hasRole(bytes(GOVERNANCE), address(0)));

        vm.stopPrank();
    }

    function test_SetRoleFor_DuplicateRole() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);

        vm.expectRevert("assigned");
        registry.setRoleFor(user1, GOVERNANCE);

        vm.stopPrank();
    }

    function test_RemoveRoleFrom_NotAssigned() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("not assigned");
        registry.removeRoleFrom(user1, GOVERNANCE);

        vm.stopPrank();
    }

    function test_SetRoleFor_NonExistentRole() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("not a role");
        registry.setRoleFor(user1, "NON_EXISTENT_ROLE");

        vm.stopPrank();
    }

    function test_RemoveRoleFrom_NonExistentRole() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("not a role");
        registry.removeRoleFrom(user1, "NON_EXISTENT_ROLE");

        vm.stopPrank();
    }

    function test_AddRole_DuplicateRole() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("is a role");
        registry.addRole(GOVERNANCE);

        vm.stopPrank();
    }

    function test_RemoveRole_NonExistentRole() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("not a role");
        registry.removeRole("NON_EXISTENT_ROLE");

        vm.stopPrank();
    }

    function test_SetLithosMultisig_ZeroAddress() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("addr0");
        registry.setLithosMultisig(address(0));

        vm.stopPrank();
    }

    function test_SetLithosMultisig_SameAddress() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("same multisig");
        registry.setLithosMultisig(lithosMultisig);

        vm.stopPrank();
    }

    function test_SetLithosTeamMultisig_ZeroAddress() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("addr 0");
        registry.setLithosTeamMultisig(address(0));

        vm.stopPrank();
    }

    function test_SetLithosTeamMultisig_SameAddress() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("same multisig");
        registry.setLithosTeamMultisig(lithosMultisig);

        vm.stopPrank();
    }

    function test_SetEmergencyCouncil_ZeroAddress() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("addr0");
        registry.setEmergencyCouncil(address(0));

        vm.stopPrank();
    }

    function test_SetEmergencyCouncil_SameAddress() public {
        vm.startPrank(lithosMultisig);

        vm.expectRevert("same emergencyCouncil");
        registry.setEmergencyCouncil(lithosMultisig);

        vm.stopPrank();
    }

    // // ============ Additional Role Management Tests ============

    function test_AddRole_Success() public {
        vm.startPrank(lithosMultisig);

        vm.expectEmit(false, false, false, true);
        emit RoleAdded(bytes(NEW_ROLE));

        registry.addRole(NEW_ROLE);

        string[] memory roles = registry.rolesToString();
        bool found = false;
        for (uint256 i = 0; i < roles.length; i++) {
            if (keccak256(bytes(roles[i])) == keccak256(bytes(NEW_ROLE))) {
                found = true;
                break;
            }
        }
        assertTrue(found);

        vm.stopPrank();
    }

    function test_RemoveRole_Success() public {
        vm.startPrank(lithosMultisig);

        registry.addRole(NEW_ROLE);
        registry.setRoleFor(user1, NEW_ROLE);

        assertTrue(registry.hasRole(bytes(NEW_ROLE), user1));

        vm.expectEmit(false, false, false, true);
        emit RoleRemoved(bytes(NEW_ROLE));

        registry.removeRole(NEW_ROLE);

        assertFalse(registry.hasRole(bytes(NEW_ROLE), user1));

        string[] memory roles = registry.rolesToString();
        for (uint256 i = 0; i < roles.length; i++) {
            assertTrue(
                keccak256(bytes(roles[i])) != keccak256(bytes(NEW_ROLE))
            );
        }

        vm.stopPrank();
    }

    // ============ View Function Tests ============

    function test_ViewFunctions() public {
        vm.startPrank(lithosMultisig);

        registry.setRoleFor(user1, GOVERNANCE);
        registry.setRoleFor(user2, VOTER_ADMIN);

        string[] memory rolesString = registry.rolesToString();
        assertEq(rolesString.length, 6);

        bytes[] memory rolesBytes = registry.roles();
        assertEq(rolesBytes.length, 6);

        uint256 rolesLength = registry.rolesLength();
        assertEq(rolesLength, 6);

        address[] memory governanceAddresses = registry.roleToAddresses(
            GOVERNANCE
        );
        assertEq(governanceAddresses.length, 1);
        assertEq(governanceAddresses[0], user1);

        string[] memory user1Roles = registry.addressToRole(user1);
        assertEq(user1Roles.length, 1);
        assertEq(user1Roles[0], GOVERNANCE);

        vm.stopPrank();
    }

    // ============ Helper Function Tests ============

    function test_HelperFunctions() public view {
        string memory testString = "TEST_ROLE";
        bytes memory testBytes = registry.helper_stringToBytes(testString);
        string memory convertedBack = registry.helper_bytesToString(testBytes);

        assertEq(keccak256(bytes(testString)), keccak256(bytes(convertedBack)));
    }

    // ============ Multisig Update Tests ============

    function test_SetLithosMultisig_Success() public {
        vm.startPrank(lithosMultisig);

        vm.expectEmit(true, false, false, true);
        emit SetLithosMultisig(user1);

        registry.setLithosMultisig(user1);

        assertEq(registry.lithosMultisig(), user1);

        vm.stopPrank();
    }

    function test_SetLithosTeamMultisig_Success() public {
        vm.startPrank(lithosMultisig);

        vm.expectEmit(true, false, false, true);
        emit SetLithosTeamMultisig(user1);

        registry.setLithosTeamMultisig(user1);

        assertEq(registry.lithosTeamMultisig(), user1);

        vm.stopPrank();
    }

    function test_SetEmergencyCouncil_Success() public {
        vm.startPrank(lithosMultisig);

        vm.expectEmit(true, false, false, true);
        emit SetEmergencyCouncil(user1);

        registry.setEmergencyCouncil(user1);

        assertEq(registry.emergencyCouncil(), user1);

        vm.stopPrank();
    }

    function test_SetEmergencyCouncil_ByEmergencyCouncil() public {
        vm.startPrank(lithosMultisig);
        registry.setEmergencyCouncil(emergencyCouncil);
        vm.stopPrank();

        vm.startPrank(emergencyCouncil);

        vm.expectEmit(true, false, false, true);
        emit SetEmergencyCouncil(user1);

        registry.setEmergencyCouncil(user1);

        assertEq(registry.emergencyCouncil(), user1);

        vm.stopPrank();
    }
}
