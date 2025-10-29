// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {PairAPI} from "../src/contracts/APIHelper/PairAPI.sol";
import {RewardAPI} from "../src/contracts/APIHelper/RewardAPI.sol";
import {veNFTAPI} from "../src/contracts/APIHelper/veNFTAPI.sol";

import {IPair} from "../src/contracts/interfaces/IPair.sol";
import {IPairFactory} from "../src/contracts/interfaces/IPairFactory.sol";
import {IVotingEscrow} from "../src/contracts/interfaces/IVotingEscrow.sol";
import {IRewardsDistributor} from "../src/contracts/interfaces/IRewardsDistributor.sol";
import {IBribeAPI} from "../src/contracts/interfaces/IBribeAPI.sol";
import {IGaugeAPI} from "../src/contracts/interfaces/IGaugeAPI.sol";
import {IERC20} from "../src/contracts/interfaces/IERC20.sol";

import {IVoter} from "../src/contracts/interfaces/IVoter.sol";

contract APIHelperMainnetForkTest is Test {
    using stdJson for string;

    PairAPI internal pairApi;
    RewardAPI internal rewardApi;
    veNFTAPI internal venftApi;

    IVoter internal voter;
    IVotingEscrow internal ve;
    IPairFactory internal pairFactory;
    IRewardsDistributor internal rewardsDistributor;

    function setUp() external {
        string memory rpcUrl = "https://rpc.plasma.to";
        if (vm.envExists("RPC_URL")) {
            rpcUrl = vm.envString("RPC_URL");
        }

        vm.createSelectFork(rpcUrl);

        string memory json = vm.readFile("deployments/mainnet/state.json");
        address voterAddr = json.readAddress(".Voter");
        address rewardsDistributorAddr = json.readAddress(".RewardsDistributor");

        pairApi = new PairAPI();
        pairApi.initialize(voterAddr);

        rewardApi = new RewardAPI();
        rewardApi.initialize(voterAddr);

        venftApi = new veNFTAPI();
        venftApi.initialize(voterAddr, rewardsDistributorAddr, address(pairApi));

        voter = IVoter(voterAddr);
        ve = IVotingEscrow(voter.ve());
        pairFactory = pairApi.pairFactory();
        rewardsDistributor = IRewardsDistributor(rewardsDistributorAddr);
    }

    function testPairAPIGetPairMatchesCoreData() external {
        (address pairAddr, address gaugeAddr) = _findPairWithGauge(50);
        if (pairAddr == address(0)) {
            vm.skip(true, "no pair with an active gauge found in search window");
        }

        address account = gaugeAddr;
        PairAPI.pairInfo memory info = pairApi.getPair(pairAddr, account);
        IPair pair = IPair(pairAddr);
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

        assertEq(info.pair_address, pairAddr, "pair address");
        assertEq(info.symbol, pair.symbol(), "pair symbol");
        assertEq(info.name, pair.name(), "pair name");
        assertEq(info.decimals, pair.decimals(), "pair decimals");
        assertEq(info.stable, pair.isStable(), "pool type");
        assertEq(info.total_supply, pair.totalSupply(), "total supply");

        address token0 = pair.token0();
        address token1 = pair.token1();

        assertEq(info.token0, token0, "token0");
        assertEq(info.token0_decimals, IERC20(token0).decimals(), "token0 decimals");
        assertEq(_hashString(info.token0_symbol), _hashString(IERC20(token0).symbol()), "token0 symbol");
        assertEq(info.reserve0, reserve0, "reserve0");

        assertEq(info.token1, token1, "token1");
        assertEq(info.token1_decimals, IERC20(token1).decimals(), "token1 decimals");
        assertEq(_hashString(info.token1_symbol), _hashString(IERC20(token1).symbol()), "token1 symbol");
        assertEq(info.reserve1, reserve1, "reserve1");

        bool isPair = pairFactory.isPair(pairAddr);
        uint256 expectedClaimable0;
        uint256 expectedClaimable1;
        if (isPair) {
            expectedClaimable0 = pair.claimable0(account);
            expectedClaimable1 = pair.claimable1(account);
        }

        assertEq(info.claimable0, expectedClaimable0, "claimable0");
        assertEq(info.claimable1, expectedClaimable1, "claimable1");

        assertEq(info.gauge, gaugeAddr, "gauge");
        assertEq(info.gauge_total_supply, IGaugeAPI(gaugeAddr).totalSupply(), "gauge total supply");
        assertEq(info.emissions, IGaugeAPI(gaugeAddr).rewardRate(), "reward rate");
        assertEq(info.emissions_token, ve.token(), "reward token");
        assertEq(info.emissions_token_decimals, IERC20(ve.token()).decimals(), "reward token decimals");

        assertEq(info.fee, voter.internal_bribes(gaugeAddr), "fee address");
        assertEq(info.bribe, voter.external_bribes(gaugeAddr), "bribe address");

        assertEq(info.account_lp_balance, IERC20(pairAddr).balanceOf(account), "account lp balance");
        assertEq(info.account_token0_balance, IERC20(token0).balanceOf(account), "account token0 balance");
        assertEq(info.account_token1_balance, IERC20(token1).balanceOf(account), "account token1 balance");
        assertEq(info.account_gauge_balance, IGaugeAPI(gaugeAddr).balanceOf(account), "account gauge balance");
        assertEq(info.account_gauge_earned, IGaugeAPI(gaugeAddr).earned(account), "account earned balance");
    }

    function testPairAPIGetAllPairRespectsFactoryOrder() external {
        uint256 totalPairs = pairFactory.allPairsLength();
        uint256 sampleSize = totalPairs >= 3 ? 3 : totalPairs;
        if (sampleSize == 0) {
            vm.skip(true, "pair factory empty on fork");
        }

        PairAPI.pairInfo[] memory pairs = pairApi.getAllPair(address(0), sampleSize, 0);

        for (uint256 i = 0; i < sampleSize; i++) {
            address expected = pairFactory.allPairs(i);
            assertEq(pairs[i].pair_address, expected, "pair ordering mismatch");
        }
    }

    function testPairAPIGetPairBribeReflectsBribeContract() external {
        (address pairAddr, address gaugeAddr, address externalBribe,) = _findPairWithExternalBribe(100);
        if (pairAddr == address(0)) {
            vm.skip(true, "pair with external bribe not found in search window");
        }

        PairAPI.pairBribeEpoch[] memory epochs = pairApi.getPairBribe(1, 0, pairAddr);
        assertEq(epochs.length, 1, "epoch length");
        assertEq(epochs[0].pair, pairAddr, "epoch pair");

        uint256 tokensLen = IBribeAPI(externalBribe).rewardsListLength();
        assertEq(epochs[0].bribes.length, tokensLen, "epoch bribes length");

        if (tokensLen > 0) {
            address rewardToken = IBribeAPI(externalBribe).rewardTokens(0);
            assertEq(epochs[0].bribes[0].token, rewardToken, "reward token address");
            assertEq(epochs[0].bribes[0].decimals, IERC20(rewardToken).decimals(), "reward token decimals");
        }

        assertEq(epochs[0].totalVotes, IBribeAPI(externalBribe).totalSupplyAt(epochs[0].epochTimestamp), "total votes");
        assertEq(epochs[0].bribes.length, tokensLen, "rewards length");

        // Sanity check that the API wires through the gauge address it derived earlier
        assertEq(pairApi.getPair(pairAddr, address(0)).gauge, gaugeAddr, "gauge resolved via getPair");
    }

    function testRewardAPIPairBribeMatchesUnderlyingBribe() external {
        (address pairAddr, address gaugeAddr, address externalBribe, address internalBribe) =
            _findPairWithExternalBribe(100);
        if (pairAddr == address(0)) {
            vm.skip(true, "pair with external bribe not found in search window");
        }

        RewardAPI.Bribes[] memory pairBribes = rewardApi.getPairBribe(pairAddr);
        assertEq(pairBribes.length, 2, "expected external and internal bribe slots");

        uint256 externalLen = IBribeAPI(externalBribe).rewardsListLength();
        assertEq(pairBribes[0].tokens.length, externalLen, "external rewards length");
        if (externalLen > 0) {
            address rewardToken = pairBribes[0].tokens[0];
            assertEq(pairBribes[0].decimals[0], IERC20(rewardToken).decimals(), "external decimals passthrough");
            assertEq(
                _hashString(pairBribes[0].symbols[0]), _hashString(IERC20(rewardToken).symbol()), "external symbol"
            );
        }

        if (internalBribe != address(0)) {
            uint256 internalLen = IBribeAPI(internalBribe).rewardsListLength();
            assertEq(pairBribes[1].tokens.length, internalLen, "internal rewards length");
        } else {
            assertEq(pairBribes[1].tokens.length, 0, "no internal bribe expected");
        }

        assertEq(voter.gauges(pairAddr), gaugeAddr, "gauge expectation");
    }

    function testRewardAPIExpectedClaimForNextEpochShapesAgainstBribe() external {
        uint256 tokenId = _findExistingTokenId(50);
        if (tokenId == 0) {
            vm.skip(true, "no minted veNFT found within search window");
        }

        (address pairAddr,, address externalBribe,) = _findPairWithExternalBribe(100);
        if (pairAddr == address(0)) {
            vm.skip(true, "pair with external bribe not found in search window");
        }

        address[] memory pairs = new address[](1);
        pairs[0] = pairAddr;

        RewardAPI.Rewards[] memory rewards = rewardApi.getExpectedClaimForNextEpoch(tokenId, pairs);
        assertEq(rewards.length, 1, "rewards length");
        assertEq(rewards[0].bribes.length, 2, "bribe buckets");

        uint256 externalLen = IBribeAPI(externalBribe).rewardsListLength();
        assertEq(rewards[0].bribes[0].tokens.length, externalLen, "external reward length");
        if (externalLen > 0) {
            address rewardToken = rewards[0].bribes[0].tokens[0];
            if (rewards[0].bribes[0].decimals[0] > 0) {
                assertEq(rewards[0].bribes[0].decimals[0], IERC20(rewardToken).decimals(), "external reward decimals");
            } else {
                assertEq(rewards[0].bribes[0].amounts[0], 0, "no rewards expected without allocation");
            }
        }
    }

    function testVeNFTAPIGathersMetadataFromVotingEscrow() external {
        uint256 tokenId = _findExistingTokenId(50);
        if (tokenId == 0) {
            vm.skip(true, "no minted veNFT found within search window");
        }

        address owner;
        try ve.ownerOf(tokenId) returns (address tokenOwner) {
            owner = tokenOwner;
        } catch {
            vm.skip(true, "veNFT owner lookup failed");
        }

        veNFTAPI.veNFT memory venft = venftApi.getNFTFromId(tokenId);
        IVotingEscrow.LockedBalance memory lock = ve.locked(tokenId);

        assertEq(venft.id, tokenId, "token id");
        assertEq(venft.account, owner, "owner");
        assertEq(venft.decimals, ve.decimals(), "ve decimals");
        assertEq(uint256(venft.amount), uint256(uint128(lock.amount)), "locked amount");
        assertEq(venft.voting_amount, ve.balanceOfNFT(tokenId), "voting balance");
        assertEq(venft.rebase_amount, rewardsDistributor.claimable(tokenId), "rebase claimable");
        assertEq(venft.lockEnd, lock.end, "lock end");
        assertEq(venft.vote_ts, voter.lastVoted(tokenId), "last vote timestamp");
        assertEq(venft.token, ve.token(), "staking token");
        assertEq(_hashString(venft.tokenSymbol), _hashString(IERC20(ve.token()).symbol()), "token symbol");
        assertEq(venft.tokenDecimals, IERC20(ve.token()).decimals(), "token decimals");
        assertEq(venft.voted, ve.voted(tokenId), "voted flag");
        assertEq(venft.attachments, ve.attachments(tokenId), "attachments");
    }

    // --- helpers -------------------------------------------------------------

    function _findPairWithGauge(uint256 maxSearch) internal view returns (address pair, address gauge) {
        uint256 totalPairs = pairFactory.allPairsLength();
        uint256 upper = totalPairs < maxSearch ? totalPairs : maxSearch;

        for (uint256 i = 0; i < upper; i++) {
            address currentPair = pairFactory.allPairs(i);
            address currentGauge = voter.gauges(currentPair);
            if (currentGauge != address(0)) {
                return (currentPair, currentGauge);
            }
        }
        return (address(0), address(0));
    }

    function _findPairWithExternalBribe(uint256 maxSearch)
        internal
        view
        returns (address pair, address gauge, address externalBribe, address internalBribe)
    {
        uint256 totalPairs = pairFactory.allPairsLength();
        uint256 upper = totalPairs < maxSearch ? totalPairs : maxSearch;

        for (uint256 i = 0; i < upper; i++) {
            address currentPair = pairFactory.allPairs(i);
            address currentGauge = voter.gauges(currentPair);
            if (currentGauge == address(0)) {
                continue;
            }

            address ext = voter.external_bribes(currentGauge);
            if (ext == address(0)) {
                continue;
            }

            try IBribeAPI(ext).rewardsListLength() returns (uint256 len) {
                if (len > 0) {
                    return (currentPair, currentGauge, ext, voter.internal_bribes(currentGauge));
                }
            } catch {
                continue;
            }
        }

        return (address(0), address(0), address(0), address(0));
    }

    function _findExistingTokenId(uint256 maxTokenId) internal view returns (uint256) {
        uint256 upper = maxTokenId;
        uint256 total = ve.totalSupply();
        if (total < upper) {
            upper = total;
        }

        for (uint256 id = 1; id <= upper; id++) {
            try ve.ownerOf(id) returns (address owner) {
                if (owner != address(0)) {
                    return id;
                }
            } catch {
                continue;
            }
        }
        return 0;
    }

    function _hashString(string memory value) internal pure returns (bytes32) {
        return keccak256(bytes(value));
    }
}
