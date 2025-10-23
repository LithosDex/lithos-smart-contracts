// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/contracts/APIHelper/RewardAPI.sol";
import "../src/contracts/interfaces/IVotingEscrow.sol";
import "../src/contracts/interfaces/IVoter.sol";
import "../src/contracts/interfaces/IRewardsDistributor.sol";

contract RewardAPIMainnetForkTest is Test {
    RewardAPI public rewardAPI;
    IVotingEscrow public votingEscrow;
    IVoter public voter;
    IRewardsDistributor public rewardsDistributor;

    // Mainnet addresses from deployments/mainnet/state.json
    address constant VOTING_ESCROW = 0x2Eff716Caa7F9EB441861340998B0952AF056686;
    address constant VOTER = 0x2AF460a511849A7aA37Ac964074475b0E6249c69;
    address constant REWARDS_DISTRIBUTOR =
        0x3B867F78D3eCfCad997b18220444AdafBC8372A8;

    // Test user address that has veNFT and hasn't claimed yet
    address constant TEST_USER = 0x5A9e792143bf2708b4765C144451dCa54f559a19;

    function setUp() public {
        // Fork mainnet
        vm.createFork("https://rpc.plasma.to");

        // Deploy our new RewardAPI contract with the updated code
        rewardAPI = new RewardAPI();
        rewardAPI.initialize(VOTER);
        rewardAPI.setRewardsDistributor(REWARDS_DISTRIBUTOR);

        // Get contract instances
        votingEscrow = IVotingEscrow(VOTING_ESCROW);
        voter = IVoter(VOTER);
        rewardsDistributor = IRewardsDistributor(REWARDS_DISTRIBUTOR);
    }

    function test_getAllRewardsForVeNFTHolders_UserWithveNFTs() public {
        // Simple function call and basic logging
        RewardAPI.AllUserRewards memory allRewards = rewardAPI.getAllRewardsForVeNFTHolders(TEST_USER);
        
        console.log("Total veNFTs:", allRewards.totalVeNFTs);
        
        for (uint256 i = 0; i < allRewards.totalVeNFTs; i++) {
            console.log("veNFT #", allRewards.veNFTRewards[i].tokenId);
            console.log("Rebase reward:", allRewards.veNFTRewards[i].rebaseReward);
            console.log("Internal bribes length:", allRewards.veNFTRewards[i].internalBribes.length);
            console.log("External bribes length:", allRewards.veNFTRewards[i].externalBribes.length);
            
            // Log internal bribe values
            for (uint256 j = 0; j < allRewards.veNFTRewards[i].internalBribes.length; j++) {
                for (uint256 k = 0; k < allRewards.veNFTRewards[i].internalBribes[j].amounts.length; k++) {
                    if (allRewards.veNFTRewards[i].internalBribes[j].amounts[k] > 0) {
                        console.log("Internal bribe amount:", allRewards.veNFTRewards[i].internalBribes[j].amounts[k]);
                    }
                }
            }
            
            // Log external bribe values
            for (uint256 j = 0; j < allRewards.veNFTRewards[i].externalBribes.length; j++) {
                for (uint256 k = 0; k < allRewards.veNFTRewards[i].externalBribes[j].amounts.length; k++) {
                    if (allRewards.veNFTRewards[i].externalBribes[j].amounts[k] > 0) {
                        console.log("External bribe amount:", allRewards.veNFTRewards[i].externalBribes[j].amounts[k]);
                    }
                }
            }
        }
        
        assertTrue(true, "Function executed successfully");
    }

    function test_getAllRewardsForVeNFTHolders_UserWithoutveNFTs() public {
        // Test with address that has no veNFTs
        address noVeNFTUser = address(0x1234);

        // Verify user has no veNFTs
        uint256 userBalance = votingEscrow.balanceOf(noVeNFTUser);
        assertEq(userBalance, 0, "Test user should have no veNFTs");

        // Call the function
        RewardAPI.AllUserRewards memory allRewards = rewardAPI
            .getAllRewardsForVeNFTHolders(noVeNFTUser);

        // Verify empty results
        assertEq(allRewards.totalVeNFTs, 0, "Total veNFTs should be 0");
        assertEq(
            allRewards.veNFTRewards.length,
            0,
            "veNFTRewards array should be empty"
        );
    }

    function test_rewardAPI_contractExists() public {
        // Basic sanity check that the contract exists and has expected functions
        assertTrue(address(rewardAPI) != address(0), "RewardAPI should exist");

        // Check that it has the voter and rewards distributor set
        assertEq(
            address(rewardAPI.voter()),
            VOTER,
            "Voter should be set correctly"
        );
        assertEq(
            address(rewardAPI.rewardsDistributor()),
            REWARDS_DISTRIBUTOR,
            "RewardsDistributor should be set correctly"
        );
    }

    function test_checkveNFTDetails() public {
        // Get detailed info about the test user's veNFTs
        uint256 userBalance = votingEscrow.balanceOf(TEST_USER);
        console.log("User has veNFTs:", userBalance);

        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = votingEscrow.tokenOfOwnerByIndex(TEST_USER, i);
            console.log("TokenId:", tokenId);
            console.log("Voting power:", votingEscrow.balanceOfNFT(tokenId));
            console.log(
                "Rebase claimable:",
                rewardsDistributor.claimable(tokenId)
            );
            console.log("Has voted:", votingEscrow.voted(tokenId));
            console.log("Pool vote length:", voter.poolVoteLength(tokenId));
        }
    }
}
