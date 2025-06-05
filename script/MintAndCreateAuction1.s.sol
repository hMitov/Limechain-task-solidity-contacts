// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ScriptConfig} from "./ScriptConfig.s.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title  MintAndCreateAuction1Script
/// @notice Mints an NFT and creates an auction for it using the EnglishAuctionFactory
/// @dev    Requires environment variables to be set in `.env` file
contract MintAndCreateAuction1Script is Script, ScriptConfig {
    EnglishAuctionFactory private factory;
    MyNFT private nft;
    uint256 private mintPrice;
    uint256 private auctionDuration;
    uint256 private minBidIncrement;
    uint256 private privateKey;
    address private sender;

    /// @notice Deploys a new English auction for a newly minted NFT
    /// @dev    Requires the following environment variables:
    /// - TEST_ACCOUNT_1_PRIVATE_KEY: Private key used for broadcasting transactions
    /// - AUCTION_FACTORY_ADDRESS: Address of the deployed EnglishAuctionFactory contract
    /// - NFT_CONTRACT_ADDRESS: Address of the deployed MyNFT contract
    /// - MINT_PUBLIC_PRICE: Price required to mint an NFT during the public sale
    /// - AUCTION_DURATION: Duration (in seconds) for the auction
    /// - AUCTION_MIN_BID_INCREMENT: Minimum bid increment for the auction
    /// This function mints an NFT, creates an auction, and approves the auction to transfer the token.
    function run() public {
        loadEnvVars();

        vm.startBroadcast(privateKey);

        uint256 tokenId = mintNFT();
        address auctionAddress = deployAuction(tokenId);
        approveAuction(tokenId, auctionAddress);

        vm.stopBroadcast();
    }

    function loadEnvVars() internal override {
        privateKey = getEnvPrivateKey("TEST_ACCOUNT_1_PRIVATE_KEY");
        sender = vm.addr(privateKey);

        factory = EnglishAuctionFactory(getEnvAddress("AUCTION_FACTORY_ADDRESS"));
        nft = MyNFT(getEnvAddress("NFT_CONTRACT_ADDRESS"));
        mintPrice = getEnvUint("MINT_PUBLIC_PRICE");
        auctionDuration = getEnvUint("AUCTION_DURATION");
        minBidIncrement = getEnvUint("AUCTION_MIN_BID_INCREMENT");
    }

    function mintNFT() internal returns (uint256 tokenId) {
        require(sender.balance >= mintPrice, "Insufficient ETH for mint");

        nft.mintPublicSale{value: mintPrice}();
        tokenId = nft.totalMinted();
    }

    function approveAuction(uint256 tokenId, address auctionAddress) internal {
        nft.approve(auctionAddress, tokenId);
    }

    function deployAuction(uint256 tokenId) internal returns (address auctionAddress) {
        auctionAddress = factory.createAuction(address(nft), tokenId, auctionDuration, minBidIncrement);
    }
}
