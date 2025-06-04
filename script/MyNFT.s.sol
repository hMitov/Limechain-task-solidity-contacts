// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ScriptUtils} from "./ScriptUtils.s.sol";
import {MyNFT} from "../src/MyNFT.sol";

/// @title  MyNFTScript
/// @notice Deployment script for the MyNFT ERC721 contract
/// @dev    Requires environment variables to be set in `.env` file
contract MyNFTScript is Script, ScriptUtils {
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
        uint256 privateKey = getEnvPrivateKey("TEST_ACCOUNT_1_PRIVATE_KEY");

        string memory name = getEnvString("NFT_NAME");
        string memory symbol = getEnvString("NFT_SYMBOL");
        string memory uri = getEnvString("NFT_URI");

        uint256 maxSupply = getEnvUint("NFT_MAX_SUPPLY");
        address royaltyReceiver = getEnvAddress("NFT_ROYALTY_RECEIVER");
        uint96 royaltyNominator = getEnvRoyalty("NFT_ROYALTY_NOMINATOR");

        vm.startBroadcast(privateKey);

        MyNFT mynft = new MyNFT(name, symbol, uri, maxSupply, royaltyReceiver, royaltyNominator);
        mynft.togglePublicSale();

        vm.stopBroadcast();
    }
}
