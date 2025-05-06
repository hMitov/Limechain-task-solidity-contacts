// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnglishAuction} from "../src/EnglishAuction.sol";

contract StartAuction1Script is Script {
    function run() public {
        uint256 privateKey = uint256(vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY"));
        vm.startBroadcast(privateKey);

        address auctionAddress = vm.envAddress("AUCTION_1_ADDRESS");
        EnglishAuction(payable(auctionAddress)).start();

        vm.stopBroadcast();
    }
} 