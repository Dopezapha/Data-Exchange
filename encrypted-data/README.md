# Data Marketplace Smart Contract

A Stacks blockchain smart contract for securely buying and selling data assets with built-in marketplace functionality.

## Features

- List data assets for sale with encrypted access keys
- Purchase data assets using STX tokens
- Automated platform fee handling
- User reputation tracking
- Secure access key distribution
- Price management for sellers

## Contract Overview

### Core Functionality

- Data asset listing creation and management
- Secure purchasing mechanism
- Access key distribution to authorized buyers
- Listing price updates
- User profile tracking

### Security Features

- Input validation for all public functions
- Access control for sensitive operations
- Encrypted off-chain storage integration
- Balance verification for purchases

## Data Structures

### Data Listings
```clarity
{
    seller-address: principal,
    listing-price: uint,
    dataset-description: (string-ascii 256),
    dataset-category: (string-ascii 64),
    is-listing-active: bool,
    listing-timestamp: uint
}
```

### User Profiles
```clarity
{
    completed-sales-count: uint,
    seller-rating: uint,
    last-interaction-time: uint
}
```

## Public Functions

### For Sellers

- `create-dataset-listing`: Create new data asset listing
- `update-listing-price`: Update price of existing listing
- `deactivate-listing`: Remove listing from marketplace

### For Buyers

- `purchase-dataset`: Purchase listed data asset
- `get-dataset-access-key`: Retrieve access key for purchased data

### Administrative

- `update-platform-fee`: Update marketplace commission rate

### Read-Only

- `get-listing-details`: View listing information
- `get-participant-profile`: View user marketplace statistics
- `get-total-completed-transactions`: Get total transaction count
- `get-current-platform-fee`: View current platform fee rate

## Error Codes

- `ERROR_NOT_CONTRACT_OWNER`: Operation restricted to contract owner
- `ERROR_DATA_LISTING_NOT_FOUND`: Requested listing doesn't exist
- `ERROR_DATA_ASSET_ALREADY_EXISTS`: Duplicate listing attempt
- `ERROR_BUYER_INSUFFICIENT_BALANCE`: Insufficient funds for purchase
- `ERROR_UNAUTHORIZED_BUYER`: Unauthorized access attempt
- `ERROR_INVALID_LISTING_PRICE`: Invalid price value
- `ERROR_INVALID_PARAMETER`: Invalid input parameter

## Platform Fees

- Default fee: 2%
- Fees automatically split between seller and platform
- Adjustable by contract administrator