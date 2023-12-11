// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./NNTHToken.sol";

/**
 * @title GovernanceAgreement
 * @dev A smart contract for managing governance proposals using NNTH tokens with token-based voting.
 */
contract GovernanceAgreement is AccessControl {
    NNTHToken public nnthToken; // Reference to the NNTH token contract
    uint256 public proposalCount;
    uint256 public quorumPercentage;       // Minimum quorum percentage required for a proposal to pass
    uint256 public minimumTokensToVote;  // Minimum tokens required to participate in voting
    bool public isVotingOpen;            // Flag to indicate if voting is open
    uint256 public currentProposalId;
    uint256 public votingDuration;
    uint256 public minBalanceToSubmit;   // Minimum balance required to submit a proposal

    struct Proposal {
        uint256 id;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        mapping(address => uint256) votedTokens;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public lockedTokens;

    event ProposalSubmitted(uint256 proposalId, string description, address proposer);
    event Voted(uint256 proposalId, address voter, bool inSupport);
    event ProposalExecuted(uint256 proposalId);
    event TokensDeposited(address indexed depositor, uint256 amount);
    event TokensWithdrawn(address indexed withdrawer, uint256 amount);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev Constructor to initialize the GovernanceAgreement contract.
     * @param _nnthToken The address of the NNTH token contract.
     * @param _quorumPercentage Minimum quorum percentage required for a proposal to pass.
     * @param _minimumTokensToVote Minimum tokens required to participate in voting.
     * @param _votingDuration Duration of the voting period for each proposal.
     * @param _minBalanceToSubmit Minimum balance required to submit a proposal.
     */
    constructor(
        address _nnthToken,
        uint256 _quorumPercentage,
        uint256 _minimumTokensToVote,
        uint256 _votingDuration,
        uint256 _minBalanceToSubmit
    ) {
        nnthToken = NNTHToken(_nnthToken); // Link to the NNTH token contract
        // _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        // _setupRole(ADMIN_ROLE, msg.sender);
        quorumPercentage = _quorumPercentage;
        minimumTokensToVote = _minimumTokensToVote;
        votingDuration = _votingDuration;
        minBalanceToSubmit = _minBalanceToSubmit;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    /**
     * @dev Modifier to check if voting is open for the current proposal.
     */
    modifier votingOpen() {
        require(isVotingOpen, "Voting is closed for the current proposal");
        _;
    }

    /**
     * @dev Modifier to check if the sender has the minimum required tokens to vote.
     */
    modifier hasMinimumTokens() {
        require(lockedTokens[msg.sender] >= minimumTokensToVote, "Insufficient tokens to vote");
        _;
    }

    /**
     * @dev Function to retrieve the voting duration.
     * @return The duration of the voting period for each proposal.
     */
    function getVotingDuration() public view returns (uint256) {
        return votingDuration;
    }

    /**
    * @dev Function to calculate the amount of tokens that can be released by the sender.
    * @return The amount of tokens available for release.
    */
    function releasableAmount() public view returns (uint256) {
        if (block.timestamp < proposals[currentProposalId].endTime) {
            // Voting is still ongoing, no tokens can be released
            return 0;
        } else {
            Proposal storage proposal = proposals[currentProposalId];
            uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
            uint256 requiredVotes = (totalVotes * quorumPercentage) / 100;

            if (totalVotes < requiredVotes) {
                // Quorum is not met, no tokens can be released
                return 0;
            } else {
                if (proposal.votesFor > proposal.votesAgainst) {
                    // Proposal passed, sender can release their locked tokens
                    return lockedTokens[msg.sender];
                } else {
                    // Proposal failed, no tokens can be released
                    return 0;
                }
            }
        }
    }


    /**
     * @dev Function to submit a new governance proposal.
     * Any token holder with a minimum balance can submit proposals, and voting is opened for each proposal.
     * @param _description The description of the proposal.
     */
    function submitProposal(string memory _description) external {
        require(!isVotingOpen, "There is an active proposal");
        require(nnthToken.balanceOf(msg.sender) >= minBalanceToSubmit, "Insufficient balance to submit a proposal");
        currentProposalId++;
        
        Proposal storage newProposal = proposals[currentProposalId];
        newProposal.id = currentProposalId;
        newProposal.description = _description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + getVotingDuration();
        newProposal.votesFor = 0;
        newProposal.votesAgainst = 0;
        newProposal.executed = false;

        emit ProposalSubmitted(currentProposalId, _description, msg.sender);
        isVotingOpen = true;
    }


    /**
     * @dev Function for users to vote on a proposal.
     * Requires that the voting is open, the sender has enough tokens, and the proposal is still within the voting period.
     * @param _proposalId The ID of the proposal to vote on.
     * @param _inSupport A boolean indicating whether the voter is in support of the proposal.
     */
    function vote(uint256 _proposalId, bool _inSupport) external votingOpen hasMinimumTokens {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.endTime, "Voting has ended for this proposal");
        // Lock tokens for voting
        lockedTokens[msg.sender] += minimumTokensToVote;
        proposal.votedTokens[msg.sender] += minimumTokensToVote;
        if (_inSupport) {
            proposal.votesFor += minimumTokensToVote;
        } else {
            proposal.votesAgainst += minimumTokensToVote;
        }
        emit Voted(_proposalId, msg.sender, _inSupport);
    }

    /**
     * @dev Function to adjust the voting duration.
     * Only the contract owner can adjust the duration.
     * @param _newVotingDuration The new voting duration in seconds.
     */
    function adjustVotingDuration(uint256 _newVotingDuration) external onlyAdmin {
        // Ensure that there is no active proposal
        require(!isVotingOpen, "Cannot adjust voting duration during an active proposal");
        
        // Set the new voting duration
        votingDuration = _newVotingDuration;
    }

    /**
     * @dev Function to adjust the quorum percentage.
     * Only the contract owner can adjust the quorum percentage.
     * @param _newQuorumPercentage The new quorum percentage.
     */
    function adjustQuorumPercentage(uint256 _newQuorumPercentage) external onlyAdmin {
        // Ensure that there is no active proposal
        require(!isVotingOpen, "Cannot adjust quorum percentage during an active proposal");
        
        // Set the new quorum percentage
        quorumPercentage = _newQuorumPercentage;
    }

    /**
    * @dev Function to execute a proposal.
    * Requires that the voting has ended, the proposal hasn't been executed, and the quorum is met.
    * If the votes in favor exceed the votes against, the proposal is executed.
    * The contract owner can execute proposals.
    * @param _proposalId The ID of the proposal to execute.
    */
    function executeProposal(uint256 _proposalId) external onlyAdmin {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.endTime, "Voting is still open for this proposal");
        require(!proposal.executed, "Proposal has already been executed");
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 requiredQuorum = (nnthToken.totalSupply() * quorumPercentage) / 100; // Calculate required quorum

        require(totalVotes >= requiredQuorum, "Quorum not met");

        if (proposal.votesFor > proposal.votesAgainst) {
            // Execute the proposal (implement the decision)
            proposal.executed = true;

            // Example: Trigger specific actions based on the proposal's outcome
            if (bytes(proposal.description).length > 0) {
                // Execute some action based on the proposal's description or other parameters
                // You can call other functions or interact with other contracts here
                // For example: executeAction(proposal.description);
            }

            // Release locked tokens
            lockedTokens[msg.sender] -= proposal.votedTokens[msg.sender];
            emit ProposalExecuted(_proposalId);
        }
        isVotingOpen = false;
    }



    /**
     * @dev Function for users to deposit tokens into the governance contract for voting.
     * @param _amount The amount of tokens to deposit.
     */
    function depositTokens(uint256 _amount) external {
        require(nnthToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        // Deposit tokens and lock them
        lockedTokens[msg.sender] += _amount;
        emit TokensDeposited(msg.sender, _amount);
    }

    /**
     * @dev Function for users to withdraw deposited tokens from the governance contract.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawTokens(uint256 _amount) external {
        require(lockedTokens[msg.sender] >= _amount, "Insufficient locked balance");

        // Check if the tokens are not involved in an active vote
        uint256 activeVotes = lockedTokens[msg.sender] - releasableAmount();
        require(activeVotes == 0, "Cannot withdraw tokens involved in active votes");

        // Withdraw locked tokens
        lockedTokens[msg.sender] -= _amount;
        require(nnthToken.transfer(msg.sender, _amount), "Token transfer failed");
        emit TokensWithdrawn(msg.sender, _amount);
    }
}
