// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Unit, IERC20} from "../src/Unit.sol";

/// @notice Deploy the BridgeFactory contract.
/// @dev Usage: forge script script/Unit.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract UnitCreate2 is Script {
    function run() public {
        address hub = vm.envAddress("HUB_SOLID");
        console2.log("HUB_SOLID at:", hub);

        vm.startBroadcast();

        Unit unit = new Unit{salt: 0x0}(IERC20(hub));
        console2.log("Deployed Unit at:", address(unit));

        vm.stopBroadcast();
    }
}
