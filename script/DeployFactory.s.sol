// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";

/// @title  DeployFactoryScript
/// @notice Deployment script for the EnglishAuctionFactory contract
/// @dev    Requires environment variables to be set in `.env` file
contract DeployFactoryScript is Script {
    /// @notice Executes the deployment of the EnglishAuctionFactory contract
    /// @dev    Requires the `TEST_ACCOUNT_1_PRIVATE_KEY` environment variables
    function run() public {
        uint256 privateKey;
        try vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY") returns (bytes32 keyBytes) {
            require(keyBytes != bytes32(0), "TEST_ACCOUNT_1_PRIVATE_KEY is empty");
            privateKey = uint256(keyBytes);
        } catch {
            revert("TEST_ACCOUNT_1_PRIVATE_KEY is missing in .env");
        }

        vm.startBroadcast(privateKey);

        EnglishAuctionFactory factory = new EnglishAuctionFactory();
        console.log("EnglishAuctionFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
