// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NNTHToken.sol";

/**
 * @title BuilderReward
 * @dev A contract for managing builder rewards in an ecosystem.
 */
contract BuilderReward is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 private _nnthToken; // Instance of the NNTHToken contract
    
    uint256 public initialCirculation;  // Initial total supply of NNTHToken
    uint256 public limitBuilderReward;  // Maximum builder reward limit
    uint256 public tokensAlreadyReceived;  // Tokens already received by the contract

    struct User {
        uint256 tokensReceived;  // Amount of tokens received by the user
        bool hasClaimed;  // Flag indicating whether the user has claimed the builder reward
    }

    mapping(address => User) public users;  // Mapping to track user information

    event BuilderRewardClaimed(address indexed user, uint256 reward);

    /**
     * @dev Constructor function to initialize the contract.
     * @param _tokenAddress Address of the NNTHToken contract.
     * @param _maxRewardTokens Maximum builder reward limit in tokens.
     */
    constructor(address _tokenAddress, uint256 _maxRewardTokens) Ownable(msg.sender) {
        _nnthToken = IERC20(_tokenAddress);
        initialCirculation = _nnthToken.totalSupply();
        limitBuilderReward = _maxRewardTokens.mul(10**18); // Convert maximum reward to wei (18 decimals)
    }

    /**
     * @dev Internal function to update tokensAlreadyReceived based on actual received tokens.
     */
    function updateTokensAlreadyReceived() internal {
        uint256 totalReceived = _nnthToken.balanceOf(address(this));
        tokensAlreadyReceived = totalReceived < limitBuilderReward ? totalReceived : limitBuilderReward;
    }

    /**
     * @dev Restricted function to set the number of tokens already received by the contract.
     * Only the owner can call this function.
     */
    function updateTokensAlreadyReceivedByOwner() external onlyOwner {
        updateTokensAlreadyReceived();
    }

    /**
     * @dev Calculates the total ecosystem fund based on the total token supply.
     * @return Total ecosystem fund in tokens.
     */
    function calculateEcosystemFund() public view returns (uint256) {
        // Consider whether 50% is the desired value or if it should be adjustable
        uint256 totalSupply = _nnthToken.totalSupply();
        return totalSupply.mul(50).div(100);  // 50% of the total supply allocated for the ecosystem fund
    }

    /**
    * @dev Calculates the builder reward for a user based on specified parameters.
    * @param tokensInCirculation Total tokens in circulation (excluding already received tokens).
    * @param numberOfRegisteredUsers Number of registered users.
    * @return Builder reward for the user in tokens.
    */
    function calculateBuilderReward(uint256 tokensInCirculation, uint256 numberOfRegisteredUsers) public view returns (uint256) {
        // Ensure inputs are valid
        require(tokensInCirculation > 0 && numberOfRegisteredUsers > 0, "Invalid inputs: Non-positive values");

        // Calculate the remaining reward pool by adjusting for already received tokens
        uint256 remainingRewardPool = tokensInCirculation.mul(10**18).sub(tokensAlreadyReceived.mul(10**18).div(limitBuilderReward)).div(10**18);

        // Ensure there is no overflow in the next multiplication
        require(remainingRewardPool < type(uint256).max.div(initialCirculation), "Overflow in reward calculation: Too large values");

        // Calculate the builder reward proportionally based on total supply and registered users
        uint256 builderReward = remainingRewardPool.mul(initialCirculation).div(numberOfRegisteredUsers.mul(10**18));

        // Ensure there is no overflow in the final result
        require(builderReward <= remainingRewardPool, "Overflow in reward calculation: Builder reward exceeds remaining pool");

        return builderReward;
    }

    /**
    * @dev Allows a user to claim their builder reward.
    * Emits BuilderRewardClaimed event upon successful claim.
    * @param numberOfRegisteredUsers Number of registered users in the ecosystem.
    */
    function claimBuilderReward(uint256 numberOfRegisteredUsers) external {
        require(users[msg.sender].tokensReceived > 0, "No tokens to claim: User has not received any tokens");
        require(!users[msg.sender].hasClaimed, "Already claimed: User has already claimed the builder reward");

        uint256 tokensInCirculation = _nnthToken.totalSupply().sub(tokensAlreadyReceived);
        uint256 builderReward = calculateBuilderReward(tokensInCirculation, numberOfRegisteredUsers);
        require(builderReward > 0, "Builder reward is zero: No reward available for the user");

        // Update state variables
        users[msg.sender].hasClaimed = true;
        tokensAlreadyReceived = tokensAlreadyReceived.add(builderReward);

        // Transfer builder reward
        _nnthToken.safeTransfer(msg.sender, builderReward);
        emit BuilderRewardClaimed(msg.sender, builderReward);
    }
}
