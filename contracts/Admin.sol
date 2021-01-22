// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

/// @author gg2001
/// @title Administration contract for a multisig contract
contract Admin {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public confirmationsRequired;

    uint256 private proposalExpiry = 3 days;

    struct Proposal {
        uint8 purpose;
        bool executed;
        address owner;
        uint256 ownerIndex;
        uint256 newConfirmationsRequired;
        uint256 expires;
        uint256 numConfirmations;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public proposalIsConfirmed;

    event SubmitProposal(address indexed owner, uint256 indexed proposalIndex);
    event ConfirmProposal(address indexed owner, uint256 indexed proposalIndex);
    event RevokeProposal(address indexed owner, uint256 indexed proposalIndex);
    event ExecuteProposal(address indexed owner, uint256 indexed proposalIndex);

    /// @notice Initializes owners and number of confirmations required
    /// @param _owners owners of the contract
    /// @param _confirmationsRequired confirmations required to execute a transaction
    /// @dev _confirmationsRequired is also the confirmations required to execute a proposal
    constructor(address[] memory _owners, uint256 _confirmationsRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _confirmationsRequired > 0 &&
                _confirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        confirmationsRequired = _confirmationsRequired;
    }

    /// @dev Throws if called by any accounts other than the owners
    modifier onlyOwner() {
        require(isOwner[msg.sender], "caller is not an owner");
        _;
    }

    /// @param _proposalIndex index of proposal in proposals array
    /// @dev Throws if proposal doesn't exist
    modifier proposalExists(uint256 _proposalIndex) {
        require(_proposalIndex < proposals.length, "proposal does not exist");
        _;
    }

    /// @param _proposalIndex index of proposal in proposals array
    /// @dev Throws if proposal has been executed
    modifier proposalNotExecuted(uint256 _proposalIndex) {
        require(
            !proposals[_proposalIndex].executed,
            "proposal already executed"
        );
        _;
    }

    /// @param _proposalIndex index of proposal in proposals array
    /// @dev Throws if proposal has been confirmed
    modifier proposalNotConfirmed(uint256 _proposalIndex) {
        require(
            !proposalIsConfirmed[_proposalIndex][msg.sender],
            "proposal already confirmed"
        );
        _;
    }

    /// @notice submit a proposal for a new owner to be added
    /// @param newOwner address of the new owner to add
    /// @dev owner must be new
    function submitNewOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "invalid owner");
        require(!isOwner[newOwner], "owner not unique");

        _submitProposal(0, newOwner, 0, 0);
    }

    /// @notice submit a proposal for an owner to be removed
    /// @param removeOwner address of the owner to remove
    /// @param removeOwnerIndex index of the owner to remove in the owner array
    /// @dev removeOwner must refer to an existing owner
    function submitRemoveOwner(address removeOwner, uint256 removeOwnerIndex)
        public
        onlyOwner
    {
        require(isOwner[removeOwner], "address is not owner");
        require(
            removeOwner == owners[removeOwnerIndex],
            "owner index not equal to address"
        );

        _submitProposal(1, removeOwner, removeOwnerIndex, 0);
    }

    /// @notice submit a proposal to modify the confirmations required
    /// @param newConfirmationsRequired new confirmations required to pass a tx or a proposal
    /// @dev confirmations must be > 0 and < owners.length
    function submitNewConfirmationsRequired(uint256 newConfirmationsRequired)
        public
        onlyOwner
    {
        require(
            newConfirmationsRequired > 0 &&
                newConfirmationsRequired <= owners.length,
            "invalid number of required confirmations"
        );
        require(
            newConfirmationsRequired != confirmationsRequired,
            "same as previous confirmations required"
        );

        _submitProposal(2, address(0), 0, newConfirmationsRequired);
    }

    /// @notice confirm a proposal, each owner can only confirm once
    /// @param _proposalIndex index of proposal in proposals array
    /// @dev proposal must exist and not have been executed
    function confirmProposal(uint256 _proposalIndex)
        public
        onlyOwner
        proposalExists(_proposalIndex)
        proposalNotExecuted(_proposalIndex)
        proposalNotConfirmed(_proposalIndex)
    {
        Proposal storage proposal = proposals[_proposalIndex];

        require(proposal.expires <= block.timestamp, "proposal expired");

        proposal.numConfirmations += 1;
        proposalIsConfirmed[_proposalIndex][msg.sender] = true;

        emit ConfirmProposal(msg.sender, _proposalIndex);
    }

    /// @notice revoke a proposal confirmation, the owner must have confirmed already to revoke
    /// @param _proposalIndex index of proposal in proposals array
    /// @dev proposal must exist and not have been executed
    function revokeProposal(uint256 _proposalIndex)
        public
        onlyOwner
        proposalExists(_proposalIndex)
        proposalNotExecuted(_proposalIndex)
    {
        Proposal storage proposal = proposals[_proposalIndex];

        require(proposal.expires <= block.timestamp, "proposal expired");
        require(
            proposalIsConfirmed[_proposalIndex][msg.sender],
            "proposal not confirmed"
        );

        proposal.numConfirmations -= 1;
        proposalIsConfirmed[_proposalIndex][msg.sender] = false;

        emit RevokeProposal(msg.sender, _proposalIndex);
    }

    /// @notice execute a proposal once enough confirmations are reached
    /// @param _proposalIndex index of proposal in proposals array
    /// @dev proposal must exist and not have been executed
    function executeProposal(uint256 _proposalIndex)
        public
        onlyOwner
        proposalExists(_proposalIndex)
        proposalNotExecuted(_proposalIndex)
    {
        Proposal storage proposal = proposals[_proposalIndex];

        require(proposal.expires <= block.timestamp, "proposal expired");
        require(
            proposal.numConfirmations >= confirmationsRequired,
            "cannot execute proposal"
        );

        if (proposal.purpose == 0) {
            isOwner[proposal.owner] = true;
            owners.push(proposal.owner);
        } else if (proposal.purpose == 1) {
            require(isOwner[proposal.owner], "address is not owner");
            require(
                proposal.owner == owners[proposal.ownerIndex],
                "owner index not equal to address"
            );

            isOwner[proposal.owner] = false;
            owners[proposal.ownerIndex] = owners[owners.length - 1];
            owners.pop();
        } else if (proposal.purpose == 2) {
            require(
                proposal.newConfirmationsRequired <= owners.length,
                "invalid number of required confirmations"
            );

            confirmationsRequired = proposal.newConfirmationsRequired;
        }

        proposal.executed = true;

        emit ExecuteProposal(msg.sender, _proposalIndex);
    }

    /// @notice returns all owners
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /// @notice returns number of proposals
    function getProposalCount() public view returns (uint256) {
        return proposals.length;
    }

    /// @notice gets all the values for a proposal
    /// @param _proposalIndex index of proposal in proposals array
    function getProposal(uint256 _proposalIndex)
        public
        view
        returns (
            uint8 purpose,
            bool executed,
            address owner,
            uint256 ownerIndex,
            uint256 newConfirmationsRequired,
            uint256 expires,
            uint256 numConfirmations
        )
    {
        Proposal storage proposal = proposals[_proposalIndex];

        return (
            proposal.purpose,
            proposal.executed,
            proposal.owner,
            proposal.ownerIndex,
            proposal.newConfirmationsRequired,
            proposal.expires,
            proposal.numConfirmations
        );
    }

    /// @notice submit a proposal to the array
    /// @param _purpose 0 - add owner, 1 - remove owner, 2 - change confirmations
    /// @param _owner owner to add or remove
    /// @param _ownerIndex index of owner to remove
    /// @param _newConfirmationsRequired new confirmations required value
    /// @dev function is private
    function _submitProposal(
        uint8 _purpose,
        address _owner,
        uint256 _ownerIndex,
        uint256 _newConfirmationsRequired
    ) private {
        proposals.push(
            Proposal({
                purpose: _purpose,
                executed: false,
                owner: _owner,
                ownerIndex: _ownerIndex,
                newConfirmationsRequired: _newConfirmationsRequired,
                expires: block.timestamp + proposalExpiry,
                numConfirmations: 0
            })
        );

        emit SubmitProposal(msg.sender, proposals.length - 1);
    }
}
