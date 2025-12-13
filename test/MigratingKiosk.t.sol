// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {KioskBaseTest} from "./KioskBase.t.sol";
import {MigratingKiosk} from "../src/MigratingKiosk.sol";
import {FixedKiosk, Kiosk} from "../src/FixedKiosk.sol";
import {IKiosk} from "../src/IKiosk.sol";
import {MockMigratableToken} from "./MockMigratableToken.sol";
import {TestToken} from "./TestToken.sol";
import {console} from "forge-std/Test.sol";

contract MigratingKioskTest is KioskBaseTest {
    MigratingKiosk public prototype;
    FixedKiosk public sourceKioskPrototype;
    MockMigratableToken public destinationToken;
    FixedKiosk public sourceKiosk;

    function setUp() public virtual override {
        super.setUp();

        // Deploy prototypes
        prototype = new MigratingKiosk{salt: 0x0}();
        sourceKioskPrototype = new FixedKiosk{salt: bytes32(uint256(1))}();

        // Create source kiosk selling upstream tokens
        sourceKiosk = creator.createKiosk(sourceKioskPrototype, token, PRICE);
        creator.give(address(sourceKiosk), 5_000 ether, token);

        // Create destination token that accepts migration from source token
        destinationToken = new MockMigratableToken("DEST", token);
    }

    function test_Create() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);
        assertEq(kiosk.listPrice(), PRICE);
        assertEq(address(kiosk.goods()), address(destinationToken));
        assertEq(address(kiosk.sourceKiosk()), address(sourceKiosk));
        assertEq(address(kiosk.destinationToken()), address(destinationToken));
    }

    function test_Quote() public returns (MigratingKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);
        value = 3 ether;
        uint256 expected = 1 ether * value / PRICE;
        (actual, soldOut) = kiosk.quote(value);
        assertEq(actual, expected);
        assertEq(soldOut, false);
    }

    function test_Inventory() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);
        uint256 inv = kiosk.inventory();
        assertEq(inv, 5_000 ether);
        assertEq(inv, sourceKiosk.inventory());
    }

    function test_Balance() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);
        vm.deal(address(sourceKiosk), 100 ether);
        uint256 bal = kiosk.balance();
        assertEq(bal, 100 ether);
        assertEq(bal, sourceKiosk.balance());
    }

    function test_Buy() public returns (MigratingKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        (kiosk, value, actual, soldOut) = test_Quote();

        uint256 buyerBalanceBefore = destinationToken.balanceOf(address(buyer));
        uint256 kioskInventoryBefore = sourceKiosk.inventory();

        buyer.buy{value: value}(Kiosk(payable(address(kiosk))));

        // Buyer should receive destination tokens
        assertEq(destinationToken.balanceOf(address(buyer)), buyerBalanceBefore + actual);

        // Source kiosk should have less inventory
        assertEq(sourceKiosk.inventory(), kioskInventoryBefore - actual);

        // Source tokens should be held by destination token
        assertEq(token.balanceOf(address(destinationToken)), actual);
    }

    function test_BuyMultiple() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);

        uint256 value1 = 1 ether;
        uint256 value2 = 2 ether;

        (uint256 expected1,) = kiosk.quote(value1);
        buyer.buy{value: value1}(Kiosk(payable(address(kiosk))));
        assertEq(destinationToken.balanceOf(address(buyer)), expected1);

        (uint256 expected2,) = kiosk.quote(value2);
        buyer.buy{value: value2}(Kiosk(payable(address(kiosk))));
        assertEq(destinationToken.balanceOf(address(buyer)), expected1 + expected2);
    }

    function test_BuyViaReceive() public returns (MigratingKiosk kiosk, uint256 value, uint256 actual, bool soldOut) {
        (kiosk, value, actual, soldOut) = test_Quote();

        uint256 buyerBalanceBefore = destinationToken.balanceOf(address(buyer));

        buyer.buyViaReceive{value: value}(Kiosk(payable(address(kiosk))));

        assertEq(destinationToken.balanceOf(address(buyer)), buyerBalanceBefore + actual);
    }

    function test_BuyRandom(uint256 value, uint256 inventory)
        public
        returns (MigratingKiosk kiosk, uint256 actual, bool soldOut)
    {
        value = value % 1000 ether;
        inventory = inventory % token.totalSupply();

        console.log("test_BuyRandom(%s, %s)", value, inventory);

        // Create fresh source kiosk with specific inventory
        FixedKiosk freshSourceKiosk = creator.createKiosk(sourceKioskPrototype, token, PRICE);
        creator.give(address(freshSourceKiosk), inventory, token);

        kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(freshSourceKiosk)), destinationToken);

        vm.deal(address(buyer), value);
        (actual, soldOut) = buyer.quote(Kiosk(payable(address(kiosk))), value);

        if (actual > 0) {
            (actual, soldOut) = buyer.buy{value: value}(Kiosk(payable(address(kiosk))));
            assertEq(destinationToken.balanceOf(address(buyer)), actual);
        }
    }

    function test_BuyUntilSoldOut() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);

        uint256 totalInventory = sourceKiosk.inventory();
        uint256 valueNeeded = totalInventory * PRICE / 1 ether;

        vm.deal(address(buyer), valueNeeded);

        (uint256 bought, bool soldOut) = buyer.buy{value: valueNeeded}(Kiosk(payable(address(kiosk))));

        assertTrue(soldOut);
        assertEq(bought, totalInventory);
        assertEq(destinationToken.balanceOf(address(buyer)), totalInventory);
        assertEq(sourceKiosk.inventory(), 0);
    }

    function test_ReclaimReverts() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);

        vm.expectRevert(MigratingKiosk.NotSupported.selector);
        creator.reclaim(Kiosk(payable(address(kiosk))), 50 ether);
    }

    function test_CollectReverts() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);

        vm.expectRevert(MigratingKiosk.NotSupported.selector);
        creator.collect(Kiosk(payable(address(kiosk))), 50 ether);
    }

    function test_BoughtZeroReverts() public {
        MigratingKiosk kiosk = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);

        // Try to buy with 0 value
        vm.expectRevert(IKiosk.ZeroBought.selector);
        buyer.buy{value: 0}(Kiosk(payable(address(kiosk))));
    }

    function test_MultipleKiosksIndependent() public {
        // Create second source kiosk with different token
        TestToken token2 = creator.newToken("TEST2", 3 * CAPACITY);
        FixedKiosk sourceKiosk2 = creator.createKiosk(sourceKioskPrototype, token2, PRICE * 2);
        creator.give(address(sourceKiosk2), 5_000 ether, token2);

        MockMigratableToken destinationToken2 = new MockMigratableToken("DEST2", token2);

        // Create two migrating kiosks
        MigratingKiosk kiosk1 = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk)), destinationToken);
        MigratingKiosk kiosk2 = creator.createMigratingKiosk(prototype, IKiosk(address(sourceKiosk2)), destinationToken2);

        // Verify they're independent
        assertEq(address(kiosk1.sourceKiosk()), address(sourceKiosk));
        assertEq(address(kiosk2.sourceKiosk()), address(sourceKiosk2));
        assertEq(kiosk1.listPrice(), PRICE);
        assertEq(kiosk2.listPrice(), PRICE * 2);

        // Buy from both
        uint256 value = 1 ether;
        (uint256 q1,) = buyer.buy{value: value}(Kiosk(payable(address(kiosk1))));
        (uint256 q2,) = buyer.buy{value: value}(Kiosk(payable(address(kiosk2))));

        assertEq(destinationToken.balanceOf(address(buyer)), q1);
        assertEq(destinationToken2.balanceOf(address(buyer)), q2);
    }
}
