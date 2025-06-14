// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyNFT} from "../../src/MyNFT.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyERC721 is Test {
    MyNFT private nft;
    string private constant TOKEN_NAME = "tokenName1";
    string private constant TOKEN_SYMBOL = "tokenSymbol1";
    string private constant URI = "https://example.com/token-image.png";
    uint256 private constant MAX_SUPPLY = 10000;
    address private constant notAdmin = address(1);
    address private constant admin = address(2);
    address private constant receiverRoyalty = address(3);
    address private constant whitelister = address(4);
    address private constant whitelistedBuyer1 = address(5);
    address private constant buyer = address(6);
    uint96 private constant FEE_NOMINATOR = 700;

    event PricesUpdated(uint256 privateSalePrice, uint256 publicSalePrice);
    event NFTMinted(address indexed to, uint256 tokenId);
    event PrivateSaleToggled();
    event PublicSaleToggled();
    event AddressAddedToWhitelist(address userAddress);
    event AddressRemovedFromWhitelist(address userAddress);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event BaseURIChanged(string newBaseURI);

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        nft = new MyNFT(TOKEN_NAME, TOKEN_SYMBOL, URI, MAX_SUPPLY, receiverRoyalty, FEE_NOMINATOR);
    }

    function testContructorRevertsOnInAppropriateArgs() public {
        vm.expectRevert("NFT name must not be empty");
        new MyNFT("", TOKEN_SYMBOL, URI, MAX_SUPPLY, receiverRoyalty, FEE_NOMINATOR);

        vm.expectRevert("NFT symbol must not be empty");
        new MyNFT(TOKEN_NAME, "", URI, MAX_SUPPLY, receiverRoyalty, FEE_NOMINATOR);

        vm.expectRevert("Base URI must not be empty");
        new MyNFT(TOKEN_NAME, TOKEN_SYMBOL, "", MAX_SUPPLY, receiverRoyalty, FEE_NOMINATOR);

        vm.expectRevert("Max supply must be greater than zero");
        new MyNFT(TOKEN_NAME, TOKEN_SYMBOL, URI, 0, receiverRoyalty, FEE_NOMINATOR);

        vm.expectRevert("Royalty receiver cannot be zero address");
        new MyNFT(TOKEN_NAME, TOKEN_SYMBOL, URI, MAX_SUPPLY, address(0), FEE_NOMINATOR);

        vm.expectRevert("Royalty fee will exceed salePrice");
        new MyNFT(TOKEN_NAME, TOKEN_SYMBOL, URI, MAX_SUPPLY, receiverRoyalty, 20000);
    }

    function testGrandPauserRoleFailsIfZeroAddressPassed() public {
        nft.grantRole(nft.ADMIN_ROLE(), admin);
        vm.startPrank(admin);
        vm.expectRevert("Cannot grant role to zero address");
        nft.grantPauserRole(address(0));
        vm.stopPrank();
    }

    function testRevokePauserRoleFailsIfZeroAddressPassed() public {
        nft.grantRole(nft.ADMIN_ROLE(), admin);
        vm.startPrank(admin);
        vm.expectRevert("Cannot revoke role from zero address");
        nft.revokePauserRole(address(0));
        vm.stopPrank();
    }

    function testGrandWhitelistAdminRoleFailsIfZeroAddressPassed() public {
        nft.grantRole(nft.ADMIN_ROLE(), admin);
        vm.startPrank(admin);
        vm.expectRevert("Cannot grant role to zero address");
        nft.grantWhitelistAdminRole(address(0));
        vm.stopPrank();
    }

    function testRevokeWhitelistAdminRoleFailsIfZeroAddressPassed() public {
        nft.grantRole(nft.ADMIN_ROLE(), admin);
        vm.startPrank(admin);
        vm.expectRevert("Cannot revoke role from zero address");
        nft.revokeWhitelistAdminRole(address(0));
        vm.stopPrank();
    }

    function testGrandWhitelistedRoleFailsIfZeroAddressPassed() public {
        nft.grantRole(nft.WHITELIST_ADMIN_ROLE(), whitelister);
        vm.startPrank(whitelister);
        vm.expectRevert("Cannot grant role to zero address");
        nft.grantWhitelistedRole(address(0));
        vm.stopPrank();
    }

    function testRevokeWhitelistedRoleFailsIfZeroAddressPassed() public {
        nft.grantRole(nft.WHITELIST_ADMIN_ROLE(), whitelister);
        vm.startPrank(whitelister);
        vm.expectRevert("Cannot revoke role from zero address");
        nft.revokeWhitelistedRole(address(0));
        vm.stopPrank();
    }

    function testAdminCanGrantAndRevokeWhitelistAdminRole() public {
        nft.grantRole(nft.ADMIN_ROLE(), admin);

        vm.startPrank(admin);
        nft.grantWhitelistAdminRole(whitelister);
        vm.stopPrank();

        assertTrue(nft.hasRole(nft.WHITELIST_ADMIN_ROLE(), whitelister));

        vm.startPrank(admin);
        nft.revokeWhitelistAdminRole(whitelister);
        vm.stopPrank();

        assertFalse(nft.hasRole(nft.WHITELIST_ADMIN_ROLE(), whitelister));
    }

    function testWhitelistAdminCanGrantAndRevokeWhitelistedRole() public {
        nft.grantRole(nft.ADMIN_ROLE(), notAdmin);

        vm.startPrank(notAdmin);
        nft.grantWhitelistAdminRole(whitelister);
        vm.stopPrank();

        address whitelisted = address(6);
        vm.startPrank(whitelister);
        nft.grantWhitelistedRole(whitelisted);
        vm.stopPrank();

        assertTrue(nft.hasRole(nft.WHITELISTED_ROLE(), whitelisted));

        vm.startPrank(whitelister);
        nft.revokeWhitelistedRole(whitelisted);
        assertFalse(nft.hasRole(nft.WHITELISTED_ROLE(), whitelisted));
        vm.stopPrank();
    }

    function testAdminCanGrantAndRevokePauserRole() public {
        nft.grantRole(nft.ADMIN_ROLE(), notAdmin);
        vm.startPrank(notAdmin);
        nft.grantPauserRole(notAdmin);
        assertTrue(nft.hasRole(nft.PAUSER_ROLE(), notAdmin));

        nft.revokePauserRole(notAdmin);
        assertFalse(nft.hasRole(nft.PAUSER_ROLE(), notAdmin));
        vm.stopPrank();
    }

    function testTogglePrivateSaleFailNotAdmin() public {
        bool initialPrivateSaleState = nft.isPrivateSaleActive();

        vm.startPrank(notAdmin);
        vm.expectRevert("Caller is not an admin");
        nft.togglePrivateSale();
        vm.stopPrank();

        assertEq(initialPrivateSaleState, nft.isPrivateSaleActive());
    }

    function testTogglePrivateSale() public {
        bool initialPrivateSaleState = nft.isPrivateSaleActive();
        vm.expectEmit(false, false, false, true);
        emit PrivateSaleToggled();
        nft.togglePrivateSale();

        assertNotEq(initialPrivateSaleState, nft.isPrivateSaleActive());
    }

    function testTogglePublicSaleFailNotAdmin() public {
        bool initialPublicSaleState = nft.isPublicSaleActive();

        vm.startPrank(notAdmin);
        vm.expectRevert("Caller is not an admin");
        nft.togglePublicSale();
        vm.stopPrank();

        assertEq(initialPublicSaleState, nft.isPublicSaleActive());
    }

    function testTogglePublicSale() public {
        bool initialPublicSaleState = nft.isPublicSaleActive();
        vm.expectEmit(false, false, false, true);
        emit PublicSaleToggled();
        nft.togglePublicSale();

        assertNotEq(initialPublicSaleState, nft.isPublicSaleActive());
    }

    function testAddAddressToWhitelist() public {
        address whitelistSeller = whitelistedBuyer1;
        vm.expectEmit(true, false, false, true);
        emit AddressAddedToWhitelist(whitelistedBuyer1);
        nft.addAddressToWhitelist(whitelistSeller);

        assertTrue(nft.hasRole(nft.WHITELISTED_ROLE(), whitelistSeller));
    }

    function testAddAddressToWhitelistFailNotAdmin() public {
        address whitelistSellers = whitelistedBuyer1;
        address nonWhitelisted = address(6);

        vm.startPrank(nonWhitelisted);
        vm.expectRevert("Caller has no whitelist admin role");
        nft.addAddressToWhitelist(whitelistSellers);

        vm.stopPrank();
    }

    function testAddAddressToWhitelistFailZeroAddress() public {
        address whitelistSeller = address(0);

        vm.expectRevert(bytes("Cannot whitelist zero address"));

        nft.addAddressToWhitelist(whitelistSeller);
    }

    function testAddAddressToWhitelistFailAlreadyWhitelisted() public {
        testAddAddressToWhitelist();

        address whitelistSeller = whitelistedBuyer1;
        vm.expectRevert(bytes("Address is already whitelisted"));

        nft.addAddressToWhitelist(whitelistSeller);
    }

    function testRemoveAddressFromWhitelist() public {
        testAddAddressToWhitelist();

        vm.expectEmit(true, false, false, true);
        emit AddressRemovedFromWhitelist(whitelistedBuyer1);
        nft.removeAddressFromWhitelist(whitelistedBuyer1);

        assertFalse(nft.hasRole(nft.WHITELISTED_ROLE(), whitelistedBuyer1));
    }

    function testRemoveAddressFromWhitelistFailNotAdmin() public {
        testAddAddressToWhitelist();

        vm.startPrank(notAdmin);
        vm.expectRevert("Caller has no whitelist admin role");
        nft.removeAddressFromWhitelist(whitelistedBuyer1);
        vm.stopPrank();
    }

    function testRemoveAddressFromWhitelistFailZeroAddress() public {
        address removeSeller = address(0);
        vm.expectRevert(bytes("Cannot remove zero address"));
        nft.removeAddressFromWhitelist(removeSeller);
    }

    function testRemoveAddressFromWhitelistFailNotWhitelisted() public {
        testRemoveAddressFromWhitelist();

        vm.expectRevert(bytes("Address is not whitelisted"));
        nft.removeAddressFromWhitelist(whitelistedBuyer1);
    }

    function testSetPricesFailNotAdmin() public {
        uint256 privateSellPrice = 5 ether;
        uint256 publicSellPrice = 7 ether;

        vm.startPrank(notAdmin);
        vm.expectRevert("Caller is not an admin");
        nft.setPrices(privateSellPrice, publicSellPrice);
        vm.stopPrank();
    }

    function testSetPrices() public {
        uint256 privateSalePrice = 5 ether;
        uint256 publicSalePrice = 7 ether;

        vm.expectEmit(true, false, false, true);
        emit PricesUpdated(privateSalePrice, publicSalePrice);
        nft.setPrices(privateSalePrice, publicSalePrice);

        assertEq(privateSalePrice, nft.privateSalePrice());
        assertEq(publicSalePrice, nft.publicSalePrice());
    }

    function testMintPrivateSaleFailSaleNotActive() public {
        nft.addAddressToWhitelist(whitelistedBuyer1);
        vm.startPrank(whitelistedBuyer1);
        vm.expectRevert(bytes("Private sale is not active"));
        nft.mintPrivateSale();
        vm.stopPrank();
    }

    function testMintPrivateSaleFailSenderNotWhitelisted() public {
        nft.togglePrivateSale();
        vm.expectRevert(bytes("Caller has no whitelisted role"));
        nft.mintPrivateSale();
    }

    function testMintPrivateSaleFailIncorrectEthAmount() public {
        uint256 ethAmount = 3 ether;
        testAddAddressToWhitelist();
        nft.togglePrivateSale();
        vm.deal(whitelistedBuyer1, ethAmount);

        vm.startPrank(whitelistedBuyer1);
        vm.expectRevert(bytes("Incorrect ETH amount sent"));
        nft.mintPrivateSale{value: ethAmount}();
        vm.stopPrank();
    }

    function testMintPrivateSale() public {
        uint256 tokenId = 1;
        uint256 ethAmount = 0.0005 ether;

        testAddAddressToWhitelist();
        nft.togglePrivateSale();
        vm.deal(whitelistedBuyer1, ethAmount);

        vm.startPrank(whitelistedBuyer1);
        vm.expectEmit(true, false, false, true);
        emit NFTMinted(whitelistedBuyer1, 1);
        nft.mintPrivateSale{value: ethAmount}();
        vm.stopPrank();

        assertEq(whitelistedBuyer1, nft.ownerOf(tokenId));
        assertEq(tokenId, nft.totalMinted());
    }

    function testMintPublicSaleFailSaleNotActive() public {
        vm.expectRevert(bytes("Public sale is not active"));
        nft.mintPublicSale();
    }

    function testMintPublicSaleFailIncorrectEthAmount() public {
        uint256 ethAmount = 3 ether;
        nft.togglePublicSale();
        vm.deal(buyer, ethAmount);

        vm.startPrank(buyer);
        vm.expectRevert(bytes("Incorrect ETH amount sent"));
        nft.mintPublicSale{value: ethAmount}();
        vm.stopPrank();
    }

    function testMintPublicSale() public {
        uint256 tokenId = 1;
        uint256 ethAmount = 0.001 ether;
        nft.togglePublicSale();
        vm.deal(buyer, ethAmount);

        vm.startPrank(buyer);
        vm.expectEmit(true, false, false, true);
        emit NFTMinted(buyer, tokenId);
        nft.mintPublicSale{value: ethAmount}();
        vm.stopPrank();

        assertEq(buyer, nft.ownerOf(tokenId));
        assertEq(tokenId, nft.totalMinted());
    }

    function testWithdraw() public {
        uint256 ethAmount = 0.001 ether;
        uint256 initialBalance = address(this).balance;
        testMintPublicSale();
        vm.expectEmit(true, false, false, true);
        emit FundsWithdrawn(address(this), ethAmount);
        nft.withdraw();

        assertEq(0, address(nft).balance);
        assertEq(initialBalance + ethAmount, address(this).balance);
    }

    function testBaseURI() public {
        vm.expectEmit(true, false, false, true);
        emit BaseURIChanged(URI);
        nft.setBaseURI(URI);
        assertEq(URI, nft.baseURI());
    }

    function testBaseURIFailZeroLength() public {
        vm.expectRevert(bytes("Base URI must not be empty"));
        nft.setBaseURI("");
    }

    function testFuzzConstructorValidArgs(
        string memory name,
        string memory symbol,
        string memory uri,
        uint256 supply,
        address royaltyReceiver,
        uint96 royaltyNominator
    ) public {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(bytes(uri).length > 0);
        vm.assume(supply > 0 && supply <= 100000);
        vm.assume(supply > 0 && supply <= 100000);
        vm.assume(royaltyReceiver != address(0));
        vm.assume(royaltyNominator <= 10000);

        MyNFT fuzzed = new MyNFT(name, symbol, uri, supply, royaltyReceiver, royaltyNominator);

        assertEq(fuzzed.name(), name);
        assertEq(fuzzed.symbol(), symbol);
        assertEq(fuzzed.baseURI(), uri);
        assertEq(fuzzed.maxSupply(), supply);
        assertEq(fuzzed.totalMinted(), 0);

        uint256 salePrice = 1 ether;
        (address receiver, uint256 royaltyAmount) = fuzzed.royaltyInfo(0, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, (salePrice * royaltyNominator) / 10000);
    }

    function testFuzzSetPrices(uint256 privatePrice, uint256 publicPrice) public {
        privatePrice = bound(privatePrice, 1, 10 ether);
        publicPrice = bound(publicPrice, 1, 10 ether);

        nft.setPrices(privatePrice, publicPrice);

        assertEq(nft.privateSalePrice(), privatePrice);
        assertEq(nft.publicSalePrice(), publicPrice);
    }

    function testFuzzAddToWhitelist(address addr) public {
        vm.assume(addr != address(0));
        nft.addAddressToWhitelist(addr);
        assertTrue(nft.hasRole(nft.WHITELISTED_ROLE(), addr));
    }

    function testFuzzRemoveFromWhitelist(address addr) public {
        vm.assume(addr != address(0));
        nft.addAddressToWhitelist(addr);
        assertTrue(nft.hasRole(nft.WHITELISTED_ROLE(), addr));

        nft.removeAddressFromWhitelist(addr);
        assertFalse(nft.hasRole(nft.WHITELISTED_ROLE(), addr));
    }

    function testFuzzMintPublicSale(address user) public {
        vm.assume(user != address(0) && user.code.length == 0);
        nft.togglePublicSale();

        vm.deal(user, 0.001 ether);
        vm.startPrank(user);
        nft.mintPublicSale{value: 0.001 ether}();
        vm.stopPrank();

        assertEq(nft.ownerOf(1), user);
        assertEq(nft.totalMinted(), 1);
    }

    fallback() external payable {}

    receive() external payable {}
}
