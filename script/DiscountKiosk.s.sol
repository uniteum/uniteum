// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {DiscountKiosk} from "../src/DiscountKiosk.sol";

/// @notice Deploy the DiscountKiosk contract.
/// @dev Usage: forge script script/DiscountKiosk.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract DiscountKioskProto is Script {
    function run() public {
        vm.startBroadcast();

        DiscountKiosk proto = new DiscountKiosk{salt: 0x0}();
        console2.log("Deployed DiscountKiosk proto at:", address(proto));

        vm.stopBroadcast();
    }
}
