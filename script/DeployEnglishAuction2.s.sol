// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title  DeployEnglishAuction2Script
/// @notice Mints an NFT and creates an auction for it using the EnglishAuctionFactory
/// @dev    Requires environment variables to be set in `.env` file
contract DeployEnglishAuction2Script is Script {
    /// @notice Deploys a new English auction for a newly minted NFT
    /// @dev    Requires the following environment variables:
    /// - TEST_ACCOUNT_2_PRIVATE_KEY: Private key used for broadcasting transactions
    /// - AUCTION_FACTORY_ADDRESS: Address of the deployed EnglishAuctionFactory contract
    /// - NFT_CONTRACT_ADDRESS: Address of the deployed MyNFT contract
    /// - MINT_PUBLIC_PRICE: Price required to mint an NFT during the public sale
    /// - AUCTION_DURATION: Duration (in seconds) for the auction
    /// - AUCTION_MIN_BID_INCREMENT: Minimum bid increment for the auction
    function run() public {
        uint256 privateKey;
        try vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY") returns (bytes32 keyBytes) {
            require(keyBytes != bytes32(0), "TEST_ACCOUNT_1_PRIVATE_KEY is empty");
            privateKey = uint256(keyBytes);
        } catch {
            revert("TEST_ACCOUNT_1_PRIVATE_KEY is missing in .env");
        }

        address factoryAddress;
        try vm.envAddress("AUCTION_FACTORY_ADDRESS") returns (address addr) {
            require(addr != address(0), "AUCTION_FACTORY_ADDRESS is zero address");
            factoryAddress = addr;
        } catch {
            revert("AUCTION_FACTORY_ADDRESS is missing or invalid");
        }

        address nftAddress;
        try vm.envAddress("NFT_CONTRACT_ADDRESS") returns (address addr) {
            require(addr != address(0), "NFT_CONTRACT_ADDRESS is zero address");
            nftAddress = addr;
        } catch {
            revert("NFT_CONTRACT_ADDRESS is missing or invalid");
        }

        uint256 mintPrice;
        try vm.envUint("MINT_PUBLIC_PRICE") returns (uint256 val) {
            require(val > 0, "MINT_PUBLIC_PRICE must be > 0");
            mintPrice = val;
        } catch {
            revert("MINT_PUBLIC_PRICE is missing or invalid");
        }

        uint256 auctionDuration;
        try vm.envUint("AUCTION_DURATION") returns (uint256 val) {
            require(val > 0, "AUCTION_DURATION must be > 0");
            auctionDuration = val;
        } catch {
            revert("AUCTION_DURATION is missing or invalid");
        }

        uint256 minBidIncrement;
        try vm.envUint("AUCTION_MIN_BID_INCREMENT") returns (uint256 val) {
            require(val > 0, "AUCTION_MIN_BID_INCREMENT must be > 0");
            minBidIncrement = val;
        } catch {
            revert("AUCTION_MIN_BID_INCREMENT is missing or invalid");
        }

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
