// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Term} from "./Term.sol";
import {Rationals, Rational, Rational8} from "./Rationals.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Units
 * @dev Library for unit term operations.
 * Base unit terms are packed into uint:
 * The last two bytes (30, 31) are a rational exponent.
 * Symbolic terms have the first 30 bytes as the base symbol.
 * Address terms have the first byte = 1, and the next 20 bytes are an address.
 * +0......0|1.........................20|21................29|30...........31+
 * | Symbol                                                   |    Exponent   |
 * |----------------------------------------------------------| ± num / den   |
 * | Type=1 | Address [1..20]            | Reserved           |  int8 | uint8 |
 * +255................................96|95................16|15....8|7.....0+
 * Example 1: meter^2\3
 * |6d 6574657200000000000000000000000000000000 000000000000000000 02 03|
 * |  |                                        |                  |  |  |
 * |01 c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 000000000000000000 ff 01|
 * Example 2: [address of WETH]^-1
 */
library Units {
    using Units for *;
    using Rationals for *;
    using Strings for *;

    /// @dev Bitmap indicating valid symbol characters: 0-9, A-Z, a-z, _, -, .
    uint256 constant SYMBOL_CHAR_BITS = 0x7fffffe87fffffe03ff600000000000;
    /// @dev The term for 1^0. The ascii code for "1" is 0x31.
    uint256 constant ONE_TERM = 0x31 << 0xf8;
    /// @dev A term with this type is an encoded address reference with an exponent.
    uint256 constant ANCHOR_TERM_TYPE = 1;
    uint256 constant ANCHOR_SHIFT = 0x58;
    string constant ONE_SYMBOL = "1";
    bytes1 constant ANCHOR_PREFIX = "$";
    bytes1 constant DIVIDE_SYMBOL = "/";
    bytes1 constant MULTIPLY_SYMBOL = "*";
    bytes1 constant POWER_SYMBOL = "^";
    bytes1 constant POWER_DIV = "\\"; // backslash escaped
    Rational8 constant ZERO_RATIONAL_8 = Rational8.wrap(1);
    Rational8 constant ONE_RATIONAL_8 = Rational8.wrap(0x101);
    uint256 constant EXPONENT_MASK = 0xffff;
    uint256 constant MAX_SYMBOL_SIZE = 30;

    // Errors
    error BaseSymbolTooBig();
    error ExponentTooBig();
    error InvalidAddressTerm(Term term);
    error BadHexCharacter(uint8 char);
    error UnexpectedCharacter(bytes1 char);

    /// @dev Extracts the base part from a term (clears the exponent byte)
    function base(Term term) internal pure returns (Term base_) {
        base_ = Term.wrap(term.raw() & ~uint256(EXPONENT_MASK));
    }

    function raw(Term term) internal pure returns (uint256) {
        return Term.unwrap(term);
    }

    /// @dev Extracts the exponent from a term (int8 stored in lowest byte)
    function exponent(Term term) internal pure returns (Rational8) {
        return Rational8.wrap(int16(uint16(term.raw())));
    }

    /// @dev Returns whether the char is on of 0-9, A-Z, a-z, _, -
    function isSymbolChar(bytes1 char) internal pure returns (bool) {
        return (SYMBOL_CHAR_BITS >> uint8(char)) & 1 != 0;
    }

    function termType(Term term) internal pure returns (uint8 termType_) {
        termType_ = uint8(term.raw() >> 0xf8);
    }

    function isBase(Term term) internal pure returns (bool) {
        return term.exponent().raw() == ONE_RATIONAL_8.raw();
    }

    /**
     * @notice Return the external token address represented by the term.
     * @dev Return address(0) if the term is not an external token term.
     */
    function anchor(Term term) internal pure returns (address token) {
        if (term.termType() == ANCHOR_TERM_TYPE && term.isBase()) {
            // forge-lint: disable-next-line(unsafe-typecast)
            token = address(uint160(term.raw() >> ANCHOR_SHIFT));
        }
    }

    /**
     * @notice Return the external token address represented by the terms.
     * @dev Return address(0) if the term is not an external token term.
     */
    function anchor(Term[] memory terms) internal pure returns (address token) {
        if (terms.length == 1) {
            token = terms[0].anchor();
        }
    }

    function parts(Term term)
        internal
        pure
        returns (
            uint256 bits,
            bool isBase_,
            uint8 termType_,
            address tokenAddress_,
            bytes30 symbol_,
            int8 numerator_,
            uint8 denominator_
        )
    {
        bits = term.raw();
        // forge-lint: disable-next-line(unsafe-typecast)
        termType_ = uint8(bits >> 0xf8);
        // forge-lint: disable-next-line(unsafe-typecast)
        numerator_ = int8(uint8(bits >> 8));
        // forge-lint: disable-next-line(unsafe-typecast)
        denominator_ = uint8(bits);
        isBase_ = numerator_ == 1 && denominator_ == 1;
        if (termType_ != ANCHOR_TERM_TYPE) {
            // forge-lint: disable-next-line(unsafe-typecast)
            symbol_ = bytes30(uint240(bits >> 16));
        } else if (isBase_) {
            // forge-lint: disable-next-line(unsafe-typecast)
            tokenAddress_ = address(uint160(bits >> ANCHOR_SHIFT));
        }
    }

    /**
     * @dev Reverts if the term is not valid
     *      - has non-symbol characters before the zero padding
     *      - has an exponent numerator = -128
     */
    function mustBeValidTerm(Term term) internal pure {
        (uint256 c,, uint8 t,, bytes30 s, int8 n, uint8 d) = term.parts();
        if (n == -128) {
            revert ExponentTooBig();
        }
        if (d == 0) {
            revert Rationals.ZeroDenominator();
        }

        if (t == ANCHOR_TERM_TYPE) {
            if (0 != ((c >> 16) << 23 * 8)) {
                revert InvalidAddressTerm(term);
            }
        } else {
            uint256 i;
            for (; i < 30; i++) {
                if (!s[i].isSymbolChar()) {
                    break;
                }
            }

            for (; i < 30; i++) {
                if (s[i] != 0) {
                    revert UnexpectedCharacter(s[i]);
                }
            }
        }
    }

    /// @dev Revert if any term is invalid.
    function mustBeValidTerms(Term[] memory terms) internal pure {
        for (uint256 i = 0; i < terms.length; i++) {
            terms[i].mustBeValidTerm();
        }
    }

    /// @dev Packs a base and exponent into a term
    function withExponent(Term base_, Rational8 exp) internal pure returns (Term term) {
        term = Term.wrap((base_.raw() & ~uint256(EXPONENT_MASK)) | uint256(uint16(int16(exp.raw()))));
    }

    /// @dev Packs a base and exponent into a term
    function withExponent(address base_, Rational8 exp) internal pure returns (Term term) {
        term = Term.wrap((uint256(uint160(base_)) << ANCHOR_SHIFT) | (ANCHOR_TERM_TYPE << 0xf8)).withExponent(exp);
    }

    /// @dev Return the reciprocal of a term (negates exponent)
    function reciprocal(Term term) internal pure returns (Term reciprocal_) {
        reciprocal_ = term.withExponent(term.exponent().neg());
    }

    /// @dev Return the reciprocal terms. Modifies the input.
    function reciprocal(Term[] memory terms) internal pure returns (Term[] memory reciprocal_) {
        reciprocal_ = terms;
        for (uint256 i = 0; i < terms.length; i++) {
            reciprocal_[i] = terms[i].reciprocal();
        }
    }

    /// @dev Concatenates three strings
    function add(string memory s1, string memory s2, string memory s3) internal pure returns (string memory) {
        return string.concat(s1, s2, s3);
    }

    function toString(bytes30 b) internal pure returns (string memory s) {
        uint256 end;
        // Find trailing zeros
        for (; end < 30; end++) {
            if (b[end] == 0) {
                break;
            }
        }

        bytes memory sb = new bytes(end);

        for (uint256 i = 0; i < end; i++) {
            sb[i] = b[i];
        }
        s = string(sb);
    }

    /// @dev Returns the symbol string for a single term
    function symbol(Term term) internal pure returns (string memory symbol_) {
        (,, uint8 t, address a, bytes30 s, int8 n, uint8 d) = term.parts();
        if (n == 0) {
            return ONE_SYMBOL;
        }
        if (t == ANCHOR_TERM_TYPE) {
            symbol_ = string.concat("$", Strings.toChecksumHexString(a));
        } else {
            symbol_ = toString(s);
        }
        if (n != 1 || d != 1) {
            symbol_ = symbol_.add("^", Strings.toStringSigned(n));
            if (d != 1) {
                symbol_ = symbol_.add("\\", Strings.toString(d));
            }
        }
    }

    /// @dev Returns the full compound unit symbol from an array of terms
    function symbol(Term[] memory terms) internal pure returns (string memory symbol_) {
        if (terms.length == 0) {
            return ONE_SYMBOL;
        }

        string memory mul; // Do not put * before the first term
        for (uint256 i = 0; i < terms.length; i++) {
            int256 n = terms[i].exponent().numerator();
            if (n > 0) {
                symbol_ = symbol_.add(mul, terms[i].symbol());
                mul = "*";
            }
        }

        if (bytes(symbol_).length == 0) {
            symbol_ = ONE_SYMBOL;
        }

        for (uint256 i = 0; i < terms.length; i++) {
            int256 n = terms[i].exponent().numerator();
            if (n < 0) {
                symbol_ = symbol_.add("/", terms[i].reciprocal().symbol());
            }
        }
    }

    /// @dev Parses a base symbol starting at buffer[start], returns base-packed uint
    function parseAddress(bytes memory buffer, uint256 start) internal pure returns (Term term, uint256 cursor) {
        uint256 end = buffer.length;
        cursor = start + 42;
        cursor.mustBeLessThan(end + 1);
        if (buffer[start] != "0") {
            revert BadHexCharacter(uint8(buffer[start]));
        }
        if (buffer[start + 1] != "x") {
            revert BadHexCharacter(uint8(buffer[start + 1]));
        }
        start += 2;
        uint160 result = 0;
        for (uint256 i = start; i < cursor; i++) {
            uint8 c = uint8(buffer[i]);
            if (c >= 48 && c <= 57) {
                // '0'-'9'
                result = result * 16 + (c - 48);
            } else if (c >= 65 && c <= 70) {
                // 'A'-'F'
                result = result * 16 + (c - 55);
            } else if (c >= 97 && c <= 102) {
                // 'a'-'f'
                result = result * 16 + (c - 87);
            } else {
                revert BadHexCharacter(c);
            }
        }
        term = address(result).withExponent(ONE_RATIONAL_8);
    }

    /// @dev Parses a base symbol starting at buffer[start], returns base-packed uint
    function parseBase(bytes memory buffer, uint256 start) internal pure returns (Term term, uint256 cursor) {
        uint256 end = buffer.length;
        cursor = start;

        // Advance the cursor past symbol characters.
        while (cursor < end && buffer[cursor].isSymbolChar()) {
            cursor++;
        }

        uint256 baseLength = cursor - start;

        if (baseLength > MAX_SYMBOL_SIZE) {
            revert BaseSymbolTooBig();
        }

        assembly {
            let word := mload(add(add(buffer, 32), start))
            let shift := sub(256, mul(baseLength, 8))
            let mask := shl(shift, sub(exp(2, mul(baseLength, 8)), 1))
            term := and(word, mask)
        }
    }

    /// @dev Parse an integer starting at buffer[start].
    function parseNumber(bytes memory buffer, uint256 start) internal pure returns (uint256 n, uint256 cursor) {
        uint256 end = buffer.length;
        cursor = start;
        while (cursor < end && n <= 128 && buffer[cursor] >= "0" && buffer[cursor] <= "9") {
            n = n * 10 + uint8(buffer[cursor]) - 48;
            cursor++;
        }
    }

    /// @dev Reverts if cursor is not less than end
    function mustBeLessThan(uint256 cursor, uint256 end) internal pure {
        if (cursor >= end) {
            revert UnexpectedCharacter(bytes1(0));
        }
    }

    /// @dev Parses a full compound symbol into an array of terms
    function parseTerms(string memory symbol_) internal pure returns (Term[] memory terms) {
        bytes memory buffer = bytes(symbol_);
        uint256 end = buffer.length;
        uint256 cursor = 0;

        cursor.mustBeLessThan(end);

        // Count number of terms
        uint256 termCount = 1;
        for (uint256 j = 1; j < end; j++) {
            if (buffer[j] == DIVIDE_SYMBOL || buffer[j] == MULTIPLY_SYMBOL) termCount++;
        }

        terms = new Term[](termCount);
        uint256 termIndex = 0;

        while (cursor < end) {
            int256 exp = 1;

            // Skip * or /
            if (cursor > 0) {
                if (buffer[cursor] == MULTIPLY_SYMBOL) {
                    cursor++;
                } else if (buffer[cursor] == DIVIDE_SYMBOL) {
                    exp = -exp;
                    cursor++;
                }
            }

            cursor.mustBeLessThan(end);

            Term term;
            if (buffer[cursor] == ANCHOR_PREFIX) {
                cursor++;
                (term, cursor) = parseAddress(buffer, cursor);
            } else {
                (term, cursor) = parseBase(buffer, cursor);
            }

            if (term.raw() == 0) {
                revert UnexpectedCharacter(cursor == end ? bytes1(0) : buffer[cursor]);
            }

            uint256 expDenom = 1;

            // Extract exponent if present
            if (cursor < end && buffer[cursor] == POWER_SYMBOL) {
                cursor++;
                cursor.mustBeLessThan(end);

                uint256 pow = 0;
                (pow, cursor) = parseNumber(buffer, cursor);
                exp *= pow.toInt128();

                if (cursor < end && buffer[cursor] == POWER_DIV) {
                    cursor++;
                    cursor.mustBeLessThan(end);
                    (expDenom, cursor) = parseNumber(buffer, cursor);
                }
            }

            Rational8 exp8 = exp.divRational8(expDenom);
            term = term.withExponent(exp8);
            terms[termIndex++] = term;
        }
    }

    function toInt128(uint256 x) internal pure returns (int128 y) {
        if (x <= uint128(type(int128).max)) {
            // forge-lint: disable-next-line(unsafe-typecast)
            y = int128(uint128(x));
        } else {
            revert ExponentTooBig();
        }
    }

    /// @dev Returns first n terms from array
    function take(Term[] memory long, uint256 n) internal pure returns (Term[] memory short) {
        if (long.length == n) {
            short = long;
        } else {
            short = new Term[](n);
            for (uint256 i = 0; i < n; i++) {
                short[i] = long[i];
            }
        }
    }

    /// @dev Merges two sorted term arrays
    function product(Term[] memory t1, Term[] memory t2) internal pure returns (Term[] memory t3) {
        uint256 n1 = t1.length;
        uint256 n2 = t2.length;

        if (n1 == 0) {
            return t2;
        }
        if (n2 == 0) {
            return t1;
        }

        t3 = new Term[](n1 + n2);
        uint256 i1 = 0;
        uint256 i2 = 0;
        uint256 i3 = 0;

        while (i1 < n1 && i2 < n2) {
            Term base1 = t1[i1].base();
            Term base2 = t2[i2].base();

            if (base1.raw() < base2.raw()) {
                t3[i3++] = t1[i1++];
            } else if (base2.raw() < base1.raw()) {
                t3[i3++] = t2[i2++];
            } else {
                // Same base, combine exponents
                // Sum using int16 then check for too big.
                Rational8 exp = t1[i1].exponent().add(t2[i2].exponent());
                if (exp.raw() != ZERO_RATIONAL_8.raw()) {
                    t3[i3++] = base1.withExponent(exp);
                }
                i1++;
                i2++;
            }
        }

        // Copy remaining terms
        while (i1 < n1) {
            t3[i3++] = t1[i1++];
        }
        while (i2 < n2) {
            t3[i3++] = t2[i2++];
        }

        t3 = t3.take(i3);
    }

    /// @dev Determine if the terms are in order.
    function inOrder(Term[] memory terms) internal pure returns (bool) {
        uint256 n = terms.length;
        if (n == 0) return true;

        for (uint256 i = 0; i < n - 1; i++) {
            if (terms[i].raw() > terms[i + 1].raw()) return false;
        }
        return true;
    }

    /// @dev Sorts terms in ascending base order using heap sort
    function sort(Term[] memory terms) internal pure returns (Term[] memory) {
        if (terms.inOrder()) return terms;

        uint256 n = terms.length;

        // Build max heap
        for (uint256 i = n / 2; i > 0; i--) {
            heapify(terms, n, i - 1);
        }

        // Extract elements from heap one by one
        for (uint256 i = n - 1; i > 0; i--) {
            // Move current root to end
            (terms[0], terms[i]) = (terms[i], terms[0]);
            // call max heapify on the reduced heap
            heapify(terms, i, 0);
        }
        return terms;
    }

    function heapify(Term[] memory terms, uint256 n, uint256 i) private pure {
        uint256 largest = i;
        uint256 left = 2 * i + 1;
        uint256 right = 2 * i + 2;

        if (left < n && terms[left].raw() > terms[largest].raw()) {
            largest = left;
        }
        if (right < n && terms[right].raw() > terms[largest].raw()) {
            largest = right;
        }
        if (largest != i) {
            (terms[i], terms[largest]) = (terms[largest], terms[i]);
            heapify(terms, n, largest);
        }
    }

    /// @dev Sorts and merges duplicate bases
    function sortAndMerge(Term[] memory terms) internal pure returns (Term[] memory) {
        terms = terms.sort();
        uint256 termCount = terms.length;
        uint256 j;
        Term term = terms[0].base();
        Rational exp = terms[0].exponent().toRational();
        for (uint256 i = 1; i < termCount; i++) {
            if (terms[i].base().raw() == term.raw()) {
                exp = exp.add(terms[i].exponent().toRational());
            } else {
                if (exp.raw() != ZERO_RATIONAL_8.raw() && term.raw() != ONE_TERM) {
                    terms[j] = term.withExponent(exp.toRational8());
                    j++;
                }
                term = terms[i].base();
                exp = terms[i].exponent().toRational();
            }
        }
        if (exp.raw() != ZERO_RATIONAL_8.raw() && term.raw() != ONE_TERM) {
            terms[j] = term.withExponent(exp.toRational8());
            j++;
        }

        terms = terms.take(j);
        return terms;
    }
}
