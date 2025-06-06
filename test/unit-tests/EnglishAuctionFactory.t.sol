// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {EnglishAuction} from "../../src/EnglishAuction.sol";
import {EnglishAuctionFactory} from "../../src/EnglishAuctionFactory.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract EnglishAuctionFactoryTest is Test {
    EnglishAuctionFactory private englishAuctionFactory;
    MockERC721 private nft;

    address private seller = vm.addr(1);

    uint256 private constant TOKEN_ID = 1;
    uint256 private constant AUCTION_DURATION = 2 days;
    uint256 private constant MIN_BID_INCREMENT = 0.01 ether;

    event AuctionCreated(
        address indexed auctionAddress,
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        uint256 duration,
        uint256 minBidIncrement
    );

    event AuctionRemoved(address indexed nft, uint256 indexed tokenId);

    function setUp() public {
        englishAuctionFactory = new EnglishAuctionFactory();
        nft = new MockERC721();
        vm.deal(seller, 10 ether);
    }

    function testCreateAuction() public {
        nft.mint(seller, TOKEN_ID);

        vm.prank(seller);
        nft.approve(address(englishAuctionFactory), TOKEN_ID);

        vm.prank(seller);
        address auctionAddress =
            englishAuctionFactory.createAuction(address(nft), TOKEN_ID, AUCTION_DURATION, MIN_BID_INCREMENT);

        EnglishAuction auction = EnglishAuction(payable(auctionAddress));

        assertEq(englishAuctionFactory.allAuctions(0), auctionAddress);

        assertEq(auction.seller(), seller);
        assertEq(address(auction.nft()), address(nft));
        assertEq(auction.nftId(), TOKEN_ID);
        assertEq(auction.duration(), AUCTION_DURATION);
        assertEq(auction.minBidIncrement(), MIN_BID_INCREMENT);
    }

    function testCannotCreateDuplicateAuction() public {
        nft.mint(seller, TOKEN_ID);

        vm.prank(seller);
        nft.approve(address(englishAuctionFactory), TOKEN_ID);

        vm.prank(seller);
        englishAuctionFactory.createAuction(address(nft), TOKEN_ID, AUCTION_DURATION, MIN_BID_INCREMENT);

        vm.prank(seller);
        vm.expectRevert("Auction already exists");

        englishAuctionFactory.createAuction(address(nft), TOKEN_ID, AUCTION_DURATION, MIN_BID_INCREMENT);
    }

    function testCreateAuctionRevertsOnZeroAddress() public {
        vm.prank(seller);
        vm.expectRevert("Invalid NFT address");
        englishAuctionFactory.createAuction(address(0), TOKEN_ID, AUCTION_DURATION, MIN_BID_INCREMENT);
    }

    function testCreateAuctionRevertsOnZeroDuration() public {
        vm.prank(seller);
        vm.expectRevert("Duration must be greater than zero");
        englishAuctionFactory.createAuction(address(nft), TOKEN_ID, 0, MIN_BID_INCREMENT);
    }

    function testCreateAuctionRevertsOnDurationTooLong() public {
        vm.prank(seller);
        vm.expectRevert("Duration too long");
        uint256 overDuration = 30 days + 1;

        englishAuctionFactory.createAuction(address(nft), TOKEN_ID, overDuration, MIN_BID_INCREMENT);
    }

    function testCreateAuctionRevertsOnZeroIncrement() public {
        vm.prank(seller);
        vm.expectRevert("Min bid increment must be greater than zero");
        englishAuctionFactory.createAuction(address(nft), TOKEN_ID, AUCTION_DURATION, 0);
    }

    function testRemoveAuctionSucceedsAfterEnded() public {
        nft.mint(seller, TOKEN_ID);

        vm.startPrank(seller);
        nft.approve(address(englishAuctionFactory), TOKEN_ID);
        address auctionAddr =
            englishAuctionFactory.createAuction(address(nft), TOKEN_ID, AUCTION_DURATION, MIN_BID_INCREMENT);

        nft.approve(auctionAddr, TOKEN_ID);
        EnglishAuction(payable(auctionAddr)).start();

        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        EnglishAuction(payable(auctionAddr)).end();

        vm.expectEmit(true, true, false, false);
        emit AuctionRemoved(address(nft), TOKEN_ID);

        englishAuctionFactory.removeAuction(address(nft), TOKEN_ID);
        vm.stopPrank();

        assertEq(englishAuctionFactory.activeAuctions(address(nft), TOKEN_ID), address(0));
    }

    function testRemoveAuctionSucceedsFailsNotEnded() public {
        nft.mint(seller, TOKEN_ID);

        vm.startPrank(seller);
        nft.approve(address(englishAuctionFactory), TOKEN_ID);

        address auctionAddr =
            englishAuctionFactory.createAuction(address(nft), TOKEN_ID, AUCTION_DURATION, MIN_BID_INCREMENT);

        nft.approve(auctionAddr, TOKEN_ID);
        EnglishAuction(payable(auctionAddr)).start();

        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        vm.expectRevert("Auction has not ended yet");
        englishAuctionFactory.removeAuction(address(nft), TOKEN_ID);

        vm.stopPrank();
    }

    function testRemoveAuctionFailsInvalidNFT() public {
        vm.expectRevert("NFT cannot be zero address");
        englishAuctionFactory.removeAuction(address(0), TOKEN_ID);
    }

    function testRemoveAuctionFailsIfNoAuction() public {
        vm.expectRevert("No active auction for the NFT");
        englishAuctionFactory.removeAuction(address(nft), TOKEN_ID);
    }

    function testFuzzCreateAuctionValidArgs(uint256 duration, uint256 increment, address user, uint256 tokenId)
        public
    {
        vm.assume(user != address(0));
        vm.assume(duration > 0 && duration <= englishAuctionFactory.MAX_AUCTION_DURATION());
        vm.assume(increment > 0);
        vm.assume(tokenId > 0 && tokenId < type(uint256).max);

        nft.mint(user, tokenId);

        vm.startPrank(user);
        nft.approve(address(englishAuctionFactory), tokenId);
        address auctionAddress = englishAuctionFactory.createAuction(address(nft), tokenId, duration, increment);
        vm.stopPrank();

        assertEq(englishAuctionFactory.activeAuctions(address(nft), tokenId), auctionAddress);
    }

    function testFuzzCreateAuctionRejectsZeroIncrement(uint256 tokenId, uint256 duration) public {
        vm.assume(tokenId > 0 && tokenId < type(uint256).max);
        vm.assume(duration > 0 && duration <= englishAuctionFactory.MAX_AUCTION_DURATION());

        nft.mint(seller, tokenId);
        vm.startPrank(seller);
        nft.approve(address(englishAuctionFactory), tokenId);

        vm.expectRevert("Min bid increment must be greater than zero");
        englishAuctionFactory.createAuction(address(nft), tokenId, duration, 0);
        vm.stopPrank();
    }

    function testFuzzCreateAuctionRejectsDurationTooLong(uint256 tokenId, uint256 longDuration) public {
        uint256 maxDuration = englishAuctionFactory.MAX_AUCTION_DURATION();
        vm.assume(longDuration > maxDuration && longDuration < type(uint256).max); // prevent overflow edge case

        nft.mint(seller, tokenId);
        vm.startPrank(seller);
        nft.approve(address(englishAuctionFactory), tokenId);

        vm.expectRevert("Duration too long");
        englishAuctionFactory.createAuction(address(nft), tokenId, longDuration, MIN_BID_INCREMENT);
        vm.stopPrank();
    }
}
