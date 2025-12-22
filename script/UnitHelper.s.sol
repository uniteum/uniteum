// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {UnitHelper} from "../src/UnitHelper.sol";

/**
 * @notice Deploy the UnitHelper contract.
 * @dev Usage: forge script script/UnitHelper.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
 */
contract UnitHelperScript is Script {
    function run() public {
        vm.startBroadcast();

        UnitHelper helper = new UnitHelper{salt: 0x0}();
        console2.log("Deployed UnitHelper at:", address(helper));

        vm.stopBroadcast();
    }
}
