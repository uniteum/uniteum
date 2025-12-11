// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {KioskBaseTest} from "./KioskBase.t.sol";
import {DiscountKiosk} from "../src/DiscountKiosk.sol";
import {console} from "forge-std/console.sol";

contract DiscountKioskTest is KioskBaseTest {
    DiscountKiosk public prototype;

    function setUp() public virtual override {
        super.setUp();
        prototype = new DiscountKiosk{salt: 0x0}();
    }

    function test_Create() public {
        DiscountKiosk kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), 5_000 ether, token);
        assertEq(kiosk.listPrice(), PRICE);
        assertEq(address(kiosk.goods()), address(token));
    }

    function logKiosk(DiscountKiosk kiosk) internal view {
        console.log("Kiosk Inventory:", kiosk.inventory());
        console.log("Kiosk Capacity :", kiosk.capacity());
        console.log("Kiosk ListPrice:", kiosk.listPrice());
    }

    function test_QuoteAllForFull() public returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), CAPACITY, token);
        logKiosk(kiosk);
        value = CAPACITY * PRICE / 2 ether;
        (actual, soldOut) = kiosk.quote(value);
        console.log("test_QuoteAllForFull value:", value);
        console.log("test_QuoteAllForFull soldOut:", soldOut);
        console.log("test_QuoteAllForFull actual:", actual);
        uint256 expected = CAPACITY;
        assertEq(actual, expected);
    }

    function test_FirstHalf() public returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), CAPACITY, token);
        logKiosk(kiosk);
        value = CAPACITY * PRICE / 8 ether;
        (actual, soldOut) = kiosk.quote(value);
        console.log("test_QuoteQuarterForHalf value:", value);
        console.log("test_QuoteQuarterForHalf soldOut:", soldOut);
        console.log("test_QuoteQuarterForHalf actual:", actual);
        uint256 expected = CAPACITY / 2;
        assertEq(actual, expected);
    }

    function test_SecondHalf() public returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), CAPACITY / 2, token);
        logKiosk(kiosk);
        value = CAPACITY * PRICE * 3 / 8 ether;
        (actual, soldOut) = kiosk.quote(value);
        console.log("test_ThreeQuarterForUpperHalf value:", value);
        console.log("test_ThreeQuarterForUpperHalf soldOut:", soldOut);
        console.log("test_ThreeQuarterForUpperHalf actual:", actual);
        uint256 expected = CAPACITY / 2;
        assertEq(actual, expected);
    }

    function test_ThirdFourth() public returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), CAPACITY / 2, token);
        logKiosk(kiosk);
        value = CAPACITY * PRICE * 5 / 32 ether;
        (actual, soldOut) = kiosk.quote(value);
        console.log("test_FiveSixteenth value:", value);
        console.log("test_FiveSixteenth soldOut:", soldOut);
        console.log("test_FiveSixteenth actual:", actual);
        uint256 expected = CAPACITY / 4;
        assertEq(actual, expected);
    }

    function test_OverflowFree(uint256 excess)
        public
        returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut)
    {
        excess = bound(excess, 1, CAPACITY);
        kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), CAPACITY + excess, token);
        value = 0;
        (actual, soldOut) = kiosk.quote(value);
        uint256 expected = excess;
        assertEq(actual, expected);
    }

    function test_Quote() public returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), 5_000 ether, token);
        value = 3 ether;
        (actual, soldOut) = kiosk.quote(value);
        //uint256 expected = value / PRICE;
        //assertEq(actual, expected);
    }

    function test_Buy() public returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        (kiosk, value, actual, soldOut) = test_Quote();
        buyer.buy{value: value}(kiosk);
        assertEq(token.balanceOf(address(buyer)), actual);
    }

    function test_BuyViaReceive() public returns (DiscountKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        (kiosk, value, actual, soldOut) = test_Quote();
        buyer.buyViaReceive{value: value}(kiosk);
        assertEq(token.balanceOf(address(buyer)), actual);
    }

    function test_ReclaimSome() public {
        DiscountKiosk kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        creator.give(address(kiosk), 120 ether, token);
        creator.reclaim(kiosk, 50 ether);
        assertEq(token.balanceOf(address(kiosk)), 70 ether);
    }

    function test_CollectSome() public {
        DiscountKiosk kiosk = creator.createDiscountKiosk(prototype, token, PRICE, CAPACITY);
        vm.deal(address(kiosk), 120 ether);
        creator.collect(kiosk, 50 ether);
        assertEq(address(creator).balance, 50 ether);
        assertEq(address(kiosk).balance, 70 ether);
    }
}
