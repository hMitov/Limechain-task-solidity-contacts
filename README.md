# NFT English Auction System

A decentralized auction system built on Ethereum that allows users to create and participate in English auctions for NFTs.

## Overview

This project implements a complete NFT auction system with the following components:

1. **MyNFT**: A custom ERC721 token contract with public and private sale functionality
2. **EnglishAuction**: A contract that manages individual NFT auctions
3. **EnglishAuctionFactory**: A factory contract that creates and manages multiple english auctions

## Features

### MyNFT Contract
- ERC721 compliant NFT implementation
- Public and private sale functionality
- Whitelist management for private sales
- Configurable sale prices
- Maximum supply limit
- Base URI management

### EnglishAuction Contract
- Time-limited auctions
- Minimum bid increment enforcement
- Bid withdrawal functionality
- Auction cancellation (when no bids exist)
- Automatic NFT transfer to winner
- Automatic ETH transfer to seller

### EnglishAuctionFactory Contract
- Creates new auction instances
- Tracks all active auctions
- Prevents duplicate auctions for the same NFT

## Technical Details

### Contracts
- `MyNFT.sol`: Custom ERC721 implementation
- `EnglishAuction.sol`: Individual auction management
- `EnglishAuctionFactory.sol`: Auction creation and management

### Dependencies
- OpenZeppelin Contracts (ERC721, Ownable, ReentrancyGuard)
- Forge Standard Library

## Deployment

The project uses Foundry for contract deployment on the Sepolia testnet. Foundry provides a robust and efficient way to deploy and interact with smart contracts. The deployment process involves:

1. Deploying the NFT contract
2. Deploying the Auction Factory
3. Creating auctions through the factory
4. Starting the auction

### Deployment Commands

The `--broadcast` flag can be used with different verbosity levels:
- `-v`: Basic transaction information
- `-vv`: Transaction information and contract addresses
- `-vvv`: Transaction information, contract addresses, and function calls
- `-vvvv`: Full transaction information, contract addresses, function calls, and stack traces

1. Deploy the NFT contract:
```shell
source .env            
forge script script/MyNFT.s.sol:MyNFTScript --rpc-url $SEPOLIA_RPC_URL --broadcast -v
```

2. Deploy the Auction Factory:
```shell
source .env            
forge script script/DeployFactory.s.sol:DeployFactoryScript --rpc-url $SEPOLIA_RPC_URL --broadcast -v
```

 ⚠️ IMPORTANT: You must start the API before creating English auctions so that it can detect their creation and begin listening for related events.
   ```

3. Create an auction:
```shell
source .env      
forge script script/DeployEnglishAuction1.s.sol:DeployEnglishAuction1Script --rpc-url $SEPOLIA_RPC_URL --broadcast -v
```

4. Start the auction:
```shell
source .env               
forge script script/StartAuction1.s.sol:StartAuction1Script --rpc-url $SEPOLIA_RPC_URL --broadcast -v
```

Each deployment script uses Foundry's scripting capabilities to:
- Load environment variables
- Connect to the Sepolia network
- Deploy contracts with the specified parameters
- Broadcast transactions to the network
- Provide detailed transaction information

### Environment Variables
Required environment variables in `.env`:
- `SEPOLIA_RPC_URL`: RPC endpoint for Sepolia
- `TEST_ACCOUNT_1_PRIVATE_KEY`: Private key for deployment
- `TEST_ACCOUNT_2_PRIVATE_KEY`: Private key for testing
- `NFT_CONTRACT_ADDRESS`: Deployed NFT contract address (update after NFT deployment)
- `AUCTION_FACTORY_ADDRESS`: Deployed factory contract address (update after factory deployment)
- `AUCTION_1_ADDRESS`: Individual auction contract address (update after auction creation)
- `AUCTION_2_ADDRESS`: Individual auction contract address (update after auction creation)

### API Repository Updates

After deploying the contracts, it is **CRUCIAL** to update the following addresses in the API repository:

1. NFT Contract Address:
   - **Update this in the API repository .env file**

2. Auction Factory Address:
   - **Update this in the API repository .env file**


These updates are **ESSENTIAL** for:
- Proper interaction between the API and smart contracts
- Correct auction creation and management
- NFT minting and transfer functionality

## Testing

The project includes comprehensive tests for all contracts:
- NFT minting and transfer tests
- Auction creation and management tests
- Bid placement and withdrawal tests
- Auction end and cancellation tests

## Usage

### Creating an Auction
1. Deploy the NFT contract
2. Deploy the Auction Factory
3. Mint an NFT
4. Create an auction through the factory
5. Start the auction

### Participating in an Auction
1. Place bids (must be higher than current bid + minimum increment)
2. Withdraw bids if outbid
3. Wait for auction end
4. Winner receives NFT, seller receives ETH

## Security Features
- Reentrancy protection
- Ownership checks
- Bid validation
- Safe ETH transfers
- NFT approval system

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

### Foundry Commands

#### Build
```shell
$ forge build
```
Compiles all contracts in the project.

#### Test
```shell
# Run all tests
$ forge test

# Run tests with detailed gas information
$ forge test --gas-report

# Run a specific test file
$ forge test --match-path test/EnglishAuction.t.sol

# Run a specific test function
$ forge test --match-test testStartAuction

# Run tests with more verbose output
$ forge test -vv
```

## Documentation
- Foundry Documentation: https://book.getfoundry.sh/

## License
MIT License
