// SPDX-License-Identifier: MIT

/*

  /$$$$$$          /$$                     /$$$$$$$   /$$$$$$   /$$$$$$ 
 /$$__  $$        |__/                    | $$__  $$ /$$__  $$ /$$__  $$
| $$  \__//$$$$$$  /$$  /$$$$$$   /$$$$$$$| $$  \ $$| $$  \ $$| $$  \ $$
| $$$$   /$$__  $$| $$ /$$__  $$ /$$_____/| $$  | $$| $$$$$$$$| $$  | $$
| $$_/  | $$  \__/| $$| $$$$$$$$|  $$$$$$ | $$  | $$| $$__  $$| $$  | $$
| $$    | $$      | $$| $$_____/ \____  $$| $$  | $$| $$  | $$| $$  | $$
| $$    | $$      | $$|  $$$$$$$ /$$$$$$$/| $$$$$$$/| $$  | $$|  $$$$$$/
|__/    |__/      |__/ \_______/|_______/ |_______/ |__/  |__/ \______/ 

*/

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Context.sol";

contract FriesDAOMultisig is Context {

    struct Transaction {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        bool pending;
    }

    address[] public signers; // Multisig signer wallets

    mapping (uint256 => Transaction) public transactions;             // Proposed and executed multisig transactions by transaction ID
    mapping (uint256 => mapping (address => bool)) public signatures; // Signatures by signers for each transaction by transaction ID
    uint256 public required;                                          // Number of signatures required to execute a transaction
    uint256 public transactionCount = 0;                              // Number of total proposed transactions

    event SignerAdded(address added);
    event SignerRemoved(address removed);

    event TransactionProposed(uint256 id);
    event TransactionExecuted(uint256 id);
    event TransactionCanceled(uint256 id);

    event SignerConfirmed(uint256 id);
    event SignerRevoked(uint256 id);
    event RequiredChanged(uint256 required);

    // Only allow multisig to call a function

    modifier onlyMultisig {
        require(_msgSender() == address(this), "FriesDAOMultisig: caller is not the multisig");
        _;
    }

    // Only allow a multisig signer wallet to call a function

    modifier onlySigner {
        require(isSigner(_msgSender()), "FriesDAOMultisig: caller is not a signer");
        _;
    }

    // Only call a function if a transaction with ID is pending execution

    modifier onlyTransactionActive(uint256 id) {
        require(id < transactionCount, "Multisig: transaction does not exist");
        require(transactions[id].pending, "Multisig: transaction is not pending execution");
        _;
    }

    // Initialize signer wallets including the deployer and set required count

    constructor(address[] memory signerWallets, uint256 requiredSignatures) {
        signers.push(_msgSender());
        emit SignerAdded(_msgSender());

        for (uint256 s = 0; s < signerWallets.length; s ++) {
            signers.push(signerWallets[s]);
            emit SignerAdded(signerWallets[s]);
        }

        required = requiredSignatures;
        emit RequiredChanged(required);
    }

    // Add a signer to the multisig

    function addSigner(address account) external onlyMultisig {
        require(!isSigner(account), "FriesDAOMultisig: account is already a signer");
        signers.push(account);
        emit SignerAdded(account);
    }

    // Remove a signer from the multisig

    function removeSigner(address account) external onlyMultisig {
        require(isSigner(account), "FriesDAOMultisig: account is not a signer");
        for (uint256 s = 0; s < signers.length; s ++) {
            if (signers[s] == account) {
                signers[s] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
        emit SignerRemoved(account);
    }

    // Change required signatures to execute a transaction

    function changeRequired(uint256 requiredSignatures) external onlyMultisig {
        require(requiredSignatures > 0 && requiredSignatures <= signers.length, "FriesDAOMultisig: invalid amount of required signatures");
        required = requiredSignatures;
        emit RequiredChanged(required);
    }

    // Propose a transaction to be executed by the multisig

    function proposeTransaction(address txTarget, uint256 txValue, bytes calldata txData) external onlySigner {
        uint256 id = transactionCount;
        transactions[id] = Transaction({
            proposer: _msgSender(),
            target: txTarget,
            value: txValue,
            data: txData,
            pending: true
        });
        transactionCount ++;
        emit TransactionProposed(id);
    }

    // Cancel a pending transaction

    function cancelTransaction(uint256 id) external onlyTransactionActive(id) {
        Transaction storage transaction = transactions[id];
        require(_msgSender() == transaction.proposer, "FriesDAOMultisig: caller is not the proposer of the transaction");
        transaction.pending = false;
        emit TransactionCanceled(id);
    }

    // Execute a pending transaction with sufficient signatures

    function executeTransaction(uint256 id) external onlySigner onlyTransactionActive(id) returns (bytes memory) {
        Transaction storage transaction = transactions[id];

        uint256 signs = 0;
        for (uint256 s = 0; s < signers.length; s ++) {
            if (signatures[id][signers[s]]) {
                signs ++;
            }
        }
        require(signs >= required, "FriesDAOMultisig: insufficient signatures");

        transaction.pending = false;
        (bool success, bytes memory result) = transaction.target.call{value: transaction.value}(transaction.data);
        require(success, "FriesDAOMultisig: transaction call failed");

        emit TransactionExecuted(id);
        return result;
    }

    // Sign off on a transaction to be executed by the multisig

    function signTransaction(uint256 id) external onlySigner onlyTransactionActive(id) {
        require(!signatures[id][_msgSender()], "FriesDAOMultisig: transaction already signed by signer");
        signatures[id][_msgSender()] = true;
        emit SignerConfirmed(id);
    }

    // Revoke a signature on a transaction to be executed by the multisig

    function revokeSignature(uint256 id) external onlySigner onlyTransactionActive(id) {
        require(signatures[id][_msgSender()], "FriesDAOMultisig: transaction not signed by signer");
        delete signatures[id][_msgSender()];
        emit SignerRevoked(id);
    }

    // Check if account is a signer wallet

    function isSigner(address account) public view returns (bool) {
        for (uint256 s = 0; s < signers.length; s ++) {
            if (signers[s] == account) {
                return true;
            }
        }
        return false;
    }

    // Default functions

    receive() external payable {}

}