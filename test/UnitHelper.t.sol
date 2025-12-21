// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {UnitBaseTest} from "./UnitBase.t.sol";
import {UnitHelper} from "../src/UnitHelper.sol";
import {IUnit} from "../src/IUnit.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract UnitHelperTest is UnitBaseTest {
    UnitHelper public helper;

    function setUp() public override {
        super.setUp();
        helper = new UnitHelper();
    }

    /**
     * @notice Test multiply with empty array.
     */
    function testMultiplyEmpty() public {
        string[] memory expressions = new string[](0);
        IUnit[] memory units = helper.multiply(l, expressions);
        assertEq(units.length, 0, "should return empty array");
    }

    /**
     * @notice Test multiply with single element.
     */
    function testMultiplySingle() public {
        string[] memory expressions = new string[](1);
        expressions[0] = "USD";

        IUnit[] memory units = helper.multiply(l, expressions);

        assertEq(units.length, 1, "should return single unit");
        assertEq(units[0].symbol(), "USD", "should have correct symbol");
    }

    /**
     * @notice Test multiply with multiple elements.
     */
    function testMultiplyMultiple() public {
        string[] memory expressions = new string[](3);
        expressions[0] = "USD";
        expressions[1] = "ETH";
        expressions[2] = "kg";

        IUnit[] memory units = helper.multiply(l, expressions);

        assertEq(units.length, 3, "should return three units");
        assertEq(units[0].symbol(), "USD", "first unit symbol");
        assertEq(units[1].symbol(), "ETH", "second unit symbol");
        assertEq(units[2].symbol(), "kg", "third unit symbol");
    }

    /**
     * @notice Test multiply with compound units.
     */
    function testMultiplyCompound() public {
        string[] memory expressions = new string[](4);
        expressions[0] = "kg*m/s^2";
        expressions[1] = "USD/ETH";
        expressions[2] = "m^2";
        expressions[3] = "kg^1\\3";

        IUnit[] memory units = helper.multiply(l, expressions);

        assertEq(units.length, 4, "should return four units");
        assertEq(units[0].symbol(), "kg*m/s^2", "force unit");
        assertEq(units[1].symbol(), "USD/ETH", "exchange rate");
        assertEq(units[2].symbol(), "m^2", "area");
        assertEq(units[3].symbol(), "kg^1\\3", "rational exponent");
    }

    /**
     * @notice Test multiply creates units that can be used in forge.
     */
    function testMultiplyForge() public {
        string[] memory expressions = new string[](2);
        expressions[0] = "USD";
        expressions[1] = "ETH";

        IUnit[] memory units = helper.multiply(l, expressions);
        IUnit usd = units[0];
        IUnit reciprocalUsd = usd.reciprocal();

        // Owen can forge with the created units
        uint256 initialOne = l.balanceOf(address(owen));
        owen.forge(usd, 1000 ether, 1000 ether);

        // Check balances changed
        assertEq(usd.balanceOf(address(owen)), 1000 ether, "should have USD");
        assertEq(reciprocalUsd.balanceOf(address(owen)), 1000 ether, "should have 1/USD");
        assertLt(l.balanceOf(address(owen)), initialOne, "should have burned 1");

        // Verify invariant
        (uint256 u, uint256 v, uint256 w) = usd.invariant();
        assertEq(w, Math.sqrt(u * v), "invariant should hold");
    }

    /**
     * @notice Test multiply with duplicate symbols returns same unit.
     */
    function testMultiplyDuplicates() public {
        string[] memory expressions = new string[](3);
        expressions[0] = "USD";
        expressions[1] = "ETH";
        expressions[2] = "USD";

        IUnit[] memory units = helper.multiply(l, expressions);

        assertEq(units.length, 3, "should return three units");
        assertEq(address(units[0]), address(units[2]), "duplicate symbols should return same unit");
        assertNotEq(address(units[0]), address(units[1]), "different symbols should return different units");
    }

    /**
     * @notice Test multiply on non-identity unit.
     */
    function testMultiplyOnNonIdentity() public {
        IUnit usd = l.multiply("USD");

        string[] memory expressions = new string[](2);
        expressions[0] = "ETH";
        expressions[1] = "m";

        IUnit[] memory units = helper.multiply(usd, expressions);

        assertEq(units.length, 2, "should return two units");
        assertEq(units[0].symbol(), "ETH*USD", "should be USD*ETH");
        assertEq(units[1].symbol(), "USD*m", "should be USD*m");
    }

    /**
     * @notice Test multiply with anchored token symbol.
     */
    function testMultiplyAnchored() public {
        string[] memory expressions = new string[](1);
        expressions[0] = "$0xdAC17F958D2ee523a2206206994597C13D831ec7"; // USDT address

        IUnit[] memory units = helper.multiply(l, expressions);

        assertEq(units.length, 1, "should return one unit");
        assertEq(units[0].symbol(), "$0xdAC17F958D2ee523a2206206994597C13D831ec7", "should have anchored symbol");
    }

    /**
     * @notice Test multiply normalizes symbols.
     */
    function testMultiplyNormalization() public {
        string[] memory expressions = new string[](2);
        expressions[0] = "a*b/a";
        expressions[1] = "m^4\\2";

        IUnit[] memory units = helper.multiply(l, expressions);

        assertEq(units.length, 2, "should return two units");
        assertEq(units[0].symbol(), "b", "should simplify a*b/a to b");
        assertEq(units[1].symbol(), "m^2", "should reduce m^4\\2 to m^2");
    }
}
