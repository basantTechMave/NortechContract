// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Import ReentrancyGuard for security

contract Staking is ReentrancyGuard {
    NNTHToken private _nnthToken;
    address public owner;

    uint256 public totalStaked;
    uint256 public totalTokenCirculation;

    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public stakingStartTimestamp;
    mapping(address => uint256) public rewards;

    uint256 public stakingDuration;
    uint256 public stakingFeePercentage;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;

    struct StakePool {
        uint256 totalStaked;
        uint256 apy;
    }

    mapping(address => StakePool) public stakePools;
    address[] public poolAddresses;

    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount);
    event RewardPaid(address indexed staker, uint256 amount);
    event StakePoolCreated(address indexed poolAddress, uint256 apy);
    event StakePoolUpdated(address indexed poolAddress, uint256 apy);
    event StatisticsUpdated(uint256 totalStaked);

    constructor(address _tokenAddress, uint256 _totalTokenCirculation, uint256 _stakingDuration, uint256 _stakingFeePercentage, uint256 _initialRewardRate) {
        _nnthToken = NNTHToken(_tokenAddress);
        owner = msg.sender;
        totalTokenCirculation = _totalTokenCirculation;
        stakingDuration = _stakingDuration;
        stakingFeePercentage = _stakingFeePercentage;
        rewardRate = _initialRewardRate;
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 amount) external nonReentrant { // Use nonReentrant to prevent reentrancy attacks
        require(amount > 0, "Must stake at least some tokens");
        require(_nnthToken.balanceOf(msg.sender) >= amount, "Insufficient balance");

        updateReward(msg.sender);

        _nnthToken.transferFrom(msg.sender, address(this), amount);
        stakedAmount[msg.sender] = stakedAmount[msg.sender] + amount;
        totalStaked = totalStaked + amount;

        stakingStartTimestamp[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant { // Use nonReentrant to prevent reentrancy attacks
        require(stakedAmount[msg.sender] > 0, "No staked tokens");

        updateReward(msg.sender);

        uint256 staked = stakedAmount[msg.sender];
        uint256 stakingStart = stakingStartTimestamp[msg.sender];

        require(block.timestamp >= stakingStart + stakingDuration, "Staking period not over yet");
        uint256 fee = (staked * stakingFeePercentage) / 10000;

        totalStaked = totalStaked - staked;
        stakedAmount[msg.sender] = 0;
        stakingStartTimestamp[msg.sender] = 0;

        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;

        _nnthToken.transfer(owner, fee);
        _nnthToken.transfer(msg.sender, staked - fee + reward);

        emit Unstaked(msg.sender, staked);
        emit RewardPaid(msg.sender, reward);
    }

    function updateReward(address staker) internal {
        if (stakedAmount[staker] > 0) {
            uint256 currentTime = block.timestamp;
            uint256 lastTime = lastUpdateTime;

            if (currentTime > lastTime) {
                uint256 stakerReward = (stakedAmount[staker] * (rewardRate * (currentTime - lastTime))) / stakingDuration;
                rewards[staker] += stakerReward;
                lastUpdateTime = currentTime;
            }
        }
    }

    function setStakingDuration(uint256 _duration) external onlyOwner {
        stakingDuration = _duration;
    }

    function setStakingFeePercentage(uint256 _percentage) external onlyOwner {
        stakingFeePercentage = _percentage;
    }

    function setRewardRate(uint256 _rate) external onlyOwner {
        updateReward(address(0));
        rewardRate = _rate;
        lastUpdateTime = block.timestamp;
    }

    function createStakePool(address poolAddress, uint256 apy) external onlyOwner {
        stakePools[poolAddress] = StakePool(0, apy);
        poolAddresses.push(poolAddress);
        emit StakePoolCreated(poolAddress, apy);
    }

    function updateStakePool(address poolAddress, uint256 apy) external onlyOwner {
        require(stakePools[poolAddress].totalStaked == 0, "Cannot update APY for non-empty pool");
        stakePools[poolAddress].apy = apy;
        emit StakePoolUpdated(poolAddress, apy);
    }

    function getStakePoolAddresses() external view returns (address[] memory) {
        return poolAddresses;
    }

    function updateStatistics() external {
        totalStaked = _nnthToken.balanceOf(address(this));
        emit StatisticsUpdated(totalStaked);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
}
