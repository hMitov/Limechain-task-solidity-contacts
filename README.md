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
- Pause/unpause functionality for emergency situations
- Auction extension when bids are placed near the end
- Comprehensive event logging for all actions

### EnglishAuctionFactory Contract
- Creates new auction instances
- Tracks all active auctions
- Prevents duplicate auctions for the same NFT
- Maximum auction duration enforcement
- Auction removal functionality

## Technical Details

### Contracts
- `MyNFT.sol`: Custom ERC721 implementation with royalty support
- `EnglishAuction.sol`: Individual auction management
- `EnglishAuctionFactory.sol`: Auction creation and management

### Dependencies
- OpenZeppelin Contracts (ERC721, AccessControl, ReentrancyGuard, Pausable, ERC2981)
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
forge script script/NFTDeployWithPublicSale.s.sol:NFTDeployWithPublicSaleScript --rpc-url $SEPOLIA_RPC_URL --broadcast -vvv
```
⚠️ **IMPORTANT**: You must set the following contract address in .env
   ```
   NFT_CONTRACT_ADDRESS=your_nft_contract_address
   ```

2. Deploy the English Auction factory:
```shell
source .env            
forge script script/DeployAuctionFactory.s.sol:DeployAuctionFactoryScript --rpc-url $SEPOLIA_RPC_URL --broadcast -vvv

```
⚠️ **IMPORTANT**: You must set the following contract address in .env
   ```
   AUCTION_FACTORY_ADDRESS=your_auction_factory_address
   ```

3. Create first auction:
```shell
source .env      
forge script script/MintAndCreateAuction1.s.sol:MintAndCreateAuction1Script --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvvv
```

⚠️ **IMPORTANT**: You must set the following contract address in .env
   ```
   AUCTION_1_ADDRESS=your_first_auction_address
   ```

4. Start first auction:
```shell
source .env               
forge script script/StartAuction1.s.sol:StartAuction1Script --rpc-url $SEPOLIA_RPC_URL --broadcast -v
```

5. Create second auction:
```shell
source .env      
forge script script/MintAndCreateAuction2.s.sol:MintAndCreateAuction2Script --rpc-url $SEPOLIA_RPC_URL --broadcast -vvvvv
```

⚠️ **IMPORTANT**: You must set the following contract address in .env
   ```
   AUCTION_2_ADDRESS=your_second_auction_address
   ```

6. Start second auction:
```shell
source .env               
forge script script/StartAuction2.s.sol:StartAuction2Script --rpc-url $SEPOLIA_RPC_URL --broadcast -v

```
Each deployment script uses Foundry's scripting capabilities to:
- Load environment variables
- Connect to the Sepolia network
- Deploy contracts with the specified parameters
- Broadcast transactions to the network
- Provide detailed transaction information

### Environment Variables
Required environment variables in `.env`:
- `SEPOLIA_RPC_URL`: RPC endpoint for Sepolia testnet
- `TEST_ACCOUNT_1_PRIVATE_KEY`: Private key for deployment and first auction
- `TEST_ACCOUNT_2_PRIVATE_KEY`: Private key for second auction
- `NFT_NAME`: Name of the NFT collection
- `NFT_SYMBOL`: Symbol of the NFT collection
- `NFT_URI`: Base URI for NFT metadata
- `NFT_MAX_SUPPLY`: Maximum number of NFTs that can be minted
- `MINT_PUBLIC_PRICE`: Price required to mint an NFT during public sale
- `AUCTION_DURATION`: Duration (in seconds) for auctions
- `AUCTION_MIN_BID_INCREMENT`: Minimum bid increment for auctions
- `NFT_ROYALTY_RECEIVER`: Public address to receive secondary sale royaltie
- `NFT_ROYALTY_NOMINATOR`: Royalty fee in basis points (e.g., 500 = 5%)   

### API Repository Updates

After deploying the contracts, it is **CRUCIAL** to update the following addresses in the API repository:

1. NFT Contract Address:
   - Update in the API repository's `.env` file
   - Used for NFT minting and transfer operations

2. Auction Factory Address:
   - Update in the API repository's `.env` file
   - Used for auction creation and management

3. Individual Auction Addresses:
   - Update in the API repository's `.env` file
   - Used for bid placement and auction interaction

These updates are **ESSENTIAL** for:
- Proper interaction between the API and smart contracts
- Correct auction creation and management
- NFT minting and transfer functionality
- Real-time auction status updates

## Testing

The project includes comprehensive tests for all contracts:

### Unit Tests
- NFT minting and transfer tests
- Auction creation and management tests
- Bid placement and withdrawal tests
- Auction end and cancellation tests
- Fuzzing tests for edge cases and parameter validation
- Pause/unpause functionality tests
- Auction extension tests
- Event emission verification

### Integration Tests
- Complete auction lifecycle with royalty payments
- Bid validation and withdrawal functionality
- Auction cancellation and extension scenarios
- Factory auction tracking and removal
- NFT ownership and royalty distribution

The integration tests verify key scenarios like bid validation, auction timing, and proper fund distribution between participants.

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
- Role checks
- Bid validation
- Safe ETH transfers
- NFT approval system
- Emergency pause functionality
- Input validation for all parameters
- Maximum duration limits
- Zero address checks
- Duplicate auction prevention
- Royalty support for NFT creators

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
