// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/// @dev ERC721 interface needed for this auction functionality
interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

/// @title  English Auction
/// @notice This contract provides an English auction for a specific ERC721 token.
/// @dev    It tracks bids, refunds and handles secure transfers.
contract EnglishAuction is AccessControl, IERC721Receiver, ReentrancyGuard, Pausable {
    /// @dev NFT token contract being auctioned
    IERC721 public immutable nft;

    /// @dev Token ID of the NFT being auctioned
    uint256 public immutable nftId;

    /// @notice The minimum amount by which a new bid must exceed the previous highest bid
    uint256 public minBidIncrement;

    /// @notice Duration of the auction
    uint256 public immutable duration;

    /// @notice Address of the seller (auction owner)
    address payable public immutable seller;

    /// @dev Bit flags for auction state (started/ended)
    uint8 private statusFlags;
    uint8 private constant STARTED_FLAG = 1 << 0;
    uint8 private constant ENDED_FLAG = 1 << 1;

    /// @notice Timestamp when the auction ends
    uint256 public endAt;

    /// @notice Grace period during which last-minute bids will extend the auction
    uint256 private constant BID_EXTENSION_GRACE_PERIOD = 10 minutes;

    /// @notice Duration to extend the auction when grace period logic triggers
    uint256 private constant EXTENSION_DURATION = 5 minutes;

    /// @notice Current highest bidder
    address public highestBidder;

    /// @notice Current highest bid amount in wei
    uint256 public highestBid;

    /// @dev Tracks refundable balances of outbid users
    mapping(address => uint256) public bids;

    /// @notice          Emitted when the auction is started
    /// @param startTime The timestamp at which the auction was started
    /// @param endTime   The timestamp when the auction will end
    event AuctionStarted(uint256 startTime, uint256 endTime);

    /// @notice       Emitted when a new valid bid is placed
    /// @param bidder The address of the bidder
    /// @param amount The amount of the bid
    event BidPlaced(address indexed bidder, uint256 amount);

    /// @notice       Emitted when a bidder withdraws their balance
    /// @param bidder The address of the withdrawing bidder
    /// @param amount The amount withdrawn
    event Withdrawal(address indexed bidder, uint256 amount);

    /// @notice       Emitted when the auction ends
    /// @param winner The address of the winning bidder
    /// @param amount The final winning bid
    event AuctionEnded(address indexed winner, uint256 amount);

    /// @notice Emitted if the auction is cancelled before any bids
    event AuctionCancelled();

    /// @notice Emitted when an auction is created
    event AuctionCreated(
        address indexed auctionAddress,
        address indexed creator,
        address indexed nft,
        uint256 tokenId,
        uint256 duration,
        uint256 minBidIncrement
    );

    /// @notice Emitted when auction time is extended
    event AuctionExtended(uint256 newEndTime, address extendedBy);

    /// @notice Emitted if royalty is paid
    event RoyaltyPaid(uint256 nftId, address indexed receiver, uint256 amount);

    /// @notice The maximum duration an auction can last
    uint256 public constant MAX_DURATION = 30 days;

    /// @notice Role identifier for general admin functions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Role identifier for accounts that can manage the pause/unpause
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");    

    /// @notice                 Initializes a new English Auction contract
    /// @param _seller          The address of the NFT owner
    /// @param _nft             The NFT contract address
    /// @param _nftId           The ID of the auctioned NFT
    /// @param _duration        Duration of the auction (in seconds)
    /// @param _minBidIncrement Minimum increment required for new bids
    constructor(address _seller, address _nft, uint256 _nftId, uint256 _duration, uint256 _minBidIncrement) {
        require(_seller != address(0), "Seller cannot be zero address");
        require(_nft != address(0), "NFT cannot be zero address");
        require(_duration > 0 && _duration <= MAX_DURATION, "Invalid auction duration");

        nft = IERC721(_nft);
        nftId = _nftId;
        seller = payable(_seller);
        duration = _duration;
        minBidIncrement = _minBidIncrement;

        _grantRole(DEFAULT_ADMIN_ROLE, _seller);
        _grantRole(ADMIN_ROLE, _seller);
        _grantRole(PAUSER_ROLE, _seller);
    }

    /// @notice Ensures that only users with the admin role can call
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    /// @notice Ensures that only users with the pauser role can call
    modifier onlyPauser() {
        require(hasRole(PAUSER_ROLE, msg.sender), "Caller is not pauser");
        _;
    }    

    /// @notice Pauses the auction (for bidding and withdrawal)
    function pause() external onlyPauser {
        _pause();
    }

    /// @notice Resumes the auction
    function unpause() external onlyPauser {
        _unpause();
    }

    function grantPauserRole(address account) external onlyAdmin() {
        grantRole(PAUSER_ROLE, account);
    }

    function revokePauserRole(address account) external onlyAdmin {
        revokeRole(PAUSER_ROLE, account);
    }

    /// @notice Returns true if the auction has started or else false
    function isStarted() public view returns (bool) {
        return (statusFlags & STARTED_FLAG) != 0;
    }

    /// @notice Returns true if the auction has ended or else false
    function isEnded() public view returns (bool) {
        return (statusFlags & ENDED_FLAG) != 0;
    }

    /// @notice Starts the auction by transferring the NFT into the contract
    /// @dev    Only callable by the seller. NFT must be approved before that.
    function start() external onlyAdmin {
        require(!isStarted(), "Auction already started");
        require(nft.getApproved(nftId) == address(this), "Auction not approved for NFT");

        statusFlags |= STARTED_FLAG;
        uint256 currentTime = block.timestamp;
        endAt = currentTime + duration;
        nft.safeTransferFrom(seller, address(this), nftId);

        emit AuctionStarted(currentTime, endAt);
    }

    /// @notice Place a bid for the auctioned NFT
    /// @dev    Automatically refunds previous highest bidder. Triggers auction extension if within grace period.
    function bid() external payable whenNotPaused {
        require(isStarted(), "Auction not started");

        uint256 currentTime = block.timestamp;
        uint256 endTime = endAt;
        address currentHighestBidder = highestBidder;
        uint256 currentHighestBid = highestBid;
        uint256 increment = minBidIncrement;

        require(currentTime < endTime, "Auction already ended");
        require(msg.value >= currentHighestBid + increment, "Bid is too low");

        uint256 timeLeft = endTime - currentTime;
        if (timeLeft <= BID_EXTENSION_GRACE_PERIOD) {
            unchecked {
                endAt = endTime + EXTENSION_DURATION;
            }
            emit AuctionExtended(endAt, msg.sender);
        }

        if (currentHighestBidder != address(0)) {
            bids[currentHighestBidder] += currentHighestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender, msg.value);
    }

    /// @notice Withdraw funds if the bidder was outbid
    function withdraw() external nonReentrant whenNotPaused {
        uint256 bal = bids[msg.sender];
        require(bal > 0, "No balance to withdraw");
        bids[msg.sender] = 0;

        _safeTransferETH(msg.sender, bal);

        emit Withdrawal(msg.sender, bal);
    }

    /// @notice Cancel the auction if it has started but received no bids
    function cancelAuction() external onlyAdmin {
        require(isStarted(), "Auction not started");
        require(!isEnded(), "Auction already ended");
        require(highestBidder == address(0), "Cannot cancel after first bid");

        statusFlags |= ENDED_FLAG;
        nft.safeTransferFrom(address(this), seller, nftId);

        emit AuctionCancelled();
    }

    /// @notice Finalizes the auction and transfers the NFT and funds
    function end() external payable onlyAdmin {
        require(isStarted(), "Auction not started");
        require(block.timestamp >= endAt, "Auction time not yet over");
        require(!isEnded(), "Auction already ended");

        address currentHighestBidder = highestBidder;
        statusFlags |= ENDED_FLAG;

        uint256 salePrice = highestBid;
        if (currentHighestBidder != address(0)) {
            nft.safeTransferFrom(address(this), currentHighestBidder, nftId);

            address royaltyReceiver;
            uint256 royaltyAmount;

            if (IERC165(address(nft)).supportsInterface(type(IERC2981).interfaceId)) {
                (royaltyReceiver, royaltyAmount) = IERC2981(address(nft)).royaltyInfo(nftId, salePrice);
            }

            if (royaltyAmount > 0) {
                _safeTransferETH(royaltyReceiver, royaltyAmount);
                _safeTransferETH(seller, salePrice - royaltyAmount);
                emit RoyaltyPaid(nftId, royaltyReceiver, royaltyAmount);
            } else {
                _safeTransferETH(seller, salePrice);
            }
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit AuctionEnded(currentHighestBidder, salePrice);
    }

    /// @dev Safely transfers ETH to a recipient
    function _safeTransferETH(address receiver, uint256 amount) internal {
        (bool success,) = receiver.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /// @notice It handles the receipt of an ERC721 token
    /// @dev    This function is called by the ERC721 contract when `safeTransferFrom` is used to transfer
    ///         an NFT to this contract. It returns the required selector to confirm the transfer.
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @dev Prevent direct ETH transfers
    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    /// @notice Fallback function to reject unexpected or invalid calls
    /// @dev    This contract only accepts ETH through designated bidding methods.
    fallback() external payable {
        revert("Contract only accepts ETH bids via bid()");
    }
}
