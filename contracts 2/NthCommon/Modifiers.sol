// Modifiers.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/security/Pausable.sol";

contract Modifiers is Pausable {
    // Define the variables used in the modifiers
    mapping(address => bool) private _isLocked;
    uint256 private _transferLockEndBlock;
    

    // Modifiers

    /**
     * @dev Modifier to check if an account is not locked.
     */
    modifier onlyUnlocked(address account) {
        require(!_isLocked[account], "Account is currently locked");
        _;
    }

    /**
     * @dev Modifier to check if the contract is not paused.
     */
    modifier onlyNotPaused() {
        require(!paused(), "Contract is currently paused");
        _;
    }

    /**
     * @dev Modifier to check if a value is positive.
     */
    modifier onlyPositiveValue(uint256 value) {
        require(value > 0, "Value must be a positive number");
        _;
    }

    /**
     * @dev Modifier to check if a percentage is valid (between 0 and 100).
     */
    modifier onlyValidPercentage(uint256 percentage) {
        require(percentage >= 0 && percentage <= 100, "Percentage must be between 0 and 100");
        _;
    }

   
}
