// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Mintlet} from "../src/Mintlet.sol";

/// @notice Deploy the Mintlet contract.
/// @dev Usage: forge script script/Mintlet.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract MintletProto is Script {
    function run() public {
        vm.startBroadcast();

        Mintlet proto = new Mintlet{salt: 0x0}();
        console2.log("Deployed Mintlet proto at:", address(proto));

        vm.stopBroadcast();
    }
}
