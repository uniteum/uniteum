// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {User} from "./User.sol";
import {FixedKiosk, Kiosk} from "../src/FixedKiosk.sol";
import {DiscountKiosk} from "../src/DiscountKiosk.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract KioskUser is User {
    constructor(string memory name_) User(name_) {}

    /**
     * @notice Accept payments to simulate a user with a wallet.
     */
    receive() external payable {}

    // Regular Kiosk
    function createKiosk(FixedKiosk prototype, IERC20Metadata token, uint256 price)
        external
        returns (FixedKiosk kiosk)
    {
        kiosk = prototype.create(token, price);
    }

    // Discount Kiosk
    function createDiscountKiosk(DiscountKiosk prototype, IERC20Metadata token, uint256 price, uint256 capacity_)
        external
        returns (DiscountKiosk kiosk)
    {
        kiosk = prototype.create(token, price, capacity_);
    }

    function buy(Kiosk kiosk) external payable returns (uint256 q, bool soldOut) {
        (q, soldOut) = kiosk.buy{value: msg.value}();
    }

    function buyViaReceive(Kiosk kiosk) external payable {
        (bool ok,) = address(kiosk).call{value: msg.value}("");
        assertTrue(ok, "Send failed");
    }

    function reclaim(Kiosk kiosk, uint256 shares) external {
        kiosk.reclaim(shares);
    }

    function collect(Kiosk kiosk, uint256 shares) external {
        kiosk.collect(shares);
    }

    function quote(Kiosk kiosk, uint256 value) external view returns (uint256, bool) {
        return kiosk.quote(value);
    }

    function inventory(Kiosk kiosk) external view returns (uint256) {
        return kiosk.inventory();
    }
}
