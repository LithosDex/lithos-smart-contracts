// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./NonblockingLzApp.sol";

abstract contract OFTCore is NonblockingLzApp {
    uint16 public constant PT_SEND = 0;

    struct LzCallParams {
        address payable refundAddress;
        address zroPaymentAddress;
        bytes adapterParams;
    }

    event SendToChain(
        uint16 indexed dstChainId,
        address indexed from,
        bytes toAddress,
        uint256 amountLD,
        uint64 nonce
    );

    event ReceiveFromChain(
        uint16 indexed srcChainId,
        address indexed to,
        uint256 amountLD,
        uint64 nonce
    );

    constructor(address _endpoint) NonblockingLzApp(_endpoint) {}

    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        LzCallParams calldata _callParams
    ) public payable virtual returns (uint64 nonce) {
        nonce = _send(_from, _dstChainId, _toAddress, _amount, _callParams);
    }

    function send(
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        LzCallParams calldata _callParams
    ) external payable virtual returns (uint64 nonce) {
        return sendFrom(_msgSender(), _dstChainId, _toAddress, _amount, _callParams);
    }

    function estimateSendFee(
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        bool _payInZRO,
        bytes calldata _adapterParams
    ) external view virtual returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(PT_SEND, _toAddress, _amount);
        return lzEndpoint.estimateFees(_dstChainId, address(this), payload, _payInZRO, _adapterParams);
    }

    function circulatingSupply() public view virtual returns (uint256);

    function _debitFrom(
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint256 _amount
    ) internal virtual returns (uint256);

    function _creditTo(
        uint16 _srcChainId,
        address _toAddress,
        uint256 _amount
    ) internal virtual returns (uint256);

    function _send(
        address _from,
        uint16 _dstChainId,
        bytes calldata _toAddress,
        uint256 _amount,
        LzCallParams calldata _callParams
    ) internal virtual returns (uint64 nonce) {
        _checkGasLimit(_dstChainId, PT_SEND, _callParams.adapterParams);

        uint256 amountDebited = _debitFrom(_from, _dstChainId, _toAddress, _amount);
        bytes memory payload = abi.encode(PT_SEND, _toAddress, amountDebited);

        nonce = _lzSend(
            _dstChainId,
            payload,
            _callParams.refundAddress,
            _callParams.zroPaymentAddress,
            _callParams.adapterParams,
            msg.value
        );

        emit SendToChain(_dstChainId, _from, _toAddress, amountDebited, nonce);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) internal virtual override {
        (uint16 packetType, bytes memory toAddressBytes, uint256 amountLD) = abi.decode(
            _payload,
            (uint16, bytes, uint256)
        );
        require(packetType == PT_SEND, "OFTCore: unknown packet type");

        address toAddress = _bytesToAddress(toAddressBytes);
        uint256 amountReceived = _creditTo(_srcChainId, toAddress, amountLD);

        emit ReceiveFromChain(_srcChainId, toAddress, amountReceived, _nonce);
    }

    function _bytesToAddress(bytes memory _addressBytes) internal pure returns (address addr) {
        require(_addressBytes.length == 20, "OFTCore: invalid address");
        assembly {
            addr := mload(add(_addressBytes, 20))
        }
    }
}
