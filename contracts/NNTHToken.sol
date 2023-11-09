// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NNTHToken is ERC20, Ownable, Pausable {
    uint256 private _transferLockEndTime;

    mapping(address => bool) private _isLocked;

    uint256 public baseRate = 1; // Base rate in percentage (1%)
    uint256 public adoptionFactor = 1; // Adoption factor
    uint256 public adoptionPercentage = 0; // Initial adoption percentage

    event LockSet(address indexed account, bool isLocked);
    event ApprovalLog(address indexed owner, address indexed spender, uint256 value);
    event GeneralFeeChanged(uint256 newBaseRate, uint256 newAdoptionFactor, uint256 newAdoptionPercentage);

    modifier onlyUnlocked(address account) {
        require(!_isLocked[account], "Account is locked");
        _;
    }

    modifier onlyNotPaused() {
        require(!paused(), "Contract is paused");
        _;
    }

    modifier onlyPositiveValue(uint256 value) {
        require(value > 0, "Value must be positive");
        _;
    }

    modifier onlyValidPercentage(uint256 percentage) {
        require(percentage >= 0 && percentage <= 100, "Percentage must be between 0 and 100");
        _;
    }

    modifier onlyOwnerOrAuthorized() {
        require(msg.sender == owner() || msg.sender == address(this), "Not authorized");
        _;
    }

    modifier transferAllowed(address sender, address recipient) {
        require(
            (_transferLockEndTime <= block.timestamp || owner() == sender || owner() == recipient),
            "Transfers are currently locked or not allowed."
        );
        _;
    }

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

    function setTransferLock(uint256 lockDuration) external onlyOwnerOrAuthorized onlyNotPaused {
        _transferLockEndTime = block.timestamp + lockDuration;
    }

    function setTransferUnlock() external onlyOwnerOrAuthorized onlyNotPaused {
        _transferLockEndTime = 0;
    }

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

    function calculateTransactionFee(uint256 amount) internal view returns (uint256) {
        uint256 adjustedRate = baseRate / (1 + adoptionFactor * adoptionPercentage / 100);
        return (amount * adjustedRate) / 100;
    }

    function _transferWithFee(address sender, address recipient, uint256 amount) internal 
        onlyUnlocked(msg.sender)
        onlyUnlocked(recipient)
        onlyNotPaused 
        transferAllowed(sender, recipient) {
        uint256 fee = calculateTransactionFee(amount);
        uint256 netAmount = amount - fee;

        _transfer(sender, recipient, netAmount);
        _burn(sender, fee);

        emit Transfer(sender, recipient, netAmount);
        emit Transfer(sender, address(0), fee);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transferWithFee(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transferWithFee(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOwner onlyNotPaused {
        _mint(to, amount);
    }

    function burn(uint256 amount) external onlyOwner onlyNotPaused {
        _burn(msg.sender, amount);
    }

    function lockAccount(address account) external onlyOwner onlyNotPaused {
        require(!_isLocked[account], "Account is already locked");
        _isLocked[account] = true;
        emit LockSet(account, true);
    }

    function unlockAccount(address account) external onlyOwner onlyNotPaused {
        require(_isLocked[account], "Account is not locked");
        _isLocked[account] = false;
        emit LockSet(account, false);
    }

    function isAccountLocked(address account) external view returns (bool) {
        return _isLocked[account];
    }

    // Function to pause the contract
    function pause() external onlyOwner onlyNotPaused {
        _pause();
    }

    // Function to unpause the contract
    function unpause() external onlyOwner {
        require(paused(), "Contract is not paused");
        _unpause();
    }
}
