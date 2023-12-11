// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./NthCommon/Modifiers.sol";
import "./NthCommon/NNTHTokenRoles.sol";
import "./NthCommon/NNTHTokenEvents.sol";

/**
 * @title NNTHToken
 * @dev ERC-20 token with additional features like transfer locking, fees, and pausing.
 */
contract NNTHToken is ERC20, Ownable, Pausable, Modifiers, NNTHTokenRoles,NNTHTokenEvents {

    using SafeMath for uint256;

    // Transfer locking variables
    uint256 private _transferLockEndBlock;
    uint256 constant MAX_LOCK_DURATION = 30 days;

    // Account locking variables
    mapping(address => bool) private _isLocked;

    // Fee calculation variables
    uint256 public baseRate = 1;
    uint256 public adoptionFactor = 1;
    uint256 public adoptionPercentage = 0;


    // Modifiers
    
    /**
     * @dev Modifier to check if the sender is the owner or an authorized entity.
     */
    modifier onlyOwnerOrAuthorized() {
        require(msg.sender == owner() || msg.sender == address(this), "Not authorized as owner or authorized entity");
        _;
    }

    /**
     * @dev Modifier to check if the contract is not paused or the sender is the owner or an authorized entity.
     */
    modifier whenNotPausedOrAuthorized() {
        require(!paused() || msg.sender == owner() || msg.sender == address(this), "Not authorized or contract is paused");
        _;
    }

    /**
     * @dev Modifier to check if transfers are allowed based on the lock state.
     */
    modifier transferAllowed(address sender, address recipient) {
        require(
            (_transferLockEndBlock == 0 || block.number > _transferLockEndBlock || owner() == sender || owner() == recipient),
            "Transfers are currently locked or not allowed."
        );
        _;
    }

    // Constructor

    /**
     * @dev Constructor to initialize the token with the given name, symbol, total supply, and initial owner.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address initialOwner
    )
        ERC20(name, symbol)
        Ownable(initialOwner)
    {
        uint256 initialSupply = totalSupply * 10**uint256(decimals());
        _mint(initialOwner, initialSupply);
    }

    // External Functions

    /**
     * @dev Sets the transfer lock duration.
     * @param lockDuration Duration of the transfer lock in seconds.
     */
    function setTransferLock(uint256 lockDuration) external onlyOwnerOrAuthorized onlyNotPaused {
        require(lockDuration <= MAX_LOCK_DURATION, "Lock duration exceeds maximum allowed");
        require(lockDuration % 15 == 0, "Lock duration must be a multiple of 15 seconds");
        _transferLockEndBlock = block.number + (lockDuration / 15);
        emit TransferLockSet(_transferLockEndBlock);
    }

    /**
     * @dev Unlocks transfers.
     */
    function setTransferUnlock() external onlyOwnerOrAuthorized onlyNotPaused {
        _transferLockEndBlock = 0;
        emit TransferUnlockSet();
    }

    /**
     * @dev Sets the general fee parameters.
     * @param newBaseRate New base rate in percentage.
     * @param newAdoptionFactor New adoption factor.
     * @param newAdoptionPercentage New adoption percentage.
     */
    function setGeneralFee(uint256 newBaseRate, uint256 newAdoptionFactor, uint256 newAdoptionPercentage) external 
        onlyOwner
        onlyNotPaused
        onlyPositiveValue(newBaseRate)
        onlyPositiveValue(newAdoptionFactor)
        onlyValidPercentage(newAdoptionPercentage)
    {
        baseRate = newBaseRate;
        adoptionFactor = newAdoptionFactor;
        adoptionPercentage = newAdoptionPercentage;
        emit GeneralFeeChanged(newBaseRate, newAdoptionFactor, newAdoptionPercentage);
    }

    /**
     * @dev Transfers tokens with a fee.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transferWithFee(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another with a fee.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transferWithFee(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);
        return true;
    }

    /**
     * @dev Mints new tokens.
     * @param to Address to which the tokens will be minted.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyMinterOrAuthorized onlyNotPaused onlyPositiveValue(amount) {
        require(totalSupply() + amount <= type(uint256).max, "Minting would exceed the maximum token supply");
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /**
     * @dev Burns tokens.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) external onlyBurnerOrAuthorized onlyNotPaused onlyPositiveValue(amount) {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    /**
     * @dev Locks the specified account.
     */
    function lockAccount(address account) external onlyLockerOrAuthorized onlyNotPaused {
        require(!_isLocked[account], "Account is already locked");
        _isLocked[account] = true;
        emit LockSet(account, true);
        emit AccountLocked(account);
    }

    /**
     * @dev Unlocks the specified account.
     */
    function unlockAccount(address account) external onlyLockerOrAuthorized onlyNotPaused {
        require(_isLocked[account], "Account is not locked");
        _isLocked[account] = false;
        emit LockSet(account, false);
        emit AccountUnlocked(account);
    }

    /**
     * @dev Checks if an account is locked.
     */
    function isAccountLocked(address account) external view returns (bool) {
        return _isLocked[account];
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner onlyNotPaused {
        _pause();
        emit ContractPaused();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        require(paused(), "Contract is not paused");
        _unpause();
        emit ContractUnpaused();
    }

    // Internal Functions

    /**
     * @dev Calculates the transaction fee based on the configured parameters.
     */
    function calculateTransactionFee(uint256 amount) internal view returns (uint256) {
        uint256 adoptionFactorAdjusted = adoptionFactor.mul(adoptionPercentage).div(100);
        uint256 adjustmentFactor = 1 + adoptionFactorAdjusted;
        uint256 adjustedRate = baseRate.div(adjustmentFactor);
        uint256 fee = amount.mul(adjustedRate).div(100);

        return fee;
    }


    /**
     * @dev Performs the token transfer with a fee.
     */
    function _transferWithFee(address sender, address recipient, uint256 amount) internal 
        onlyUnlocked(msg.sender)
        onlyUnlocked(recipient)
        whenNotPausedOrAuthorized 
        transferAllowed(sender, recipient) 
    {
        require(recipient != address(0), "Transfer to zero address is not allowed");
        require(amount <= balanceOf(sender), "Insufficient balance");

        uint256 fee = calculateTransactionFee(amount);
        require(fee <= balanceOf(sender), "Insufficient balance for fee");

        uint256 netAmount = amount.sub(fee);

        _transfer(sender, recipient, netAmount);
        _burn(sender, fee);

        // emit TransferWithFee(sender, recipient, netAmount, fee);
        emit Transfer(sender, recipient, netAmount);
        emit Transfer(sender, address(0), fee);
    }
}
