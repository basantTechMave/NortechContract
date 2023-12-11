// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 private _nnthToken20; // Instance of the NNTHToken contract
    NNTHToken private _nnthToken; // Instance of the NNTHToken contract

    // Roles for contract administration
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public owner; // Owner of the contract

    // Global staking statistics
    uint256 public totalStaked;
    uint256 public earlyUnstakeFeePercentage;

    // Individual staking data for each user and pool
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public stakingStartTimestamp;
    mapping(address => uint256) public rewards;

    // Staking parameters
    uint256 public stakingDuration;
    uint256 public stakingFeePercentage;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;

    // Struct to store information about each staking pool
    struct StakePool {
        uint256 totalStaked;
        uint256 apy;
        uint256 lastUpdateTime;
    }

    mapping(address => StakePool) public stakePools; // Mapping of pool address to pool information
    address[] public poolAddresses; // Array to store all pool addresses

    mapping(address => mapping(address => uint256)) public userStakes; // Mapping of user address to pool address to staked amount

    // Events for important contract actions
    event Staked(address indexed staker, uint256 amount, address indexed pool);
    event Unstaked(address indexed staker, uint256 amount, address indexed pool);
    event RewardPaid(address indexed staker, uint256 amount, address indexed pool);
    event StakePoolCreated(address indexed poolAddress, uint256 apy);
    event StakePoolUpdated(address indexed poolAddress, uint256 apy);
    event StatisticsUpdated(uint256 totalStaked);
    event EarlyUnstaked(address indexed staker, uint256 amount, uint256 penaltyFee);
    event StakingDurationUpdated(uint256 newDuration);
    event StakingFeePercentageUpdated(uint256 newPercentage);
    event RewardRateUpdated(uint256 newRate);

    /**
     * @dev Constructor to initialize the Staking contract
     * @param _tokenAddress Address of the NNTHToken contract
     * @param _totalTokenCirculation Total token supply
     * @param _stakingDuration Duration of staking in seconds
     * @param _stakingFeePercentage Percentage fee for staking
     * @param _earlyUnstakeFeePercentage Percentage fee for early unstaking
     * @param _initialRewardRate Initial reward rate
     */
    constructor(
        address _tokenAddress,
        uint256 _totalTokenCirculation,
        uint256 _stakingDuration,
        uint256 _stakingFeePercentage,
        uint256 _earlyUnstakeFeePercentage,
        uint256 _initialRewardRate
    ) {
        _nnthToken20 = IERC20(_tokenAddress);
        owner = msg.sender;

        totalStaked = _totalTokenCirculation;
        stakingDuration = _stakingDuration;
        stakingFeePercentage = _stakingFeePercentage;
        rewardRate = _initialRewardRate;
        lastUpdateTime = block.timestamp;
        earlyUnstakeFeePercentage = _earlyUnstakeFeePercentage;
    }

    /**
     * @dev Modifier to restrict a function to only the admin
     */
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin can perform this action");
        _;
    }

    /**
     * @dev Function to stake tokens into a specific pool
     * @param amount Amount of tokens to stake
     * @param pool Address of the staking pool
     */
    function stake(uint256 amount, address pool) external nonReentrant {
        require(amount > 0, "Must stake at least some tokens");
        require(_nnthToken20.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(stakePools[pool].apy > 0, "Invalid pool address");

        // Calculate and update rewards at the time of staking
        updateReward(msg.sender, pool);

        // Transfer tokens from the staker to the contract
        _nnthToken20.safeTransferFrom(msg.sender, address(this), amount);

        // Update staking data
        stakedAmount[msg.sender] = stakedAmount[msg.sender].add(amount);
        userStakes[msg.sender][pool] = userStakes[msg.sender][pool].add(amount);
        stakePools[pool].totalStaked = stakePools[pool].totalStaked.add(amount);
        totalStaked = totalStaked.add(amount);

        stakingStartTimestamp[msg.sender] = block.timestamp;

        // Apply staking fee to buyback and burn
        uint256 fee = (amount.mul(stakingFeePercentage)) / 10000;
        _nnthToken20.safeTransfer(owner, fee);
        _nnthToken.burn(fee);

        // Emit staking event
        emit Staked(msg.sender, amount, pool);

        // Update staking statistics
        _updateStakePoolStatistics(pool);
    }

    /**
     * @dev Function to unstake tokens from a specific pool
     * @param pool Address of the staking pool
     */
    function unstake(address pool) external nonReentrant {
        require(userStakes[msg.sender][pool] > 0, "No staked tokens in this pool");

        // Calculate and update rewards at the time of unstaking
        updateReward(msg.sender, pool);

        uint256 staked = userStakes[msg.sender][pool];
        uint256 stakingStart = stakingStartTimestamp[msg.sender];

        // Ensure staking period is over
        require(block.timestamp >= stakingStart.add(stakingDuration), "Staking period not over yet");

        // Calculate unstaking fee
        uint256 fee = (staked.mul(stakingFeePercentage)) / 10000;

        // Total amount to be withdrawn, including rewards
        uint256 totalWithdrawal = staked.sub(fee).add(rewards[msg.sender]);

        // Update global and user staking data
        totalStaked = totalStaked.sub(staked);
        userStakes[msg.sender][pool] = 0;
        stakePools[pool].totalStaked = stakePools[pool].totalStaked.sub(staked);
        rewards[msg.sender] = 0;

        // Transfer tokens to the staker and apply the unstaking fee
        _nnthToken20.safeTransfer(owner, fee);
        _nnthToken20.safeTransfer(msg.sender, totalWithdrawal);

        // Emit unstaking and reward events
        emit Unstaked(msg.sender, staked, pool);
        emit RewardPaid(msg.sender, rewards[msg.sender], pool);

        // Update staking statistics
        _updateStakePoolStatistics(pool);
    }

    /**
     * @dev Internal function to update staking pool statistics
     * @param pool Address of the staking pool
     */
    function _updateStakePoolStatistics(address pool) internal {
        stakePools[pool].totalStaked = _nnthToken20.balanceOf(address(this));
        stakePools[pool].lastUpdateTime = block.timestamp;

        // Emit event to signify updated statistics
        emit StatisticsUpdated(stakePools[pool].totalStaked);
    }

    /**
     * @dev Internal function to update the reward for a staker
     * @param staker Address of the staker
     * @param pool Address of the staking pool
     */
    function updateReward(address staker, address pool) internal {
        if (userStakes[staker][pool] > 0) {
            uint256 currentTime = block.timestamp;
            uint256 lastTime = stakePools[pool].lastUpdateTime;

            if (currentTime > lastTime) {
                // Calculate staker's reward based on the time passed and reward rate
                uint256 stakerReward =
                    (userStakes[staker][pool].mul(rewardRate).mul(currentTime - lastTime)) / stakingDuration;
                rewards[staker] = rewards[staker].add(stakerReward);
                stakePools[pool].lastUpdateTime = currentTime;
            }
        }
    }

    /**
     * @dev Function to set the staking duration
     * @param _duration New staking duration in seconds
     */
    function setStakingDuration(uint256 _duration) external onlyAdmin {
        stakingDuration = _duration;
        emit StakingDurationUpdated(_duration);
    }

    /**
     * @dev Function to set the staking fee percentage
     * @param _percentage New staking fee percentage
     */
    function setStakingFeePercentage(uint256 _percentage) external onlyAdmin {
        stakingFeePercentage = _percentage;
        emit StakingFeePercentageUpdated(_percentage);
    }

    /**
     * @dev Function to set the reward rate
     * @param _rate New reward rate
     */
    function setRewardRate(uint256 _rate) external onlyAdmin {
        updateReward(address(0), address(0));
        rewardRate = _rate;
        lastUpdateTime = block.timestamp;
        emit RewardRateUpdated(_rate);
    }

    /**
     * @dev Function to create a new staking pool
     * @param poolAddress Address of the new staking pool
     * @param apy Annual percentage yield for the new staking pool
     */
    function createStakePool(address poolAddress, uint256 apy) external onlyAdmin {
        stakePools[poolAddress] = StakePool(0, apy, block.timestamp);
        poolAddresses.push(poolAddress);
        emit StakePoolCreated(poolAddress, apy);

        // Update staking statistics
        _updateStakePoolStatistics(poolAddress);
    }

    /**
     * @dev Function to update an existing staking pool
     * @param poolAddress Address of the staking pool to update
     * @param apy New annual percentage yield for the staking pool
     */
    function updateStakePool(address poolAddress, uint256 apy) external onlyAdmin {
        StakePool storage pool = stakePools[poolAddress];
        require(pool.totalStaked == 0, "Cannot update APY for non-empty pool");

        // Migrate existing stakers with the new APY
        migrateStakers(poolAddress);

        // Update the pool's APY and last update time
        pool.apy = apy;
        pool.lastUpdateTime = block.timestamp;

        emit StakePoolUpdated(poolAddress, apy);

        // Update staking statistics
        _updateStakePoolStatistics(poolAddress);
    }

    /**
     * @dev Internal function to migrate stakers from an old pool to a new one
     * @param poolAddress Address of the staking pool to update
     */
    function migrateStakers(address poolAddress) internal {
        address staker;
        uint256 stakedAmount;

        // Loop through all stakers
        for (uint256 i = 0; i < poolAddresses.length; i++) {
            staker = poolAddresses[i];
            stakedAmount = userStakes[staker][poolAddress];

            if (stakedAmount > 0) {
                // Calculate and update rewards with the old APY
                updateReward(staker, poolAddress);

                // Transfer staked amount to the new pool with the updated APY
                _nnthToken20.safeTransferFrom(staker, address(this), stakedAmount);
                userStakes[staker][poolAddress] = 0;
                stakePools[poolAddress].totalStaked = stakePools[poolAddress].totalStaked.sub(stakedAmount);

                // Stake the transferred amount in the new pool
                this.stake(stakedAmount, poolAddress);
            }
        }
    }

    // Function to get the addresses of all staking pools
    function getStakePoolAddresses() external view returns (address[] memory) {
        return poolAddresses;
    }

    /**
     * @dev Updates overall staking statistics and individual pool statistics.
     * Emits a `StatisticsUpdated` event.
     */
    function updateStatistics() external {
        totalStaked = _nnthToken20.balanceOf(address(this));
        emit StatisticsUpdated(totalStaked);

        for (uint256 i = 0; i < poolAddresses.length; i++) {
            address poolAddress = poolAddresses[i];
            _updateStakePoolStatistics(poolAddress);
        }
    }

    /**
     * @dev Allows a user to perform an early unstake from a specific pool.
     * Calculates and updates rewards, applies penalty fee, and transfers funds accordingly.
     * Emits `EarlyUnstaked` and `RewardPaid` events.
     * @param pool The address of the staking pool.
     */
    function earlyUnstake(address pool) external nonReentrant {
        require(userStakes[msg.sender][pool] > 0, "No staked tokens in this pool");

        updateReward(msg.sender, pool);

        uint256 staked = userStakes[msg.sender][pool];

        // Calculate penalty fee for early unstake
        uint256 penaltyFee = (staked * earlyUnstakeFeePercentage) / 10000;

        // Total amount to be withdrawn, including penalty fee and rewards
        uint256 totalWithdrawal = staked - penaltyFee + rewards[msg.sender];

        // Update staking data
        totalStaked -= staked;
        userStakes[msg.sender][pool] = 0;
        stakePools[pool].totalStaked -= staked;
        rewards[msg.sender] = 0;

        // Transfer tokens to owner as penalty
        _nnthToken20.safeTransfer(owner, penaltyFee);

        // Transfer remaining tokens (staked amount - penalty fee + rewards) to the user
        _nnthToken20.safeTransfer(msg.sender, totalWithdrawal);

        // Emit events
        emit EarlyUnstaked(msg.sender, staked, penaltyFee);
        emit RewardPaid(msg.sender, rewards[msg.sender], pool);

        // Update staking statistics for the specific pool
        _updateStakePoolStatistics(pool);
    }

    /**
     * @dev Sets the early unstake fee percentage.
     * Only the contract admin can call this function.
     * @param _percentage The new early unstake fee percentage.
     */
    function setEarlyUnstakeFeePercentage(uint256 _percentage) external onlyAdmin {
        earlyUnstakeFeePercentage = _percentage;
    }
}
