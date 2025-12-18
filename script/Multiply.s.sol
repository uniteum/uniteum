// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IUnit} from "../src/IUnit.sol";

/// @notice Deploy a specific unit using an existing "1" (ONE) contract.
/// @dev Usage examples:
///      SYMBOL="meter" forge script script/Multiply.s.sol -f $chain --private-key $tx_key --broadcast
///      SYMBOL="kg*m/s^2" forge script script/Multiply.s.sol -f $chain --private-key $tx_key --broadcast
///      SYMBOL="\$btc" forge script script/Multiply.s.sol -f $chain --private-key $tx_key --broadcast
///
/// @dev Environment variables:
///      ONE    - Address of the identity unit "1" (required)
///      SYMBOL - Symbol of the unit to create (required, e.g., "meter", "kg*m/s^2", "$0xdAC17F958D2ee523a2206206994597C13D831ec7")
///
/// @dev The script will:
///      1. Connect to the existing ONE contract
///      2. Check if the unit already exists
///      3. Create the unit if it doesn't exist using multiply()
///      4. Log the unit address and symbol
contract Multiply is Script {
    function run() public {
        // Get the address of the identity unit "1"
        address oneAddress = vm.envAddress("ONE");
        string memory symbol = vm.envString("SYMBOL");

        IUnit one = IUnit(oneAddress);

        console2.log("Using ONE at:", oneAddress);
        console2.log("Requested symbol:", symbol);

        // Check if unit already exists
        (IUnit unit, string memory canonicalSymbol) = one.product(symbol);
        bool alreadyExists = address(unit).code.length > 0;

        if (alreadyExists) {
            console2.log("\nUnit already exists!");
        } else {
            console2.log("\nUnit does not exist, deploying...");
            console2.log("Canonical symbol:", canonicalSymbol);

            vm.startBroadcast();

            unit = one.multiply(symbol);

            vm.stopBroadcast();

            console2.log("\nSuccessfully deployed!");
        }
        console2.log("Unit address:", address(unit));
        console2.log("Unit symbol:", unit.symbol());
    }
}
