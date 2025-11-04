// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

/// @title IAlgebraFactory
/// @notice Simplified interface for Algebra Factory
interface IAlgebraFactory {
    /// @notice Returns the pool address for a given pair of tokens, or address 0 if it does not exist
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @return pool The pool address
    function poolByPair(address tokenA, address tokenB) external view returns (address pool);
}

/// @title IAlgebraPool
/// @notice Simplified interface for Algebra Pool
interface IAlgebraPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @title AlgebraHypervisor
/// @notice Simplified Hypervisor that wraps an Algebra position as ERC20
contract AlgebraHypervisor {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public pool;
    address public owner;
    address public token0;
    address public token1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed sender, address indexed to, uint256 shares, uint256 amount0, uint256 amount1);
    event Withdraw(address indexed sender, address indexed to, uint256 shares, uint256 amount0, uint256 amount1);

    constructor(address _pool, address _owner, string memory _name, string memory _symbol) {
        pool = _pool;
        owner = _owner;
        name = _name;
        symbol = _symbol;

        token0 = IAlgebraPool(_pool).token0();
        token1 = IAlgebraPool(_pool).token1();
    }

    /// @notice Deposit tokens and receive shares
    function deposit(uint256 amount0, uint256 amount1, address to) external returns (uint256 shares) {
        // Simplified: shares = amount0 + amount1 (for testing)
        shares = amount0 + amount1;

        // Transfer tokens from sender
        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        // Mint shares
        _mint(to, shares);

        emit Deposit(msg.sender, to, shares, amount0, amount1);
    }

    /// @notice Withdraw tokens by burning shares
    function withdraw(uint256 shares, address to) external returns (uint256 amount0, uint256 amount1) {
        // Simplified: return proportional amounts
        amount0 = (shares * _balance0()) / totalSupply;
        amount1 = (shares * _balance1()) / totalSupply;

        // Burn shares
        _burn(msg.sender, shares);

        // Transfer tokens
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        emit Withdraw(msg.sender, to, shares, amount0, amount1);
    }

    function _balance0() internal view returns (uint256) {
        return IERC20(token0).balanceOf(address(this));
    }

    function _balance1() internal view returns (uint256) {
        return IERC20(token1).balanceOf(address(this));
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferFrom failed");
    }

    // ERC20 functions
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title AlgebraHypervisorFactory
/// @notice Factory for creating Hypervisors for Algebra pools
contract AlgebraHypervisorFactory {
    address public owner;
    IAlgebraFactory public algebraFactory;
    mapping(address => mapping(address => address)) public getHypervisor; // token0, token1 -> hypervisor
    address[] public allHypervisors;

    event HypervisorCreated(address indexed token0, address indexed token1, address hypervisor, uint256 index);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _algebraFactory) {
        require(_algebraFactory != address(0), "Zero address");
        algebraFactory = IAlgebraFactory(_algebraFactory);
        owner = msg.sender;
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Get the number of hypervisors created
    function allHypervisorsLength() external view returns (uint256) {
        return allHypervisors.length;
    }

    /// @notice Create a Hypervisor for an Algebra pool
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @param name Name of the hypervisor LP token
    /// @param symbol Symbol of the hypervisor LP token
    /// @return hypervisor Address of created hypervisor
    function createHypervisor(address tokenA, address tokenB, string memory name, string memory symbol)
        external
        onlyOwner
        returns (address hypervisor)
    {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");
        require(getHypervisor[token0][token1] == address(0), "HYPERVISOR_EXISTS");

        // Get Algebra pool
        address pool = algebraFactory.poolByPair(token0, token1);
        require(pool != address(0), "POOL_DOES_NOT_EXIST");

        // Create hypervisor
        hypervisor = address(new AlgebraHypervisor(pool, owner, name, symbol));

        getHypervisor[token0][token1] = hypervisor;
        getHypervisor[token1][token0] = hypervisor;
        allHypervisors.push(hypervisor);

        emit HypervisorCreated(token0, token1, hypervisor, allHypervisors.length - 1);
    }
}

