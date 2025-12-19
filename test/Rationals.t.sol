// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Rationals, Rational, Rational8} from "../src/Rationals.sol";
import {RationalsContractor} from "./RationalsContractor.sol";

contract RationalsTest is Test {
    using Rationals for *;

    RationalsContractor contractor;

    function setUp() public {
        contractor = new RationalsContractor();
    }

    function expectRational(Rational r, int256 en, uint256 ed) internal pure {
        (int256 on, uint256 od) = r.parts();
        assertEq(on, en);
        assertEq(od, ed);
    }

    function expectRational(Rational8 r, int256 en, uint256 ed) internal pure {
        (int256 on, uint256 od) = r.parts();
        assertEq(on, en);
        assertEq(od, ed);
    }

    function testUnary(int256 n, uint256 d, int256 en, uint256 ed) internal pure {
        Rational r = n.divRational(d);
        expectRational(r, en, ed);
        expectRational(r.neg(), -en, ed);

        Rational original = n.divRational(d);
        Rational8 packed = original.toRational8();
        Rational unpacked = packed.toRational();
        expectRational(unpacked, en, ed);
    }

    function testUnaryAll() public pure {
        testUnary(0, 1, 0, 1);
        testUnary(0, 3, 0, 1);
        testUnary(1, 3, 1, 3);
        testUnary(-1, 3, -1, 3);
        testUnary(2, 2, 1, 1);
        testUnary(-2, 2, -1, 1);
        testUnary(42, 7, 6, 1);
        testUnary(-42, 7, -6, 1);
        testUnary(127, 3, 127, 3);
        testUnary(-3, 128, -3, 128);
        testUnary(-3, 255, -1, 85);
        testUnary(-7, 255, -7, 255);
    }

    function rational8Div(int256 n, uint256 d, int256 en, uint256 ed) internal pure {
        Rational8 r = n.divRational8(d).div(2);
        expectRational(r, en, ed);
    }

    function testDiv() public pure {
        rational8Div(0, 1, 0, 1);
        rational8Div(0, 3, 0, 1);
        rational8Div(1, 3, 1, 6);
        rational8Div(-1, 3, -1, 6);
        rational8Div(2, 2, 1, 2);
        rational8Div(-2, 2, -1, 2);
        rational8Div(42, 7, 3, 1);
        rational8Div(-42, 7, -3, 1);
        rational8Div(127, 3, 127, 6);
        rational8Div(-3, 255, -1, 170);
    }

    function testBinary(
        int256 n1,
        uint256 d1,
        int256 n2,
        uint256 d2,
        int256 na,
        uint256 da,
        int256 ns,
        uint256 ds,
        int256 nm,
        uint256 dm,
        int256 nd,
        int256 dd
    ) internal pure {
        Rational a = n1.divRational(d1);
        Rational b = n2.divRational(d2);
        expectRational(a.add(b), na, da);
        expectRational(a.sub(b), ns, ds);
        expectRational(a.mul(b), nm, dm);
        //expectRational(a.div(b), nd, dd);
        expectRational(b.add(a), na, da);
        expectRational(b.sub(a), -ns, ds);
        expectRational(b.mul(a), nm, dm);
        if (nd == 0) {
            return;
        }
        if (nd < 0) {
            nd = -nd;
            dd = -dd;
        }
        // forge-lint: disable-next-line(unsafe-typecast)
        expectRational(b.div(a), dd, uint256(nd));
    }

    function testBinaryAll() public pure {
        testBinary(1, 3, 1, 6, 1, 2, 1, 6, 1, 18, 2, 1);
        testBinary(3, 4, 1, 4, 1, 1, 1, 2, 3, 16, 3, 1);
        testBinary(2, 3, 3, 4, 17, 12, -1, 12, 1, 2, 8, 9);
        testBinary(3, 5, 1, 2, 11, 10, 1, 10, 3, 10, 6, 5);
        testBinary(-1, 3, 2, 3, 1, 3, -1, 1, -2, 9, -1, 2);
        testBinary(2, 6, 4, 8, 5, 6, -1, 6, 1, 6, 2, 3);
        testBinary(-3, 5, -2, 5, -1, 1, -1, 5, 6, 25, 3, 2);
        testBinary(5, 9, -1, 3, 2, 9, 8, 9, -5, 27, -5, 3);
        testBinary(0, 5, 1, 7, 1, 7, -1, 7, 0, 1, 0, 1);
        testBinary(4, 6, 2, 6, 1, 1, 1, 3, 2, 9, 2, 1);
        testBinary(-2, 3, -1, 6, -5, 6, -1, 2, 1, 9, 4, 1);
        testBinary(1, 2, -1, 2, 0, 1, 1, 1, -1, 4, -1, 1);
        testBinary(7, 10, 5, 10, 6, 5, 1, 5, 7, 20, 7, 5);
        testBinary(-4, 9, 4, 9, 0, 1, -8, 9, -16, 81, -1, 1);
        testBinary(9, 10, -2, 5, 1, 2, 13, 10, -9, 25, -9, 4);
        testBinary(0, 1, 1, 1, 1, 1, -1, 1, 0, 1, 0, 1);
        testBinary(8, 9, 1, 3, 11, 9, 5, 9, 8, 27, 8, 3);
        testBinary(-5, 8, 3, 8, -1, 4, -1, 1, -15, 64, -5, 3);
        testBinary(-63, 255, 1, 255, -62, 255, -64, 255, -7, 7225, -63, 1);
        testBinary(-64, 255, 1, 255, -21, 85, -13, 51, -64, 65025, -64, 1);
        testBinary(-65, 255, 1, 255, -64, 255, -22, 85, -13, 13005, -65, 1);
        testBinary(127, 255, 1, 255, 128, 255, 42, 85, 127, 65025, 127, 1);
        testBinary(128, 255, 1, 255, 43, 85, 127, 255, 128, 65025, 128, 1);
        testBinary(129, 255, 1, 255, 26, 51, 128, 255, 43, 21675, 129, 1);
        testBinary(-127, 255, 1, 255, -42, 85, -128, 255, -127, 65025, -127, 1);
        testBinary(-128, 255, 1, 255, -127, 255, -43, 85, -128, 65025, -128, 1);
        testBinary(-129, 255, 1, 255, -128, 255, -26, 51, -43, 21675, -129, 1);
        testBinary(255, 255, 1, 255, 256, 255, 254, 255, 1, 255, 255, 1);
        testBinary(256, 255, 1, 255, 257, 255, 1, 1, 256, 65025, 256, 1);
        testBinary(257, 255, 1, 255, 86, 85, 256, 255, 257, 65025, 257, 1);
        testBinary(-255, 255, 1, 255, -254, 255, -256, 255, -1, 255, -255, 1);
        testBinary(-256, 255, 1, 255, -1, 1, -257, 255, -256, 65025, -256, 1);
        testBinary(-257, 255, 1, 255, -256, 255, -86, 85, -257, 65025, -257, 1);
    }

    function testRational8NumeratorTooBig(int256 n, uint256 d) public {
        n = bound(n, 128, 130);
        d = bound(d, 1, 5);
        // forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(uint256(n).gcd(d) == 1);
        Rational r = n.divRational(d);
        vm.expectRevert();
        contractor.toRational8(r);
    }

    function testRational8DenominatorTooBig(int256 n, uint256 d) public {
        n = bound(n, 1, 127);
        d = bound(d, 256, 300);
        // forge-lint: disable-next-line(unsafe-typecast)
        vm.assume(uint256(n).gcd(d) == 1);
        Rational r = n.divRational(d);
        vm.expectRevert();
        contractor.toRational8(r);
    }

    function testRational8ZeroDenominator() public {
        Rational8 r = Rational8.wrap(256);
        vm.expectRevert(Rationals.ZeroDenominator.selector);
        contractor.toRational(r);
    }

    function testRationalZeroDenominator(int256 n) public {
        uint256 d = 0;
        vm.expectRevert(Rationals.ZeroDenominator.selector);
        contractor.divRational(n, d);
    }

    function testRationalDivZeroDenominator(int256 n) public {
        n = bound(n, 1, 2 ** 64);
        Rational r = n.divRational(1);
        Rational z = int256(0).divRational(1);
        vm.expectRevert(Rationals.ZeroDenominator.selector);
        contractor.div(r, z);
    }
}
