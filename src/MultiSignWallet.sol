// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interface/IMultiSignWallet.sol";

contract MultiSignWallet is IMultiSignWallet {
    address[] public owners;
    Transaction[] public transactions;
    uint256 public minConfirmationsRequired;
    mapping(address account => bool) isOwner;
    mapping(uint256 index => mapping(address owner => bool)) isConfirmed;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _minConfirmationsRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _minConfirmationsRequired > 0 &&
                _minConfirmationsRequired <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        minConfirmationsRequired = _minConfirmationsRequired;
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external override onlyOwner {
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

        emit SubmitTransaction(txIndex, msg.sender, _to, _value, _data);
    }

    function confirmTransaction(
        uint256 _txIndex
    ) external override onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        ++transaction.numConfirmations;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);

    }

    function revokeConfirmation(
        uint256 _txIndex
    ) external override onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(isConfirmed[_txIndex][msg.sender], "Tx not confirmed");

        --transaction.numConfirmations;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint256 _txIndex
    ) external override onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.numConfirmations >= minConfirmationsRequired,
            "cannot execute tx"
        );

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Tx execute failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint) {
        return transactions.length;
    }

    function getTransaction(
        uint _txIndex
    ) external view returns (Transaction memory) {
        return transactions[_txIndex];
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
}