// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./EnglishAuction.sol";

/// @title  English Auction Factory
/// @notice Deploys EnglishAuction contracts and tracks active auctions. Removes English contracts.
/// @dev    Ensures that only one active auction exists per unique NFT and token at any time.
contract EnglishAuctionFactory {
    /// @notice All auctions created by this factory
    address[] public allAuctions;

    /// @notice Maximum duration allowed for any auction
    uint256 public constant MAX_AUCTION_DURATION = 30 days;

    /// @notice Tracks active auctions by NFT contract address and token ID
    mapping(address => mapping(uint256 => address)) public activeAuctions;

    /// @notice                Emitted when a new auction is created
    /// @param auctionAddress  The deployed auction address
    /// @param creator         The address of the creator of the auction
    /// @param nft             The NFT contract address
    /// @param tokenId         The NFT token ID
    /// @param duration        The duration of the auction
    /// @param minBidIncrement Minimum bid increment in wei
    event AuctionCreated(
        address indexed auctionAddress,
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        uint256 duration,
        uint256 minBidIncrement
    );

    /// @notice        Emitted when an auction is removed from active mapping
    /// @param nft     The NFT contract address
    /// @param tokenId The NFT token ID
    event AuctionRemoved(address indexed nft, uint256 indexed tokenId);

    /// @notice                 Creates a new EnglishAuction contract
    /// @param _nft             The NFT contract address
    /// @param _tokenId         Token ID of the NFT being auctioned
    /// @param _duration        Duration of the auction in seconds
    /// @param _minBidIncrement Minimum bid increment in wei
    /// @return                 'The' address of the newly created auction
    function createAuction(address _nft, uint256 _tokenId, uint256 _duration, uint256 _minBidIncrement)
        external
        returns (address)
    {
        require(_nft != address(0), "Invalid NFT address");
        require(_duration > 0, "Duration must be greater than zero");
        require(_duration <= MAX_AUCTION_DURATION, "Duration too long");
        require(_minBidIncrement > 0, "Min bid increment must be greater than zero");
        require(activeAuctions[_nft][_tokenId] == address(0), "Auction already exists");

        address creator = msg.sender;
        EnglishAuction auction = new EnglishAuction(creator, _nft, _tokenId, _duration, _minBidIncrement);

        address auctionAddress = address(auction);
        allAuctions.push(auctionAddress);

        activeAuctions[_nft][_tokenId] = auctionAddress;

        emit AuctionCreated(auctionAddress, creator, _nft, _tokenId, _duration, _minBidIncrement);

        return auctionAddress;
    }

    /// @notice         Removes an auction from the active mapping
    /// @dev            It can be executed only if it is ended
    /// @param _nft     The NFT contract address
    /// @param _tokenId Token ID of the NFT
    function removeAuction(address _nft, uint256 _tokenId) external {
        require(_nft != address(0), "NFT cannot be zero address");
        address auction = activeAuctions[_nft][_tokenId];
        require(auction != address(0), "No active auction for the NFT");

        require(EnglishAuction(payable(auction)).isEnded(), "Auction has not ended yet");

        delete activeAuctions[_nft][_tokenId];

        emit AuctionRemoved(_nft, _tokenId);
    }
}
