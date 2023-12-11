// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract RewardCalculator {
    uint8 public constant CATEGORY_A_PERCENTAGE = 10;
    uint8 public constant CATEGORY_B_PERCENTAGE = 15;
    uint8 public constant CATEGORY_C_PERCENTAGE = 20;
    uint8 public constant CATEGORY_D_PERCENTAGE = 25;
    uint8 public constant CATEGORY_E_PERCENTAGE = 30;

    mapping(uint8 => uint8) public categoryPercentages;


    constructor() {
        // Initialize category percentages in the constructor
        categoryPercentages[1] = CATEGORY_A_PERCENTAGE;
        categoryPercentages[2] = CATEGORY_B_PERCENTAGE;
        categoryPercentages[3] = CATEGORY_C_PERCENTAGE;
        categoryPercentages[4] = CATEGORY_D_PERCENTAGE;
        categoryPercentages[5] = CATEGORY_E_PERCENTAGE;
    }

    /**
    * @dev Function to calculate the reward for a specific category.
    * @param category Category for which to calculate the reward (1 to 5).
    * @return The calculated reward amount.
    */
    function calculateCategoryReward(uint8 category, uint256 totalAvailableRewards, uint256 totalTokenCirculation) external view returns (uint256) {
        require(category >= 1 && category <= 5, "Invalid category");

        // Ensure that totalTokenCirculation is not zero to avoid division by zero
        require(totalTokenCirculation > 0, "Total token circulation is zero");

        // Calculate reward based on the percentage, handling potential rounding issues
        uint256 rewardAmount = (categoryPercentages[category] * totalAvailableRewards) / totalTokenCirculation;

        // Ensure that the calculated reward does not exceed totalAvailableRewards
        return rewardAmount > totalAvailableRewards ? totalAvailableRewards : rewardAmount;
    }
}
