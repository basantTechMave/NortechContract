// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./NNTHToken.sol"; // Import your token contract

/**
 * @title BurningMechanisms
 * @dev A contract for implementing various token burning mechanisms.
 */
contract BurningMechanisms is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 private _nnthToken; // Instance of the NNTHToken contract

    uint256 public constant MAX_BURN_LIMIT = 1000 * 10**18; // 1000 NTH

    // Burning rates as percentages (1% represented as 100, 0.1% represented as 10, etc.)
    uint256 public constant PERCENTAGE_FACTOR = 100;
    uint8 public transactionBurningRate = 10; // 0.1%
    uint16 public communityGrowthBurningPercentage = 500; // 0.5%
    uint8 public certificateAssociatedBurningPercentage = 100; // 1%
    uint8 public liquidityOperationsBurningRate = 100; // 1%

    uint256 public lastUserCount;
    uint256 public currentActiveTokenSupply;

    // Timelock variables
    uint256 public timelockDuration = 7 days;
    uint256 public timelockExpiration;
    uint8 public pendingTransactionBurningRate;
    uint16 public pendingCommunityGrowthBurningPercentage;
    uint8 public pendingCertificateAssociatedBurningPercentage;
    uint8 public pendingLiquidityOperationsBurningRate;

    // Maximum burn percentage allowed in a single transaction
    uint256 public constant MAX_BURN_PERCENTAGE = 5; // 5%

    event TokensBurned(uint256 amount);
    event BurningParametersUpdated(uint8 newTransactionBurningRate, uint16 newCommunityGrowthBurningPercentage, uint8 newCertificateAssociatedBurningPercentage, uint8 newLiquidityOperationsBurningRate);
    event TransactionBurningRateUpdated(uint8 newTransactionBurningRate);
    event CommunityGrowthBurningPercentageUpdated(uint16 newCommunityGrowthBurningPercentage);
    event CertificateAssociatedBurningPercentageUpdated(uint8 newCertificateAssociatedBurningPercentage);
    event LiquidityOperationsBurningRateUpdated(uint8 newLiquidityOperationsBurningRate);

    modifier onlyAfterTimelock() {
        require(block.timestamp >= timelockExpiration, "Timelock period has not expired");
        _;
    }

    modifier onlyAdmin() {
        // Assuming you want to designate an "admin" role. You can customize this function as needed.
        require(msg.sender == owner() || msg.sender == adminAddress, "Not authorized");
        _;
    }

    address public adminAddress;

    constructor(address _tokenAddress, address _adminAddress) Ownable(msg.sender) {
        _nnthToken = IERC20(_tokenAddress);
        adminAddress = _adminAddress;
    }

    /**
     * @dev Set a new admin address.
     * @param _newAdminAddress New admin address.
     */
    function setAdminAddress(address _newAdminAddress) external onlyOwner {
        require(_newAdminAddress != address(0), "Invalid admin address");
        adminAddress = _newAdminAddress;
    }

    /**
     * @dev Updates the burning parameters with a timelock.
     * @param _newTransactionBurningRate New transaction burning rate as a percentage (0.1% represented as 10).
     * @param _newCommunityGrowthBurningPercentage New community growth burning percentage (0.5% represented as 500).
     * @param _newCertificateAssociatedBurningPercentage New certificate-associated burning percentage (1% represented as 100).
     * @param _newLiquidityOperationsBurningRate New liquidity operations burning rate as a percentage (1% represented as 100).
     */
    function updateBurningParametersWithTimelock(
        uint8 _newTransactionBurningRate,
        uint16 _newCommunityGrowthBurningPercentage,
        uint8 _newCertificateAssociatedBurningPercentage,
        uint8 _newLiquidityOperationsBurningRate
    ) external onlyAdmin {
        require(_newTransactionBurningRate != transactionBurningRate, "No changes to transaction burning rate");
        require(_newCommunityGrowthBurningPercentage != communityGrowthBurningPercentage, "No changes to community growth burning percentage");
        require(_newCertificateAssociatedBurningPercentage != certificateAssociatedBurningPercentage, "No changes to certificate-associated burning percentage");
        require(_newLiquidityOperationsBurningRate != liquidityOperationsBurningRate, "No changes to liquidity operations burning rate");

        require(_newTransactionBurningRate <= type(uint8).max, "New transaction burning rate exceeds uint8");
        require(_newCommunityGrowthBurningPercentage <= type(uint16).max, "New community growth burning percentage exceeds uint16");

        pendingTransactionBurningRate = uint8(_newTransactionBurningRate);
        pendingCommunityGrowthBurningPercentage = _newCommunityGrowthBurningPercentage;
        pendingCertificateAssociatedBurningPercentage = _newCertificateAssociatedBurningPercentage;
        pendingLiquidityOperationsBurningRate = _newLiquidityOperationsBurningRate;

        timelockExpiration = block.timestamp.add(timelockDuration);
    }

    /**
     * @dev Executes the pending burning parameter changes after the timelock has expired.
     */
    function executePendingBurningParameterChanges() external onlyAdmin onlyAfterTimelock {
        transactionBurningRate = pendingTransactionBurningRate;
        communityGrowthBurningPercentage = pendingCommunityGrowthBurningPercentage;
        certificateAssociatedBurningPercentage = pendingCertificateAssociatedBurningPercentage;
        liquidityOperationsBurningRate = pendingLiquidityOperationsBurningRate;

        // Reset pending values
        pendingTransactionBurningRate = 0;
        pendingCommunityGrowthBurningPercentage = 0;
        pendingCertificateAssociatedBurningPercentage = 0;
        pendingLiquidityOperationsBurningRate = 0;

        emit BurningParametersUpdated(transactionBurningRate, communityGrowthBurningPercentage, certificateAssociatedBurningPercentage, liquidityOperationsBurningRate);
    }

    /**
     * @dev Updates the transaction burning rate.
     * @param _newRate New transaction burning rate as a percentage (0.1% represented as 10).
     */
    function updateTransactionBurningRate(uint8 _newRate) external onlyOwner {
        require(_newRate != transactionBurningRate, "No changes to transaction burning rate");
        transactionBurningRate = _newRate;
        emit TransactionBurningRateUpdated(_newRate);
    }

    /**
     * @dev Updates the community growth burning percentage.
     * @param _newPercentage New community growth burning percentage (0.5% represented as 500).
     */
    function updateCommunityGrowthBurningPercentage(uint8 _newPercentage) external onlyOwner {
        require(_newPercentage != communityGrowthBurningPercentage, "No changes to community growth burning percentage");
        communityGrowthBurningPercentage = _newPercentage;
        emit CommunityGrowthBurningPercentageUpdated(_newPercentage);
    }

    /**
     * @dev Updates the certificate-associated burning percentage.
     * @param _newPercentage New certificate-associated burning percentage (1% represented as 100).
     */
    function updateCertificateAssociatedBurningPercentage(uint8 _newPercentage) external onlyOwner {
        require(_newPercentage != certificateAssociatedBurningPercentage, "No changes to certificate-associated burning percentage");
        certificateAssociatedBurningPercentage = _newPercentage;
        emit CertificateAssociatedBurningPercentageUpdated(_newPercentage);
    }

    /**
     * @dev Updates the liquidity operations burning rate.
     * @param _newRate New liquidity operations burning rate as a percentage (1% represented as 100).
     */
    function updateLiquidityOperationsBurningRate(uint8 _newRate) external onlyOwner {
        require(_newRate != liquidityOperationsBurningRate, "No changes to liquidity operations burning rate");
        liquidityOperationsBurningRate = _newRate;
        emit LiquidityOperationsBurningRateUpdated(_newRate);
    }

    /**
     * @dev Updates the last user count.
     * @param _newUserCount New value for the last user count.
     */
    function updateLastUserCount(uint256 _newUserCount) external onlyOwner {
        lastUserCount = _newUserCount;
    }

    /**
     * @dev Updates the current active token supply.
     * @param _newSupply New value for the current active token supply.
     */
    function updateCurrentActiveTokenSupply(uint256 _newSupply) external onlyOwner {
        currentActiveTokenSupply = _newSupply;
    }

    /**
     * @dev Calculates the burning amount for a transaction based on the transaction value.
     * @param transactionValue Value of the transaction.
     * @return The calculated burning amount.
     */
    function calculateTransactionBurning(uint256 transactionValue) public view returns (uint256) {
        uint256 burningAmount = (transactionValue * transactionBurningRate) / PERCENTAGE_FACTOR;
        return (burningAmount > MAX_BURN_LIMIT) ? MAX_BURN_LIMIT : burningAmount;
    }

    /**
     * @dev Calculates the burning amount for community growth based on the difference in user count.
     * @param differenceInUserCount The difference in the user count.
     * @return The calculated burning amount for community growth.
     */
    function calculateCommunityGrowthBurning(uint256 differenceInUserCount) public view returns (uint256) {
        uint256 burningAmount = (communityGrowthBurningPercentage * differenceInUserCount * currentActiveTokenSupply) / PERCENTAGE_FACTOR;
        return (burningAmount > MAX_BURN_LIMIT) ? MAX_BURN_LIMIT : burningAmount;
    }

    /**
     * @dev Calculates the burning amount for certificate-associated rewards.
     * @param certificateReward The certificate reward amount.
     * @return The calculated burning amount for certificate-associated rewards.
     */
    function calculateCertificateAssociatedBurning(uint256 certificateReward) public view returns (uint256) {
        return (certificateReward * certificateAssociatedBurningPercentage) / PERCENTAGE_FACTOR;
    }

    /**
     * @dev Calculates the burning amount for liquidity operations based on the quantity of tokens in liquidity.
     * @param quantityOfTokensInLiquidity The quantity of tokens in liquidity.
     * @return The calculated burning amount for liquidity operations.
     */
    function calculateLiquidityOperationsBurning(uint256 quantityOfTokensInLiquidity) public view returns (uint256) {
        uint256 burningAmount = (quantityOfTokensInLiquidity * liquidityOperationsBurningRate) / PERCENTAGE_FACTOR;
        return (burningAmount > MAX_BURN_LIMIT) ? MAX_BURN_LIMIT : burningAmount;
    }

    /**
    * @dev Burns a specified amount of tokens from the contract's balance.
    * @param amount The amount of tokens to burn.
    */
    function burnTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= MAX_BURN_LIMIT, "Amount exceeds maximum burn limit");
        
        uint256 availableBalance = _nnthToken.balanceOf(address(this));
        require(availableBalance >= amount, "Insufficient balance in contract");

        // Ensure burning amount does not exceed a certain percentage of the total supply
        uint256 totalSupply = _nnthToken.totalSupply();
        uint256 burningPercentage = (amount * PERCENTAGE_FACTOR) / totalSupply;
        require(burningPercentage <= MAX_BURN_PERCENTAGE, "Burning percentage exceeds maximum limit");

        _nnthToken.transfer(address(0xdead), amount);
        emit TokensBurned(amount);
    }
}
