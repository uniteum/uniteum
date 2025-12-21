// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IUnit} from "./IUnit.sol";

/**
 * @title UnitHelper
 * @notice Helper contract for common IUnit operations.
 */
contract UnitHelper {
    /**
     * @notice Multiply a unit by an array of symbolic expressions.
     * @dev Calls multiply on the provided unit for each string in the array.
     * @param unit The base unit to multiply.
     * @param expressions Array of string expressions to multiply by.
     * @return units Array of resulting IUnit instances.
     */
    function multiply(IUnit unit, string[] memory expressions) external returns (IUnit[] memory units) {
        units = new IUnit[](expressions.length);
        for (uint256 i = 0; i < expressions.length; i++) {
            units[i] = unit.multiply(expressions[i]);
        }
    }

    /**
     * @notice Predict the units resulting from multiplying a unit by an array of symbolic expressions.
     * @dev View-only; calls product on the provided unit for each string in the array.
     * @param unit The base unit to multiply.
     * @param expressions Array of string expressions to multiply by.
     * @return units Array of predicted IUnit instances.
     * @return symbols Array of canonical symbol strings.
     */
    function product(IUnit unit, string[] memory expressions)
        external
        view
        returns (IUnit[] memory units, string[] memory symbols)
    {
        units = new IUnit[](expressions.length);
        symbols = new string[](expressions.length);
        for (uint256 i = 0; i < expressions.length; i++) {
            (units[i], symbols[i]) = unit.product(expressions[i]);
        }
    }
}
