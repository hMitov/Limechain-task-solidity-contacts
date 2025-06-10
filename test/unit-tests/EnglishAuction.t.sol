// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {EnglishAuction} from "../../src/EnglishAuction.sol";
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

    address private constant seller = address(1);
    address private constant bidder1 = address(2);
    address private constant bidder2 = address(3);

    uint256 private constant NFT_ID = 1;
    uint256 private constant AUCTION_DURATION = 3 days;
    uint256 private constant MIN_BID_INCREMENT = 0.1 ether;

    uint256 private constant BID_EXTENSION_GRACE_PERIOD = 10 minutes;
    uint256 private constant EXTENSION_DURATION = 5 minutes;

    address owner = address(1);
    address nonOwner = address(2);

    error OwnableUnauthorizedAccount(address account);

    event AuctionStarted(uint256 startTime, uint256 endTime);
    event BidPlaced(address indexed bidder, uint256 amount);
    event Withdrawal(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event AuctionCancelled();
    event AuctionExtended(uint256 newEndTime, address extendedBy);

    error EnforcedPause();

    function setUp() public {
        vm.startPrank(seller);

        nft = new MockERC721();
        nft.mint(seller, NFT_ID);
        auction = new EnglishAuction(seller, address(nft), NFT_ID, AUCTION_DURATION, MIN_BID_INCREMENT);

        vm.stopPrank();
    }

    function testGrandPauserRoleFailsIfZeroAddressPassed() public {
        vm.startPrank(seller);
        vm.expectRevert("Cannot grant role to zero address");
        auction.grantPauserRole(address(0));
        vm.stopPrank();
    }

    function testRevokePauserRoleFailsIfZeroAddressPassed() public {
        vm.startPrank(seller);
        vm.expectRevert("Cannot revoke role from zero address");
        auction.revokePauserRole(address(0));
        vm.stopPrank();
    }

    function testPauseUnpauseByPauser() public {
        vm.startPrank(seller);
        address pauser = address(4);
        auction.grantPauserRole(pauser);
        vm.stopPrank();

        vm.startPrank(pauser);
        auction.pause();
        vm.stopPrank();
        assertTrue(auction.paused());

        vm.startPrank(pauser);
        auction.unpause();
        vm.stopPrank();
        assertFalse(auction.paused());
    }

    function testPauseFailsIfNotPauser() public {
        vm.startPrank(nonOwner);
        vm.expectRevert("Caller is not pauser");
        auction.pause();
        vm.stopPrank();
    }

    function testContructorRevertsOnInAppropriateArgs() public {
        vm.expectRevert("Seller cannot be zero address");
        new EnglishAuction(address(0), address(nft), NFT_ID, AUCTION_DURATION, MIN_BID_INCREMENT);

        vm.expectRevert("NFT cannot be zero address");
        new EnglishAuction(seller, address(0), NFT_ID, AUCTION_DURATION, MIN_BID_INCREMENT);

        vm.expectRevert("Invalid auction duration");
        new EnglishAuction(seller, address(nft), NFT_ID, 0, MIN_BID_INCREMENT);
    
        vm.expectRevert("Min bid increment must be greater than zero");
        new EnglishAuction(seller, address(nft), NFT_ID, AUCTION_DURATION, 0);
    }

    function testStartAuction() public {
        vm.prank(seller);

        nft.setApprovalForAll(address(this), true);
        nft.approve(address(auction), NFT_ID);
        uint256 currentTime = block.timestamp;
        vm.expectEmit(true, false, false, true);
        emit AuctionStarted(currentTime, currentTime + AUCTION_DURATION);

        vm.startPrank(seller);
        auction.start();
        vm.stopPrank();

        uint256 endAt = auction.endAt();
        assertGe(endAt, currentTime + AUCTION_DURATION);
        assertLe(endAt, block.timestamp + AUCTION_DURATION);

        address nftOwner = nft.ownerOf(NFT_ID);
        assertEq(nftOwner, address(auction), "NFT should be transferred to auction contract");
    }

    function testStartAuctionFailNotAdmin() public {
        vm.startPrank(nonOwner);
        vm.expectRevert("Caller is not an admin");
        auction.start();
        vm.stopPrank();
    }

    function testStartAuctionFailsNotApproved() public {
        vm.prank(seller);
        vm.mockCall(address(nft), abi.encodeWithSelector(nft.getApproved.selector, NFT_ID), abi.encode(address(0)));
        vm.expectRevert(bytes("Auction not approved for NFT"));
        auction.start();
    }

    function testStartAuctionTwiceFail() public {
        testStartAuction();

        vm.startPrank(seller);
        vm.expectRevert("Auction already started");
        auction.start();
        vm.stopPrank();
    }

    function testAuctionExtensionEmitsEvent() public {
        testStartAuction();
        uint256 originalEndAt = auction.endAt();

        vm.warp(originalEndAt - BID_EXTENSION_GRACE_PERIOD + 1);

        uint256 bidAmount = 1 ether;
        vm.deal(bidder1, bidAmount);

        vm.expectEmit(true, true, false, true);
        emit AuctionExtended(originalEndAt + EXTENSION_DURATION, bidder1);

        vm.prank(bidder1);
        auction.bid{value: bidAmount}();
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

    function testBidFailsIfNotStarted() public {
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        vm.expectRevert("Auction not started");
        auction.bid{value: 1 ether}();
    }

    function testBidExtendsAuctionIfCloseToEnd() public {
        testStartAuction();
        uint256 originalEndAt = auction.endAt();

        vm.warp(originalEndAt - BID_EXTENSION_GRACE_PERIOD + 1);

        uint256 bidAmount = 1 ether;
        vm.deal(bidder1, bidAmount);

        vm.prank(bidder1);
        auction.bid{value: bidAmount}();

        uint256 newEndAt = auction.endAt();
        assertEq(newEndAt, originalEndAt + EXTENSION_DURATION);
        assertEq(auction.highestBidder(), bidder1);
        assertEq(auction.highestBid(), bidAmount);
    }

    function testBidFailNotApproved() public {
        vm.expectRevert(bytes("Auction not started"));
        auction.bid();
    }

    function testBidFailElapsedAuctionTime() public {
        testStartAuction();

        vm.warp(block.timestamp + 5 days);
        vm.expectRevert(bytes("Auction already ended"));
        auction.bid();
    }

    function testBidFailsIfTooLow() public {
        testStartAuction();

        uint256 bidAmount = 3 ether;
        vm.startPrank(bidder1);
        vm.deal(bidder1, bidAmount);
        vm.expectRevert(bytes("Bid is too low"));
        auction.bid{value: 1 wei}();
        vm.stopPrank();
    }

    function testWithdrawFailNoBalance() public {
        vm.expectRevert(bytes("No balance to withdraw"));
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

    function testBidRevertsWhenPaused() public {
        testStartAuction();

        vm.prank(seller);
        auction.pause();

        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        vm.expectRevert(EnforcedPause.selector);
        auction.bid{value: 1 ether}();
    }

    function testWithdrawRevertsWhenPaused() public {
        testBid();

        vm.prank(seller);
        auction.pause();

        vm.prank(bidder1);
        vm.expectRevert(EnforcedPause.selector);
        auction.withdraw();
    }

    function testCancelAuctionFailNotAdmin() public {
        vm.startPrank(nonOwner);
        vm.expectRevert("Caller is not an admin");
        auction.start();
        vm.stopPrank();
    }

    function testCancelAuctionFailNotStarted() public {
        vm.prank(seller);
        vm.expectRevert(bytes("Auction not started"));
        auction.cancelAuction();
    }

    function testCancelAuctionFailActiveBidsExist() public {
        testBid();

        vm.prank(seller);
        vm.expectRevert(bytes("Cannot cancel after first bid"));
        auction.cancelAuction();
    }

    function testCancelAuction() public {
        testStartAuction();

        vm.prank(seller);
        vm.expectEmit(false, false, false, false);
        emit AuctionCancelled();
        auction.cancelAuction();
    }

    function testEndAuctionFailNotAdmin() public {
        vm.startPrank(nonOwner);
        vm.expectRevert("Caller is not an admin");
        auction.end();
        vm.stopPrank();
    }

    function testEndAuctionFailNotStartedYet() public {
        vm.startPrank(seller);
        vm.expectRevert(bytes("Auction not started"));
        auction.end();
        vm.stopPrank();
    }

    function testEndAuctionWithBid() public {
        testBid();

        uint256 endAt = auction.endAt();
        vm.warp(endAt + 1);

        address expectedWinner = auction.highestBidder();
        uint256 expectedBid = auction.highestBid();

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(expectedWinner, expectedBid);
        auction.end();
        vm.stopPrank();

        assertEq(nft.ownerOf(NFT_ID), expectedWinner);
        assertEq(seller.balance, expectedBid);
    }

    function testEndAuctionWithoutBid() public {
        testStartAuction();

        vm.warp(auction.endAt() + 1);

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(address(0), 0);
        auction.end();
        vm.stopPrank();

        assertEq(nft.ownerOf(NFT_ID), seller);
    }

    function testEndAuctionFailAlreadyEnded() public {
        testEndAuctionWithoutBid();

        vm.startPrank(seller);
        vm.expectRevert(bytes("Auction already ended"));
        auction.end();
        vm.stopPrank();
    }

    function testCancelAuctionFailAlreadyEnded() public {
        testEndAuctionWithBid();

        vm.prank(seller);
        vm.warp(block.timestamp + 4 days);
        vm.expectRevert(bytes("Auction already ended"));
        auction.cancelAuction();
    }

    function testFuzzConstructorValidArgs(address sellerAddr, address nftAddr, uint256 dur, uint256 inc) public {
        vm.assume(sellerAddr != address(0));
        vm.assume(nftAddr != address(0));

        uint256 duration = bound(dur, 1, 30 days);
        uint256 increment = bound(inc, 1 ether, 1000 ether);

        EnglishAuction newAuction = new EnglishAuction(sellerAddr, nftAddr, NFT_ID, duration, increment);

        assertEq(newAuction.duration(), duration);
        assertEq(newAuction.minBidIncrement(), increment);
        assertEq(newAuction.seller(), payable(sellerAddr));
    }

    function testFuzzBidAmount(uint256 bid1, uint256 bid2) public {
        testStartAuction();

        bid1 = bound(bid1, 1 ether, 1000 ether);
        bid2 = bound(bid2, bid1 + MIN_BID_INCREMENT, 2000 ether);

        vm.startPrank(bidder1);
        vm.deal(bidder1, bid1);
        auction.bid{value: bid1}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        vm.deal(bidder2, bid2);
        auction.bid{value: bid2}();
        vm.stopPrank();

        assertEq(auction.highestBid(), bid2);
        assertEq(auction.highestBidder(), bidder2);
        assertEq(auction.bids(bidder1), bid1);
    }

    function testFuzzWithdraw(uint256 bid1, uint256 bid2) public {
        testStartAuction();

        bid1 = bound(bid1, 1 ether, 50 ether);
        bid2 = bound(bid2, bid1 + MIN_BID_INCREMENT, 100 ether);

        vm.startPrank(bidder1);
        vm.deal(bidder1, bid1);
        auction.bid{value: bid1}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        vm.deal(bidder2, bid2);
        auction.bid{value: bid2}();
        vm.stopPrank();

        uint256 refund = auction.bids(bidder1);
        assertEq(refund, bid1);

        vm.prank(bidder1);
        auction.withdraw();

        assertEq(auction.bids(bidder1), 0);
    }

    function testFuzzBidTooLow(uint256 baseBid, uint256 lowBid) public {
        testStartAuction();

        baseBid = bound(baseBid, 1 ether, 100 ether);
        lowBid = bound(lowBid, 1 wei, baseBid + MIN_BID_INCREMENT - 1);

        vm.deal(bidder1, baseBid);
        vm.prank(bidder1);
        auction.bid{value: baseBid}();

        vm.deal(bidder2, lowBid);
        vm.prank(bidder2);
        vm.expectRevert("Bid is too low");
        auction.bid{value: lowBid}();
    }

    function testFuzzRejectLateBid(uint256 bidAmount) public {
        testStartAuction();

        bidAmount = bound(bidAmount, MIN_BID_INCREMENT, 10 ether);

        vm.warp(auction.endAt() - 10);
        vm.deal(bidder1, bidAmount);
        vm.prank(bidder1);
        uint256 previousEndAt = auction.endAt();
        auction.bid{value: 2 ether}();

        assertEq(auction.endAt(), previousEndAt + EXTENSION_DURATION);
    }

    function testFuzzWithdrawFailsIfZeroBalance(address randomAddress) public {
        vm.assume(randomAddress != address(0) && randomAddress != bidder1 && randomAddress != bidder2);
        vm.prank(randomAddress);
        vm.expectRevert("No balance to withdraw");
        auction.withdraw();
    }
}
