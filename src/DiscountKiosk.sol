// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Kiosk, IERC20} from "./Kiosk.sol";
import {Prototype} from "./Prototype.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Discount Kiosk
 * @notice A kiosk variant with a discounting price curve: price decreases
 *         linearly as inventory approaches a defined capacity.
 * @dev Inherits Kiosk for core buying, redemption, shares, and cloning logic.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
contract DiscountKiosk is Kiosk {
    /**
     * @notice Inventory level at which the effective price reaches zero.
     * @dev Defines the discount curve. When inventory ≥ capacity, goods past that point are free.
     */
    uint256 public capacity;

    /**
     * @notice Returns the quantity of goods purchasable for a given payment `v`
     *         under a linear discounting price curve.
     * @dev
     * - If inventory exceeds `capacity`, the excess portion is free.
     * - Otherwise, solves the closed-form integral of the linear price function:
     *       price(x) = listPrice * (1 - x / capacity)
     * @param v Amount of native tokens provided.
     * @return q Quantity of goods purchasable for value `v`.
     * @inheritdoc Kiosk
     */
    function quote(uint256 v) public view virtual override returns (uint256 q, bool soldOut) {
        uint256 available = inventory();
        bool beyondCapacity = capacity < available;

        uint256 d = beyondCapacity ? 0 : capacity - available;

        q = Math.sqrt(d * d + 2 ether * v * capacity / listPrice) - d;

        if (beyondCapacity) {
            // Add the free region beyond capacity.
            q += available - capacity;
        }
        soldOut = q >= available;
        if (soldOut) {
            q = available;
        }
    }

    /**
     * @notice Create a new DiscountKiosk clone and assign all initial shares to the caller.
     * @param goods_ The ERC-20 token being sold.
     * @param listPrice_ Base price per unit when inventory is full.
     * @param capacity_ Inventory level at which the price falls to zero.
     * @return kiosk The newly created DiscountKiosk instance.
     */
    function create(IERC20 goods_, uint256 listPrice_, uint256 capacity_) external returns (DiscountKiosk kiosk) {
        // forge-lint: disable-next-line(asm-keccak256)
        bytes memory initData = abi.encode(msg.sender, goods_, listPrice_, capacity_);
        (address tokenAddress,) = __clone(initData);
        kiosk = DiscountKiosk(payable(tokenAddress));
    }

    /**
     * @dev Internal initializer for a newly cloned kiosk.
     *      Called only by the Prototype during clone creation.
     * @param creator The account receiving the initial shares.
     * @param goods_ The token sold by the kiosk.
     * @param listPrice_ Base price per unit of goods.
     * @param capacity_ Inventory level where price reaches zero.
     */
    function __initialize(address creator, IERC20 goods_, uint256 listPrice_, uint256 capacity_) internal {
        super.__initialize(creator, goods_, listPrice_);
        capacity = capacity_;
    }

    /**
     * @inheritdoc Prototype
     * @dev Decodes initialization calldata and dispatches to the typed initializer.
     */
    function __initialize(bytes memory initData) public virtual override onlyPrototype {
        (address creator, IERC20 goods_, uint256 listPrice_, uint256 capacity_) =
            abi.decode(initData, (address, IERC20, uint256, uint256));

        __initialize(creator, goods_, listPrice_, capacity_);
    }
}
