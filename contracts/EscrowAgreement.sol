// EscrowAgreement.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NNTHToken.sol";

/**
 * @title EscrowAgreement
 * @dev A simple smart contract for handling escrow agreements using NNTH tokens.
 */
contract EscrowAgreement is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public payer;
    address public payee;
    address public arbiter;
    uint256 public totalNNTHAmount;
    uint256 public releaseNNTHAmount;
    uint256 public remainingNNTHAmount;
    IERC20 public nnthToken; // Import the NNTH token contract

    enum State { InProgress, Completed, Aborted }
    State public state;

    // Events
    event MilestoneCompleted(address indexed payee, uint256 releaseAmount);
    event AgreementAborted(address indexed caller);
    event FundsReleased(address indexed receiver, uint256 releaseAmount);
    event FundsRefunded(uint256 refundAmount);
    event ArbiterSet(address indexed oldArbiter, address indexed newArbiter);
    event RemainingFundsWithdrawn(address indexed owner, uint256 amount);

    // Modifiers

    /**
     * @dev Modifier to check if the contract is in progress.
     */
    modifier inProgress() {
        require(state == State.InProgress, "Escrow is not in progress");
        _;
    }

    /**
     * @dev Modifier to check if the contract is not in an Aborted or Completed state.
     */
    modifier notAbortedOrCompleted() {
        require(state != State.Aborted && state != State.Completed, "Escrow is finalized");
        _;
    }

    /**
     * @dev Modifier to restrict access to only the payer.
     */
    modifier onlyPayer() {
        require(msg.sender == payer, "Only the payer can perform this action");
        _;
    }

    /**
     * @dev Modifier to restrict access to only the payee.
     */
    modifier onlyPayee() {
        require(msg.sender == payee, "Only the payee can perform this action");
        _;
    }

    /**
     * @dev Modifier to restrict access to only the arbiter.
     */
    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only the arbiter can perform this action");
        _;
    }

    /**
     * @dev Constructor to initialize the escrow agreement.
     * @param _payer The address of the payer.
     * @param _payee The address of the payee.
     * @param _arbiter The address of the arbiter.
     * @param _totalNNTHAmount The total amount of NNTH tokens in the escrow.
     * @param _releaseNNTHAmount The amount to be released upon milestone completion.
     * @param _nnthTokenAddress The address of the NNTH token contract.
     * @param _initialOwner The initial owner of the contract (for Ownable).
     */
    constructor(
        address _payer,
        address _payee,
        address _arbiter,
        uint256 _totalNNTHAmount,
        uint256 _releaseNNTHAmount,
        address _nnthTokenAddress,
        address _initialOwner
    ) Ownable(_initialOwner) {
        payer = _payer;
        payee = _payee;
        arbiter = _arbiter;
        totalNNTHAmount = _totalNNTHAmount;
        releaseNNTHAmount = _releaseNNTHAmount;
        remainingNNTHAmount = totalNNTHAmount;
        state = State.InProgress;
        nnthToken = IERC20(_nnthTokenAddress); // Initialize the NNTH token contract
    }

    /**
    * @dev Function to release funds.
    * If called by the payee, it completes a milestone and releases funds.
    * If called by the arbiter, it releases funds based on arbiter's decision.
    * @param _isArbiterRelease A boolean indicating whether the release is initiated by the arbiter.
    */
    function releaseFunds(bool _isArbiterRelease) external inProgress notAbortedOrCompleted {
        require(
            !_isArbiterRelease || msg.sender == arbiter,
            "Only the arbiter can initiate arbiter releases"
        );

        uint256 releaseAmount = _isArbiterRelease ? releaseNNTHAmount : remainingNNTHAmount;

        // Ensure that the release amount does not exceed the remaining funds
        require(releaseAmount <= remainingNNTHAmount, "Release amount exceeds remaining funds");

        remainingNNTHAmount = remainingNNTHAmount.sub(releaseAmount);

        if (remainingNNTHAmount == 0) {
            state = State.Completed;
        }

        // Transfer NNTH tokens to the payee upon milestone completion or arbiter's decision
        nnthToken.safeTransfer(_isArbiterRelease ? payee : msg.sender, releaseAmount);

        if (_isArbiterRelease) {
            emit FundsReleased(payee, releaseAmount);
        } else {
            emit MilestoneCompleted(payee, releaseAmount);
        }

        // Handle any remaining funds after the final release
        if (remainingNNTHAmount > 0 && state == State.Completed) {
            // If there are remaining funds after completing the escrow, transfer them to the payee
            nnthToken.safeTransfer(payee, remainingNNTHAmount);
            emit FundsReleased(payee, remainingNNTHAmount);
            remainingNNTHAmount = 0;
        }
    }

    /**
     * @dev Function to abort the escrow agreement.
     * Only the payer can call this function.
     */
    function abortAgreement() external onlyPayer inProgress {
        state = State.Aborted;

        emit AgreementAborted(msg.sender);
    }

    /**
     * @dev Function to refund funds to the payer.
     * Only the arbiter can call this function, and a refund is allowed only if the contract is in progress.
     */
    function refundFunds() external onlyArbiter inProgress {
        // Ensure that a refund is allowed only if there are remaining funds
        require(remainingNNTHAmount > 0, "No remaining funds for refund");

        // Transfer NNTH tokens back to the payer in case of a refund
        nnthToken.safeTransfer(payer, totalNNTHAmount.sub(remainingNNTHAmount));
        remainingNNTHAmount = 0;
        state = State.Aborted;

        emit FundsRefunded(totalNNTHAmount.sub(remainingNNTHAmount));
    }

    /**
     * @dev Function to set a new arbiter.
     * Only the owner of the contract can call this function.
     * @param _newArbiter The address of the new arbiter.
     */
    function setArbiter(address _newArbiter) external onlyOwner {
        require(_newArbiter != address(0), "Invalid arbiter address");
        address oldArbiter = arbiter;
        arbiter = _newArbiter;

        emit ArbiterSet(oldArbiter, _newArbiter);
    }

    /**
     * @dev Function to withdraw any remaining funds from the contract.
     * Only the owner of the contract can call this function.
     */
    function withdrawRemainingFunds() external onlyOwner {
        require(state == State.Completed || state == State.Aborted, "Escrow not finalized");
        nnthToken.safeTransfer(owner(), remainingNNTHAmount);
        remainingNNTHAmount = 0;

        emit RemainingFundsWithdrawn(owner(), remainingNNTHAmount);
    }
}
