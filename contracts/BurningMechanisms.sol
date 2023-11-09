// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol"; // Import your token contract

contract BurningMechanisms {
    NNTHToken private _nnthToken; // Assuming Token is the name of your token contract
    address public owner;
    uint256 public constant MAX_BURN_LIMIT = 1000 * 10**18; // 1000 NTH

    uint8 public transactionBurningRate = 1; // 0.1% represented as 1
    uint8 public communityGrowthBurningPercentage = 5; // 0.5% represented as 5
    uint8 public certificateAssociatedBurningPercentage = 1; // 1%
    uint8 public liquidityOperationsBurningRate = 1; // 1%

    uint256 public lastUserCount;
    uint256 public currentActiveTokenSupply;

    event TokensBurned(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor(address _tokenAddress) {
        _nnthToken = NNTHToken(_tokenAddress);
        owner = msg.sender;
    }

    function updateTransactionBurningRate(uint8 _newRate) external onlyOwner {
        transactionBurningRate = _newRate;
    }

    function updateCommunityGrowthBurningPercentage(uint8 _newPercentage) external onlyOwner {
        communityGrowthBurningPercentage = _newPercentage;
    }

    function updateCertificateAssociatedBurningPercentage(uint8 _newPercentage) external onlyOwner {
        certificateAssociatedBurningPercentage = _newPercentage;
    }

    function updateLiquidityOperationsBurningRate(uint8 _newRate) external onlyOwner {
        liquidityOperationsBurningRate = _newRate;
    }

    function updateLastUserCount(uint256 _newUserCount) external onlyOwner {
        lastUserCount = _newUserCount;
    }

    function updateCurrentActiveTokenSupply(uint256 _newSupply) external onlyOwner {
        currentActiveTokenSupply = _newSupply;
    }

    function calculateTransactionBurning(uint256 transactionValue) public view returns (uint256) {
        uint256 burningAmount = (transactionValue * transactionBurningRate) / 1000;
        return (burningAmount > MAX_BURN_LIMIT) ? MAX_BURN_LIMIT : burningAmount;
    }

    function calculateCommunityGrowthBurning(uint256 differenceInUserCount) public view returns (uint256) {
        uint256 burningAmount = (communityGrowthBurningPercentage * differenceInUserCount * currentActiveTokenSupply) / 10000;
        return (burningAmount > MAX_BURN_LIMIT) ? MAX_BURN_LIMIT : burningAmount;
    }

    function calculateCertificateAssociatedBurning(uint256 certificateReward) public view returns (uint256) {
        return (certificateReward * certificateAssociatedBurningPercentage) / 100;
    }

    function calculateLiquidityOperationsBurning(uint256 quantityOfTokensInLiquidity) public view returns (uint256) {
        uint256 burningAmount = (quantityOfTokensInLiquidity * liquidityOperationsBurningRate) / 100;
        return (burningAmount > MAX_BURN_LIMIT) ? MAX_BURN_LIMIT : burningAmount;
    }

    function burnTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(_nnthToken.balanceOf(address(this)) >= amount, "Insufficient balance in contract");
        _nnthToken.burn(amount);
        emit TokensBurned(amount);
    }
}
