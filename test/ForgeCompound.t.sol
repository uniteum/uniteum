// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {UnitBaseTest, Units, IUnit} from "./UnitBase.t.sol";

contract ForgeCompoundTest is UnitBaseTest {
    using Units for *;

    uint256 initialOne = 1e6;
    uint256 maxTransfer = initialOne;
    IUnit public W;

    function setUp() public virtual override {
        super.setUp();
        V = l.multiply("V");
        U.multiply(V).sqrtResolve();
        (W,) = U.multiply(V).sqrt();
        owen.migrate(proto1.balanceOf(address(owen)));
        alex.addToken(V);
        alex.addToken(V.reciprocal());
        alex.addToken(W);
        alex.addToken(W.reciprocal());
    }

    function testForgeW() public returns (int256 dw) {
        owen.give(address(alex), initialOne, l);

        dw = alex.forge(W, 100, 100);
        dw = alex.forge(U, 100, 100);
        dw = alex.forge(V, 100, 100);
        (W, dw) = alex.forge(U, V, -1, -1);
        (W, dw) = alex.forge(U, V, -1, -1);
        (W, dw) = alex.forge(U, V, -20, -10);
        //(W, dw) = alex.forge(U, V, 10, 10);
    }
}
