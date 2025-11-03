// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script, console2} from "forge-std/Script.sol";

import {IVotingEscrow} from "../src/contracts/interfaces/IVotingEscrow.sol";
import {IVoter} from "../src/contracts/interfaces/IVoter.sol";
import {IBribeAPI} from "../src/contracts/interfaces/IBribeAPI.sol";
import {IPair} from "../src/contracts/interfaces/IPair.sol";
import {VoterV3} from "../src/contracts/VoterV3.sol";

interface IRewardsDistributorClaim {
    function claim(uint256 _tokenId) external returns (uint256);
    function claim_many(uint256[] memory _tokenIds) external returns (bool);
}

contract ClaimVeNFTRewardsScript is Script {
    struct DeployedAddrs {
        address voter;
        address ve;
        address rewardsDistributor;
    }

    DeployedAddrs internal deployed;

    function run() external {
        string memory env = vm.envOr("DEPLOY_ENV", string("mainnet"));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(pk);

        string memory statePath = string.concat("deployments/", env, "/state.json");
        _loadState(statePath);

        require(deployed.voter != address(0), "voter missing");
        require(deployed.ve != address(0), "ve missing");
        require(deployed.rewardsDistributor != address(0), "rewardsDistributor missing");

        VoterV3 voter = VoterV3(deployed.voter);
        IVotingEscrow ve = IVotingEscrow(deployed.ve);
        IRewardsDistributorClaim rewards = IRewardsDistributorClaim(deployed.rewardsDistributor);

        console2.log("=== Claim veNFT Rewards (bribes, fees, rebase) ===");
        console2.log("Environment:", env);
        console2.log("Caller:", caller);
        console2.log("Voter:", address(voter));
        console2.log("ve:", address(ve));
        console2.log("RewardsDistributor:", address(rewards));

        uint256 nftCount = ve.balanceOf(caller);
        require(nftCount > 0, "no veNFTs for caller");
        console2.log("veNFTs owned:", nftCount);

        uint256[] memory tokenIds = new uint256[](nftCount);
        for (uint256 i = 0; i < nftCount; i++) {
            tokenIds[i] = ve.tokenOfOwnerByIndex(caller, i);
            console2.log("  - tokenId:", tokenIds[i]);
        }

        vm.startBroadcast(pk);

        // Claim rebase for all tokenIds
        console2.log("Claiming rebase via RewardsDistributor.claim_many...\n");
        try rewards.claim_many(tokenIds) returns (bool ok) {
            console2.log("Rebase claim_many success:", ok);
        } catch {
            console2.log("Rebase claim_many failed, attempting individual claims");
            for (uint256 i = 0; i < tokenIds.length; i++) {
                try rewards.claim(tokenIds[i]) returns (uint256 amt) {
                    console2.log("  tokenId", tokenIds[i], "rebase claimed:", amt);
                } catch {
                    console2.log("  tokenId", tokenIds[i], "rebase claim failed");
                }
            }
        }

        // For each tokenId, aggregate bribe + fee claims based on current votes
        for (uint256 t = 0; t < tokenIds.length; t++) {
            uint256 tokenId = tokenIds[t];
            uint256 pvLen = IVoter(address(voter)).poolVoteLength(tokenId);

            // Upper-bound entries by 2 per pool (fee + external bribe)
            address[] memory feeAddrsTmp = new address[](pvLen);
            address[][] memory feeTokensTmp = new address[][](pvLen);
            uint256 feeCount = 0;

            address[] memory bribeAddrsTmp = new address[](pvLen);
            address[][] memory bribeTokensTmp = new address[][](pvLen);
            uint256 bribeCount = 0;

            for (uint256 i = 0; i < pvLen; i++) {
                address pair = IVoter(address(voter)).poolVote(tokenId, i);
                if (pair == address(0)) continue;

                address gauge = IVoter(address(voter)).gauges(pair);
                if (gauge == address(0)) continue;

                address feeBribe = IVoter(address(voter)).internal_bribes(gauge);
                address extBribe = IVoter(address(voter)).external_bribes(gauge);

                // Fee claim: pair's token0/token1
                if (feeBribe != address(0)) {
                    address t0 = IPair(pair).token0();
                    address t1 = IPair(pair).token1();
                    address[] memory ftoks = new address[](2);
                    ftoks[0] = t0;
                    ftoks[1] = t1;
                    feeAddrsTmp[feeCount] = feeBribe;
                    feeTokensTmp[feeCount] = ftoks;
                    feeCount++;
                }

                // External bribes: dynamic reward token list
                if (extBribe != address(0)) {
                    uint256 n = 0;
                    // Wrap in try/catch in case the contract doesn't expose rewardsListLength()
                    try IBribeAPI(extBribe).rewardsListLength() returns (uint256 len) {
                        n = len;
                    } catch {
                        n = 0;
                    }

                    if (n > 0) {
                        address[] memory btoks = new address[](n);
                        for (uint256 k = 0; k < n; k++) {
                            btoks[k] = IBribeAPI(extBribe).rewardTokens(k);
                        }
                        bribeAddrsTmp[bribeCount] = extBribe;
                        bribeTokensTmp[bribeCount] = btoks;
                        bribeCount++;
                    }
                }
            }

            // Trim arrays to actual sizes
            address[] memory feeAddrs = new address[](feeCount);
            address[][] memory feeTokens = new address[][](feeCount);
            for (uint256 j = 0; j < feeCount; j++) {
                feeAddrs[j] = feeAddrsTmp[j];
                feeTokens[j] = feeTokensTmp[j];
            }

            address[] memory bribeAddrs = new address[](bribeCount);
            address[][] memory bribeTokens = new address[][](bribeCount);
            for (uint256 j = 0; j < bribeCount; j++) {
                bribeAddrs[j] = bribeAddrsTmp[j];
                bribeTokens[j] = bribeTokensTmp[j];
            }

            // Execute claims if any
            if (feeCount > 0) {
                console2.log("Claiming fees for tokenId:", tokenId, "entries:", feeCount);
                try voter.claimFees(feeAddrs, feeTokens, tokenId) {
                    console2.log("  Fees claimed");
                } catch {
                    console2.log("  Fees claim failed for tokenId:", tokenId);
                }
            } else {
                console2.log("No fee claims for tokenId:", tokenId);
            }

            if (bribeCount > 0) {
                console2.log("Claiming bribes for tokenId:", tokenId, "entries:", bribeCount);
                try voter.claimBribes(bribeAddrs, bribeTokens, tokenId) {
                    console2.log("  Bribes claimed");
                } catch {
                    console2.log("  Bribes claim failed for tokenId:", tokenId);
                }
            } else {
                console2.log("No bribe claims for tokenId:", tokenId);
            }
        }

        vm.stopBroadcast();

        console2.log("\nAll claims attempted.");
    }

    function _loadState(string memory path) internal {
        require(vm.exists(path), "state file missing");
        string memory json = vm.readFile(path);

        // Voter may be stored as "Voter" or "VoterV3"
        address voterAddr;
        try vm.parseJsonAddress(json, ".VoterV3") returns (address parsed) {
            voterAddr = parsed;
        } catch {
            try vm.parseJsonAddress(json, ".Voter") returns (address parsed) {
                voterAddr = parsed;
            } catch {}
        }
        require(voterAddr != address(0), "voter addr missing");

        address veAddr = vm.parseJsonAddress(json, ".VotingEscrow");
        address rewardsAddr = vm.parseJsonAddress(json, ".RewardsDistributor");

        deployed = DeployedAddrs({voter: voterAddr, ve: veAddr, rewardsDistributor: rewardsAddr});
    }
}

