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

## Smart Contract Functions

### Public Functions

- `register-property`: Allows landlords to register properties with rent amount and deposit
- `assign-tenant`: Assigns a tenant to a registered property
- `pay-rent`: Enables tenants to pay rent into escrow
- `release-rent`: Releases escrowed rent to landlord if maintenance conditions are met

### Read-Only Functions

- `get-property-details`: Retrieves property information
- `get-escrow-balance`: Checks current escrow balance for a property

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
