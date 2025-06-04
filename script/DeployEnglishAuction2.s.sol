// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ScriptUtils} from "./ScriptUtils.s.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title  DeployEnglishAuction2Script
/// @notice Mints an NFT and creates an auction for it using the EnglishAuctionFactory
/// @dev    Requires environment variables to be set in `.env` file
contract DeployEnglishAuction2Script is Script, ScriptUtils {
    /// @notice Deploys a new English auction for a newly minted NFT
    /// @dev    Requires the following environment variables:
    /// - TEST_ACCOUNT_2_PRIVATE_KEY: Private key used for broadcasting transactions
    /// - AUCTION_FACTORY_ADDRESS: Address of the deployed EnglishAuctionFactory contract
    /// - NFT_CONTRACT_ADDRESS: Address of the deployed MyNFT contract
    /// - MINT_PUBLIC_PRICE: Price required to mint an NFT during the public sale
    /// - AUCTION_DURATION: Duration (in seconds) for the auction
    /// - AUCTION_MIN_BID_INCREMENT: Minimum bid increment for the auction
    /// This function mints an NFT, creates an auction, and approves the auction to transfer the token.   
    function run() public {
        uint256 privateKey = getEnvPrivateKey("TEST_ACCOUNT_2_PRIVATE_KEY");

        address factoryAddress = getEnvAddress("AUCTION_FACTORY_ADDRESS");
        address nftAddress = getEnvAddress("NFT_CONTRACT_ADDRESS");
        uint256 mintPrice = getEnvUint("MINT_PUBLIC_PRICE");
        uint256 auctionDuration = getEnvUint("AUCTION_DURATION");
        uint256 minBidIncrement = getEnvUint("AUCTION_MIN_BID_INCREMENT");

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
