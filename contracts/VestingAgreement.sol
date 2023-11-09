// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol";

contract VestingAgreement {
    address public beneficiary;
    address public owner;
    uint256 public totalTokens;
    uint256 public startTime;
    uint256 public cliffDuration;
    uint256 public vestingDuration;

    uint256 public releasedTokens;
    bool public isVestingComplete;

    NNTHToken public nnthToken;

    constructor(
        address _beneficiary,
        address _nnthToken,
        uint256 _totalTokens,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) {
        beneficiary = _beneficiary;
        owner = msg.sender;
        totalTokens = _totalTokens;
        cliffDuration = _cliffDuration;
        vestingDuration = _vestingDuration;
        startTime = block.timestamp;
        nnthToken = NNTHToken(_nnthToken);
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Only the beneficiary can perform this action");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function releasableAmount() public view returns (uint256) {
        if (block.timestamp < startTime + cliffDuration) {
            return 0;
        } else if (block.timestamp >= startTime + vestingDuration) {
            return totalTokens - releasedTokens;
        } else {
            return ((totalTokens * (block.timestamp - startTime)) / vestingDuration) - releasedTokens;
        }
    }

    function release() external onlyBeneficiary {
        require(!isVestingComplete, "Vesting has already been completed");
        uint256 vestedAmount = releasableAmount();
        require(vestedAmount > 0, "No tokens are currently vested");
        releasedTokens += vestedAmount;
        nnthToken.transfer(beneficiary, vestedAmount);
        if (releasedTokens >= totalTokens) {
            isVestingComplete = true;
        }
    }

    // function withdrawExcessTokens() external onlyOwner {
    //     uint256 excessTokens = totalTokens - releasedTokens;
    //     require(excessTokens > 0, "No excess tokens to withdraw");
    //     releasedTokens = totalTokens;
    // }
}
