// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";

/// @title  StartAuction1Script
/// @notice A script to start a specific EnglishAuction contract using a private key from environment
/// @dev    Requires environment variables to be set in `.env` file
contract StartAuction1Script is Script {
    /// @notice Runs the broadcast script to call `start()` on a deployed auction
    /// @dev    Requires the `TEST_ACCOUNT_1_PRIVATE_KEY` and `AUCTION_1_ADDRESS` environment variables
    function run() public {
        uint256 privateKey;
        try vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY") returns (bytes32 keyBytes) {
            require(keyBytes != bytes32(0), "TEST_ACCOUNT_1_PRIVATE_KEY is empty");
            privateKey = uint256(keyBytes);
        } catch {
            revert("TEST_ACCOUNT_1_PRIVATE_KEY is missing in .env");
        }

        address auctionAddress;
        try vm.envAddress("AUCTION_1_ADDRESS") returns (address addr) {
            require(addr != address(0), "AUCTION_1_ADDRESS is zero address");
            auctionAddress = addr;
        } catch {
            revert("AUCTION_1_ADDRESS is missing or invalid in .env");
        }

        vm.startBroadcast(privateKey);

        EnglishAuction(payable(auctionAddress)).start();

        vm.stopBroadcast();
    }
}
