// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IKiosk} from "./IKiosk.sol";
import {Prototype} from "./Prototype.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/**
 * @title Kiosk
 * @notice Sell ERC-20 tokens for native currency with no refunds.
 * @dev Owners can collect proceeds and reclaim unsold inventory.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
abstract contract Kiosk is IKiosk, Prototype, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /**
     * @notice ERC-20 token being sold.
     */
    IERC20 public goods;

    /**
     * @notice Reference price in native tokens per unit.
     */
    uint256 public listPrice;

    /**
     * @notice Kiosk creator and owner.
     */
    address public owner;

    // ============ Initialization ============

    function __initialize(address creator, IERC20 goods_, uint256 listPrice_) internal {
        owner = creator;
        goods = goods_;
        listPrice = listPrice_;
    }

    // ============ View Functions ============

    /**
     * @notice Native currency balance held by kiosk.
     */
    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Available inventory of goods.
     */
    function inventory() public view returns (uint256) {
        return goods.balanceOf(address(this));
    }

    /**
     * @notice Calculate goods purchasable for given native token amount.
     * @param v Native tokens to spend.
     * @return q Quantity of goods buyer receives.
     * @return soldOut True if inventory exhausted.
     */
    function quote(uint256 v) public view virtual returns (uint256 q, bool soldOut);

    // ============ External Functions ============

    /**
     * @notice Buy goods with native tokens (no refunds if depleted).
     * @return q Quantity of goods purchased.
     * @return soldOut True if inventory exhausted.
     */
    function buy() public payable nonReentrant returns (uint256 q, bool soldOut) {
        (q, soldOut) = quote(msg.value);
        if (soldOut) {
            emit KioskSoldOut(msg.sender, msg.value, q);
        }
        if (q == 0) {
            revert ZeroBought();
        }
        goods.safeTransfer(msg.sender, q);
        emit KioskBuy(msg.sender, msg.value, q);
    }

    /**
     * @notice Accept direct payments (calls buy).
     */
    receive() external payable {
        buy();
    }

    /**
     * @notice Reject unknown function calls.
     */
    fallback() external payable {
        revert UnknownFunctionCalledOrHexDataSent();
    }

    // ============ Owner Functions ============

    /**
     * @notice Reclaim unsold inventory.
     * @param quantity Amount of goods to reclaim.
     */
    function reclaim(uint256 quantity) external onlyOwner {
        goods.safeTransfer(msg.sender, quantity);
    }

    /**
     * @notice Collect sale proceeds.
     * @param value Amount of native tokens to collect.
     */
    function collect(uint256 value) external onlyOwner {
        (bool ok,) = address(msg.sender).call{value: value}("");
        if (!ok) {
            revert CollectFailed();
        }
    }

    // ============ Modifiers ============

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        if (msg.sender != owner) revert NotOwner();
    }
}
