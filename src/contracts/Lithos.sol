// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.29;

import "./interfaces/ILithos.sol";
import "./layerzero/OFTCore.sol";

contract Lithos is ILithos, OFTCore {
    string public constant name = "Lithos";
    string public constant symbol = "LITH";
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 0;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool public initialMinted;
    address public minter;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address _lzEndpoint) OFTCore(_lzEndpoint) {
        minter = msg.sender;
        _mint(msg.sender, 0);
    }

    // No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function setMinter(address _minter) external {
        require(msg.sender == minter);
        minter = _minter;
    }

    // Initial mint: total 1B
    function initialMint(address _recipient) external {
        require(msg.sender == minter && !initialMinted);
        initialMinted = true;
        _mint(_recipient, 1 * 1000 * 1e6 * 1e18); // need to change in mainnet
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _mint(address _to, uint256 _amount) internal returns (bool) {
        totalSupply += _amount;
        unchecked {
            balanceOf[_to] += _amount;
        }
        emit Transfer(address(0x0), _to, _amount);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal returns (bool) {
        balanceOf[_from] -= _value;
        unchecked {
            balanceOf[_to] += _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        uint256 allowed_from = allowance[_from][msg.sender];
        if (allowed_from != type(uint256).max) {
            allowance[_from][msg.sender] -= _value;
        }
        return _transfer(_from, _to, _value);
    }

    function mint(address account, uint256 amount) external returns (bool) {
        require(msg.sender == minter, "not allowed");
        _mint(account, amount);
        return true;
    }

    // ========= LayerZero OFT overrides =========

    function circulatingSupply() public view virtual override returns (uint256) {
        return totalSupply;
    }

    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        if (_from != msg.sender) {
            uint256 allowed = allowance[_from][msg.sender];
            if (allowed != type(uint256).max) {
                allowance[_from][msg.sender] = allowed - _amount;
            }
        }

        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
        emit Transfer(_from, address(0), _amount);
        return _amount;
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        _mint(_toAddress, _amount);
        return _amount;
    }
}
