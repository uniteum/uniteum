// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Unit, IERC20} from "../src/Unit.sol";

/// @notice Deploy the BridgeFactory contract.
/// @dev Usage: forge script script/Unit.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract UnitCreate2 is Script {
    address constant UPSTREAM_ONE = 0xC833f0B7cd7FC479DbbF6581EB4eEFc396Cf39E4;

    function run() public {
        vm.startBroadcast();

        Unit unit = new Unit{salt: 0x0}(IERC20(UPSTREAM_ONE));
        console2.log("Deployed Unit at:", address(unit));

        vm.stopBroadcast();
    }
}
