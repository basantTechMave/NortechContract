// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardDistribution is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 private _nnthToken;

    uint256 public totalAvailableRewards;
    uint256 public totalTokenCirculation;

    // Event emitted when rewards are claimed
    event RewardsClaimed(address indexed student, uint256 amount);

    /**
     * @dev Constructor to initialize the contract.
     * @param _tokenAddress Address of the ERC-20 token used for rewards.
     * @param _totalAvailableRewards Total available rewards in the contract.
     * @param _totalTokenCirculation Total token circulation for reward percentage calculations.
     * @param initialOwner Address to set as the initial owner of the contract.
     */
    constructor(address _tokenAddress, uint256 _totalAvailableRewards, uint256 _totalTokenCirculation, address initialOwner) Ownable(initialOwner) {
        _nnthToken = IERC20(_tokenAddress);
        totalAvailableRewards = _totalAvailableRewards;
        totalTokenCirculation = _totalTokenCirculation;
    }

    /**
    * @dev Function to claim rewards for a specific category.
    */
    function claimReward(address student, uint256 rewardAmount) external onlyOwner nonReentrant {
        require(rewardAmount > 0, "Reward amount must be greater than zero");
        require(totalAvailableRewards >= rewardAmount, "Not enough available rewards");

        // Deduct the claimed reward from total available rewards
        totalAvailableRewards -= rewardAmount;
        
        // Use SafeERC20 to safely transfer the reward tokens to the student
        _nnthToken.safeTransfer(student, rewardAmount);

        // Emit an event indicating that rewards have been claimed
        emit RewardsClaimed(student, rewardAmount);
    }
    
    /**
    * @dev Function to set the total available rewards (onlyOwner).
    * @param amount New total available rewards amount.
    */
    function setTotalAvailableRewards(uint256 amount) external onlyOwner {
        // Add a check to prevent setting an unreasonable value
        require(amount <= 1e27, "Amount exceeds maximum allowed");

        totalAvailableRewards = amount;
    }

    /**
    * @dev Function to set the total token circulation (onlyOwner).
    * @param amount New total token circulation amount.
    */
    function setTotalTokenCirculation(uint256 amount) external onlyOwner {
        // Add a check to prevent setting an unreasonable value
        require(amount <= 1e27, "Amount exceeds maximum allowed");

        totalTokenCirculation = amount;
    }
}
