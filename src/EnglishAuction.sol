// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "forge-std/console.sol";

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract EnglishAuction is Ownable, IERC721Receiver, ReentrancyGuard {
    event AuctionStarted(uint256 startTime, uint256 endTime);
    event BidPlaced(address indexed bidder, uint256 amount);
    event Withdrawal(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event AuctionCancelled();

    IERC721 public immutable nft;
    uint256 public immutable nftId;
    uint256 public minBidIncrement;
    uint256 public immutable duration;

    address payable public immutable seller;
    bool public started;
    bool public ended;
    uint256 public endAt;

    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public bids;

    constructor(address _nft, uint256 _nftId, uint256 _duration, uint256 _minBidIncrement) Ownable(msg.sender) {
        nft = IERC721(_nft);
        nftId = _nftId;
        seller = payable(msg.sender);
        duration = _duration;
        minBidIncrement = _minBidIncrement;
    }

    function start() external onlyOwner {
        require(!started, "Auction has already started.");
        require(nft.getApproved(nftId) == address(this), "Auction contract is not approved to manage this NFT.");

        started = true;
        endAt = block.timestamp + duration;
        nft.safeTransferFrom(seller, address(this), nftId);

        emit AuctionStarted(block.timestamp, endAt);
    }

    function bid() external payable {
        require(started, "Auction has not started yet.");
        require(block.timestamp < endAt, "Auction time has already elapsed, no bids area allowed.");
        require(msg.value >= highestBid + minBidIncrement, "Your bid is tool low.");

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
            console.log("Highest bidder: ", highestBidder);
            console.log(bids[highestBidder]);
        }

        highestBid = msg.value;
        console.log("Highest bid is", highestBid);
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, msg.value);
    }

    function withdraw() external nonReentrant {
        uint256 bal = bids[msg.sender];
        console.log(bal);
        require(bal > 0, "There is no balance to withdraw.");
        bids[msg.sender] = 0;

        _safeTransferETH(msg.sender, bal);

        emit Withdrawal(msg.sender, bal);
    }

    function cancelAuction() external onlyOwner {
        require(started, "Auction has not started yet.");
        require(!ended, "Auction has already ended.");
        require(highestBidder == address(0), "There are already bids, you cannot cancel auction.");

        ended = true;
        nft.safeTransferFrom(address(this), seller, nftId);

        emit AuctionCancelled();
    }

    function end() external payable onlyOwner {
        require(started, "Auction has not started yet.");
        require(!ended, "Auction has already ended.");

        ended = true;
        if (highestBidder != address(0)) {
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            _safeTransferETH(seller, highestBid);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit AuctionEnded(highestBidder, highestBid);
    }

    function _safeTransferETH(address receiver, uint256 amount) internal {
        (bool success,) = receiver.call{value: amount}("");
        require(success, "ETH transfer failed.");
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        revert("Direct payments not allowed.");
    }

    fallback() external payable {
        revert("This contract accepts ETH bids only.");
    }
}
