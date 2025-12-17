// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {UnitBaseTest, Units, Unit, IUnit} from "./UnitBase.t.sol";
import {Prototype} from "../src/Prototype.sol";

contract UnitTest is UnitBaseTest {
    using Units for *;

    address constant USDT_ADDRESS = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
    string constant USDT_SYMBOL = "$0xffD4505B3452Dc22f8473616d50503bA9E1710Ac";
    string public constant NAME_PREFIX = "Uniteum 0.1 ";

    function testOneSymbolIs1() public view {
        assertEq(l.symbol(), "1");
    }

    function testOneIsOwnReciprocal() public view {
        assertEq(address(l.reciprocal()), address(l));
    }

    function testRejectLongUnits() public {
        string memory longName = "abcdefghijklmnopqrstuvwxyz0123456789";
        vm.expectRevert(Units.BaseSymbolTooBig.selector);
        l.multiply(longName);
    }

    function testSymbolicExternalUnit() public {
        string memory s = USDT_SYMBOL;
        address extoken = USDT_ADDRESS;
        IUnit wrap = unit(s);
        assertEq(wrap.symbol(), s, "wrap.symbol()");
        assertEq(address(wrap.anchor()), extoken, "wrap.wrapped()");
        assertEq(address(wrap.reciprocal().anchor()), address(0), "reciprocal should not have anchor");
    }

    function unaryTest(string memory s, string memory canonical, string memory r) public {
        IUnit u = unit(s);
        IUnit recip = u.reciprocal();
        assertEq(u.symbol(), canonical);
        assertEq(u.name(), string.concat(NAME_PREFIX, canonical));
        assertEq(recip.symbol(), r);
        assertEq(recip.name(), string.concat(NAME_PREFIX, r));
    }

    function testUnitUnary() public {
        unaryTest("foo*foo", "foo^2", "1/foo^2");
        unaryTest("1^127", "1", "1");
        unaryTest("a^127", "a^127", "1/a^127");
        unaryTest("a", "a", "1/a");
        unaryTest("a/a", "1", "1");
        unaryTest("a*b/a", "b", "1/b");
        unaryTest("a*b/b", "a", "1/a");
        unaryTest("a/a*b/b", "1", "1");
        unaryTest("a/b", "a/b", "b/a");
        unaryTest("a*b^3*c/a/b/c/b/c", "b/c", "c/b");
        unaryTest(
            "8*o*J*r*y*B*q*z*T*t*l*_*-*w*G*x*K*W*X*i*E*Z*Y*D*N*L*H*5*U*2*6*p*d*F*f*b*S*A*n*O*P*g*j*s*1*e*v*h*Q*R*m*k*7*a*M*C*I*V*c*0*u*4*9*3*.",
            "-*.*0*2*3*4*5*6*7*8*9*A*B*C*D*E*F*G*H*I*J*K*L*M*N*O*P*Q*R*S*T*U*V*W*X*Y*Z*_*a*b*c*d*e*f*g*h*i*j*k*l*m*n*o*p*q*r*s*t*u*v*w*x*y*z",
            "1/-/./0/2/3/4/5/6/7/8/9/A/B/C/D/E/F/G/H/I/J/K/L/M/N/O/P/Q/R/S/T/U/V/W/X/Y/Z/_/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z"
        );
        unaryTest("a^15\\6", "a^5\\2", "1/a^5\\2");
        unaryTest("example.com", "example.com", "1/example.com");
        unaryTest("a.b.c.d.e", "a.b.c.d.e", "1/a.b.c.d.e");
    }

    function binaryTest(string memory n, string memory d, string memory p, string memory q) public {
        IUnit nu = unit(n);
        IUnit du = unit(d);
        IUnit pu = nu.multiply(du);
        IUnit ru = du.reciprocal();
        IUnit qu = nu.multiply(ru);
        assertEq(pu.symbol(), p);
        assertEq(qu.symbol(), q);
        pu = nu.multiply(d);
        assertEq(pu.symbol(), p);
    }

    function testUnitBinary() public {
        binaryTest("foo", "foo", "foo^2", "1");
        binaryTest("foo", "bar", "bar*foo", "foo/bar");
        binaryTest("foo", "baz", "baz*foo", "foo/baz");
        binaryTest("bar", "foo", "bar*foo", "bar/foo");
        binaryTest("bar", "bar", "bar^2", "1");
        binaryTest("bar", "baz", "bar*baz", "bar/baz");
        binaryTest("baz", "foo", "baz*foo", "baz/foo");
        binaryTest("baz", "bar", "bar*baz", "baz/bar");
        binaryTest("baz", "baz", "baz^2", "1");
    }

    function badProductUnitTest(string memory n, string memory d) public {
        IUnit nu = unit(n);
        IUnit du = unit(d);
        vm.expectRevert(Units.ExponentTooBig.selector);
        nu.product(du);
    }

    function testBadProductUnits() public {
        badProductUnitTest("a^127", "a");
    }

    function tooBigExponent(string memory n) public {
        vm.expectRevert(Units.ExponentTooBig.selector);
        unit(n);
    }

    function testTooBigExponent() public {
        tooBigExponent("a^128");
        tooBigExponent("1/a^128");
        tooBigExponent("1/a^128\\3");
        tooBigExponent("1/a^1\\256");
        tooBigExponent(
            "a^9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
        );
    }

    function testUnauthorizedInitializer() public {
        IUnit u = unit("u");
        vm.expectRevert(Prototype.Unauthorized.selector);
        Unit(address(u)).__initialize(bytes("Random junk"));
    }

    function unit(string memory s) internal returns (IUnit u) {
        u = l.multiply(s);
    }
}
