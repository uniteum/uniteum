// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IKiosk
 * @notice Interface for kiosks that sell ERC-20 tokens in return for native currency.
 */
interface IKiosk {
    /**
     * @notice The ERC-20 token sold by this kiosk.
     */
    function goods() external view returns (IERC20);

    /**
     * @notice Reference native-token price per unit of goods.
     */
    function listPrice() external view returns (uint256);

    /**
     * @notice The owner/creator of the Kiosk.
     */
    function owner() external view returns (address);

    /**
     * @notice Return the native currency held by the kiosk.
     */
    function balance() external view returns (uint256);

    /**
     * @notice Returns the current goods inventory held by the kiosk.
     */
    function inventory() external view returns (uint256);

    /**
     * @notice Return the quantity of goods that can be bought for the given value.
     * @param v The value of native tokens sent to buy goods.
     * @return q The quantity of goods that can be bought for the given value.
     * @return soldOut True if the kiosk has no remaining goods to sell.
     */
    function quote(uint256 v) external view returns (uint256 q, bool soldOut);

    /**
     * @notice Buy goods from the kiosk by sending native tokens.
     * @return q The quantity of goods bought.
     * @return soldOut True if the kiosk became depleted.
     */
    function buy() external payable returns (uint256 q, bool soldOut);

    /**
     * @notice Reclaim some inventory of goods currently held by the kiosk.
     * @param quantity of goods to reclaim.
     */
    function reclaim(uint256 quantity) external;

    /**
     * @notice Collect some native tokens currently held by the kiosk.
     * @param value of native tokens to collect.
     */
    function collect(uint256 value) external;

    /**
     * @notice Emit when a kiosk runs out of goods during a buy.
     * @param buyer The caller who bought the goods.
     * @param valueSent The amount of native tokens sent.
     * @param quantityBought The quantity of goods bought.
     */
    event KioskSoldOut(address buyer, uint256 valueSent, uint256 quantityBought);

    /**
     * @notice Emit when goods are bought from the kiosk.
     * @param buyer The caller who bought the goods.
     * @param valueSent The amount of native tokens sent.
     * @param quantityBought The quantity of goods bought.
     */
    event KioskBuy(address buyer, uint256 valueSent, uint256 quantityBought);

    /**
     * @notice Emitted when a kiosk is created.
     * @param creator Account that receives the initial kiosk shares.
     * @param goods ERC-20 token being sold by this kiosk.
     * @param listPrice Fixed price in native tokens per unit of goods.
     */
    event KioskCreated(address creator, IERC20 goods, uint256 listPrice);

    /**
     * @notice Revert when the quantity bought is zero.
     */
    error ZeroBought();

    /**
     * @notice Collecting native tokens in this Kiosk failed.
     */
    error CollectFailed();

    /**
     * @notice Revert when caller is not the owner.
     */
    error NotOwner();

    /**
     * @notice Reject unknown function calls or unexpected calldata.
     */
    error UnknownFunctionCalledOrHexDataSent();
}
