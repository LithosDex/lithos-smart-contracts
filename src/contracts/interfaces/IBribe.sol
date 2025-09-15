// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IBribe {
    function deposit(uint256 amount, uint256 tokenId) external;
    function withdraw(uint256 amount, uint256 tokenId) external;
    function getRewardForOwner(uint256 tokenId, address[] memory tokens) external;
    function getRewardForAddress(address _owner, address[] memory tokens) external;
    function notifyRewardAmount(address token, uint256 amount) external;
    function left(address token) external view returns (uint256);
}
