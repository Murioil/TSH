// SPDX-License-Identifier: GPL-3.0
pragma solidity = 0.8.4;

interface TSHDATA {
    function mint(address to, uint256 value) external returns (bool);
    function burn(address to, uint256 value) external returns (bool);
    function changeMinter(address newminter) external returns (bool);
    function pauseContract(uint duration) external returns (bool);
}

contract Administration {
    string public constant name = "Coin Administration";
    string public version = "1";

    address public proxyContract;

    uint256 public totalVotes;
    uint256 public voteThreshold; // threshold in percentage
    uint256 public voteTimeLimit; // time limit for voting in seconds
    uint256 public maxWeight;

    struct Proposal {
        address proposer;
        address user;
        uint256 value;
        uint8 proposalType; // 0 = mint, 1 = burn, 2 = change curator weight (0 removes), 3 = pauseContract, 4 = changeMinter
        uint256 timestamp; // start time of proposal
        uint256 weight; // how much weight proposal has received
        bytes32 hash;
        bool executed;
    }

    mapping(address => bool) public isCurator;
    mapping(address => uint256) public myWeight;
    mapping(bytes32 => uint256) public proposalIndex; // map proposal hash to index in proposals array
    mapping(bytes32 => mapping(address => bool)) public hasVoted;

    address[] public curators;
    Proposal[] public proposals;
    uint256 public recentNonce; // minimum nonce where all prior orders in proposal expired
    uint256 public timeLimit = 15552000; // curators should be encouraged to stay active(6 months)

    event ProposalCreated(address indexed from, uint256 indexed propIndex, bytes32 hash);
    event ProposalExecuted(bytes32 hash);

    modifier onlyCurator() {
        require(isCurator[msg.sender], "Not a curator");
        _;
    }

    constructor(address _proxyContract, uint256 _voteThreshold, uint256 _voteTimeLimit, uint256 weight, uint256 _maxWeight) {
        proxyContract = _proxyContract;
        voteThreshold = _voteThreshold;
        voteTimeLimit = _voteTimeLimit;
        maxWeight = _maxWeight;
        isCurator[msg.sender] = true;
        myWeight[msg.sender] = weight;
        curators.push(msg.sender);
    }

    function updateList(uint iterations) public {
        uint x = recentNonce;
        while(x < iterations) {
            if(x >= proposals.length) {
                break;
            }
            if(proposals[x].timestamp + voteTimeLimit < block.timestamp) {
                recentNonce = x + 1;
            }
            x++;
        }
    }

    function createProposal(address user, uint256 value, uint8 proposalType) public onlyCurator {
        updateList(100);
        bytes32 hash = keccak256(abi.encodePacked(user, value, proposalType, proposals.length - 1));
        Proposal memory newProposal = Proposal({
            proposer: msg.sender,
            user: user,
            value: value,
            proposalType: proposalType,
            timestamp: block.timestamp,
            weight: myWeight[msg.sender],
            hash: hash,
            executed: false
        });
        require(!hasVoted[hash][msg.sender], "Already voted");
        hasVoted[hash][msg.sender] = true;
        proposals.push(newProposal);
        uint256 propIndex = proposals.length - 1;
        proposalIndex[hash] = propIndex;
        if (newProposal.weight >= (totalVotes * voteThreshold / 100)) {
            executeProposal(proposals[propIndex]);
        }
        emit ProposalCreated(msg.sender, propIndex, hash);
    }

    function voteProposal(bytes32 hash) public onlyCurator {
        updateList(100);
        uint256 propIndex = proposalIndex[hash];
        Proposal storage proposal = proposals[propIndex];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp <= proposal.timestamp + voteTimeLimit, "Proposal expired");
        require(!hasVoted[hash][msg.sender], "Already voted");
        hasVoted[hash][msg.sender] = true;
        proposal.weight += myWeight[msg.sender];
        if (proposal.weight >= (totalVotes * voteThreshold / 100)) {
            executeProposal(proposal);
        }
    }

    function executeProposal(Proposal storage proposal) internal {
        require(!proposal.executed, "Proposal already executed");
        require(proposal.weight >= (totalVotes * voteThreshold / 100), "Not enough votes");

        proposal.executed = true;

        if (proposal.proposalType == 0) {
            TSHDATA(proxyContract).mint(proposal.user, proposal.value);
        } else if (proposal.proposalType == 1) {
            TSHDATA(proxyContract).burn(proposal.user, proposal.value);
        } else if (proposal.proposalType == 2) {
            updateCurator(proposal.user, proposal.value);
        } else if (proposal.proposalType == 3) {
            TSHDATA(proxyContract).pauseContract(proposal.value);
        } else if (proposal.proposalType == 4) {
            TSHDATA(proxyContract).changeMinter(proposal.user);
        }
        emit ProposalExecuted(proposal.hash);
    }

    function updateCurator(address curator, uint256 weight) internal {
        require(weight <= maxWeight, "Weight exceeds max weight");
        if (weight == 0) {
            isCurator[curator] = false;
            totalVotes -= myWeight[curator];
            myWeight[curator] = 0;
        } else {
            if (!isCurator[curator]) {
                isCurator[curator] = true;
                curators.push(curator);
            }
            if(weight < myWeight[curator]) {
                totalVotes -= (myWeight[curator] - weight);
            } else {
                totalVotes += (weight - myWeight[curator]);
            }
            myWeight[curator] = weight;
        }
    }
}