// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol";

contract BuilderReward {
    NNTHToken private _nnthToken;
    address public owner;
    
    uint256 public initialCirculation;
    uint256 public limitBuilderReward;
    uint256 public tokensAlreadyReceived;

    struct User {
        uint256 tokensReceived;
        bool hasClaimed;
    }

    mapping(address => User) public users;

    event BuilderRewardClaimed(address indexed user, uint256 reward);

    constructor(address _tokenAddress, uint256 _maxRewardTokens) {
        _nnthToken = NNTHToken(_tokenAddress);
        owner = msg.sender;
        initialCirculation = _nnthToken.totalSupply();
        limitBuilderReward = _maxRewardTokens * 10**18; // 120 million tokens
    }

    function setTokensAlreadyReceived(uint256 tokens) external onlyOwner {
        tokensAlreadyReceived = tokens;
    }

    function calculateEcosystemFund() public view returns (uint256) {
        uint256 totalSupply = _nnthToken.totalSupply();
        return (totalSupply * 50) / 100;
    }

    function calculateBuilderReward(uint256 tokensInCirculation, uint256 numberOfRegisteredUsers) public view returns (uint256) {
        require(tokensInCirculation > 0 && numberOfRegisteredUsers > 0, "Invalid inputs");
        
        uint256 builderReward = (
            (tokensInCirculation * (10**18 - (tokensAlreadyReceived * 10**18 / limitBuilderReward))) *
            (initialCirculation * 10**18 / tokensInCirculation)
        ) / numberOfRegisteredUsers / 10**18;
        
        return builderReward;
    }

    function claimBuilderReward() external {
        require(users[msg.sender].tokensReceived > 0, "No tokens to claim");
        require(!users[msg.sender].hasClaimed, "Already claimed");

        uint256 builderReward = calculateBuilderReward(_nnthToken.totalSupply() - tokensAlreadyReceived, 1); // Assuming 1 registered user for simplicity
        require(builderReward > 0, "Builder reward is zero");

        users[msg.sender].hasClaimed = true;
        _nnthToken.transfer(msg.sender, builderReward);
        emit BuilderRewardClaimed(msg.sender, builderReward);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
}
