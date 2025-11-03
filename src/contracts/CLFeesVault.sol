// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IPermissionsRegistry.sol";
import "./interfaces/IPairInfo.sol";

/**
 * @title CLFeesVault
 * @notice Collects trading fees from Algebra Hypervisors and distributes them to gauges
 * @dev Simplified version for Lithos - sends 100% of fees to internal bribe for voters
 */
contract CLFeesVault {
    using SafeERC20 for IERC20;

    /* ========================================================================== */
    /*                                   STATE                                    */
    /* ========================================================================== */

    /// @notice The voter contract that manages gauges
    IVoter public voter;

    /// @notice The Algebra pool/hypervisor this vault collects fees from
    address public pool;

    /// @notice Permissions registry for access control
    IPermissionsRegistry public permissionsRegistry;

    /* ========================================================================== */
    /*                                  MODIFIERS                                 */
    /* ========================================================================== */

    modifier onlyGauge() {
        require(voter.isGauge(msg.sender), "!gauge");
        _;
    }

    modifier onlyAdmin() {
        require(
            permissionsRegistry.hasRole("CL_FEES_VAULT_ADMIN", msg.sender),
            "!admin"
        );
        _;
    }

    /* ========================================================================== */
    /*                                   EVENTS                                   */
    /* ========================================================================== */

    event FeesCollected(
        uint256 amount0,
        uint256 amount1,
        address indexed token0,
        address indexed token1,
        address indexed gauge,
        uint256 timestamp
    );

    /* ========================================================================== */
    /*                                CONSTRUCTOR                                 */
    /* ========================================================================== */

    /**
     * @notice Initialize the CLFeesVault
     * @param _pool The Algebra pool/hypervisor address
     * @param _permissionRegistry The permissions registry address
     * @param _voter The voter contract address
     */
    constructor(
        address _pool,
        address _permissionRegistry,
        address _voter
    ) {
        require(_pool != address(0), "zero pool");
        require(_permissionRegistry != address(0), "zero registry");
        require(_voter != address(0), "zero voter");

        pool = _pool;
        permissionsRegistry = IPermissionsRegistry(_permissionRegistry);
        voter = IVoter(_voter);
    }

    /* ========================================================================== */
    /*                              CORE FUNCTIONS                                */
    /* ========================================================================== */

    /**
     * @notice Claim fees from the vault and send to gauge
     * @dev Called by gauge during fee distribution
     * @return claimed0 Amount of token0 claimed
     * @return claimed1 Amount of token1 claimed
     */
    function claimFees()
        external
        onlyGauge
        returns (uint256 claimed0, uint256 claimed1)
    {
        // Verify gauge is for this pool
        address _pool = voter.poolForGauge(msg.sender);
        require(pool == _pool, "wrong pool");

        // Get pool tokens
        address token0 = IPairInfo(pool).token0();
        address token1 = IPairInfo(pool).token1();

        // Get balances
        claimed0 = IERC20(token0).balanceOf(address(this));
        claimed1 = IERC20(token1).balanceOf(address(this));

        // Transfer all fees to gauge (gauge will send to internal bribe)
        if (claimed0 > 0) {
            IERC20(token0).safeTransfer(msg.sender, claimed0);
        }

        if (claimed1 > 0) {
            IERC20(token1).safeTransfer(msg.sender, claimed1);
        }

        emit FeesCollected(
            claimed0,
            claimed1,
            token0,
            token1,
            msg.sender,
            block.timestamp
        );
    }

    /* ========================================================================== */
    /*                              ADMIN FUNCTIONS                               */
    /* ========================================================================== */

    /**
     * @notice Update the voter address
     * @param _voter New voter address
     */
    function setVoter(address _voter) external onlyAdmin {
        require(_voter != address(0), "zero address");
        voter = IVoter(_voter);
    }

    /**
     * @notice Update the permissions registry
     * @param _registry New registry address
     */
    function setPermissionsRegistry(address _registry) external onlyAdmin {
        require(_registry != address(0), "zero address");
        permissionsRegistry = IPermissionsRegistry(_registry);
    }

    /**
     * @notice Update the pool address
     * @param _pool New pool address
     */
    function setPool(address _pool) external onlyAdmin {
        require(_pool != address(0), "zero address");
        pool = _pool;
    }

    /**
     * @notice Emergency withdraw tokens
     * @param tokenAddress Token to withdraw
     * @param tokenAmount Amount to withdraw
     */
    function emergencyWithdraw(address tokenAddress, uint256 tokenAmount)
        external
        onlyAdmin
    {
        require(
            tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)),
            "insufficient balance"
        );
        IERC20(tokenAddress).safeTransfer(
            permissionsRegistry.emergencyCouncil(),
            tokenAmount
        );
    }
}

