// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title TimelockController
 * @notice Production-ready timelock controller for PairFactoryUpgradeable
 * @dev This contract will become the owner of PairFactoryUpgradeable to enforce time delays on critical operations
 * 
 * SECURITY CONSIDERATIONS:
 * - minDelay should be at least 48 hours for production (172800 seconds)
 * - Proposers should be trusted multisig or governance contract
 * - Executors can be broader set including EOAs for execution after timelock
 * - Admin role should be renounced or transferred to governance after setup
 */
contract TimelockController is Initializable, TimelockControllerUpgradeable {
    
    event TimelockInitialized(
        uint256 minDelay,
        address[] proposers,
        address[] executors,
        address admin
    );

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the timelock controller
     * @param minDelay Minimum delay in seconds for operations (recommend 172800 = 48 hours)
     * @param proposers Array of addresses that can propose operations
     * @param executors Array of addresses that can execute operations after delay
     * @param admin Address that can manage roles (should be renounced after setup)
     */
    function initialize(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) public override initializer {
        require(minDelay >= 3600, "TimelockController: delay too short"); // Minimum 1 hour
        require(proposers.length > 0, "TimelockController: no proposers");
        require(executors.length > 0, "TimelockController: no executors");
        
        __TimelockController_init(minDelay, proposers, executors, admin);
        
        emit TimelockInitialized(minDelay, proposers, executors, admin);
    }

    /**
     * @notice Get the current minimum delay
     * @return The minimum delay in seconds
     */
    function getMinDelay() public view override returns (uint256) {
        return super.getMinDelay();
    }

    /**
     * @notice Check if an operation is ready for execution
     * @param target The target contract address
     * @param value The ETH value to send
     * @param data The call data
     * @param predecessor The predecessor operation ID
     * @param salt A salt for unique operation ID
     * @return Whether the operation is ready
     */
    function checkOperationReady(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external view returns (bool) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        return isOperationReady(id);
    }

    /**
     * @notice Get operation timestamp
     * @param target The target contract address
     * @param value The ETH value to send
     * @param data The call data
     * @param predecessor The predecessor operation ID
     * @param salt A salt for unique operation ID
     * @return The timestamp when operation can be executed
     */
    function getOperationTimestamp(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external view returns (uint256) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        return getTimestamp(id);
    }
}