// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NNTHToken.sol";

/**
 * @title VestingAgreement
 * @dev A smart contract for token vesting with a flexible release schedule.
 */
contract VestingAgreement is Pausable, Ownable {
    address public beneficiary;
    uint256 public totalTokens;
    uint256 public startTime;
    uint256 public cliffDuration;
    uint256 public vestingDuration;

    uint256 public releasedTokens;
    bool public isVestingComplete;

    NNTHToken public nnthToken;

    // Event emitted when tokens are released
    event TokensReleased(address indexed beneficiary, uint256 amount);

    // Event emitted when the owner withdraws unvested tokens
    event UnvestedTokensWithdrawn(address indexed owner, uint256 amount);

    // Event emitted when the contract is paused
    event EmergencyPaused(address indexed owner);

    // Event emitted when the contract is unpaused
    event EmergencyUnpaused(address indexed owner);

    // Event emitted when the contract is terminated
    event VestingTerminated(address indexed owner);

    /**
     * @dev Constructor to initialize the vesting parameters.
     * @param _beneficiary The address of the beneficiary (recipient of vested tokens).
     * @param _nnthToken The address of the ERC20 token used for vesting.
     * @param _totalTokens The total number of tokens to be vested.
     * @param _cliffDuration The duration, in seconds, before tokens start vesting.
     * @param _vestingDuration The total duration, in seconds, of the vesting period.
     */
    constructor(
        address _beneficiary,
        address _nnthToken,
        uint256 _totalTokens,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) Ownable(msg.sender) {
        beneficiary = _beneficiary;
        totalTokens = _totalTokens;
        cliffDuration = _cliffDuration;
        vestingDuration = _vestingDuration;
        startTime = block.timestamp;
        nnthToken = NNTHToken(_nnthToken);
    }

    /**
     * @dev Modifier to restrict a function's access to the beneficiary.
     */
    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Only the beneficiary can perform this action");
        _;
    }

    /**
     * @dev Function to calculate the amount of tokens that are currently releasable.
     * @return The amount of tokens available for release.
     */
    function releasableAmount() public view returns (uint256) {
        if (block.timestamp < startTime + cliffDuration) {
            return 0;
        } else if (block.timestamp >= startTime + vestingDuration) {
            return totalTokens - releasedTokens;
        } else {
            // Consider implementing a more flexible vesting schedule here
            // For example, a linear vesting schedule:
            // return ((totalTokens * (block.timestamp - startTime)) / vestingDuration) - releasedTokens;

            // Or a milestone-based vesting schedule:
            // uint256 milestoneVestingAmount = totalTokens / numberOfMilestones;
            // uint256 currentMilestone = (block.timestamp - startTime) / milestoneDuration;
            // return currentMilestone * milestoneVestingAmount - releasedTokens;

            // Implement additional vesting schedule logic as needed for your use case
            // The above examples are just illustrative and may need adjustment based on specific requirements
            revert("Custom vesting schedule not implemented");
        }
    }

    /**
     * @dev Function to release vested tokens to the beneficiary.
     * Emits a TokensReleased event.
     */
    function release() external onlyBeneficiary whenNotPaused {
        require(!isVestingComplete, "Vesting has already been completed");
        uint256 vestedAmount = releasableAmount();
        require(vestedAmount > 0, "No tokens are currently vested");
        releasedTokens += vestedAmount;
        nnthToken.transfer(beneficiary, vestedAmount);

        // Emit event for tokens release
        emit TokensReleased(beneficiary, vestedAmount);

        if (releasedTokens >= totalTokens) {
            isVestingComplete = true;
        }
    }

    /**
     * @dev Function for the owner to withdraw unvested tokens after vesting ends.
     * Can only be called by the owner. Emits an UnvestedTokensWithdrawn event.
     */
    function withdrawUnvestedTokens() external onlyOwner {
        require(isVestingComplete, "Vesting is not yet complete");
        uint256 unvestedTokens = totalTokens - releasedTokens;
        require(unvestedTokens > 0, "No unvested tokens to withdraw");
        nnthToken.transfer(owner(), unvestedTokens);

        // Emit event for unvested tokens withdrawal
        emit UnvestedTokensWithdrawn(owner(), unvestedTokens);
    }

    /**
     * @dev Function for the owner to withdraw excess tokens after the vesting period ends.
     * Can only be called by the owner.
     */
    function withdrawExcessTokens() external onlyOwner {
        require(block.timestamp >= startTime + vestingDuration, "Vesting period is still ongoing");
        uint256 excessTokens = nnthToken.balanceOf(address(this)) - totalTokens;
        require(excessTokens > 0, "No excess tokens to withdraw");
        nnthToken.transfer(owner(), excessTokens);
    }

    /**
    * @dev Function for the owner to terminate the vesting contract.
    * Can only be called after the vesting period ends.
    */
    function terminateVesting() external onlyOwner {
        require(block.timestamp >= startTime + vestingDuration, "Vesting termination is not yet allowed");
        emit VestingTerminated(owner());
        address payable payableOwner = payable(owner());
        payableOwner.transfer(address(this).balance);
    }


    /**
     * @dev Function for the owner to pause the contract in case of emergencies.
     * Can only be called by the owner. Emits an EmergencyPaused event.
     */
    function emergencyPause() external onlyOwner {
        _pause();

        // Emit event for emergency pause
        emit EmergencyPaused(owner());
    }

    /**
     * @dev Function for the owner to unpause the contract after resolving the emergency.
     * Can only be called by the owner. Emits an EmergencyUnpaused event.
     */
    function emergencyUnpause() external onlyOwner {
        _unpause();

        // Emit event for emergency unpause
        emit EmergencyUnpaused(owner());
    }
}
