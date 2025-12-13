// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {KioskBaseTest} from "./KioskBase.t.sol";
import {FixedKiosk, Kiosk} from "../src/FixedKiosk.sol";
import {IKiosk} from "../src/IKiosk.sol";
import {console} from "forge-std/Test.sol";

contract KioskTest is KioskBaseTest {
    FixedKiosk public prototype;

    function setUp() public virtual override {
        super.setUp();
        prototype = new FixedKiosk{salt: 0x0}();
    }

    function test_Create() public {
        FixedKiosk kiosk = creator.createKiosk(prototype, token, PRICE);
        creator.give(address(kiosk), 5_000 ether, token);
        assertEq(kiosk.listPrice(), PRICE);
        assertEq(address(kiosk.goods()), address(token));
    }

    function test_Balance(uint256 bal) public {
        bal = bal % 1_000 ether;
        FixedKiosk kiosk = creator.createKiosk(prototype, token, PRICE);
        vm.deal(address(kiosk), bal);
        uint256 actual = kiosk.balance();
        assertEq(actual, bal);
    }

    function test_Quote() public returns (FixedKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        kiosk = creator.createKiosk(prototype, token, PRICE);
        creator.give(address(kiosk), 5_000 ether, token);
        value = 3 ether;
        uint256 expected = 1 ether * value / PRICE;
        (actual, soldOut) = kiosk.quote(value);
        assertEq(actual, expected);
    }

    function test_Buy() public returns (FixedKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        (kiosk, value, actual, soldOut) = test_Quote();
        buyer.buy{value: value}(kiosk);
        assertEq(token.balanceOf(address(buyer)), actual);
    }

    function test_BuyRandom(uint256 price, uint256 value, uint256 inventory)
        public
        returns (FixedKiosk kiosk, uint256 actual, bool soldOut)
    {
        price = (price % 1 ether) + 1 wei;
        value = value % 1000 ether;
        inventory = inventory % token.totalSupply();
        console.log("test_BuyRandom(%s, %s, %s)", price, value, inventory);
        kiosk = creator.createKiosk(prototype, token, price);
        creator.give(address(kiosk), inventory, token);
        vm.deal(address(buyer), price * inventory / 2);
        (actual, soldOut) = buyer.quote(kiosk, value);
        if (actual > 0) {
            (actual, soldOut) = buyer.buy{value: value}(kiosk);
            assertEq(token.balanceOf(address(buyer)), actual);
        }
    }

    function test_BuyViaReceive() public returns (FixedKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        (kiosk, value, actual, soldOut) = test_Quote();
        buyer.buyViaReceive{value: value}(kiosk);
        assertEq(token.balanceOf(address(buyer)), actual);
    }

    function test_ReclaimSome() public {
        FixedKiosk kiosk = creator.createKiosk(prototype, token, PRICE);
        creator.give(address(kiosk), 120 ether, token);
        creator.reclaim(kiosk, 50 ether);
        assertEq(token.balanceOf(address(kiosk)), 70 ether);
    }

    function test_CollectSome() public {
        FixedKiosk kiosk = creator.createKiosk(prototype, token, PRICE);
        vm.deal(address(kiosk), 120 ether);
        creator.collect(kiosk, 50 ether);
        assertEq(address(creator).balance, 50 ether);
        assertEq(address(kiosk).balance, 70 ether);
    }

    function test_BoughtZeroReverts(uint256 price, uint256 value, uint256 inventory)
        public
        returns (FixedKiosk kiosk, uint256 actual, bool soldOut)
    {
        price = (price % 1 ether) + 1 wei;
        value = value % 1000 ether;
        inventory = inventory % token.totalSupply() + 1;
        console.log("test_BuyRandom(%s, %s, %s)", price, value, inventory);
        kiosk = creator.createKiosk(prototype, token, price);
        vm.deal(address(buyer), price * inventory / 2);
        vm.expectRevert(IKiosk.ZeroBought.selector);
        (actual, soldOut) = buyer.buy{value: value}(kiosk);
        assertEq(token.balanceOf(address(buyer)), actual);
    }
}
