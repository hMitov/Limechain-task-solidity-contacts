// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ScriptConfig} from "./ScriptConfig.s.sol";
import {MyNFT} from "../src/MyNFT.sol";

/// @title  NFTDeployWithPublicSaleScript
/// @notice Deployment script for the MyNFT ERC721 contract
/// @dev    Requires environment variables to be set in `.env` file
contract NFTDeployWithPublicSaleScript is Script, ScriptConfig {
    MyNFT public mynft;
    uint256 private privateKey;
    string private name;
    string private symbol;
    string private uri;
    uint256 private maxSupply;
    address private royaltyReceiver;
    uint96 private royaltyNominator;

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
        loadEnvVars();

        vm.startBroadcast(privateKey);

        mynft = new MyNFT(name, symbol, uri, maxSupply, royaltyReceiver, royaltyNominator);
        enablePublicSale();

        vm.stopBroadcast();
    }

    function loadEnvVars() internal override {
        privateKey = getEnvPrivateKey("TEST_ACCOUNT_1_PRIVATE_KEY");
        name = getEnvString("NFT_NAME");
        symbol = getEnvString("NFT_SYMBOL");
        uri = getEnvString("NFT_URI");
        maxSupply = getEnvUint("NFT_MAX_SUPPLY");
        royaltyReceiver = getEnvAddress("NFT_ROYALTY_RECEIVER");
        royaltyNominator = getEnvRoyalty("NFT_ROYALTY_NOMINATOR");
    }

    function enablePublicSale() internal {
        mynft.togglePublicSale();
    }
}
