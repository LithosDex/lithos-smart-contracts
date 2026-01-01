// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./LzApp.sol";

abstract contract NonblockingLzApp is LzApp {
    mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32))) public failedMessages;

    event MessageFailed(
        uint16 indexed srcChainId,
        bytes srcAddress,
        uint64 indexed nonce,
        bytes payload,
        bytes reason
    );

    constructor(address _endpoint) LzApp(_endpoint) {}

    function _blockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) internal virtual override {
        try this.nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload) {
            // no-op on success
        } catch (bytes memory reason) {
            failedMessages[_srcChainId][_srcAddress][_nonce] = keccak256(_payload);
            emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload, reason);
        }
    }

    function nonblockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external virtual {
        require(msg.sender == address(this), "NonblockingLzApp: caller must be LzApp");
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function retryMessage(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external virtual payable {
        bytes32 payloadHash = failedMessages[_srcChainId][_srcAddress][_nonce];
        require(payloadHash != bytes32(0), "NonblockingLzApp: no stored message");
        require(payloadHash == keccak256(_payload), "NonblockingLzApp: invalid payload");

        failedMessages[_srcChainId][_srcAddress][_nonce] = bytes32(0);
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) internal virtual;
}
