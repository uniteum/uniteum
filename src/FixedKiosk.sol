// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Kiosk, IERC20} from "./Kiosk.sol";
import {Prototype} from "./Prototype.sol";

/**
 * @title Fixed Kiosk
 * @notice Fixed-price kiosk for selling ERC-20 tokens in return for native currency.
 * @dev Inherits Kiosk for core buying, redemption, shares, and cloning logic.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
contract FixedKiosk is Kiosk {
    /**
     * @notice This kiosk uses fixed pricing: q = v / listPrice.
     * @inheritdoc Kiosk
     */
    function quote(uint256 v) public view virtual override returns (uint256 q, bool soldOut) {
        q = 1 ether * v / listPrice;
        soldOut = q >= inventory();
        if (soldOut) {
            q = inventory();
        }
    }

    /**
     * @notice Create a kiosk and send all of the newly minted shares to the caller.
     * @param goods_ The token being sold.
     * @param listPrice_ Fixed price in native tokens per unit of goods.
     */
    function create(IERC20 goods_, uint256 listPrice_) public returns (FixedKiosk kiosk) {
        // forge-lint: disable-next-line(asm-keccak256)
        bytes memory initData = abi.encode(msg.sender, goods_, listPrice_);
        (address tokenAddress,) = __clone(initData);
        kiosk = FixedKiosk(payable(tokenAddress));
    }

    /// @inheritdoc Prototype
    function __initialize(bytes memory initData) public virtual override onlyPrototype {
        (address creator, IERC20 goods_, uint256 listPrice_) = abi.decode(initData, (address, IERC20, uint256));
        __initialize(creator, goods_, listPrice_);
    }
}
