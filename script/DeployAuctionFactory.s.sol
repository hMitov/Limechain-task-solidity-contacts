// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnvLoader} from "./EnvLoader.s.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";

/// @title  DeployAuctionFactoryScript
/// @notice Deployment script for the EnglishAuctionFactory contract
/// @dev    Requires environment variables to be set in `.env` file
contract DeployAuctionFactoryScript is EnvLoader {
    EnglishAuctionFactory public factory;
    uint256 private privateKey;

    /// @notice Executes the deployment of the EnglishAuctionFactory contract
    /// @dev    Requires the `TEST_ACCOUNT_1_PRIVATE_KEY` environment variables
    function run() public {
        loadEnvVars();

        vm.startBroadcast(privateKey);
        factory = new EnglishAuctionFactory();
        vm.stopBroadcast();

        console.log("EnglishAuctionFactory deployed at:", address(factory));
    }

    function loadEnvVars() internal override {
        privateKey = getEnvPrivateKey("TEST_ACCOUNT_1_PRIVATE_KEY");
    }
}
