// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";

contract AuctionFlowIT is Test {
    MyNFT private nft;
    EnglishAuctionFactory private factory;
    EnglishAuction private auction;

    address private constant seller = address(1);
    address private constant bidder1 = address(2);
    address private constant bidder2 = address(3);

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

    function setUp() public {
        vm.deal(seller, STARTING_BALANCE);
        vm.deal(bidder1, STARTING_BALANCE);
        vm.deal(bidder2, STARTING_BALANCE);

        vm.startPrank(seller);

        nft = new MyNFT(NFT_NAME, NFT_SYMBOL, NFT_URI, NFT_MAX_SUPPLY, seller, ROYALTY_FEE);
        nft.togglePrivateSale();
        nft.addAddressToWhitelist(seller);
        nft.setPrivateSalePrice(MINT_PRICE);
        nft.mintPrivateSale{value: MINT_PRICE}();

        factory = new EnglishAuctionFactory();
        address auctionAddr = factory.createAuction(address(nft), 1, AUCTION_DURATION, MIN_BID_INCREMENT);
        auction = EnglishAuction(payable(auctionAddr));

        nft.approve(address(auction), 1);

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
        auction.bid{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        uint256 winningBid = 1.5 ether;
        auction.bid{value: winningBid}();
        vm.stopPrank();

        vm.warp(block.timestamp + AUCTION_DURATION + 1);
        vm.startPrank(seller);
        auction.end();
        vm.stopPrank();

        assertEq(nft.ownerOf(TOKEN_ID), bidder2);

        (address royaltyReceiver, uint256 royaltyAmount) = nft.royaltyInfo(TOKEN_ID, winningBid);
        assertEq(royaltyReceiver, seller);
        assertEq(royaltyAmount, (winningBid * ROYALTY_FEE) / 10000);
    }

    function testRejectsLowBid() public {
        vm.startPrank(bidder1);
        auction.bid{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        vm.expectRevert("Bid is too low");
        uint256 lowBid = 1.05 ether;
        auction.bid{value: lowBid}();
        vm.stopPrank();
    }

    function testWithdrawFailsIfNotOutbid() public {
        vm.startPrank(bidder1);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(bidder1);
        vm.expectRevert("No balance to withdraw");
        auction.withdraw();
        vm.stopPrank();
    }

    function testBidWithdrawal() public {
        vm.startPrank(bidder1);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(bidder2);
        uint256 higherBid = 1.2 ether;
        auction.bid{value: higherBid}();
        vm.stopPrank();

        uint256 before = bidder1.balance;
        vm.startPrank(bidder1);
        auction.withdraw();
        vm.stopPrank();

        assertApproxEqAbs(bidder1.balance, before + 1 ether, ASSERT_DELTA);
    }

    function testCancelAuction() public {
        vm.startPrank(seller);
        auction.cancelAuction();
        vm.stopPrank();

        assertEq(nft.ownerOf(1), seller);
    }

    function testCannotCancelAfterBids() public {
        vm.startPrank(bidder1);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert("Cannot cancel after first bid");
        auction.cancelAuction();
        vm.stopPrank();
    }

    function testExtendAuctionWhenLastMinuteBid() public {
        vm.startPrank(bidder1);
        auction.bid{value: BIDDER1_BID}();
        vm.stopPrank();

        vm.warp(block.timestamp + AUCTION_DURATION - EXTENSION_DURATION);
        vm.startPrank(bidder2);
        uint256 bidder2Bid = 1.2 ether;
        auction.bid{value: bidder2Bid}();
        vm.stopPrank();

        assertGt(auction.endAt(), block.timestamp + (EXTENSION_DURATION - 1));
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
        auction.end();

        factory.removeAuction(address(nft), TOKEN_ID);
        assertEq(factory.activeAuctions(address(nft), TOKEN_ID), address(0));
    }
}
