// EscrowAgreement.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol";

contract EscrowAgreement {
    address public payer;
    address public payee;
    address public arbiter;
    uint256 public totalNNTHAmount;
    uint256 public releaseNNTHAmount;
    uint256 public remainingNNTHAmount;
    NNTHToken public nnthToken; // Import the NNTH token contract

    enum State { InProgress, Completed, Aborted }
    State public state;

    constructor(
        address _payer,
        address _payee,
        address _arbiter,
        uint256 _totalNNTHAmount,
        uint256 _releaseNNTHAmount,
        address _nnthTokenAddress
    ) {
        payer = _payer;
        payee = _payee;
        arbiter = _arbiter;
        totalNNTHAmount = _totalNNTHAmount;
        releaseNNTHAmount = _releaseNNTHAmount;
        remainingNNTHAmount = totalNNTHAmount;
        state = State.InProgress;
        nnthToken = NNTHToken(_nnthTokenAddress); // Initialize the NNTH token contract
    }

    modifier onlyPayer() {
        require(msg.sender == payer, "Only the payer can perform this action");
        _;
    }

    modifier onlyPayee() {
        require(msg.sender == payee, "Only the payee can perform this action");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only the arbiter can perform this action");
        _;
    }

    modifier inProgress() {
        require(state == State.InProgress, "Escrow is not in progress");
        _;
    }

    function completeMilestone() external onlyPayee inProgress {
        require(releaseNNTHAmount <= remainingNNTHAmount, "Release amount exceeds remaining funds");
        remainingNNTHAmount -= releaseNNTHAmount;

        if (remainingNNTHAmount == 0) {
            state = State.Completed;
        }

        // Transfer NNTH tokens to the payee upon milestone completion
        nnthToken.transfer(payee, releaseNNTHAmount);
    }

    function abortAgreement() external onlyPayer inProgress {
        state = State.Aborted;
    }

    function releaseFunds() external onlyArbiter inProgress {
        require(releaseNNTHAmount <= remainingNNTHAmount, "Release amount exceeds remaining funds");
        remainingNNTHAmount -= releaseNNTHAmount;

        if (remainingNNTHAmount == 0) {
            state = State.Completed;
        }

        // Transfer NNTH tokens to the payee upon arbiter's decision
        nnthToken.transfer(payee, releaseNNTHAmount);
    }

    function refundFunds() external onlyArbiter inProgress {
        // Transfer NNTH tokens back to the payer in case of a refund
        nnthToken.transfer(payer, totalNNTHAmount - remainingNNTHAmount);
        remainingNNTHAmount = 0;
        state = State.Aborted;
    }
}
