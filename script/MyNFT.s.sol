// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {MyNFT} from "../src/MyNFT.sol";

/// @title  MyNFTScript
/// @notice Deployment script for the MyNFT ERC721 contract
/// @dev    Requires environment variables to be set in `.env` file
contract MyNFTScript is Script {
    /// @notice Executes the deployment of the MyNFT contract
    /// @dev    Requires the following environment variables:
    /// - TEST_ACCOUNT_1_PRIVATE_KEY
    /// - NFT_NAME
    /// - NFT_SYMBOL
    /// - NFT_URI
    /// - NFT_MAX_SUPPLY
    /// - NFT_ROYALTY_RECEIVER
    /// - NFT_ROYALTY_NOMINATOR
    function run() public {
        uint256 privateKey;

        try vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY") returns (bytes32 keyBytes) {
            require(keyBytes != bytes32(0), "TEST_ACCOUNT_1_PRIVATE_KEY is empty");
            privateKey = uint256(keyBytes);
        } catch {
            revert("TEST_ACCOUNT_1_PRIVATE_KEY is missing in .env");
        }

        string memory name;
        try vm.envString("NFT_NAME") returns (string memory val) {
            require(bytes(val).length > 0, "NFT_NAME is empty");
            name = val;
        } catch {
            revert("NFT_NAME is missing in .env");
        }

        string memory symbol;
        try vm.envString("NFT_SYMBOL") returns (string memory val) {
            require(bytes(val).length > 0, "NFT_SYMBOL is empty");
            symbol = val;
        } catch {
            revert("NFT_SYMBOL is missing in .env");
        }

        string memory uri;
        try vm.envString("NFT_URI") returns (string memory val) {
            require(bytes(val).length > 0, "NFT_URI is empty");
            uri = val;
        } catch {
            revert("NFT_URI is missing in .env");
        }

        uint256 maxSupply;
        try vm.envUint("NFT_MAX_SUPPLY") returns (uint256 val) {
            require(val > 0, "NFT_MAX_SUPPLY must be > 0");
            maxSupply = val;
        } catch {
            revert("NFT_MAX_SUPPLY is missing or invalid in .env");
        }

        address royaltyReceiver;
        try vm.envAddress("NFT_ROYALTY_RECEIVER") returns (address addr) {
            require(addr != address(0), "NFT_ROYALTY_RECEIVER must not be zero address");
            royaltyReceiver = addr;
        } catch {
            revert("NFT_ROYALTY_RECEIVER is missing or invalid in .env");
        }

        uint96 royaltyNominator;
        try vm.envUint("NFT_ROYALTY_NOMINATOR") returns (uint256 val) {
            require(val <= 10000, "Royalty nominator must be <= 10000");
            royaltyNominator = uint96(val);
        } catch {
            revert("NFT_ROYALTY_NOMINATOR is missing or invalid in .env");
        }

        vm.startBroadcast(privateKey);

        MyNFT mynft = new MyNFT(name, symbol, uri, maxSupply, royaltyReceiver, royaltyNominator);
        mynft.togglePublicSale();

        vm.stopBroadcast();
    }
}
