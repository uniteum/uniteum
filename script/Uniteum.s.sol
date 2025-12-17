// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/Uniteum.sol";

/// @notice Deploy the Uniteum 0.0 1 contract.
/// @dev Usage: forge script script/Uniteum.s.sol -f $chain --private-key $tx_key
contract UniteumCreate2 is Script {
    function run() external {
        vm.startBroadcast();
        Uniteum actual = new Uniteum{salt: 0x0}();
        vm.stopBroadcast();
        console2.log("actual   :", address(actual));
    }
}
