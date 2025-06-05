// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ScriptConfig} from "./ScriptConfig.s.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";

/// @title  StartAuction1Script
/// @notice A script to start a specific EnglishAuction contract using a private key from environment
/// @dev    Requires environment variables to be set in `.env` file
contract StartAuction1Script is Script, ScriptConfig {
    uint256 private privateKey;
    address private auctionAddress;

    /// @notice Runs the broadcast script to call `start()` on a deployed auction
    /// @dev    Requires the `TEST_ACCOUNT_1_PRIVATE_KEY` and `AUCTION_1_ADDRESS` environment variables
    function run() public {
        loadEnvVars();

        vm.startBroadcast(privateKey);
        EnglishAuction(payable(auctionAddress)).start();
        vm.stopBroadcast();
    }

    function loadEnvVars() internal override {
        privateKey = getEnvPrivateKey("TEST_ACCOUNT_1_PRIVATE_KEY");
        auctionAddress = getEnvAddress("AUCTION_1_ADDRESS");
    }
}
