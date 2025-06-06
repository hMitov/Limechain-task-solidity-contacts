// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyNFT} from "../../src/MyNFT.sol";
import {EnglishAuction} from "../../src/EnglishAuction.sol";
import {EnglishAuctionFactory} from "../../src/EnglishAuctionFactory.sol";

contract AuctionFlowIT is Test {
    MyNFT private nft;
    EnglishAuctionFactory private factory;
    EnglishAuction private auction;

    address private constant seller = address(1);
    address private constant bidder1 = address(2);
    address private constant bidder2 = address(3);
    address private constant creator = address(4);

    uint256 private constant STARTING_BALANCE = 100 ether;
    uint256 private constant MINT_PRICE = 0.0005 ether;
    uint256 private constant AUCTION_DURATION = 1 days;
    uint256 private constant MIN_BID_INCREMENT = 0.1 ether;
    uint96 private constant ROYALTY_FEE = 500;

    string private constant NFT_NAME = "New NFT";
    string private constant NFT_SYMBOL = "_NFT__";
    string private constant NFT_URI = "https://www.google.com/";
    uint256 private constant NFT_MAX_SUPPLY = 10000;
    uint256 private constant TOKEN_ID = 1;

    uint256 private constant BIDDER1_BID = 1 ether;
    uint256 private constant EXTENSION_DURATION = 5 minutes;
    uint256 private constant ASSERT_DELTA = 1e14;

    event AuctionStarted(uint256 startTime, uint256 endTime);
    event BidPlaced(address indexed bidder, uint256 amount);
    event Withdrawal(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event AuctionCancelled();
    event AuctionExtended(uint256 newEndTime, address extendedBy);
    event RoyaltyPaid(uint256 nftId, address indexed receiver, uint256 amount);

    function setUp() public {
        vm.deal(seller, STARTING_BALANCE);
        vm.deal(bidder1, STARTING_BALANCE);
        vm.deal(bidder2, STARTING_BALANCE);

        vm.startPrank(seller);

        nft = new MyNFT(NFT_NAME, NFT_SYMBOL, NFT_URI, NFT_MAX_SUPPLY, creator, ROYALTY_FEE);
        nft.togglePrivateSale();
        nft.addAddressToWhitelist(seller);
        nft.setPrivateSalePrice(MINT_PRICE);
        nft.mintPrivateSale{value: MINT_PRICE}();

        factory = new EnglishAuctionFactory();
        address auctionAddr = factory.createAuction(address(nft), TOKEN_ID, AUCTION_DURATION, MIN_BID_INCREMENT);
        auction = EnglishAuction(payable(auctionAddr));

        nft.approve(address(auction), TOKEN_ID);

        uint256 nowTime = block.timestamp;
        vm.expectEmit(true, false, false, true);
        emit AuctionStarted(nowTime, nowTime + AUCTION_DURATION);

        auction.start();

        vm.stopPrank();
    }

    function testCannotStartAuctionTwice() public {
        vm.prank(seller);
        vm.expectRevert("Auction already started");
        auction.start();
    }

    function testAuctionFullFlowWithRoyalty() public {
        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder1, 1 ether);
        auction.bid{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        uint256 winningBid = 1.5 ether;
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder2, winningBid);
        auction.bid{value: winningBid}();
        vm.stopPrank();

        uint256 expectedRoyalty = (winningBid * ROYALTY_FEE) / 10000;

        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        vm.startPrank(seller);
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(bidder2, winningBid);
        emit RoyaltyPaid(TOKEN_ID, seller, expectedRoyalty);
        auction.end();
        vm.stopPrank();

        assertEq(nft.ownerOf(TOKEN_ID), bidder2);
        assertEq(creator.balance, expectedRoyalty);
    }

    function testRejectsLowBid() public {
        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder1, 1 ether);
        auction.bid{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        vm.expectRevert("Bid is too low");
        auction.bid{value: 1.05 ether}();
        vm.stopPrank();
    }

    function testWithdrawFailsIfNotOutbid() public {
        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder1, BIDDER1_BID);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(bidder1);
        vm.expectRevert("No balance to withdraw");
        auction.withdraw();
        vm.stopPrank();
    }

    function testBidWithdrawal() public {
        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder1, BIDDER1_BID);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        uint256 higherBid = 1.2 ether;
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder2, higherBid);
        auction.bid{value: higherBid}();
        vm.stopPrank();

        uint256 before = bidder1.balance;

        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(bidder1, BIDDER1_BID);
        auction.withdraw();
        vm.stopPrank();

        assertApproxEqAbs(bidder1.balance, before + BIDDER1_BID, ASSERT_DELTA);
    }

    function testCancelAuction() public {
        vm.startPrank(seller);
        vm.expectEmit(false, false, false, false);
        emit AuctionCancelled();
        auction.cancelAuction();
        vm.stopPrank();

        assertEq(nft.ownerOf(TOKEN_ID), seller);
    }

    function testCannotCancelAfterBids() public {
        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder1, BIDDER1_BID);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert("Cannot cancel after first bid");
        auction.cancelAuction();
        vm.stopPrank();
    }

    function testCannotEndBeforeTimeDeadline() public {
        vm.startPrank(bidder1);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert("Auction time not yet over");
        auction.end();
        vm.stopPrank();
    }

    function testFactoryAuctionTracking() public {
        address auctionAddr = factory.activeAuctions(address(nft), TOKEN_ID);
        assertEq(address(auction), auctionAddr);

        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        vm.prank(seller);
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(address(0), 0);
        auction.end();

        factory.removeAuction(address(nft), TOKEN_ID);
        assertEq(factory.activeAuctions(address(nft), TOKEN_ID), address(0));
    }

    function testWithdrawOnlyOnce() public {
        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder1, BIDDER1_BID);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder2, 1.2 ether);
        auction.bid{value: 1.2 ether}();
        vm.stopPrank();

        vm.startPrank(bidder1);
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(bidder1, BIDDER1_BID);
        auction.withdraw();
        vm.expectRevert("No balance to withdraw");
        auction.withdraw();
        vm.stopPrank();
    }

    function testAuctionEndsWithoutBids() public {
        vm.warp(block.timestamp + AUCTION_DURATION + 1);

        vm.prank(seller);
        vm.expectEmit(true, false, false, true);
        emit AuctionEnded(address(0), 0);
        auction.end();

        assertEq(nft.ownerOf(TOKEN_ID), seller);
    }

    function testReceiveFunctionReverts() public {
        (bool success,) = address(auction).call{value: 1 ether}("");
        assertFalse(success, "Direct ETH transfer should fail");
    }

    function testWithdrawClearsBalance() public {
        vm.startPrank(bidder1);
        auction.bid{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        auction.bid{value: 1.5 ether}();
        vm.stopPrank();

        assertEq(auction.bids(bidder1), 1 ether);

        vm.startPrank(bidder1);
        auction.withdraw();
        vm.stopPrank();

        assertEq(auction.bids(bidder1), 0);
    }

    function testExtendAuctionWhenLastMinuteBid() public {
        _placeInitialBid();

        uint256 originalEndAt = auction.endAt();
        vm.warp(originalEndAt - 9 minutes);

        vm.deal(bidder2, 2 ether);

        vm.expectEmit(true, true, false, true);
        emit AuctionExtended(originalEndAt + EXTENSION_DURATION, bidder2);

        vm.prank(bidder2);
        auction.bid{value: 2 ether}();

        assertEq(auction.endAt(), originalEndAt + EXTENSION_DURATION);
    }

    function testMultipleBidsUpdatesHighestBidder() public {
        _placeInitialBid();

        vm.startPrank(bidder2);
        vm.deal(bidder2, 2 ether);
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(bidder2, 2 ether);
        auction.bid{value: 2 ether}();
        vm.stopPrank();

        assertEq(auction.highestBidder(), bidder2);
        assertEq(auction.highestBid(), 2 ether);
    }

    function _placeInitialBid() internal {
        vm.startPrank(bidder1);
        auction.bid{value: 1 ether}();
        vm.stopPrank();
    }
}
