// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./Admin.sol";

/// @author Gautham Ganesh Elango
/// @title Multisig contract
contract MultiSig is Admin {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    /// @notice Initializes owners and number of confirmations required
    /// @param _owners owners of the contract
    /// @param _confirmationsRequired confirmations required to execute a transaction
    /// @dev _confirmationsRequired is also the confirmations required to execute a proposal
    constructor(address[] memory _owners, uint256 _confirmationsRequired)
        Admin(_owners, _confirmationsRequired)
    {}

    /// @notice fallback receive function
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /// @param _txIndex index of transaction in transactions array
    /// @dev Throws if transaction doesn't exist
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    /// @param _txIndex index of transaction in transactions array
    /// @dev Throws if transaction has been executed
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    /// @param _txIndex index of transaction in transactions array
    /// @dev Throws if transaction has been confirmed
    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    /// @notice submit a new transaction
    /// @param _to address to send to
    /// @param _value amount to send
    /// @param _data transaction data
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /// @notice confirm a transaction, each owner can only confirm once
    /// @param _txIndex index of transaction in transactions array
    /// @dev transaction must exist and not have been executed
    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    /// @notice revoke a transaction confirmation, the owner must have confirmed already
    /// @param _txIndex index of transaction in transactions array
    /// @dev transaction must exist and not have been executed
    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    /// @notice execute a proposal once enough confirmations are reached
    /// @param _txIndex index of transaction in transactions array
    /// @dev transaction must exist and not have been executed
    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= confirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) =
            transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /// @notice returns number of transactions
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    /// @notice gets all the values for a transaction
    /// @param _txIndex index of transaction in transactions array
    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
