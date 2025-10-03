// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface ILayerZeroEndpoint {
    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable;

    function receivePayload(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        address _dstAddress,
        uint64 _nonce,
        uint256 _gasLimit,
        bytes calldata _payload
    ) external;

    function estimateFees(
        uint16 _dstChainId,
        address _userApplication,
        bytes calldata _payload,
        bool _payInZRO,
        bytes calldata _adapterParams
    ) external view returns (uint256 nativeFee, uint256 zroFee);

    function getOutboundNonce(uint16 _dstChainId, address _srcAddress) external view returns (uint64);

    function getInboundNonce(uint16 _srcChainId, address _dstAddress) external view returns (uint64);

    function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes calldata _config) external;

    function getConfig(
        uint16 _version,
        uint16 _chainId,
        address _ua,
        uint256 _configType
    ) external view returns (bytes memory);

    function setSendVersion(uint16 _version) external;

    function setReceiveVersion(uint16 _version) external;

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external;
}
