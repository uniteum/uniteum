// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {UnitBaseTest, Units, IUnit} from "./UnitBase.t.sol";
import {TestToken} from "./TestToken.sol";

contract ForgeAnchoredTest is UnitBaseTest {
    using Units for *;

    uint256 initialOne = 1e6;
    uint256 maxTransfer = initialOne;
    TestToken public wbtc;
    TestToken public weth;
    IUnit public awbtc;
    IUnit public awbtcr;

    function setUp() public virtual override {
        super.setUp();
        owen.migrate(proto1.balanceOf(address(owen)));

        wbtc = alex.newToken("WBTC", 1e6);
        awbtc = l.anchored(wbtc);
        awbtcr = awbtc.reciprocal();
        alex.addToken(awbtc);
        alex.addToken(awbtcr);
    }

    function test_AnchoredForge() public returns (int256 du, int256 dv, int256 dw) {
        owen.give(address(alex), initialOne, l);

        dw = alex.forge(awbtc, 1, 0);
        assertEq(awbtc.balanceOf(address(alex)), 1, "alex should have 1 awbtc");
        assertEq(wbtc.balanceOf(address(alex)), 1e6 - 1, "alex should have 1e6 - 1 wbtc");
        dw = alex.forge(awbtc, -1, 0);
        assertEq(awbtc.balanceOf(address(alex)), 0, "alex should have 0 awbtc");
        assertEq(wbtc.balanceOf(address(alex)), 1e6, "alex should have 1e6 wbtc");
        dw = alex.forge(awbtc, 1, 0);
        dw = alex.forge(awbtc, 0, 1);
        dw = alex.forge(awbtc, 1, 0);
        dw = alex.forge(awbtc, 0, 1);
        dw = alex.forge(awbtc, -1, -1);
        dw = alex.forge(awbtc, -1, -1);
        dw = alex.forge(awbtc, 10, 10);
        dw = alex.forge(awbtc, -10, -10);

        (du, dv, dw) = alex.liquidate(awbtc);
        assertEq(l.balanceOf(address(alex)), initialOne, "alex lost/gained some 1");
        assertEq(l.totalSupply(), ONE_MINTED, "supply lost/gained some 1");
    }
}
