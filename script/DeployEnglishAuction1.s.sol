// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title  DeployEnglishAuction1Script
/// @notice Mints an NFT and creates an auction for it using the EnglishAuctionFactory
/// @dev    Requires environment variables to be set in `.env` file
contract DeployEnglishAuction1Script is Script {
    /// @notice Main script execution entry point
    /// @dev    Requires the following environment variables:
    /// - TEST_ACCOUNT_1_PRIVATE_KEY: Private key used for broadcasting transactions
    /// - AUCTION_FACTORY_ADDRESS: Address of the deployed EnglishAuctionFactory contract
    /// - NFT_CONTRACT_ADDRESS: Address of the deployed MyNFT contract
    /// - MINT_PUBLIC_PRICE: Price required to mint an NFT during the public sale
    /// - AUCTION_DURATION: Duration (in seconds) for the auction
    /// - AUCTION_MIN_BID_INCREMENT: Minimum bid increment for the auction
    /// This function mints an NFT, creates an auction, and approves the auction to transfer the token.
    function run() public {
        bytes32 pkBytes = vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY");
        require(pkBytes != bytes32(0), "Missing TEST_ACCOUNT_1_PRIVATE_KEY");
        uint256 privateKey = uint256(pkBytes);

        address factoryAddress = vm.envAddress("AUCTION_FACTORY_ADDRESS");
        require(factoryAddress != address(0), "Missing or invalid AUCTION_FACTORY_ADDRESS");

        address nftAddress = vm.envAddress("NFT_CONTRACT_ADDRESS");
        require(nftAddress != address(0), "Missing or invalid NFT_CONTRACT_ADDRESS");

        uint256 mintPrice = vm.envUint("MINT_PUBLIC_PRICE");
        require(mintPrice > 0, "Invalid MINT_PUBLIC_PRICE");

        uint256 auctionDuration = vm.envUint("AUCTION_DURATION");
        require(auctionDuration > 0, "Invalid AUCTION_DURATION");

        uint256 minBidIncrement = vm.envUint("AUCTION_MIN_BID_INCREMENT");
        require(minBidIncrement > 0, "Invalid AUCTION_MIN_BID_INCREMENT");

        vm.startBroadcast(privateKey);

        EnglishAuctionFactory factory = EnglishAuctionFactory(factoryAddress);
        MyNFT nft = MyNFT(nftAddress);

        nft.mintPublicSale{value: mintPrice}();
        uint256 tokenId = nft.totalMinted();

        address auctionAddress = factory.createAuction(nftAddress, tokenId, auctionDuration, minBidIncrement);

        nft.approve(auctionAddress, tokenId);

        vm.stopBroadcast();
    }
}
