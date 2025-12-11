// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Rationals, Rational, Rational8} from "../src/Rationals.sol";

contract RationalsContractor {
    using Rationals for *;

    function parts(Rational x) external pure returns (int256, uint256) {
        return x.parts();
    }

    function divRational(int256 n, uint256 d) external pure returns (Rational z) {
        z = n.divRational(d);
    }

    function add(Rational x, Rational y) external pure returns (Rational z) {
        z = x.add(y);
    }

    function sub(Rational x, Rational y) external pure returns (Rational z) {
        z = x.sub(y);
    }

    function mul(Rational x, Rational y) external pure returns (Rational z) {
        z = x.mul(y);
    }

    function div(Rational x, Rational y) external pure returns (Rational z) {
        z = x.div(y);
    }

    function neg(Rational x) external pure returns (Rational z) {
        z = x.neg();
    }

    function toRational8(Rational rat128) external pure returns (Rational8 z) {
        z = rat128.toRational8();
    }

    function toRational(Rational8 rat8) external pure returns (Rational z) {
        z = rat8.toRational();
    }

    function lcd(uint256 x, uint256 y) external pure returns (uint256 z) {
        z = x.lcm(y);
    }

    function gcd(uint256 x, uint256 y) external pure returns (uint256 z) {
        z = x.gcd(y);
    }
}
