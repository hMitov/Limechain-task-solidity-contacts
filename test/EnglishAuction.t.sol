// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract EnglishAuctionTest is Test {
    EnglishAuction private auction;
    MockERC721 private nft;
    address private seller = address(1);
    address private bidder1 = address(2);
    address private bidder2 = address(3);
    uint256 private nftId = 1;
    uint256 private startingBid = 1 ether;
    uint256 private duration = 3 days;
    uint256 private minBidIncrement = 0.1 ether;

    address owner = address(1);
    address nonOwner = address(2);

    error OwnableUnauthorizedAccount(address account);

    event AuctionStarted(uint256 startTime, uint256 endTime);
    event BidPlaced(address indexed bidder, uint256 amount);
    event Withdrawal(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event AuctionCancelled();

    function setUp() public {
        vm.startPrank(seller);
        nft = new MockERC721();
        nft.mint(seller, nftId);
        auction = new EnglishAuction(address(nft), nftId, duration, minBidIncrement);
        vm.stopPrank();
    }

    function testStartAuctionFailNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        auction.start();
        vm.stopPrank();
    }

    function testStartAuctionFailNotApproved() public {
        vm.prank(seller);
        vm.mockCall(address(nft), abi.encodeWithSelector(nft.getApproved.selector, nftId), abi.encode(address(0)));
        vm.expectRevert(bytes("Auction contract is not approved to manage this NFT."));
        auction.start();
    }

    function testStartAuction() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(this), true);
        nft.approve(address(auction), nftId);
        uint256 currentTime = block.timestamp;
        vm.expectEmit(true, false, false, true);
        emit AuctionStarted(currentTime, currentTime + duration);

        vm.startPrank(seller);
        auction.start();
        vm.stopPrank();

        // Check that endAt is correctly set (within a reasonable window)
        uint256 endAt = auction.endAt();
        // endAt should equal the block timestamp (at start) plus the duration
        assertGe(endAt, currentTime + duration);
        // In case a few seconds have passed, endAt should be no more than the current block.timestamp + duration
        assertLe(endAt, block.timestamp + duration);

        // Verify that the NFT is now owned by the auction contract
        address nftOwner = nft.ownerOf(nftId);
        assertEq(nftOwner, address(auction), "NFT should be transferred to auction contract");
    }

    function testStartAuctionTwiceFail() public {
        testStartAuction();

        vm.startPrank(seller);
        vm.expectRevert("Auction has already started.");
        auction.start();
        vm.stopPrank();
    }

    function testBidFailNotApproved() public {
        vm.expectRevert(bytes("Auction has not started yet."));
        auction.bid();
    }

    function testBidFailElapsedAuctionTime() public {
        testStartAuction();

        vm.warp(block.timestamp + 5 days);
        vm.expectRevert(bytes("Auction time has already elapsed, no bids area allowed."));
        auction.bid();
    }

    function testBidFailLowBid() public {
        testStartAuction();

        uint256 bidAmount = 3 ether;
        vm.startPrank(bidder1);
        vm.deal(bidder1, bidAmount);
        vm.expectRevert(bytes("Your bid is tool low."));
        auction.bid{value: 1 wei}();
        vm.stopPrank();
    }

    function testBid() public {
        testStartAuction();

        uint256 bidAmount = 3 ether;
        vm.startPrank(bidder1);
        vm.deal(bidder1, bidAmount);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder1, bidAmount);

        auction.bid{value: bidAmount}();
        vm.stopPrank();

        assertEq(bidAmount, auction.highestBid());
        assertEq(bidder1, auction.highestBidder());
    }

    function testWithdrawFailNoBalance() public {
        vm.expectRevert(bytes("There is no balance to withdraw."));
        auction.withdraw();
    }

    function testWithdraw() public {
        testBid();

        uint256 bidAmount = 4 ether;
        vm.startPrank(bidder2);
        vm.deal(bidder2, bidAmount);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder2, bidAmount);

        auction.bid{value: bidAmount}();
        vm.stopPrank();

        uint256 previousHighestBid = 3 ether;
        vm.prank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(bidder1, previousHighestBid);
        auction.withdraw();
    }

    function testCancelAuctionFailNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        auction.start();
        vm.stopPrank();
    }

    function testCancelAuctionFailNotStarted() public {
        vm.prank(seller);
        vm.expectRevert(bytes("Auction has not started yet."));
        auction.cancelAuction();
    }

    function testCancelAuctionFailActiveBidsExist() public {
        testBid();

        vm.prank(seller);
        vm.expectRevert(bytes("There are already bids, you cannot cancel auction."));
        auction.cancelAuction();
    }

    function testCancelAuction() public {
        testStartAuction();

        vm.prank(seller);
        vm.expectEmit(false, false, false, false);
        emit AuctionCancelled();
        auction.cancelAuction();
    }

    function testEndAuctionFailNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        auction.end();
        vm.stopPrank();
    }

    function testEndAuctionFailNotStartedYet() public {
        vm.startPrank(seller);
        vm.expectRevert(bytes("Auction has not started yet."));
        auction.end();
        vm.stopPrank();
    }

    function testEndAuctionWithBid() public {
        testBid();

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(auction.highestBidder(), auction.highestBid());
        auction.end();
        vm.stopPrank();

        assertEq(nft.ownerOf(nftId), auction.highestBidder());
        assertEq(seller.balance, auction.highestBid());
    }

    function testEndAuctionWithoutBid() public {
        testStartAuction();

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(auction.highestBidder(), auction.highestBid());
        auction.end();
        vm.stopPrank();

        assertEq(nft.ownerOf(nftId), seller);
    }

    function testEndAuctionFailAlreadyEnded() public {
        testEndAuctionWithoutBid();

        vm.startPrank(seller);
        vm.expectRevert(bytes("Auction has already ended."));
        auction.end();
        vm.stopPrank();
    }

    function testCancelAuctionFailAlreadyEnded() public {
        testEndAuctionWithBid();

        vm.prank(seller);
        vm.expectRevert(bytes("Auction has already ended."));
        auction.cancelAuction();
    }
}
