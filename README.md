# SafeNest

A secure smart contract for managing digital assets on the Stacks blockchain. SafeNest provides features for:

- Depositing and withdrawing assets
- Setting time locks on assets
- Multi-signature requirements for withdrawals
- Emergency asset recovery
- Allowance management for approved addresses

## Features

- Secure asset storage with time-locking capabilities
- Multi-signature support for enhanced security
  - Configurable number of required signatures
  - Two-step withdrawal process with signature tracking
  - Protection against duplicate signatures
- Emergency recovery mechanism
- Allowance system for controlled spending
- Full audit trail of all operations

## Multi-Signature Withdrawals

The contract now supports a robust multi-signature withdrawal process:

1. A user initiates a withdrawal request
2. Authorized signers can approve the request
3. When sufficient signatures are collected, the withdrawal executes automatically
4. Signature tracking prevents duplicate approvals
5. Withdrawal requests can be queried for status updates

## Security

The contract implements multiple security measures including:
- Time locks
- Multi-signature requirements
- Emergency recovery addresses
- Withdrawal limits
- Activity monitoring
- Signature validation and tracking

## Usage

See the contract documentation for detailed usage instructions and function definitions.
