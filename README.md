# Decentralized Rent Escrow

A blockchain-based solution for secure and transparent rental payments using smart contracts on the Stacks network.

## Overview

This project implements a decentralized rent escrow system where rent payments are held in escrow and released to landlords only after property maintenance standards are met. This creates accountability and trust between landlords and tenants.

## Features

- Property registration by landlords
- Tenant assignment system
- Automated rent collection and escrow
- Maintenance-based rent release mechanism
- Balance tracking and verification
- **Digital Access Keys**: Secure NFT-based property access management

## Smart Contract Functions

### Public Functions

- `register-property`: Allows landlords to register properties with rent amount and deposit
- `assign-tenant`: Assigns a tenant to a registered property
- `pay-rent`: Enables tenants to pay rent into escrow
- `release-rent`: Releases escrowed rent to landlord if maintenance conditions are met

### Read-Only Functions

- `get-property-details`: Retrieves property information
- `get-escrow-balance`: Checks current escrow balance for a property

## Digital Access Keys

The Digital Access Keys feature provides a secure, blockchain-based solution for property access management using non-fungible tokens (NFTs). This feature enables landlords to issue time-bound, revocable digital keys to tenants that can be verified by smart locks and IoT devices.

### Key Features

- **Time-bound Access**: Keys automatically expire after a specified duration
- **Revocable**: Landlords can instantly revoke access when needed
- **Non-transferable**: Keys cannot be transferred between users
- **IoT Compatible**: External systems can verify access permissions
- **Self-contained**: Works independently of other contracts

### Access Keys Contract Functions

#### Public Functions

- `mint-access-key(tenant, property, duration-blocks)`: Issues a new digital key
- `revoke-access-key(token-id)`: Revokes an existing key (landlord only)
- `extend-access-key(token-id, additional-blocks)`: Extends key expiration

#### Read-Only Functions

- `has-valid-access-key(tenant, property)`: Verifies if tenant has valid access
- `verify-property-access(tenant, property)`: IoT-friendly access verification
- `get-access-key-details(token-id)`: Retrieves key metadata
- `get-contract-info()`: Returns contract statistics

### Usage Example

```clarity
;; Landlord issues a 30-day access key to tenant
(contract-call? .access-keys mint-access-key 
    'SP1TENANT123... 
    'SP1PROPERTY456... 
    u4320) ;; ~30 days in blocks

;; Smart lock verifies tenant access
(contract-call? .access-keys verify-property-access 
    'SP1TENANT123... 
    'SP1PROPERTY456...)
;; Returns: { access-granted: true, verified-at: block-height, ... }
```

### Integration with IoT Devices

Smart locks and IoT devices can query the blockchain to verify access permissions:

1. Tenant presents digital wallet/key
2. Device calls `has-valid-access-key` function
3. Access granted if key is valid and not expired
4. All access attempts are recorded on-chain

## Testing

The project includes comprehensive tests using Vitest and Clarinet:

- Property registration validation
- Tenant assignment verification
- Rent payment processing
- Escrow balance tracking

## Technical Stack

- Language: Clarity (Smart Contracts)
- Testing Framework: Vitest
- Development Environment: Clarinet
- Network: Stacks Blockchain
