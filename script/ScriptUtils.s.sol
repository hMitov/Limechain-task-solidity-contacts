// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

abstract contract ScriptUtils is Script {
    function getEnvPrivateKey(string memory key) internal view returns (uint256) {
        try vm.envBytes32(key) returns (bytes32 keyBytes) {
            require(keyBytes != bytes32(0), string.concat(key, " is empty"));
            return uint256(keyBytes);
        } catch {
            revert(string.concat(key, " is missing in .env"));
        }
    }

    function getEnvAddress(string memory key) internal view returns (address) {
        try vm.envAddress(key) returns (address addr) {
            require(addr != address(0), string.concat(key, " is zero address"));
            return addr;
        } catch {
            revert(string.concat(key, " is missing or invalid in .env"));
        }
    }

    function getEnvUint(string memory key) internal view returns (uint256) {
        try vm.envUint(key) returns (uint256 val) {
            require(val > 0, string.concat(key, " must be > 0"));
            return val;
        } catch {
            revert(string.concat(key, " is missing or invalid in .env"));
        }
    }

    function getEnvString(string memory key) internal view returns (string memory) {
        try vm.envString(key) returns (string memory val) {
            require(bytes(val).length > 0, string.concat(key, " is empty"));
            return val;
        } catch {
            revert(string.concat(key, " is missing in .env"));
        }
    }

    function getEnvRoyalty(string memory key) internal view returns (uint96) {
        try vm.envUint(key) returns (uint256 val) {
            require(val > 0 && val <= 10000, string.concat(key, " must be <= 10000"));
            return uint96(val);
        } catch {
            revert(string.concat(key, " is missing or invalid in .env"));
        }
    }
}
