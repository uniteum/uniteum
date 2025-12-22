// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {UnitBaseTest, Units, Unit, IUnit, console, Math} from "./UnitBase.t.sol";
import {TestToken, IERC20Metadata} from "./TestToken.sol";

contract ForgeTest is UnitBaseTest {
    using Units for *;

    uint256 initialOne = 1e6;
    uint256 maxTransfer = initialOne;

    function setUp() public virtual override {
        super.setUp();
        owen.migrate(proto1.balanceOf(address(owen)));
    }

    function test_ForgeSimple() public returns (int256 du, int256 dv, int256 dw) {
        owen.give(address(alex), initialOne, l);

        dw = alex.forge(U, 1, 1);
        dw = alex.forge(U, 0, 1);
        dw = alex.forge(U, 1, 0);
        dw = alex.forge(U, -1, -1);
        dw = alex.forge(U, -1, -1);
        dw = alex.forge(U, 10, 10);
        dw = alex.forge(U, -10, -10);

        (du, dv, dw) = alex.rndForge(U);

        // forge-lint: disable-next-line(unsafe-typecast)
        int256 we = -2 * int256(Math.sqrt(uint256(du * dv)));
        assertEq(dw, we, "unexpected change in 1");

        for (int256 i = 0; i < 2; i++) {
            (du, dv, dw) = alex.rndForge(U);
            (du, dv, dw) = alex.rndForge(V);
        }

        (uint256 us, uint256 vs, uint256 ws) = U.invariant();
        uint256 wse = Math.sqrt(us * vs);
        assertEq(ws, wse, "unexpected invariant");

        (du, dv, dw) = alex.liquidate(U);
        assertEq(l.balanceOf(address(alex)), initialOne, "alex lost/gained some 1");
        assertEq(l.totalSupply(), ONE_MINTED, "supply lost/gained some 1");
    }

    /// @dev This test case exposes a bug where the reciprocal name was not normalized in __initialize.
    function test_Bug() public returns (int256 du, int256 dv, int256 dw) {
        owen.give(address(alex), initialOne, l);

        dw = alex.forge(U, 210490, 100658);
        dw = alex.forge(V, 448532, 207095);
        (du, dv, dw) = alex.liquidate(U);
        assertEq(l.balanceOf(address(alex)), initialOne, "alex lost/gained some 1");
        assertEq(l.totalSupply(), ONE_MINTED, "supply lost/gained some 1");
    }

    /**
     * @dev This test case illustrates that a forger that mints a unit and its reciprocal makes money if the price changes after forging.
     * The is the complement to impermanent loss.
     */
    function test_VolatilityHedge() public returns (int256 du, int256 dv, int256 dw) {
        owen.give(address(alex), 1e3, l);
        owen.give(address(beck), 1e7, l);
        dw = alex.forge(U, 500, 500);
        dw = beck.forge(U, 5e5, 1e6);
        (du, dv, dw) = alex.liquidate(U);
        assertLt(1e3, alex.balance(l), "alex should have more 1");
        (du, dv, dw) = beck.liquidate(U);
        assertLt(beck.balance(l), 1e7, "beck should have less 1");
    }

    /**
     * @dev This test case illustrates what happens when alex sells off 1 of two equally priced pairs.
     * beck sells after, then alex sells to rebalance
     */
    function test_ForgeOrder() public returns (int256 du, int256 dv, int256 dw) {
        owen.give(address(alex), initialOne, l);
        owen.give(address(beck), initialOne, l);
        dw = alex.forge(U, 1e5, 1e5);
        dw = beck.forge(U, 1e5, 1e5);
        dw = alex.forge(U, -5e4, 0);
        dw = beck.forge(U, -5e4, -5e4);
        dw = alex.forge(U, 0, -5e4);
        assertLt(alex.balance(l), beck.balance(l), "alex should have less 1 than beck");
        (du, dv, dw) = alex.liquidate(U);
        (du, dv, dw) = beck.liquidate(U);
        assertLt(alex.balance(l), beck.balance(l), "alex should have less 1 than beck");
    }

    function test_ForgeExtreme() public returns (int256 du, int256 dv, int256 dw) {
        owen.give(address(alex), ONE_MINTED, l);
        du = 1;
        // forge-lint: disable-next-line(unsafe-typecast)
        dv = int256(ONE_MINTED * ONE_MINTED / 4);
        dw = alex.forge(U, du, dv);
        assertEq(l.totalSupply(), 0, "supply should be depleted");
    }

    function test_NonReentrantRevertsWhenNotOne() public {
        vm.expectRevert(IUnit.FunctionNotCalledOnOne.selector);
        Unit(address(U)).__nonReentrantBefore();
        vm.expectRevert(IUnit.FunctionNotCalledOnOne.selector);
        Unit(address(U)).__nonReentrantAfter();
    }

    function test_ForgeOneReverts() public {
        owen.give(address(alex), initialOne, l);
        vm.expectRevert(IUnit.FunctionCalledOnOne.selector);
        alex.forge(l, 1, 1);
    }

    IUnit anchored;

    function reenterSelf(IERC20Metadata, address f, address t, uint256 a) public {
        console.log("reenterSelf(%s, %s, %s)", f, t, a);
        alex.approve(address(anchored), 1, anchored.anchor());
        alex.forge(anchored, 1, 0);
    }

    function reenterReciprocal(IERC20Metadata, address f, address t, uint256 a) public {
        console.log("reenterReciprocal(%s, %s, %s)", f, t, a);
        alex.approve(address(anchored), 1, anchored.anchor());
        alex.forge(anchored.reciprocal(), 1, 0);
    }

    function reenterU(IERC20Metadata, address f, address t, uint256 a) public {
        console.log("reenterU(%s, %s, %s)", f, t, a);
        alex.approve(address(anchored), 1, anchored.anchor());
        alex.forge(U, 1, 0);
    }

    function test_RentrancyReverts() public {
        owen.give(address(alex), initialOne, l);

        TestToken hookToken = alex.newToken("ALIUM", 1e6);
        console.log("alex has %s %s", hookToken.balanceOf(address(alex)), hookToken.symbol());
        anchored = l.anchored(hookToken);
        console.log("anchored", address(anchored));
        console.log("/anchored", address(anchored.reciprocal()));
        console.log("anchored.anchor", address(anchored.anchor()));
        alex.addToken(anchored);
        alex.logBalances();
        alex.approve(address(anchored), 100, hookToken);
        alex.give(address(hookToken), 100, l);
        alex.approve(address(anchored), 100, hookToken);
        hookToken.doAfterUpdate(this.reenterSelf);
        vm.expectRevert(IUnit.ReentryForbidden.selector);
        alex.forge(anchored, 1, 1);
        hookToken.doAfterUpdate(this.reenterReciprocal);
        vm.expectRevert(IUnit.ReentryForbidden.selector);
        alex.forge(anchored, 1, 1);
        hookToken.doAfterUpdate(this.reenterU);
        vm.expectRevert(IUnit.ReentryForbidden.selector);
        alex.forge(anchored, 1, 1);
    }
}
