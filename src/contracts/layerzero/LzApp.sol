// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroUserApplicationConfig.sol";

abstract contract LzApp is Ownable, ILayerZeroReceiver, ILayerZeroUserApplicationConfig {
    ILayerZeroEndpoint public immutable lzEndpoint;

    mapping(uint16 => bytes) public trustedRemoteLookup;
    mapping(uint16 => mapping(uint16 => uint256)) public minDstGasLookup;

    bool public useCustomAdapterParams;

    event SetTrustedRemote(uint16 indexed srcChainId, bytes srcAddress);
    event SetTrustedRemoteAddress(uint16 indexed remoteChainId, bytes remoteAddress);
    event SetUseCustomAdapterParams(bool useCustomAdapterParams);
    event SetMinDstGas(uint16 indexed dstChainId, uint16 indexed packetType, uint256 minGas);

    constructor(address _endpoint) Ownable(msg.sender) {
        require(_endpoint != address(0), "LzApp: endpoint not set");
        lzEndpoint = ILayerZeroEndpoint(_endpoint);
    }

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external virtual override {
        require(msg.sender == address(lzEndpoint), "LzApp: invalid endpoint caller");
        bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
        require(trustedRemote.length != 0, "LzApp: invalid source chain");
        require(
            _srcAddress.length == trustedRemote.length && keccak256(_srcAddress) == keccak256(trustedRemote),
            "LzApp: invalid source sending contract"
        );
        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _blockingLzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) internal virtual;

    function _lzSend(
        uint16 _dstChainId,
        bytes memory _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams,
        uint256 _nativeFee
    ) internal virtual returns (uint64) {
        bytes memory trustedRemote = trustedRemoteLookup[_dstChainId];
        require(trustedRemote.length != 0, "LzApp: destination chain not trusted");

        lzEndpoint.send{value: _nativeFee}(
            _dstChainId,
            trustedRemote,
            _payload,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams
        );

        return lzEndpoint.getOutboundNonce(_dstChainId, address(this));
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        lzEndpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }

    function setTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external onlyOwner {
        trustedRemoteLookup[_srcChainId] = _srcAddress;
        emit SetTrustedRemote(_srcChainId, _srcAddress);
    }

    function setTrustedRemoteAddress(uint16 _dstChainId, bytes calldata _remoteAddress) external onlyOwner {
        trustedRemoteLookup[_dstChainId] = _remoteAddress;
        emit SetTrustedRemoteAddress(_dstChainId, _remoteAddress);
    }

    function setUseCustomAdapterParams(bool _value) external onlyOwner {
        useCustomAdapterParams = _value;
        emit SetUseCustomAdapterParams(_value);
    }

    function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint256 _minGas) external onlyOwner {
        minDstGasLookup[_dstChainId][_packetType] = _minGas;
        emit SetMinDstGas(_dstChainId, _packetType, _minGas);
    }

    function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes calldata _config)
        external
        override
        onlyOwner
    {
        lzEndpoint.setConfig(_version, _chainId, _configType, _config);
    }

    function setSendVersion(uint16 _version) external override onlyOwner {
        lzEndpoint.setSendVersion(_version);
    }

    function setReceiveVersion(uint16 _version) external override onlyOwner {
        lzEndpoint.setReceiveVersion(_version);
    }

    function getConfig(uint16 _version, uint16 _chainId, uint256 _configType) external view returns (bytes memory) {
        return lzEndpoint.getConfig(_version, _chainId, address(this), _configType);
    }

    function _checkGasLimit(uint16 _dstChainId, uint16 _packetType, bytes memory _adapterParams) internal view {
        if (useCustomAdapterParams || _adapterParams.length == 0) {
            return;
        }

        require(_adapterParams.length >= 34, "LzApp: invalid adapter params");

        uint256 providedGas;
        assembly {
            providedGas := mload(add(_adapterParams, 34))
        }

        uint256 minGas = minDstGasLookup[_dstChainId][_packetType];
        require(minGas > 0, "LzApp: min gas not set");
        require(providedGas >= minGas, "LzApp: gas limit too low");
    }

}
