// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IVoter {
    function ve() external view returns (address);
    function gauges(address _pair) external view returns (address);
    function isGauge(address _gauge) external view returns (bool);
    function poolForGauge(address _gauge) external view returns (address);
    function factory() external view returns (address);
    function minter() external view returns (address);
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint256 amount) external;
    function distributeAll() external;
    function distributeFees(address[] memory _gauges) external;

    function internal_bribes(address _gauge) external view returns (address);
    function external_bribes(address _gauge) external view returns (address);

    function usedWeights(uint256 id) external view returns (uint256);
    function lastVoted(uint256 id) external view returns (uint256);
    function poolVote(uint256 id, uint256 _index) external view returns (address _pair);
    function votes(uint256 id, address _pool) external view returns (uint256 votes);
    function poolVoteLength(uint256 tokenId) external view returns (uint256);
}
