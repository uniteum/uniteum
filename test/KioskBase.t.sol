// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {BaseTest} from "./Base.t.sol";
import {TestToken} from "./TestToken.sol";
import {KioskUser} from "./KioskUser.sol";

contract KioskBaseTest is BaseTest {
    uint256 public constant PRICE = 0.001 ether;
    uint256 public constant CAPACITY = 1000000 ether;

    TestToken public token;
    KioskUser public creator;
    KioskUser public buyer;

    function setUp() public virtual override {
        creator = new KioskUser("Creator");
        buyer = new KioskUser("Buyer");
        vm.deal(address(buyer), PRICE * CAPACITY / 2);
        token = creator.newToken("TEST", 3 * CAPACITY);
    }
}
