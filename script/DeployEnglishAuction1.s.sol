// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DeployEnglishAuction1Script is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey1 = uint256(vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY"));
        vm.startBroadcast(privateKey1);

        // Replace with your actual deployed factory address
        address factoryAddress = vm.envAddress("AUCTION_FACTORY_ADDRESS");
        EnglishAuctionFactory factory = EnglishAuctionFactory(factoryAddress);

        address nftAddress = vm.envAddress("NFT_CONTRACT_ADDRESS");
        MyNFT nft = MyNFT(nftAddress);
        nft.mintPublicSale{value: 0.001 ether}();
        uint256 tokenId = nft.totalMinted();

        // Deploy auction via factory
        address auctionAddress = factory.createAuction(
            nftAddress,
            tokenId,
            2 days,
            0.001 ether
        );

        // Approve auction to transfer NFT
        nft.approve(auctionAddress, tokenId);
        vm.stopBroadcast();
    }
} 