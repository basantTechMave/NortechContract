// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./NNTHToken.sol";

contract GovernanceAgreement {
    NNTHToken public nnthToken; // Reference to your NNTH token contract
    address public owner;      // The owner of the governance contract

    uint256 public proposalCount;
    uint256 public quorum;        // Minimum quorum required for a proposal to pass
    uint256 public minimumTokensToVote; // Minimum tokens required to participate in voting
    bool public isVotingOpen;    // Flag to indicate if voting is open
    uint256 public currentProposalId;
    uint256 public votingDuration;

    struct Proposal {
        uint256 id;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public tokenBalances;

    event ProposalSubmitted(uint256 proposalId, string description, address proposer);
    event Voted(uint256 proposalId, address voter, bool inSupport);
    event ProposalExecuted(uint256 proposalId);

    constructor(address _nnthToken, uint256 _quorum, uint256 _minimumTokensToVote,uint256 _votingDuration) {
        nnthToken = NNTHToken(_nnthToken); // Link to your NNTH token contract
        owner = msg.sender;
        quorum = _quorum;
        minimumTokensToVote = _minimumTokensToVote;
        votingDuration = _votingDuration;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier votingOpen() {
        require(isVotingOpen, "Voting is closed for the current proposal");
        _;
    }

    modifier hasMinimumTokens() {
        require(tokenBalances[msg.sender] >= minimumTokensToVote, "Insufficient tokens to vote");
        _;
    }

    // Add the getVotingDuration function to retrieve the voting duration
    function getVotingDuration() public view returns (uint256) {
        return votingDuration;
    }

    function releasableAmount() public view returns (uint256) {
        if (block.timestamp < proposals[currentProposalId].endTime) {
            return 0;
        } else {
            uint256 totalVotes = proposals[currentProposalId].votesFor + proposals[currentProposalId].votesAgainst;
            if (totalVotes < quorum) {
                return 0;
            } else {
                if (proposals[currentProposalId].votesFor > proposals[currentProposalId].votesAgainst) {
                    return tokenBalances[msg.sender];
                } else {
                    return 0;
                }
            }
        }
    }

    function submitProposal(string memory _description) external onlyOwner {
        require(!isVotingOpen, "There is an active proposal");
        currentProposalId++;
        proposals[currentProposalId] = Proposal({
            id: currentProposalId,
            description: _description,
            startTime: block.timestamp,
            endTime: block.timestamp + getVotingDuration(),
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });
        emit ProposalSubmitted(currentProposalId, _description, msg.sender);
        isVotingOpen = true;
    }

    function vote(uint256 _proposalId, bool _inSupport) external votingOpen hasMinimumTokens {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp < proposal.endTime, "Voting has ended for this proposal");
        tokenBalances[msg.sender] -= minimumTokensToVote;
        if (_inSupport) {
            proposal.votesFor += minimumTokensToVote;
        } else {
            proposal.votesAgainst += minimumTokensToVote;
        }
        emit Voted(_proposalId, msg.sender, _inSupport);
    }

    function executeProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.endTime, "Voting is still open for this proposal");
        require(!proposal.executed, "Proposal has already been executed");
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes >= quorum, "Quorum not met");
        if (proposal.votesFor > proposal.votesAgainst) {
            // Execute the proposal (implement the decision)
            proposal.executed = true;
            emit ProposalExecuted(_proposalId);
        }
        isVotingOpen = false;
    }

    function depositTokens(uint256 _amount) external {
        require(nnthToken.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        tokenBalances[msg.sender] += _amount;
    }

    function withdrawTokens(uint256 _amount) external {
        require(tokenBalances[msg.sender] >= _amount, "Insufficient balance");
        tokenBalances[msg.sender] -= _amount;
        require(nnthToken.transfer(msg.sender, _amount), "Token transfer failed");
    }
}
