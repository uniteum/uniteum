// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {BaseTest} from "./Base.t.sol";
import {UnitUser, User, TestToken, SafeERC20} from "./UnitUser.sol";
import {console} from "forge-std/Test.sol";
import {Unit, IUnit, IERC20} from "../src/Unit.sol";
import {Units} from "../src/Units.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract UnitBaseTest is BaseTest {
    using Units for *;
    using Math for *;
    using SafeERC20 for *;

    uint256 public constant ONE_MINTED = 1e9 ether;
    TestToken public proto1;
    IUnit public l;
    IUnit public U;
    IUnit public V;
    UnitUser public owen;
    UnitUser public alex;
    UnitUser public beck;

    function newUser(string memory name) internal returns (UnitUser u) {
        u = new UnitUser(name, l);
    }

    function setUp() public virtual override {
        super.setUp();

        proto1 = new TestToken("1p", ONE_MINTED);
        l = new Unit{salt: 0x0}(proto1);
        console.log("1 deployed to", address(IERC20(l)));

        owen = newUser("owen");
        alex = newUser("alex");
        beck = newUser("beck");

        proto1.safeTransfer(address(owen), ONE_MINTED);
        owen.migrate(ONE_MINTED);

        U = l.multiply("U");
        V = U.reciprocal();

        assertEq(U.reciprocal().symbol(), V.symbol(), "unexpected reciprocal symbol");
        assertEq(V.reciprocal().symbol(), U.symbol(), "unexpected reciprocal symbol");

        assertEq(address(U.reciprocal()), address(V), "unexpected reciprocal");
        assertEq(address(V.reciprocal()), address(U), "unexpected reciprocal");

        addTokens(owen);
        addTokens(alex);
        addTokens(beck);
    }

    function addTokens(User p) internal {
        p.addToken(U);
        p.addToken(V);
        p.addToken(l);
    }
}
