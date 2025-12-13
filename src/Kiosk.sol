// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IKiosk} from "./IKiosk.sol";
import {Prototype} from "./Prototype.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/**
 * @title Kiosk
 * @notice Base contract for selling ERC-20 tokens in return for native currency.
 * @dev The creator/owner can collect native tokens earned by the kiosk and reclaim inventory held by the kiosk.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
abstract contract Kiosk is IKiosk, Prototype, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    /**
     * @notice The ERC-20 token sold by this kiosk.
     */
    IERC20 public goods;

    /**
     * @notice Reference native-token price per unit of goods.
     */
    uint256 public listPrice;

    /**
     * @notice The owner/creator of the Kiosk.
     */
    address public owner;

    /**
     * @notice Return the native currency held by the kiosk.
     */
    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns the current goods inventory held by the kiosk.
     * @dev This is simply the kiosk’s balance of the goods token.
     */
    function inventory() public view returns (uint256) {
        return goods.balanceOf(address(this));
    }

    /**
     * @notice Return the quantity of goods that can be bought for the given value.
     * Note: the quantity of goods may vary if the quote does not happen within a transaction.
     * @param v The value of native tokens sent to buy goods.
     * @return q The quantity of goods that can be bought for the given value.
     * @return soldOut True if the kiosk has no remaining goods to sell.
     */
    function quote(uint256 v) public view virtual returns (uint256 q, bool soldOut);

    /**
     * @notice Reject unknown function calls or unexpected calldata.
     */
    fallback() external payable {
        revert UnknownFunctionCalledOrHexDataSent();
    }

    /**
     * @notice Buy goods from the kiosk by sending native tokens to the contract.
     * NOTE: there are no refunds if the kiosk becomes depleted!
     */
    receive() external payable {
        buy();
    }

    /**
     * @notice Buy goods from the kiosk by sending native tokens.
     * NOTE: there are no refunds if the kiosk becomes depleted!
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
     * @notice Reclaim some inventory of goods currently held by the kiosk.
     * @param quantity of goods to reclaim.
     */
    function reclaim(uint256 quantity) external onlyOwner {
        goods.safeTransfer(msg.sender, quantity);
    }

    /**
     * @notice Collect some native tokens currently held by the kiosk.
     * @param value of goods to reclaim.
     */
    function collect(uint256 value) external onlyOwner {
        (bool ok,) = address(msg.sender).call{value: value}("");
        if (!ok) {
            revert CollectFailed();
        }
    }

    function __initialize(address creator, IERC20 goods_, uint256 listPrice_) internal {
        owner = creator;
        goods = goods_;
        listPrice = listPrice_;
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        if (msg.sender != owner) revert NotOwner();
    }
}
