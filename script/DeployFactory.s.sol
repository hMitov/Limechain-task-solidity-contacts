// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {EnglishAuctionFactory} from "../src/EnglishAuctionFactory.sol";

contract DeployFactoryScript is Script {
    function run() public {
        uint256 privateKey = uint256(vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY"));
        vm.startBroadcast(privateKey);

        EnglishAuctionFactory factory = new EnglishAuctionFactory();

        console.log("EnglishAuctionFactory contract deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
