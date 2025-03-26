// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;


contract PollingSystem {

    // Data structure to store poll information
    struct Poll {
        string name;
        uint256 pollId;
        uint256 startTime;
        uint256 endTime;
        string[] choices;
        mapping(string => uint256) voteCount;
        bool isCreated;
        bool isActive;
        string winnerChoice;
    }

    // Data structure to store voter information
    struct Voter {
        string name;
        address voter;
        bool isApproved;
        bool hasVoted;
    }

    address pollCreator;
    
    mapping(uint256 => Poll) public Polls;  // Mapping of poll ID to Poll struct
    mapping(address => Voter) public Voters;  // Mapping of voter address to Voter struct

    // Events to emit
    event VoterRegistered(address indexed voter, string name);
    event VoterApproved(address indexed voter);
    event PollCreated(uint256 indexed pollId, string name);
    event VotedOnPoll(address indexed voter, uint256 indexed pollId, string choice);


    //constructor to restict the access of contract to pollCreator
    constructor() {
        pollCreator = msg.sender;
    }


    //modifier to call some function by only pollCreator
    modifier onlyPollCreator() {
        require(pollCreator == msg.sender, "You are not the poll creator");
        _;
    }


    // function to register a new voter
    function registerVoter(string memory _name, address _voter) public {
        require(_voter != address(0), "Invalid voter address");
        require(Voters[_voter].voter == address(0), "Voter already registered");  // Ensure voter is not registered
        Voters[_voter] = Voter({
            name: _name,
            voter: _voter,
            isApproved: false,
            hasVoted: false
        });

        emit VoterRegistered(_voter, _name);
    }


    // function to approve voter for vote on poll
    function approveVoter(address _voterAddress) external onlyPollCreator {
        require(_voterAddress != address(0), "Invalid address");
        require(Voters[_voterAddress].voter == _voterAddress, "Voter not registered");
        Voters[_voterAddress].isApproved = true;


        emit VoterApproved(_voterAddress);
    }


    // function to create a new poll
    function createPoll(
        string memory _name,
        uint256 _pollId,
        uint256 _endTime,
        string[] memory _choices
    ) public onlyPollCreator {
        require(bytes(Polls[_pollId].name).length == 0, "Poll already created");
        
        Polls[_pollId].name = _name;
        Polls[_pollId].pollId = _pollId;
        Polls[_pollId].startTime = block.timestamp;
        Polls[_pollId].endTime = block.timestamp + _endTime;
        Polls[_pollId].choices = _choices;
        Polls[_pollId].isCreated = true;
        Polls[_pollId].isActive = true;


        emit PollCreated(_pollId, _name);
    }


    // function to vote in the poll
    function voteOnPoll(uint _pollId, string memory _choice) public {
        Poll storage poll = Polls[_pollId];

        require(poll.isCreated, "Poll not created yet");
        require(Voters[msg.sender].isApproved, "Voter not approved");
        require(!Voters[msg.sender].hasVoted, "Voter already voted");
        require(block.timestamp >= poll.startTime && block.timestamp <= poll.endTime, "Poll time has ended");

        // Check if the choice exists in the poll
        bool choiceExists = false;
        for (uint256 i = 0; i < poll.choices.length; i++) {
            if (keccak256(abi.encodePacked(_choice)) == keccak256(abi.encodePacked(poll.choices[i]))) {
                choiceExists = true;
                break;
            }
        }
        require(choiceExists, "Invalid choice");
        poll.voteCount[_choice] += 1;
        Voters[msg.sender].hasVoted = true;

        emit VotedOnPoll(msg.sender, _pollId, _choice);
    }


    //function to retrieve the vote count for a choice in a poll
    function getVoteCount(uint _pollId, string memory _choice) public view returns (uint256) {
        return Polls[_pollId].voteCount[_choice];
    }


    // function to determine the winner automatically internally by the contract
    function calculateWinner(uint _pollId) internal {
        Poll storage poll = Polls[_pollId];
        
        uint256 maxVotes = 0;
        string memory winner;
        
        for (uint256 i = 0; i < poll.choices.length; i++) {
            uint256 currentVoteCount = poll.voteCount[poll.choices[i]];
            if (currentVoteCount > maxVotes) {
                maxVotes = currentVoteCount;
                winner = poll.choices[i];
            }
        }
        
        // Set the winner
        poll.winnerChoice = winner;
    }


    //function to close the poll and automatically determine the winner
    function closePoll(uint _pollId) public onlyPollCreator {
        Poll storage poll = Polls[_pollId];
        require(block.timestamp >= poll.endTime, "Poll time has not ended yet");
        
        poll.isActive = false;

        // automatically calculate the winner after the poll ends
        calculateWinner(_pollId);
    }


    // function to get the winner of a poll
    function getWinner(uint _pollId) public view returns (string memory) {
        return Polls[_pollId].winnerChoice;
    }
}