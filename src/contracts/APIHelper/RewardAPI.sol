// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "../libraries/Math.sol";
import "../interfaces/IBribeAPI.sol";
import "../interfaces/IWrappedBribeFactory.sol";
import "../interfaces/IGaugeAPI.sol";
import "../interfaces/IGaugeFactoryV2.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/IPair.sol";
import "../interfaces/IPairFactory.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IVotingEscrow.sol";
import "../interfaces/IRewardsDistributor.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RewardAPI is Initializable {
    IPairFactory public pairFactory;
    IVoter public voter;
    address public underlyingToken;
    address public owner;
    IRewardsDistributor public rewardsDistributor;

    constructor() {}

    function initialize(address _voter) public initializer {
        owner = msg.sender;
        voter = IVoter(_voter);
        pairFactory = _resolvePairFactory(_voter);
        underlyingToken = IVotingEscrow(voter.ve()).token();
    }

    function setRewardsDistributor(address _rewardsDistributor) external {
        require(msg.sender == owner, "not owner");
        require(_rewardsDistributor != address(0), "zeroAddr");
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
    }

    struct Bribes {
        address[] tokens;
        string[] symbols;
        uint[] decimals;
        uint[] amounts;
    }

    struct Rewards {
        Bribes[] bribes;
    }

    struct UserRewards {
        uint256 tokenId;
        uint256 rebaseReward;
        Bribes[] internalBribes;
        Bribes[] externalBribes;
    }

    struct AllUserRewards {
        UserRewards[] veNFTRewards;
        uint256 totalVeNFTs;
    }

    /// @notice Get the rewards available the next epoch.
    function getExpectedClaimForNextEpoch(
        uint tokenId,
        address[] memory pairs
    ) external view returns (Rewards[] memory) {
        uint i;
        uint len = pairs.length;
        address _gauge;
        address _bribe;

        Bribes[] memory _tempReward = new Bribes[](2);
        Rewards[] memory _rewards = new Rewards[](len);

        //external
        for (i = 0; i < len; i++) {
            _gauge = voter.gauges(pairs[i]);

            // get external
            _bribe = voter.external_bribes(_gauge);
            _tempReward[0] = _getEpochRewards(tokenId, _bribe);

            // get internal
            _bribe = voter.internal_bribes(_gauge);
            _tempReward[1] = _getEpochRewards(tokenId, _bribe);
            _rewards[i].bribes = _tempReward;
        }

        return _rewards;
    }

    function _getEpochRewards(
        uint tokenId,
        address _bribe
    ) internal view returns (Bribes memory _rewards) {
        uint totTokens = IBribeAPI(_bribe).rewardsListLength();
        uint[] memory _amounts = new uint[](totTokens);
        address[] memory _tokens = new address[](totTokens);
        string[] memory _symbol = new string[](totTokens);
        uint[] memory _decimals = new uint[](totTokens);
        uint ts = IBribeAPI(_bribe).getEpochStart();
        uint i = 0;
        uint _supply = IBribeAPI(_bribe).totalSupplyAt(ts);
        uint _balance = IBribeAPI(_bribe).balanceOfAt(tokenId, ts);
        address _token;
        IBribeAPI.Reward memory _reward;

        for (i; i < totTokens; i++) {
            _token = IBribeAPI(_bribe).rewardTokens(i);
            _tokens[i] = _token;
            if (_balance == 0) {
                _amounts[i] = 0;
                _symbol[i] = "";
                _decimals[i] = 0;
            } else {
                _symbol[i] = IERC20(_token).symbol();
                _decimals[i] = IERC20(_token).decimals();
                _reward = IBribeAPI(_bribe).rewardData(_token, ts);
                _amounts[i] =
                    (((_reward.rewardsPerEpoch * 1e18) / _supply) * _balance) /
                    1e18;
            }
        }

        _rewards.tokens = _tokens;
        _rewards.amounts = _amounts;
        _rewards.symbols = _symbol;
        _rewards.decimals = _decimals;
    }

    // read all the bribe available for a pair
    function getPairBribe(
        address pair
    ) external view returns (Bribes[] memory) {
        address _gauge;
        address _bribe;

        Bribes[] memory _tempReward = new Bribes[](2);

        // get external
        _gauge = voter.gauges(pair);
        _bribe = voter.external_bribes(_gauge);
        _tempReward[0] = _getNextEpochRewards(_bribe);

        // get internal
        _bribe = voter.internal_bribes(_gauge);
        _tempReward[1] = _getNextEpochRewards(_bribe);
        return _tempReward;
    }

    function _getNextEpochRewards(
        address _bribe
    ) internal view returns (Bribes memory _rewards) {
        uint totTokens = IBribeAPI(_bribe).rewardsListLength();
        uint[] memory _amounts = new uint[](totTokens);
        address[] memory _tokens = new address[](totTokens);
        string[] memory _symbol = new string[](totTokens);
        uint[] memory _decimals = new uint[](totTokens);
        uint ts = IBribeAPI(_bribe).getNextEpochStart();
        uint i = 0;
        address _token;
        IBribeAPI.Reward memory _reward;

        for (i; i < totTokens; i++) {
            _token = IBribeAPI(_bribe).rewardTokens(i);
            _tokens[i] = _token;
            _symbol[i] = IERC20(_token).symbol();
            _decimals[i] = IERC20(_token).decimals();
            _reward = IBribeAPI(_bribe).rewardData(_token, ts);
            _amounts[i] = _reward.rewardsPerEpoch;
        }

        _rewards.tokens = _tokens;
        _rewards.amounts = _amounts;
        _rewards.symbols = _symbol;
        _rewards.decimals = _decimals;
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner, "not owner");
        require(_owner != address(0), "zeroAddr");
        owner = _owner;
    }

    function setVoter(address _voter) external {
        require(msg.sender == owner, "not owner");
        require(_voter != address(0), "zeroAddr");
        voter = IVoter(_voter);
        // update variable depending on voter
        pairFactory = _resolvePairFactory(_voter);
        underlyingToken = IVotingEscrow(voter.ve()).token();
    }

    function getAllRewardsForVeNFTHolders(
        address _user
    ) external view returns (AllUserRewards memory allRewards) {
        IVotingEscrow ve = IVotingEscrow(voter.ve());
        uint256 userBalance = ve.balanceOf(_user);

        if (userBalance == 0) {
            allRewards.totalVeNFTs = 0;
            allRewards.veNFTRewards = new UserRewards[](0);
            return allRewards;
        }

        allRewards.totalVeNFTs = userBalance;
        allRewards.veNFTRewards = new UserRewards[](userBalance);

        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = ve.tokenOfOwnerByIndex(_user, i);

            UserRewards memory userReward;
            userReward.tokenId = tokenId;

            userReward.rebaseReward = rewardsDistributor.claimable(tokenId);

            // Get all bribes from all pools in the system
            (
                Bribes memory allInternalBribes,
                Bribes memory allExternalBribes
            ) = _getAllBribesForToken(tokenId);

            // Create arrays with single aggregated result
            userReward.internalBribes = new Bribes[](1);
            userReward.externalBribes = new Bribes[](1);
            userReward.internalBribes[0] = allInternalBribes;
            userReward.externalBribes[0] = allExternalBribes;

            allRewards.veNFTRewards[i] = userReward;
        }

        return allRewards;
    }

    function _getAllBribesForToken(
        uint256 tokenId
    )
        internal
        view
        returns (
            Bribes memory allInternalBribes,
            Bribes memory allExternalBribes
        )
    {
        uint256 totalPairs = pairFactory.allPairsLength();
        uint256 maxPairs = totalPairs > 50 ? 50 : totalPairs; // Limit to first 50 pairs for gas efficiency

        // Dynamic arrays to collect all rewards
        address[] memory internalTokens = new address[](100); // Reduced size
        uint256[] memory internalAmounts = new uint256[](100);
        string[] memory internalSymbols = new string[](100);
        uint256[] memory internalDecimals = new uint256[](100);
        uint256 internalCount = 0;

        address[] memory externalTokens = new address[](100);
        uint256[] memory externalAmounts = new uint256[](100);
        string[] memory externalSymbols = new string[](100);
        uint256[] memory externalDecimals = new uint256[](100);
        uint256 externalCount = 0;

        // Iterate through limited pairs
        for (uint256 i = 0; i < maxPairs; i++) {
            address pair = pairFactory.allPairs(i);
            address gauge = voter.gauges(pair);

            if (gauge == address(0)) continue;

            // Check internal bribes
            address internalBribe = voter.internal_bribes(gauge);
            if (internalBribe != address(0)) {
                internalCount = _collectBribeRewards(
                    tokenId,
                    internalBribe,
                    internalTokens,
                    internalAmounts,
                    internalSymbols,
                    internalDecimals,
                    internalCount
                );
            }

            // Check external bribes
            address externalBribe = voter.external_bribes(gauge);
            if (externalBribe != address(0)) {
                externalCount = _collectBribeRewards(
                    tokenId,
                    externalBribe,
                    externalTokens,
                    externalAmounts,
                    externalSymbols,
                    externalDecimals,
                    externalCount
                );
            }
        }

        // Create final arrays with exact size
        allInternalBribes.tokens = new address[](internalCount);
        allInternalBribes.amounts = new uint256[](internalCount);
        allInternalBribes.symbols = new string[](internalCount);
        allInternalBribes.decimals = new uint256[](internalCount);

        allExternalBribes.tokens = new address[](externalCount);
        allExternalBribes.amounts = new uint256[](externalCount);
        allExternalBribes.symbols = new string[](externalCount);
        allExternalBribes.decimals = new uint256[](externalCount);

        // Copy data to final arrays
        for (uint256 i = 0; i < internalCount; i++) {
            allInternalBribes.tokens[i] = internalTokens[i];
            allInternalBribes.amounts[i] = internalAmounts[i];
            allInternalBribes.symbols[i] = internalSymbols[i];
            allInternalBribes.decimals[i] = internalDecimals[i];
        }

        for (uint256 i = 0; i < externalCount; i++) {
            allExternalBribes.tokens[i] = externalTokens[i];
            allExternalBribes.amounts[i] = externalAmounts[i];
            allExternalBribes.symbols[i] = externalSymbols[i];
            allExternalBribes.decimals[i] = externalDecimals[i];
        }
    }

    function _collectBribeRewards(
        uint256 tokenId,
        address bribe,
        address[] memory tokens,
        uint256[] memory amounts,
        string[] memory symbols,
        uint256[] memory decimals,
        uint256 currentCount
    ) internal view returns (uint256 newCount) {
        uint256 rewardTokensLength = IBribeAPI(bribe).rewardsListLength();
        newCount = currentCount;

        for (uint256 i = 0; i < rewardTokensLength; i++) {
            address token = IBribeAPI(bribe).rewardTokens(i);
            uint256 earned = IBribeAPI(bribe).earned(tokenId, token);

            if (earned > 0) {
                // Check if token already exists (aggregate amounts)
                bool found = false;
                for (uint256 j = 0; j < newCount; j++) {
                    if (tokens[j] == token) {
                        amounts[j] += earned;
                        found = true;
                        break;
                    }
                }

                // If new token, add it
                if (!found && newCount < tokens.length) {
                    tokens[newCount] = token;
                    amounts[newCount] = earned;
                    symbols[newCount] = IERC20(token).symbol();
                    decimals[newCount] = IERC20(token).decimals();
                    newCount++;
                }
            }
        }
    }

    function _getClaimableBribes(
        uint256 tokenId,
        address _bribe
    ) internal view returns (Bribes memory _rewards) {
        if (_bribe == address(0)) {
            return _rewards;
        }

        uint totTokens = IBribeAPI(_bribe).rewardsListLength();
        if (totTokens == 0) {
            return _rewards;
        }

        uint[] memory _amounts = new uint[](totTokens);
        address[] memory _tokens = new address[](totTokens);
        string[] memory _symbol = new string[](totTokens);
        uint[] memory _decimals = new uint[](totTokens);

        for (uint i = 0; i < totTokens; i++) {
            address _token = IBribeAPI(_bribe).rewardTokens(i);
            _tokens[i] = _token;
            _amounts[i] = IBribeAPI(_bribe).earned(tokenId, _token);

            if (_amounts[i] > 0) {
                _symbol[i] = IERC20(_token).symbol();
                _decimals[i] = IERC20(_token).decimals();
            } else {
                _symbol[i] = "";
                _decimals[i] = 0;
            }
        }

        _rewards.tokens = _tokens;
        _rewards.amounts = _amounts;
        _rewards.symbols = _symbol;
        _rewards.decimals = _decimals;
    }

    function _resolvePairFactory(
        address _voter
    ) internal view returns (IPairFactory) {
        (bool ok, bytes memory data) = _voter.staticcall(
            abi.encodeWithSignature("factory()")
        );
        if (ok && data.length >= 32) {
            address factoryAddr = abi.decode(data, (address));
            if (factoryAddr != address(0)) {
                return IPairFactory(factoryAddr);
            }
        }

        (ok, data) = _voter.staticcall(abi.encodeWithSignature("factories()"));
        if (ok && data.length >= 32) {
            address[] memory factories = abi.decode(data, (address[]));
            if (factories.length > 0 && factories[0] != address(0)) {
                return IPairFactory(factories[0]);
            }
        }

        revert("RewardAPI: factory not found");
    }
}
