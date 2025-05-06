// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./EnglishAuction.sol";

contract EnglishAuctionFactory {
    address[] public allAuctions;

    mapping(address => mapping(uint256 => address)) public activeAuctions;

    event AuctionCreated(
        address indexed auctionAddress,
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        uint256 duration,
        uint256 minBidIncrement
    );

    function createAuction(address _nft, uint256 _tokenId, uint256 _duration, uint256 _minBidIncrement)
        external
        returns (address)
    {
        require(activeAuctions[_nft][_tokenId] == address(0), "Auction already exists for this NFT");

        EnglishAuction auction = new EnglishAuction(tx.origin, _nft, _tokenId, _duration, _minBidIncrement);

        address auctionAddress = address(auction);
        allAuctions.push(auctionAddress);

        activeAuctions[_nft][_tokenId] = auctionAddress;

        emit AuctionCreated(auctionAddress, tx.origin, _nft, _tokenId, _duration, _minBidIncrement);

        return auctionAddress;
    }
}
