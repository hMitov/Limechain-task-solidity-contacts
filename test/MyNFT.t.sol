// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/console.sol";

contract MyERC7212 is Test {
    MyNFT private nft;
    string private tokenName = "tokenName1";
    string private tokenSymbol = "tokenSymbol1";
    string private uri = "https://example.com/token-image.png";
    address private nonOwner = address(1);
    address private whitelistedBuyer1 = address(2);
    address private buyer = address(3);


    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        nft = new MyNFT(tokenName, tokenSymbol, uri);
    }

    function testTogglePrivateSaleFailNotOwner() public {
        bool initialPrivateSaleState = nft.isPrivateSaleActive();
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        nft.togglePrivateSale();
        vm.stopPrank();
        assertEq(initialPrivateSaleState, nft.isPrivateSaleActive());
    }

    function testTogglePrivateSale() public {
        bool initialPrivateSaleState = nft.isPrivateSaleActive();
        nft.togglePrivateSale();
        assertNotEq(initialPrivateSaleState, nft.isPrivateSaleActive());
    }

    function testTogglePublicSaleFailNotOwner() public {
        bool initialPublicSaleState = nft.isPublicSaleActive();
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        nft.togglePublicSale();
        vm.stopPrank();
        assertEq(initialPublicSaleState, nft.isPublicSaleActive());
    }

    function testTogglePublicSale() public {
        bool initialPublicSaleState = nft.isPublicSaleActive();
        nft.togglePublicSale();
        assertNotEq(initialPublicSaleState, nft.isPublicSaleActive());
    }

    function testAddAddressesToWhitelistFailNotOwner() public {
        address[] memory whitelistSellers = new address[](2);
        whitelistSellers[0] = whitelistedBuyer1;

        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        nft.addAddressesToWhitelist(whitelistSellers);
        vm.stopPrank();
    }

    function testAddAddressesToWhitelist() public {
        address[] memory whitelistSellers = new address[](2);
        whitelistSellers[0] = whitelistedBuyer1;

        nft.addAddressesToWhitelist(whitelistSellers);

        assertEq(true, nft.whitelist(whitelistedBuyer1));
    }

    function testRemoveAddressesFromWhitelistFailNotOwner() public {
        testAddAddressesToWhitelist();

        address[] memory removeSellers = new address[](2);
        removeSellers[0] = whitelistedBuyer1;

        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        nft.removeAddressesFromWhitelist(removeSellers);
        vm.stopPrank();
    }

    function testRemoveAddressesFromWhitelist() public {
        testAddAddressesToWhitelist();

        address[] memory removeSellers = new address[](2);
        removeSellers[0] = whitelistedBuyer1;

        nft.removeAddressesFromWhitelist(removeSellers);

        assertEq(false, nft.whitelist(whitelistedBuyer1));
    }

    function testSetPricesFailNotOwner() public {
        uint256 privateSellPrice = 5 ether;
        uint256 publicSellPrice = 7 ether;

        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
        nft.setPrices(privateSellPrice, publicSellPrice);
        vm.stopPrank();
    }

    function testSetPrices() public {
        uint256 privateSalePrice = 5 ether;
        uint256 publicSalePrice = 7 ether;

        nft.setPrices(privateSalePrice, publicSalePrice);

        assertEq(privateSalePrice, nft.privateSalePrice());
        assertEq(publicSalePrice, nft.publicSalePrice());
    }

    function testMintPrivateSaleFailSaleNotActive() public {
        uint tokenId = 23;
        vm.expectRevert(bytes("Private sale is still not active."));
        nft.mintPrivateSale(tokenId);
    }

    function testMintPrivateSaleFailSenderNotWhitelisted() public {
        uint tokenId = 23;
        nft.togglePrivateSale();
        vm.expectRevert(bytes("Sender is not whitelisted."));
        nft.mintPrivateSale(tokenId);
    }

    function testMintPrivateSaleFailIncorrectEthAmount() public {
        uint tokenId = 23;
        uint ethAmount = 3 ether;

        testAddAddressesToWhitelist();
        nft.togglePrivateSale();
        vm.deal(whitelistedBuyer1, ethAmount);
        vm.startPrank(whitelistedBuyer1);
        vm.expectRevert(bytes("There is a fixed ETH amount. The provided one is incorrect."));
        nft.mintPrivateSale{value: ethAmount}(tokenId);
        vm.stopPrank();
    }

    function testMintPrivateSale() public {
        uint tokenId = 23;
        uint ethAmount = 0.05 ether;

        testAddAddressesToWhitelist();
        nft.togglePrivateSale();
        vm.deal(whitelistedBuyer1, ethAmount);
        vm.startPrank(whitelistedBuyer1);
        nft.mintPrivateSale{value: ethAmount}(tokenId);
        vm.stopPrank();

        assertEq(whitelistedBuyer1, nft.ownerOf(tokenId));
        assertEq(1, nft.totalMinted());
    }


    function testMintPublicSaleFailSaleNotActive() public {
        uint tokenId = 23;
        vm.expectRevert(bytes("Public sale is still not active."));
        nft.mintPublicSale(tokenId);
    }

    function testMintPublicSaleFailIncorrectEthAmount() public {
        uint tokenId = 23;
        uint ethAmount = 3 ether;

        nft.togglePublicSale();
        vm.deal(buyer, ethAmount);
        vm.startPrank(buyer);
        vm.expectRevert(bytes("There is a fixed ETH amount. The provided one is incorrect."));
        nft.mintPublicSale{value: ethAmount}(tokenId);
        vm.stopPrank();
    }

    function testMintPublicSale() public {
        uint tokenId = 23;
        uint ethAmount = 0.1 ether;

        nft.togglePublicSale();
        vm.deal(buyer, ethAmount);
        vm.startPrank(buyer);
        nft.mintPublicSale{value: ethAmount}(tokenId);
        vm.stopPrank();

        assertEq(buyer, nft.ownerOf(tokenId));
        assertEq(1, nft.totalMinted());
    }

    function testWithdraw() public {
        uint ethAmount = 0.1 ether;
        uint initialBalance = address(this).balance;
        testMintPublicSale();
        nft.withdraw();
        assertEq(0, address(nft).balance);
        assertEq(initialBalance + ethAmount, address(this).balance);
    }

    function testBaseURI() public {
        assertEq(uri, nft.baseURI());
    }

    fallback() external payable {}

    receive() external payable {}
}
