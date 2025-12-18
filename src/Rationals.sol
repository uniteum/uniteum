// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Rational, Rational8} from "./Rational.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Rationals
 * @notice Library for rational number arithmetic with 128-bit and 8-bit representations
 * @dev Rational: int256 with high 128 bits = numerator, low 128 bits = denominator
 *      Rational8: int16 with high 8 bits = numerator, low 8 bits = denominator
 *      All rationals are stored in reduced form (lowest terms)
 */
library Rationals {
    int128 constant NUMERATOR_MAX = type(int128).max;
    uint128 constant DENOMINATOR_MAX = type(uint128).max;
    int8 constant NUMERATOR8_MAX = type(int8).max;
    uint8 constant DENOMINATOR8_MAX = type(uint8).max;

    using Rationals for *;
    using Strings for *;

    /**
     * @dev Reverts when a denominator is zero
     */
    error ZeroDenominator();

    /**
     * @dev Reverts when a value cannot safely downcast to a smaller type
     */
    error ExponentTooBig();
    error DenominatorTooBig();
    error NumeratorTooBig();

    /**
     * @dev Reverts when exact Rat16 encoding is impossible
     */
    error Rat16EncodingImpossible();

    /**
     * @notice Unwraps a Rational to its underlying int256 representation
     */
    function raw(Rational n) internal pure returns (int256) {
        return Rational.unwrap(n);
    }

    /**
     * @notice Unwraps a Rational8 to its underlying int16 representation
     */
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
     * @notice Encodes a numerator and denominator as a Rational, reduced to lowest terms
     * @param n Signed 128-bit numerator
     * @param d Unsigned 128-bit denominator (must be nonzero)
     * @return a Encoded Rational value in reduced form
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
     * @notice Adds two Rational values and returns normalized result
     * @dev Computes a/b + c/d by finding common denominator using LCM
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
     * @notice Subtracts two Rational values and returns normalized result
     * @dev Computes a - b as a + (-b)
     */
    function sub(Rational a, Rational b) internal pure returns (Rational) {
        return a.add(b.neg());
    }

    /**
     * @notice Multiplies two Rational values and returns normalized result
     * @dev Computes (a/b) * (c/d) = (a*c)/(b*d), then reduces using GCD
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
     * @notice Divides Rational a by Rational b and returns normalized result
     * @dev Computes (a/b) / (c/d) = (a*d)/(b*c), handling sign normalization
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

    /**
     * @notice Extracts the numerator from a Rational8 value
     */
    function numerator(Rational8 a8) internal pure returns (int256 n) {
        n = int8(a8.raw() >> 8);
    }

    /**
     * @notice Extracts the denominator from a Rational8 value
     */
    function denominator(Rational8 a8) internal pure returns (uint256 d) {
        d = uint8(uint256(a8.raw()));
    }

    /**
     * @notice Decodes a Rational8 value into numerator and denominator
     * @param a A Rational8-encoded int value
     * @return n Signed 8-bit numerator
     * @return d Unsigned 8-bit denominator
     */
    function parts(Rational8 a) internal pure returns (int8 n, uint8 d) {
        int256 r = a.raw();
        // forge-lint: disable-next-line(unsafe-typecast)
        n = int8(r >> 8);
        // forge-lint: disable-next-line(unsafe-typecast)
        d = uint8(uint256(r) & DENOMINATOR8_MAX);
    }

    /**
     * @notice Encodes a numerator and denominator as a Rational8, reduced to lowest terms
     * @param n Signed 8-bit numerator
     * @param d Unsigned 8-bit denominator (must be nonzero)
     * @return a Rational8 value in reduced form
     */
    function divRational8(int256 n, uint256 d) internal pure returns (Rational8 a) {
        if (d == 0) {
            revert ZeroDenominator();
        }

        uint256 g = gcd(_abs(n), d);
        // forge-lint: disable-next-line(unsafe-typecast)
        n /= int8(uint8(g));
        // forge-lint: disable-next-line(unsafe-typecast)
        d /= uint8(g);

        if (n < -NUMERATOR8_MAX || n > NUMERATOR8_MAX) {
            revert ExponentTooBig();
        }
        if (d > DENOMINATOR8_MAX) {
            revert ExponentTooBig();
        }
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 encoded = (n << 8) | int256(uint256(d));
        // forge-lint: disable-next-line(unsafe-typecast)
        a = Rational8.wrap(int16(encoded));
    }

    /**
     * @notice Negates a Rational8-encoded value
     * @param a A Rational8-encoded int16 value
     * @return Negated Rational8-encoded value
     */
    function neg(Rational8 a) internal pure returns (Rational8) {
        (int8 n, uint8 d) = a.parts();
        return divRational8(-n, d);
    }

    /**
     * @notice Adds two Rational8 values by converting to Rational, adding, then converting back
     */
    function add(Rational8 a, Rational8 b) internal pure returns (Rational8) {
        return a.toRational().add(b.toRational()).toRational8();
    }

    /**
     * @notice Converts a Rational to an exact Rational8, reverts if not representable
     */
    function toRational8(Rational a) internal pure returns (Rational8 a8) {
        (int256 n, uint256 d) = a.parts();
        a8 = n.divRational8(d);
    }

    /**
     * @notice Converts a Rational8 value to Rational
     */
    function toRational(Rational8 a8) internal pure returns (Rational a) {
        (int256 n, uint256 d) = a8.parts();
        a = n.divRational(d);
    }

    /**
     * @notice Safely converts uint256 to int256, reverting on overflow
     */
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
     * @notice Returns the absolute value of an int256
     * @dev Handles type(int256).min safely using unchecked negation
     */
    function _abs(int256 x) internal pure returns (uint256) {
        if (x >= 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            return uint256(x);
        } else {
            unchecked {
                // forge-lint: disable-next-line(unsafe-typecast)
                return uint256(-x);
            }
        }
    }
}
