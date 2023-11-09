// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ProofOfStudy is ReentrancyGuard {
    NNTHToken private _nnthToken;
    address public owner;

    uint256 public totalAvailableRewards;
    uint256 public totalTokenCirculation;

    uint8 public constant CATEGORY_A_PERCENTAGE = 10;
    uint8 public constant CATEGORY_B_PERCENTAGE = 15;
    uint8 public constant CATEGORY_C_PERCENTAGE = 20;
    uint8 public constant CATEGORY_D_PERCENTAGE = 25;
    uint8 public constant CATEGORY_E_PERCENTAGE = 30;

    mapping(address => bool) public hasCompletedCategoryA;
    mapping(address => bool) public hasCompletedCategoryB;
    mapping(address => bool) public hasCompletedCategoryC;
    mapping(address => bool) public hasCompletedCategoryD;
    mapping(address => bool) public hasCompletedCategoryE;

    event RewardsClaimed(address indexed student, uint256 amount);

    modifier hasCompletedCategory(address student, uint8 category) {
        require(
            (category == 1 && hasCompletedCategoryA[student]) ||
            (category == 2 && hasCompletedCategoryB[student]) ||
            (category == 3 && hasCompletedCategoryC[student]) ||
            (category == 4 && hasCompletedCategoryD[student]) ||
            (category == 5 && hasCompletedCategoryE[student]),
            "Student has not completed the specified category"
        );
        _;
    }

    constructor(address _tokenAddress, uint256 _totalAvailableRewards, uint256 _totalTokenCirculation) {
        _nnthToken = NNTHToken(_tokenAddress);
        owner = msg.sender;
        totalAvailableRewards = _totalAvailableRewards;
        totalTokenCirculation = _totalTokenCirculation;
    }

    function calculateCategoryReward(uint8 category) public view returns (uint256) {
        require(category >= 1 && category <= 5, "Invalid category");

        uint256 percentage;

        if (category == 1) {
            percentage = CATEGORY_A_PERCENTAGE;
        } else if (category == 2) {
            percentage = CATEGORY_B_PERCENTAGE;
        } else if (category == 3) {
            percentage = CATEGORY_C_PERCENTAGE;
        } else if (category == 4) {
            percentage = CATEGORY_D_PERCENTAGE;
        } else if (category == 5) {
            percentage = CATEGORY_E_PERCENTAGE;
        }

        return (percentage * totalAvailableRewards) / totalTokenCirculation;
    }

    function claimReward(uint8 category) external nonReentrant hasCompletedCategory(msg.sender, category) {
        uint256 rewardAmount = calculateCategoryReward(category);
        require(rewardAmount > 0, "No rewards available for this category");

        totalAvailableRewards = totalAvailableRewards - rewardAmount;

        _nnthToken.transfer(msg.sender, rewardAmount);

        emit RewardsClaimed(msg.sender, rewardAmount);
    }

    function checkCategoryStatus(address student, uint8 category) external view returns (bool) {
        require(category >= 1 && category <= 5, "Invalid category");

        if (category == 1) {
            return hasCompletedCategoryA[student];
        } else if (category == 2) {
            return hasCompletedCategoryB[student];
        } else if (category == 3) {
            return hasCompletedCategoryC[student];
        } else if (category == 4) {
            return hasCompletedCategoryD[student];
        } else if (category == 5) {
            return hasCompletedCategoryE[student];
        }

        return false;
    }

    function setCategoryCompletion(address student, uint8 category) external onlyOwner {
        require(category >= 1 && category <= 5, "Invalid category");

        if (category == 1) {
            hasCompletedCategoryA[student] = true;
        } else if (category == 2) {
            hasCompletedCategoryB[student] = true;
        } else if (category == 3) {
            hasCompletedCategoryC[student] = true;
        } else if (category == 4) {
            hasCompletedCategoryD[student] = true;
        } else if (category == 5) {
            hasCompletedCategoryE[student] = true;
        }
    }

    function removeCategoryCompletion(address student, uint8 category) external onlyOwner {
        require(category >= 1 && category <= 5, "Invalid category");

        if (category == 1) {
            hasCompletedCategoryA[student] = false;
        } else if (category == 2) {
            hasCompletedCategoryB[student] = false;
        } else if (category == 3) {
            hasCompletedCategoryC[student] = false;
        } else if (category == 4) {
            hasCompletedCategoryD[student] = false;
        } else if (category == 5) {
            hasCompletedCategoryE[student] = false;
        }
    }

    function setTotalAvailableRewards(uint256 amount) external onlyOwner {
        totalAvailableRewards = amount;
    }

    function setTotalTokenCirculation(uint256 amount) external onlyOwner {
        totalTokenCirculation = amount;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
}
