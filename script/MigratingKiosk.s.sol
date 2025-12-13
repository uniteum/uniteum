// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {MigratingKiosk} from "../src/MigratingKiosk.sol";

/// @notice Deploy the MigratingKiosk contract.
/// @dev Usage: forge script script/MigratingKiosk.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract MigratingKioskProto is Script {
    function run() public {
        vm.startBroadcast();

        MigratingKiosk proto = new MigratingKiosk{salt: 0x0}();
        console2.log("Deployed MigratingKiosk proto at:", address(proto));

        vm.stopBroadcast();
    }
}
