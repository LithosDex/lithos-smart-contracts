// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IPermissionsRegistry {
    function emergencyCouncil() external view returns (address);
    function lithosTeamMultisig() external view returns (address);
    function hasRole(
        bytes memory role,
        address caller
    ) external view returns (bool);
}
