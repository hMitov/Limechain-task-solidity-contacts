// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract MyNFT is ERC721, Ownable, ReentrancyGuard {
    uint256 public maxSupply = 10000;
    uint256 public totalMinted;

    uint256 public privateSalePrice = 0.0005 ether;
    uint256 public publicSalePrice = 0.001 ether;
    bool public isPrivateSaleActive = false;
    bool public isPublicSaleActive = false;

    mapping(address => bool) public whitelist;
    string public baseURI;

    constructor(string memory _name, string memory _symbol, string memory _URI)
        ERC721(_name, _symbol)
        Ownable(msg.sender)
    {
        baseURI = _URI;
    }

    function togglePrivateSale() external onlyOwner {
        isPrivateSaleActive = !isPrivateSaleActive;
    }

    function togglePublicSale() external onlyOwner {
        isPublicSaleActive = !isPublicSaleActive;
    }

    function addAddressesToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }
    }

    function removeAddressesFromWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (whitelist[addresses[i]]) {
                whitelist[addresses[i]] = false;
            }
        }
    }

    function setPrivateSalePrice(uint256 _privateSalePrice) public onlyOwner {
        privateSalePrice = _privateSalePrice;
    }

    function setPublicSalePrice(uint256 _publicSalePrice) public onlyOwner {
        publicSalePrice = _publicSalePrice;
    }

    function setPrices(uint256 _privateSalePrice, uint256 _publicSalePrice) external onlyOwner {
        setPrivateSalePrice(_privateSalePrice);
        setPublicSalePrice(_publicSalePrice);
    }

    function mintPrivateSale() external payable {
        require(isPrivateSaleActive, "Private sale is still not active.");
        require(whitelist[msg.sender], "Sender is not whitelisted.");
        require(msg.value == privateSalePrice, "There is a fixed ETH amount. The provided one is incorrect.");
        require(totalMinted < maxSupply, "Max supply has been already reached. You are not allowed to min anymore.");

        _safeMint(msg.sender, totalMinted + 1);
        totalMinted++;
    }

    function mintPublicSale() external payable {
        require(isPublicSaleActive, "Public sale is still not active.");
        require(msg.value == publicSalePrice, "There is a fixed ETH amount. The provided one is incorrect.");
        require(totalMinted < maxSupply, "Max supply has been already reached. You are not allowed to mind anymore.");

        _safeMint(msg.sender, totalMinted + 1);
        totalMinted++;
    }

    function withdraw() external onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newURI) external onlyOwner {
        baseURI = newURI;
    }
}
