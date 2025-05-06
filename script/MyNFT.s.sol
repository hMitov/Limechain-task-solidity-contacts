// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract MyNFTScript is Script {
    function setUp() public {}

    function run() public {
        uint privateKey = uint256(vm.envBytes32("TEST_ACCOUNT_1_PRIVATE_KEY"));
        vm.startBroadcast(privateKey);

        MyNFT mynft = new MyNFT(
            "BestNft",
            "---@@66@@---",
            "https://example.com/token-image.png"
        );

        mynft.togglePublicSale();

        console.log("NFT contract deployed at:", address(mynft));

        vm.stopBroadcast();
    }
}
