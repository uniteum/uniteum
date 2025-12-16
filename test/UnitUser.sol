// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {User, TestToken, console} from "./User.sol";
import {IUnit, IERC20} from "../src/Unit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UnitUser is User {
    using SafeERC20 for IERC20;

    IUnit public immutable ONE;
    TestToken ignore;

    constructor(string memory name_, IUnit one) User(name_) {
        ONE = one;
    }

    function migrate(uint256 value) public {
        console.log("%s migrate", name, value);
        ONE.UPSTREAM().approve(address(ONE), value);
        ONE.migrate(value);
        logBalance(ONE);
    }

    function unmigrate(uint256 value) public {
        console.log("%s unmigrate", name, value);
        ONE.unmigrate(value);
        logBalance(ONE);
    }

    function forge(IUnit U, int256 du, int256 dv) public returns (int256 dw) {
        console.log("%s.forge", name, U.symbol());
        console.log("du:", du);
        console.log("dv:", dv);
        dw = U.forgeQuote(du, dv);
        console.log("dw:", dw);
        if (address(U.anchor()) != address(0) && du > 0) {
            U.anchor().approve(address(U), uint256(du));
        }
        dw = U.forge(du, dv);
        logBalances();
        console.log("total 1:", ONE.totalSupply());
    }

    function forge(IUnit U, IUnit V, int256 du, int256 dv) public returns (IUnit W, int256 dw) {
        console.log("%s.forge(%s, %s)", name, U.symbol(), V.symbol());
        console.log("du:", du);
        console.log("dv:", dv);
        (W, dw) = U.forgeQuote(V, du, dv);
        console.log("dw:", dw);
        (W, dw) = U.forge(V, du, dv);
        logBalances();
        console.log("total 1:", ONE.totalSupply());
    }

    function liquidate(IUnit U) public returns (int256 du, int256 dv, int256 dw) {
        IUnit V = U.reciprocal();
        du = -int256(U.balanceOf(address(this)));
        dv = -int256(V.balanceOf(address(this)));
        dw = forge(U, du, dv);
        assertHasNo(U);
        assertHasNo(V);
    }

    function rndUnits(IUnit U) public returns (int256 x) {
        int256 xmin = -int256(U.balanceOf(address(this)));
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 xmax = int256(ONE.balanceOf(address(this)));
        x = rnd(xmin, xmax);
    }

    function rndForge(IUnit U) public returns (int256 du, int256 dv, int256 dw) {
        du = rndUnits(U);
        dv = rndUnits(U.reciprocal());
        dw = U.forgeQuote(du, dv);
        if (dw < -int256(ONE.balanceOf(address(this)))) {
            console.log("forge not called because insufficient balance");
        } else {
            dw = forge(U, du, dv);
        }
    }
}
