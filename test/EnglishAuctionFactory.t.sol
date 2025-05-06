// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/EnglishAuction.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    // function approve(address to, uint256 tokenId) external {
    //   _approve[tokenId] = to;
    // }

    // function ownerOf(uint256 tokenId) external view returns (address) {
    //    return _owners[tokenId];
    // }
}

contract EnglishAuctionFactoryTest is Test {
    EnglishAuctionFactory private englishAuctionFactory;
    MockERC721 private nft;
    address private seller;

    event AuctionCreated(
        address indexed auctionAddress,
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        uint256 duration,
        uint256 minBidIncrement
    );

    function setUp() public {
        englishAuctionFactory = new EnglishAuctionFactory();
        seller = vm.addr(1);
        vm.deal(seller, 10 ether);

        nft = new MockERC721();
        uint256 tokenId = 1;
        nft.mint(seller, tokenId);

        vm.startPrank(seller);
        nft.approve(address(this), tokenId);
        vm.stopPrank();
    }

    function testCreateAuction() public {
        // Set both msg.sender and tx.origin to be the seller
        vm.prank(seller, seller);
        vm.deal(seller, 10 ether);

        vm.expectEmit(false, true, true, true);
        emit AuctionCreated(address(0), seller, address(nft), 1, 2 days, 0.01 ether);

        address auctionAddress = englishAuctionFactory.createAuction(address(nft), 1, 2 days, 0.01 ether);
        EnglishAuction createdAuction = EnglishAuction(payable(auctionAddress));

        assertEq(englishAuctionFactory.allAuctions(0), auctionAddress, "Auction not added to allAuctions");
        assertEq(createdAuction.seller(), seller, "Seller address incorrect");
        assertEq(address(createdAuction.nft()), address(nft), "NFT address incorrect");
        assertEq(createdAuction.nftId(), 1, "Token ID incorrect");
        assertEq(createdAuction.duration(), 2 days, "Duration incorrect");
        assertEq(createdAuction.minBidIncrement(), 0.01 ether, "Min bid increment incorrect");
    }

    function testCannotCreateDuplicateAuction() public {
        vm.prank(seller, seller);
        vm.deal(seller, 10 ether);
        englishAuctionFactory.createAuction(address(nft), 1, 2 days, 0.01 ether);

        // Try to create another auction for the same NFT and token ID
        vm.expectRevert("Auction already exists for this NFT");
        englishAuctionFactory.createAuction(address(nft), 1, 2 days, 0.01 ether);
    }
}
