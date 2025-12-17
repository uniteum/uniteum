// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Rational, Rational8} from "./Rational.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library Rationals {
    int128 constant NUMERATOR_MAX = type(int128).max;
    uint128 constant DENOMINATOR_MAX = type(uint128).max;
    int8 constant NUMERATOR8_MAX = type(int8).max;
    uint8 constant DENOMINATOR8_MAX = type(uint8).max;

    using Rationals for *;
    using Strings for *;

    /// @dev Reverts when a denominator is zero
    error ZeroDenominator();

    /// @dev Reverts when a value cannot safely downcast to a smaller type
    error ExponentTooBig();
    error DenominatorTooBig();
    error NumeratorTooBig();

    /// @dev Reverts when exact Rat16 encoding is impossible
    error Rat16EncodingImpossible();

    function raw(Rational n) internal pure returns (int256) {
        return Rational.unwrap(n);
    }

    function raw(Rational8 n) internal pure returns (int256) {
        return Rational8.unwrap(n);
    }

    /**
     * @notice Decodes a Ratio128 value into numerator and denominator
     * @param a A Ratio128-encoded int value
     * @return n Signed 128-bit numerator
     * @return d Unsigned 128-bit denominator
     */
    function parts(Rational a) internal pure returns (int256 n, uint256 d) {
        int256 r = a.raw();
        n = r >> 128;
        // forge-lint: disable-next-line(unsafe-typecast)
        d = uint256(r) & DENOMINATOR_MAX;
    }

    /**
     * @notice Encodes a numerator and denominator as a Ratio128 int value
     * @param n Signed 128-bit numerator
     * @param d Unsigned 128-bit denominator (must be nonzero)
     * @return a Encoded Ratio128 value
     */
    function divRational(int256 n, uint256 d) internal pure returns (Rational a) {
        if (d == 0) {
            revert ZeroDenominator();
        }

        uint256 g = gcd(_abs(n), d);
        // forge-lint: disable-next-line(unsafe-typecast)
        n /= int128(uint128(g));
        // forge-lint: disable-next-line(unsafe-typecast)
        d /= uint128(g);

        if (n < -NUMERATOR_MAX || NUMERATOR_MAX < n) {
            revert NumeratorTooBig();
        }

        if (d > DENOMINATOR_MAX) {
            revert DenominatorTooBig();
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        a = Rational.wrap((n << 128) | int256(uint256(d)));
    }

    /**
     * @notice Negates a Ratio128-encoded value
     * @param a A Ratio128-encoded int value
     * @return Negated Ratio128-encoded value
     */
    function neg(Rational a) internal pure returns (Rational) {
        (int256 n, uint256 d) = a.parts();
        return (-n).divRational(d);
    }

    /**
     * @notice Adds two Ratio128 values and returns normalized result
     */
    function add(Rational a, Rational b) internal pure returns (Rational) {
        (int256 an, uint256 ad) = a.parts();
        (int256 bn, uint256 bd) = b.parts();
        uint256 gd = gcd(ad, bd);
        // forge-lint: disable-next-line(divide-before-multiply)
        uint256 d = (ad / gd) * bd;
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 n = an * int256(d / ad) + bn * int256(d / bd);

        return n.divRational(d);
    }

    /**
     * @notice Subtracts two Ratio128 values and returns normalized result
     */
    function sub(Rational a, Rational b) internal pure returns (Rational) {
        return a.add(b.neg());
    }

    /**
     * @notice Multiplies two Ratio128 values and returns normalized result
     * a/b * c/d = a/d * c/b
     */
    function mul(Rational a, Rational b) internal pure returns (Rational) {
        (int256 an, uint256 ad) = a.parts();
        (int256 bn, uint256 bd) = b.parts();
        int256 n = int256(an) * int256(bn);
        uint256 d = uint256(ad) * uint256(bd);
        uint256 g = gcd(uint256(_abs(n)), d);
        return (n / g.toInt256()).divRational(d / g);
    }

    /**
     * @notice Divides Ratio128 a by Ratio128 b and returns normalized result
     */
    function div(Rational a, Rational b) internal pure returns (Rational r) {
        (int256 an, uint256 ad) = a.parts();
        (int256 bn, uint256 bd) = b.parts();
        if (bn == 0) {
            revert ZeroDenominator();
        }
        int256 n = an * bd.toInt256();
        int256 d = ad.toInt256() * bn;
        if (d < 0) {
            n = -n;
            d = -d;
        }
        // forge-lint: disable-next-line(unsafe-typecast)
        r = n.divRational(uint256(d));
    }

    function numerator(Rational8 a8) internal pure returns (int256 n) {
        n = int8(a8.raw() >> 8);
    }

    function denominator(Rational8 a8) internal pure returns (uint256 d) {
        d = uint8(uint256(a8.raw()));
    }

    /**
     * @notice Decodes a Ratio128 value into numerator and denominator
     * @param a A Ratio128-encoded int value
     * @return n Signed 128-bit numerator
     * @return d Unsigned 128-bit denominator
     */
    function parts(Rational8 a) internal pure returns (int8 n, uint8 d) {
        int256 r = a.raw();
        // forge-lint: disable-next-line(unsafe-typecast)
        n = int8(r >> 8);
        // forge-lint: disable-next-line(unsafe-typecast)
        d = uint8(uint256(r) & DENOMINATOR8_MAX);
    }

    /**
     * @notice Encodes a numerator and denominator as a Ratio128 int value
     * @param n Signed 128-bit numerator
     * @param d Unsigned 128-bit denominator (must be nonzero)
     * @return a Ratio128 value
     */
    function divRational8(int256 n, uint256 d) internal pure returns (Rational8 a) {
        if (d == 0) {
            revert ZeroDenominator();
        }
        if (n < -NUMERATOR8_MAX || n > NUMERATOR8_MAX) {
            revert ExponentTooBig();
        }
        if (d > DENOMINATOR8_MAX) {
            revert ExponentTooBig();
        }
        // forge-lint: disable-next-line(unsafe-typecast)
        a = Rational8.wrap(int16(int256((uint256(n) << 8) | d)));
    }

    /**
     * @notice Negates a Ratio8-encoded value
     * @param a A Ratio8-encoded int16 value
     * @return Negated Ratio128-encoded value
     */
    function neg(Rational8 a) internal pure returns (Rational8) {
        (int8 n, uint8 d) = a.parts();
        return divRational8(-n, d);
    }

    function add(Rational8 a, Rational8 b) internal pure returns (Rational8) {
        return a.toRational().add(b.toRational()).toRational8();
    }

    /**
     * @notice Converts a Ratio128 to an exact Rat16, reverts if not representable
     */
    function toRational8(Rational a) internal pure returns (Rational8 a8) {
        (int256 n, uint256 d) = a.parts();
        a8 = n.divRational8(d);
    }

    /**
     * @notice Converts a Rat16 value to Ratio128
     */
    function toRational(Rational8 a8) internal pure returns (Rational a) {
        (int256 n, uint256 d) = a8.parts();
        a = n.divRational(d);
    }

    function toInt256(uint256 x) internal pure returns (int256 y) {
        if (x <= uint256(type(int256).max)) {
            // forge-lint: disable-next-line(unsafe-typecast)
            y = int256(uint256(x));
        } else {
            revert ExponentTooBig();
        }
    }

    /**
     * @notice Computes greatest common divisor using Euclidean algorithm
     */
    function gcd(uint256 a, uint256 b) public pure returns (uint256) {
        while (b != 0) {
            uint256 t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    /**
     * @notice Computes least common multiple of two denominators
     * @dev Uses identity lcm(a, b) = (a / gcd(a, b)) * b
     */
    function lcm(uint256 a, uint256 b) public pure returns (uint256) {
        // forge-lint: disable-next-line(divide-before-multiply)
        return (a / gcd(a, b)) * b;
    }

    /**
     * @notice Returns the absolute value of an int
     */
    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}
