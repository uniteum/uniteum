// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Unit, IERC20} from "../src/Unit.sol";

/// @notice Deploy the BridgeFactory contract.
/// @dev Usage: forge script script/Unit.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract UnitCreate2 is Script {
    address constant UPSTREAM = 0x8af6774Bec3b698a6dC873b117c4415367dEfea6;

    function run() public {
        vm.startBroadcast();

        Unit unit = new Unit{salt: 0x0}(IERC20(UPSTREAM));
        console2.log("Deployed Unit at:", address(unit));

        vm.stopBroadcast();
    }
}
