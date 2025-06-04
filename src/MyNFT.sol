// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";

/// @title  MyNFT Contract
/// @notice This contract implements an ERC721-compliant NFT with private and public minting mechanisms.
/// @dev    It includes whitelist-based private sales, togglable sale phases, fixed-price minting,
///         and admin controls for pricing, supply, and base URI, royalties (EIP-2981) and pause control.
contract MyNFT is ERC721Royalty, Ownable, ReentrancyGuard, Pausable {
    /// @notice The maximum number of NFTs that can be minted
    uint256 public immutable maxSupply;

    /// @notice The total number of NFTs minted so far
    uint256 public totalMinted;

    /// @notice ETH price for private sale
    uint256 public privateSalePrice = 0.0005 ether;

    /// @notice ETH price for public sale
    uint256 public publicSalePrice = 0.001 ether;

    /// @dev Bit flag for sale states (private/public)
    uint8 private saleFlags;
    uint8 private constant PRIVATE_SALE_FLAG = 1 << 0;
    uint8 private constant PUBLIC_SALE_FLAG = 1 << 1;

    /// @notice Tracks addresses allowed to mint in the private sale
    mapping(address => bool) public whitelist;

    /// @notice Base URI for token metadata
    string public baseURI;

    /// @notice Emitted when private sale is toggled
    event PrivateSaleToggled();

    /// @notice Emitted when public sale is toggled
    event PublicSaleToggled();

    /// @notice Emitted when sale prices are updated
    event PricesUpdated(uint256 privateSalePrice, uint256 publicSalePrice);

    /// @notice Emitted when a user is added to whitelist
    event AddressAddedToWhitelist(address userAddress);

    /// @notice Emitted when a user is removed from whitelist
    event AddressRemovedFromWhitelist(address userAddress);

    /// @notice Emitted when an NFT is minted
    event NFTMinted(address indexed to, uint256 tokenId);

    /// @notice Emitted when contract funds are withdrawn
    event FundsWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when base URI is changed
    event BaseURIChanged(string newBaseURI);

    /// @param _name                Name of the NFT collection
    /// @param _symbol              Symbol of the NFT
    /// @param _URI                 Base URI for metadata
    /// @param _maxSupply           Maximum number of NFTs that can be minted
    /// @param _royaltyReceiver     Address that will receive royalty payments
    /// @param _royaltyFeeNumerator Royalty fee in basis points (e.g., 500 = 5%)
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _URI,
        uint256 _maxSupply,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        require(bytes(_name).length > 0, "NFT name must not be empty");
        require(bytes(_symbol).length > 0, "NFT symbol must not be empty");
        require(bytes(_URI).length > 0, "Base URI must not be empty");
        require(_maxSupply > 0, "Max supply must be greater than zero");
        require(_royaltyReceiver != address(0), "Royalty receiver cannot be zero address");
        require(_royaltyFeeNumerator <= _feeDenominator(), "Royalty fee will exceed salePrice");

        baseURI = _URI;
        maxSupply = _maxSupply;

        _setDefaultRoyalty(_royaltyReceiver, _royaltyFeeNumerator);
    }

    /// @notice Pauses the auction (for bidding and withdrawal)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes the auction
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Toggles the private sale status
    function togglePrivateSale() external onlyOwner {
        saleFlags ^= PRIVATE_SALE_FLAG;
        emit PrivateSaleToggled();
    }

    /// @notice Toggles the public sale status
    function togglePublicSale() external onlyOwner {
        saleFlags ^= PUBLIC_SALE_FLAG;
        emit PublicSaleToggled();
    }

    /// @notice      Checks if private sale is active
    /// @return true if private sale is active
    function isPrivateSaleActive() public view returns (bool) {
        return (saleFlags & PRIVATE_SALE_FLAG) != 0;
    }

    /// @notice      Checks if public sale is active
    /// @return true if public sale is active
    function isPublicSaleActive() public view returns (bool) {
        return (saleFlags & PUBLIC_SALE_FLAG) != 0;
    }

    /// @notice            Adds a user address to the private sale whitelist
    /// @param userAddress The address to whitelist
    function addAddressToWhitelist(address userAddress) external onlyOwner {
        require(userAddress != address(0), "Cannot whitelist zero address");
        require(!whitelist[userAddress], "Address is already whitelisted");

        whitelist[userAddress] = true;
        emit AddressAddedToWhitelist(userAddress);
    }

    /// @notice            Removes a user from the private sale whitelist
    /// @param userAddress The address to remove
    function removeAddressFromWhitelist(address userAddress) external onlyOwner {
        require(userAddress != address(0), "Cannot remove zero address");
        require(whitelist[userAddress], "Address is already whitelisted");

        whitelist[userAddress] = false;
        emit AddressRemovedFromWhitelist(userAddress);
    }

    /// @notice                  Sets the private sale price
    /// @param _privateSalePrice New price for private sale
    function setPrivateSalePrice(uint256 _privateSalePrice) public onlyOwner {
        privateSalePrice = _privateSalePrice;
        emit PricesUpdated(privateSalePrice, publicSalePrice);
    }

    /// @notice                 Sets the public sale price
    /// @param _publicSalePrice New price for public sale
    function setPublicSalePrice(uint256 _publicSalePrice) public onlyOwner {
        publicSalePrice = _publicSalePrice;
        emit PricesUpdated(privateSalePrice, publicSalePrice);
    }

    /// @notice                  Sets both private and public sale prices
    /// @param _privateSalePrice New private sale price
    /// @param _publicSalePrice  New public sale price
    function setPrices(uint256 _privateSalePrice, uint256 _publicSalePrice) external onlyOwner {
        setPrivateSalePrice(_privateSalePrice);
        setPublicSalePrice(_publicSalePrice);
        emit PricesUpdated(privateSalePrice, publicSalePrice);
    }

    /// @notice Mints NFT for the sender during the private sale phase.
    /// @dev    Requires the private sale to be active and the sender to be whitelisted.
    ///         The caller must send exactly `privateSalePrice` in ETH.
    ///         Emits a standard {Transfer} event from ERC721 upon successful mint.
    function mintPrivateSale() external payable whenNotPaused {
        require(isPrivateSaleActive(), "Private sale is not active");
        require(whitelist[msg.sender], "Caller is not whitelisted");
        require(msg.value == privateSalePrice, "Incorrect ETH amount sent");

        uint256 minted = totalMinted;
        require(minted < maxSupply, "Max supply reached, cannot mint more");

        uint256 newTokenId = minted + 1;
        _safeMint(msg.sender, newTokenId);
        totalMinted = newTokenId;

        emit NFTMinted(msg.sender, newTokenId);
    }

    /// @notice Mints NFT for the sender during the public sale phase.
    /// @dev    Requires the public sale to be active. The caller must send exactly `publicSalePrice` in ETH.
    ///         Emits a standard {Transfer} event from ERC721 upon successful mint.
    function mintPublicSale() external payable whenNotPaused {
        require(isPublicSaleActive(), "Public sale is not active");
        require(msg.value == publicSalePrice, "Incorrect ETH amount sent");
        uint256 minted = totalMinted;
        require(minted < maxSupply, "Max supply reached, cannot mint more");

        uint256 newTokenId = minted + 1;
        _safeMint(msg.sender, newTokenId);
        totalMinted = newTokenId;

        emit NFTMinted(msg.sender, newTokenId);
    }

    /// @notice Withdraws all ETH from the contract to the owner
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }

    /// @dev           Returns the base URI for metadata
    /// @return string URI used for all token metadata
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /// @notice       Sets a new base URI
    /// @param newURI The new URI to set
    function setBaseURI(string memory newURI) external onlyOwner {
        require(bytes(newURI).length > 0, "Base URI must not be empty");
        baseURI = newURI;
        emit BaseURIChanged(newURI);
    }
}
