// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./OFTCore.sol";

abstract contract OFT is OFTCore, ERC20 {
    constructor(string memory _name, string memory _symbol, address _lzEndpoint)
        ERC20(_name, _symbol)
        OFTCore(_lzEndpoint)
    {}

    function circulatingSupply() public view virtual override returns (uint256) {
        return totalSupply();
    }

    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        if (_from != _msgSender()) {
            _spendAllowance(_from, _msgSender(), _amount);
        }
        _burn(_from, _amount);
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

    function _msgSender()
        internal
        view
        virtual
        override(Context)
        returns (address)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context)
        returns (bytes calldata)
    {
        return super._msgData();
    }
}
