// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TalentShow is Ownable, ReentrancyGuard {
    // Constants
    uint256 constant PLATFORM_FEE_PERCENTAGE = 5;
    uint256 constant REQUIRED_STAKE_AMOUNT = 1 ether; // 1 ETH or equivalent
    uint256 constant VOTING_WINDOW_DURATION = 1 days;

    struct Performance {
        address performer;
        string videoLink;
        uint256 selfScore;
        uint256 totalStake;
        uint256[] judgesScores;
        mapping(address => uint256) audienceScores;
        mapping(address => bool) hasAudienceVoted;
        uint256 votingStartTime;
        bool isCompleted;
        bool potClaimed;
        mapping(address => bool) judgeVoted;
    }

    // State variables
    mapping(uint256 => Performance) public performances;
    address[] public judges;
    uint256 public performanceCounter;
    uint256 public platformBalance;
    mapping(address => bool) public isJudge;

    // Events
    event PerformanceSubmitted(
        uint256 indexed performanceId,
        address indexed performer,
        string videoLink,
        uint256 timestamp
    );

    event ScoreSubmitted(
        uint256 indexed performanceId,
        address indexed voter,
        uint256 score,
        bool isJudge
    );

    event RewardsDistributed(
        uint256 indexed performanceId,
        uint256 totalPot,
        uint256 platformFee,
        uint256 performerReward,
        uint256 timestamp
    );

    // Constructor
    constructor(
        address initialOwner,
        address[] memory _judges
    ) Ownable(initialOwner) {
        for (uint i = 0; i < _judges.length; i++) {
            judges.push(_judges[i]);
            isJudge[_judges[i]] = true;
        }
    }

    // Submit a new performance
    function submitPerformance(
        string calldata videoLink,
        uint256 selfScore
    ) external payable nonReentrant {
        require(msg.value == REQUIRED_STAKE_AMOUNT, "Incorrect stake amount");
        require(selfScore <= 10, "Score must be between 0 and 10");

        performanceCounter++;
        Performance storage newPerf = performances[performanceCounter];
        newPerf.performer = msg.sender;
        newPerf.videoLink = videoLink;
        newPerf.selfScore = selfScore;
        newPerf.totalStake = msg.value;
        newPerf.votingStartTime = block.timestamp;

        emit PerformanceSubmitted(
            performanceCounter,
            msg.sender,
            videoLink,
            block.timestamp
        );
    }

    // Submit audience score
    function submitAudienceScore(
        uint256 performanceId,
        uint256 score
    ) external payable nonReentrant {
        require(msg.value == REQUIRED_STAKE_AMOUNT, "Incorrect stake amount");
        require(score <= 10, "Score must be between 0 and 10");

        Performance storage perf = performances[performanceId];
        require(!perf.isCompleted, "Voting window expired");
        require(
            block.timestamp <= perf.votingStartTime + VOTING_WINDOW_DURATION,
            "Voting window expired"
        );
        require(!perf.hasAudienceVoted[msg.sender], "Already voted");

        perf.audienceScores[msg.sender] = score;
        perf.hasAudienceVoted[msg.sender] = true;
        perf.totalStake += msg.value;

        emit ScoreSubmitted(performanceId, msg.sender, score, false);
    }

    // Submit judge score
    function submitJudgeScore(
        uint256 performanceId,
        uint256 score
    ) external nonReentrant {
        require(isJudge[msg.sender], "Not a judge");
        require(score <= 10, "Score must be between 0 and 10");

        Performance storage perf = performances[performanceId];
        require(
            block.timestamp > perf.votingStartTime + VOTING_WINDOW_DURATION,
            "Voting window still active"
        );
        require(!perf.judgeVoted[msg.sender], "Already voted");

        perf.judgesScores.push(score);
        perf.judgeVoted[msg.sender] = true;

        emit ScoreSubmitted(performanceId, msg.sender, score, true);

        if (perf.judgesScores.length == judges.length) {
            perf.isCompleted = true;
        }
    }

    // Calculate average judge score
    function calculateAverageScore(
        uint256[] memory scores
    ) internal pure returns (uint256) {
        if (scores.length == 0) return 0;

        uint256 total = 0;
        for (uint i = 0; i < scores.length; i++) {
            total += scores[i];
        }
        return total / scores.length;
    }

    // Distribute rewards
    function distributeRewards(
        uint256 performanceId
    ) external nonReentrant {
        Performance storage perf = performances[performanceId];
        require(perf.isCompleted, "Performance not completed");
        require(!perf.potClaimed, "Rewards already claimed");

        uint256 totalPot = perf.totalStake;
        uint256 platformFee = (totalPot * PLATFORM_FEE_PERCENTAGE) / 100;
        platformBalance += platformFee;

        uint256 remainingPot = totalPot - platformFee;
        uint256 judgeAvg = calculateAverageScore(perf.judgesScores);
        uint256 performerReward = 0;

        // Handle performer's correct guess
        if (perf.selfScore == judgeAvg) {
            performerReward = remainingPot / 2;
            payable(perf.performer).transfer(performerReward);
            remainingPot -= performerReward;
        }

        // Count matching audience scores
        uint256 matchingVoters = 0;
        for (uint i = 0; i < judges.length; i++) {
            if (perf.audienceScores[judges[i]] == judgeAvg) {
                matchingVoters++;
            }
        }

        // Distribute remaining pot to matching voters
        if (matchingVoters > 0) {
            uint256 rewardPerVoter = remainingPot / matchingVoters;
            for (uint i = 0; i < judges.length; i++) {
                if (perf.audienceScores[judges[i]] == judgeAvg) {
                    payable(judges[i]).transfer(rewardPerVoter);
                }
            }
        } else {
            // If no matching voters, add to platform balance
            platformBalance += remainingPot;
        }

        perf.potClaimed = true;

        emit RewardsDistributed(
            performanceId,
            totalPot,
            platformFee,
            performerReward,
            block.timestamp
        );
    }

    // Withdraw platform fees (only owner)
    function withdrawPlatformFees() external onlyOwner {
        uint256 amount = platformBalance;
        platformBalance = 0;
        payable(owner()).transfer(amount);
    }

    // Getter functions
    function getPerformanceDetails(
        uint256 performanceId
    ) external view returns (
        address performer,
        string memory videoLink,
        uint256 selfScore,
        uint256 totalStake,
        bool isCompleted,
        bool potClaimed,
        uint256 votingStartTime
    ) {
        Performance storage perf = performances[performanceId];
        return (
            perf.performer,
            perf.videoLink,
            perf.selfScore,
            perf.totalStake,
            perf.isCompleted,
            perf.potClaimed,
            perf.votingStartTime
        );
    }

    function getJudgesScore(
        uint256 performanceId
    ) external view returns (uint256[] memory) {
        return performances[performanceId].judgesScores;
    }

    function getAudienceScore(
        uint256 performanceId,
        address voter
    ) external view returns (uint256) {
        return performances[performanceId].audienceScores[voter];
    }
}