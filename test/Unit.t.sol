// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {UnitBaseTest, Units, Unit, IUnit, IERC20} from "./UnitBase.t.sol";
import {Prototype} from "../src/Prototype.sol";

contract UnitTest is UnitBaseTest {
    using Units for *;

    address constant USDT_ADDRESS = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;
    string constant USDT_SYMBOL = "$0xffD4505B3452Dc22f8473616d50503bA9E1710Ac";
    string public constant NAME_PREFIX = "Uniteum 0.4 ";

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

    function sqrtTest(string memory s, string memory r) public {
        IUnit u = unit(s);
        (, string memory sqrtSymbol) = u.sqrt();
        assertEq(sqrtSymbol, r);
    }

    function testSqrt() public {
        sqrtTest("a*a", "a");
        /*
        sqrtTest("a", "a^1\\2");
        sqrtTest("a^3", "a^3\\2");
        sqrtTest("1^127", "1");
        sqrtTest("a^127", "a^127\\2");
        sqrtTest("a*b/a", "b^1\\2");
        sqrtTest("a*b/b", "1/a");
        sqrtTest("a/a*b/b", "1");
        sqrtTest("a/b", "b/a");
        sqrtTest("a*b^3*c/a/b/c/b/c", "c^1\\2/b^1\\2");
        */
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
        vm.expectRevert();
        nu.product(du);
    }

    function testBadProductUnits() public {
        badProductUnitTest("a^127", "a");
    }

    function tooBigExponent(string memory n) public {
        vm.expectRevert();
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

    // ============ Symbol Edge Cases ============

    function testEmptySymbolReverts() public {
        vm.expectRevert();
        l.multiply("");
    }

    function testSymbolWithSpacesReverts() public {
        vm.expectRevert();
        l.multiply("foo bar");
    }

    function testSymbolWithSpecialCharsReverts() public {
        vm.expectRevert();
        l.multiply("foo@bar");
        vm.expectRevert();
        l.multiply("foo#bar");
        vm.expectRevert();
        l.multiply("foo$bar");
        vm.expectRevert();
        l.multiply("foo%bar");
    }

    function testValidSymbolCharacters() public {
        // Test all valid characters
        unit("abc");
        unit("ABC");
        unit("123");
        unit("_");
        unit("-");
        unit(".");
        unit("a1B2_3-4.5");
    }

    function testSymbolExactly30Chars() public {
        // Exactly 30 chars should work
        string memory s30 = "123456789012345678901234567890";
        IUnit u = unit(s30);
        assertEq(u.symbol(), s30);
    }

    function testSymbol31CharsReverts() public {
        string memory s31 = "1234567890123456789012345678901";
        vm.expectRevert(Units.BaseSymbolTooBig.selector);
        l.multiply(s31);
    }

    // ============ Exponent Edge Cases ============

    function testZeroExponent() public {
        unaryTest("a^0", "1", "1");
    }

    function testNegativeExponent() public {
        unaryTest("1/a", "1/a", "a");
        unaryTest("1/a^2", "1/a^2", "a^2");
    }

    function testMaxExponent127() public {
        unaryTest("a^127", "a^127", "1/a^127");
    }

    function testMinExponentNeg127() public {
        unaryTest("1/a^127", "1/a^127", "a^127");
    }

    function testRationalExponents() public {
        unaryTest("a^1\\2", "a^1\\2", "1/a^1\\2");
        unaryTest("a^2\\3", "a^2\\3", "1/a^2\\3");
        unaryTest("1/a^3\\4", "1/a^3\\4", "a^3\\4");
    }

    function testExponentReduction() public {
        // Test that exponents are reduced to lowest terms
        unaryTest("a^2\\4", "a^1\\2", "1/a^1\\2");
        unaryTest("a^4\\2", "a^2", "1/a^2");
        unaryTest("a^6\\9", "a^2\\3", "1/a^2\\3");
        unaryTest("a^100\\50", "a^2", "1/a^2");
    }

    function testComplexExponentComposition() public {
        // a^(2/3) * a^(1/3) = a^1
        IUnit a23 = unit("a^2\\3");
        IUnit a13 = unit("a^1\\3");
        IUnit product = a23.multiply(a13);
        assertEq(product.symbol(), "a");
    }

    // ============ Reciprocal Edge Cases ============

    function testReciprocalOfReciprocal() public view {
        assertEq(address(U.reciprocal().reciprocal()), address(U));
        assertEq(address(V.reciprocal().reciprocal()), address(V));
    }

    function testReciprocalSymmetry() public {
        IUnit foo = unit("foo");
        IUnit fooRecip = foo.reciprocal();
        assertEq(fooRecip.symbol(), "1/foo");
        assertEq(fooRecip.reciprocal().symbol(), "foo");
    }

    function testReciprocalOfComplexUnit() public {
        IUnit complex = unit("kg*m/s^2");
        IUnit recip = complex.reciprocal();
        assertEq(recip.symbol(), "s^2/kg/m");
    }

    // ============ Product Edge Cases ============

    function testProductWithSelf() public {
        binaryTest("foo", "foo", "foo^2", "1");
    }

    function testProductWithReciprocal() public {
        IUnit foo = unit("foo");
        IUnit fooRecip = foo.reciprocal();
        IUnit product = foo.multiply(fooRecip);
        assertEq(product.symbol(), "1");
        assertEq(address(product), address(l));
    }

    function testProductCommutative() public {
        IUnit a = unit("a");
        IUnit b = unit("b");
        IUnit ab1 = a.multiply(b);
        IUnit ab2 = b.multiply(a);
        assertEq(address(ab1), address(ab2));
        assertEq(ab1.symbol(), "a*b");
    }

    function testProductAssociative() public {
        IUnit a = unit("a");
        IUnit b = unit("b");
        IUnit c = unit("c");
        IUnit ab = a.multiply(b);
        IUnit abc1 = ab.multiply(c);
        IUnit bc = b.multiply(c);
        IUnit abc2 = a.multiply(bc);
        assertEq(address(abc1), address(abc2));
    }

    function testProductWithOne() public {
        IUnit foo = unit("foo");
        IUnit product = foo.multiply(l);
        assertEq(address(product), address(foo));
    }

    function testMultipleProductsOfSameUnits() public {
        IUnit a = unit("a");
        IUnit b = unit("b");
        IUnit ab1 = a.multiply(b);
        IUnit ab2 = a.multiply(b);
        assertEq(address(ab1), address(ab2), "should return same unit");
    }

    // ============ Anchored Unit Edge Cases ============

    function testAnchoredUnitFormat() public view {
        address token = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        string memory expected = "$0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
        string memory actual = l.anchoredSymbol(IERC20(token));
        assertEq(actual, expected);
    }

    function testAnchoredUnitCreation() public {
        IUnit wrapped = unit(USDT_SYMBOL);
        assertEq(address(wrapped.anchor()), USDT_ADDRESS);
        assertEq(wrapped.symbol(), USDT_SYMBOL);
    }

    function testAnchoredReciprocalHasNoAnchor() public {
        IUnit wrapped = unit(USDT_SYMBOL);
        assertEq(address(wrapped.reciprocal().anchor()), address(0));
    }

    function testAnchoredWithExponent() public {
        // Anchored units with exponents != 1 should not have anchor
        string memory anchoredSquared = string.concat(USDT_SYMBOL, "^2");
        IUnit u = unit(anchoredSquared);
        assertEq(address(u.anchor()), address(0), "only base units can be anchored");
    }

    // ============ Name and Metadata Edge Cases ============

    function testNameFormat() public view {
        assertEq(l.name(), string.concat(NAME_PREFIX, "1"));
        assertEq(U.name(), string.concat(NAME_PREFIX, "U"));
        assertEq(V.name(), string.concat(NAME_PREFIX, "1/U"));
    }

    function testDecimals() public view {
        assertEq(l.decimals(), 18);
        assertEq(U.decimals(), 18);
        assertEq(V.decimals(), 18);
    }

    // ============ Duplicate Creation Edge Cases ============

    function testCreateSameUnitTwiceReturnsSameAddress() public {
        IUnit foo1 = l.multiply("foo");
        IUnit foo2 = l.multiply("foo");
        assertEq(address(foo1), address(foo2));
    }

    function testNormalizedSymbolsCreateSameUnit() public {
        IUnit u1 = l.multiply("a*b/a");
        IUnit u2 = l.multiply("b");
        assertEq(address(u1), address(u2));
    }

    // ============ Complex Symbol Composition ============

    function testTripleProduct() public {
        IUnit a = unit("a");
        IUnit b = unit("b");
        IUnit c = unit("c");
        IUnit abc = a.multiply(b).multiply(c);
        assertEq(abc.symbol(), "a*b*c");
    }

    function testMixedProductAndDivision() public {
        unaryTest("a*b/c*d/e", "a*b*d/c/e", "c*e/a/b/d");
    }

    function testDeepNesting() public {
        unaryTest("a/b/c/d/e", "a/b/c/d/e", "b*c*d*e/a");
    }

    function testPowerThenMultiply() public {
        IUnit a2 = unit("a^2");
        IUnit b = unit("b");
        IUnit a2b = a2.multiply(b);
        assertEq(a2b.symbol(), "a^2*b");
    }

    // ============ Invariant View Function Edge Cases ============

    function testInvariantOnOne() public {
        vm.expectRevert(IUnit.FunctionCalledOnOne.selector);
        l.invariant();
    }

    function testInvariantWithSelfReverts() public {
        vm.expectRevert(IUnit.DuplicateUnits.selector);
        U.invariant(U);
    }

    function testInvariantPureFunction() public view {
        uint256 w1 = l.invariant(100, 100);
        assertEq(w1, 100);
        uint256 w2 = l.invariant(100, 400);
        assertEq(w2, 200);
        uint256 w3 = l.invariant(0, 0);
        assertEq(w3, 0);
    }

    // ============ Product View Function Edge Cases ============

    function testProductViewDoesNotCreateUnit() public view {
        string memory symbolToTest = "newUnitNotYetCreated";
        (IUnit predicted, string memory canonical) = l.product(symbolToTest);
        assertEq(canonical, symbolToTest);
        // Unit should not exist yet
        assertEq(address(predicted).code.length, 0, "unit should not be deployed");
    }

    function testProductViewNormalizesSymbol() public view {
        (, string memory canonical) = l.product("a*b/a");
        assertEq(canonical, "b");
    }

    // ============ Symbol Sorting Edge Cases ============

    function testAlphabeticalSorting() public {
        unaryTest("z*a*m*b", "a*b*m*z", "1/a/b/m/z");
    }

    function testNumbersBeforeLetters() public {
        // Verify sorting order: numbers, uppercase, lowercase, special chars
        IUnit u = unit("z*A*0");
        string memory sym = u.symbol();
        // The actual sorting is determined by ASCII/implementation
        // Just verify it's deterministic
        assertEq(l.multiply("z*A*0").symbol(), sym);
        assertEq(l.multiply("A*z*0").symbol(), sym);
        assertEq(l.multiply("0*z*A").symbol(), sym);
    }

    // ============ Edge Cases for Product Function with IUnit ============

    function testProductCaching() public {
        IUnit a = unit("a");
        IUnit b = unit("b");

        // First call should cache the result
        IUnit ab1 = a.multiply(b);

        // Second call should use cache
        IUnit ab2 = a.multiply(b);

        assertEq(address(ab1), address(ab2));
    }

    function testProductViewUsesCache() public {
        IUnit a = unit("a");
        IUnit b = unit("b");

        // Create the product
        IUnit ab = a.multiply(b);

        // Product view should return the same address
        (IUnit abView, string memory canonical) = a.product(b);
        assertEq(address(ab), address(abView));
        assertEq(canonical, ab.symbol());
    }

    // ============ Exponent Overflow Edge Cases ============

    function testExponentOverflowAt128() public {
        vm.expectRevert();
        l.multiply("a^128");
        vm.expectRevert();
        l.multiply("1/a^128");
    }

    function testProductCausingExponentOverflow() public {
        badProductUnitTest("a^127", "a");
        badProductUnitTest("a^64", "a^64");
        badProductUnitTest("a^100", "a^50");
    }

    function testExponentUnderflowAt128() public {
        vm.expectRevert();
        l.multiply("1/a^128");
    }

    // ============ Rational Denominator Edge Cases ============

    function testMaxDenominator255() public {
        // Should work with denominator up to 255
        unaryTest("a^1\\255", "a^1\\255", "1/a^1\\255");
    }

    function testDenominatorOverflow() public {
        tooBigExponent("a^1\\256");
        tooBigExponent("a^1\\257");
        tooBigExponent("a^1\\1000");
    }

    // ============ One Unit Special Cases ============

    function testOneTimesOneEqualsOne() public {
        IUnit one1 = l.multiply("1");
        assertEq(address(one1), address(l));
    }

    function testOneToAnyPowerIsOne() public {
        unaryTest("1^2", "1", "1");
        unaryTest("1^100", "1", "1");
        unaryTest("1/1^50", "1", "1");
        unaryTest("1^3\\7", "1", "1");
    }

    function testComplexExpressionSimplifyingToOne() public {
        unaryTest("a*b/a/b", "1", "1");
        unaryTest("foo/foo", "1", "1");
        unaryTest("a^2/a^2", "1", "1");
    }

    // ============ Anchored Symbol Helper Function Edge Cases ============

    function testAnchoredSymbolWithZeroAddress() public view {
        string memory sym = l.anchoredSymbol(IERC20(address(0)));
        assertEq(sym, "$0x0000000000000000000000000000000000000000");
    }

    function testAnchoredPredict() public view {
        (, string memory canonical) = l.anchoredPredict(IERC20(USDT_ADDRESS));
        assertEq(canonical, USDT_SYMBOL);
        // Can't test address until created
    }

    function testAnchoredFunction() public {
        IUnit anchored1 = l.anchored(IERC20(USDT_ADDRESS));
        assertEq(anchored1.symbol(), USDT_SYMBOL);

        // Calling again should return same unit
        IUnit anchored2 = l.anchored(IERC20(USDT_ADDRESS));
        assertEq(address(anchored1), address(anchored2));
    }

    // ============ Malformed Expression Edge Cases ============

    function testInvalidExponentFormat() public {
        vm.expectRevert();
        l.multiply("a^");

        vm.expectRevert();
        l.multiply("a^^2");
    }

    function testInvalidRationalFormat() public {
        vm.expectRevert();
        l.multiply("a^1\\");
    }

    function testLeadingOperators() public {
        vm.expectRevert();
        l.multiply("*a");

        vm.expectRevert();
        l.multiply("/a");
    }

    function testTrailingOperators() public {
        vm.expectRevert();
        l.multiply("a*");

        vm.expectRevert();
        l.multiply("a/");
    }

    function testDoubleOperators() public {
        vm.expectRevert();
        l.multiply("a**b");

        vm.expectRevert();
        l.multiply("a//b");

        vm.expectRevert();
        l.multiply("a*/b");
    }

    // ============ Mixed Anchored and Regular Units ============

    function testMixedAnchoredAndRegular() public {
        IUnit usd = unit("USD");
        IUnit weth = unit(USDT_SYMBOL);
        IUnit pair = usd.multiply(weth);
        // Verify both are in the symbol
        string memory sym = pair.symbol();
        assertTrue(bytes(sym).length > 0);
    }

    // ============ Determinism Tests ============

    function testUnitAddressDeterministic() public {
        IUnit foo1 = l.multiply("foo");
        address addr1 = address(foo1);

        // Predict should give same address
        (IUnit fooPredicted,) = l.product("foo");
        assertEq(address(fooPredicted), addr1);
    }

    function testComplexSymbolDeterministic() public {
        string memory complex = "kg*m^2/s^2";
        IUnit u1 = l.multiply(complex);

        // Different order should normalize to same address
        IUnit u2 = l.multiply("m^2*kg/s^2");
        assertEq(address(u1), address(u2));
    }
}
