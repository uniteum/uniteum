// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IKiosk} from "./IKiosk.sol";
import {IMigratable} from "./IMigratable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {Prototype} from "./Prototype.sol";

/**
 * @title MigratingKiosk
 * @notice A kiosk that wraps another kiosk and automatically migrates purchased tokens.
 * @dev Implements IKiosk interface as a passthrough wrapper around a source kiosk.
 *      Buys tokens from the source kiosk and migrates them to a destination token.
 *
 *      Example use case: Buy Uniteum 0.0 1 and migrate it to Uniteum 0.1 1 in one transaction.
 *
 *      The contract:
 *      1. Receives native currency from the caller via buy()
 *      2. Buys source tokens from the wrapped source kiosk
 *      3. Migrates source tokens to destination tokens
 *      4. Sends destination tokens to the caller
 *
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
contract MigratingKiosk is IKiosk, Prototype, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    /**
     * @notice The wrapped source kiosk from which we buy tokens.
     */
    IKiosk public sourceKiosk;

    /**
     * @notice The destination token that accepts migration from the source token.
     * @dev Must implement IMigratable interface with migrate(uint256) function.
     */
    IMigratable public destinationToken;

    /**
     * @notice The owner/creator of this MigratingKiosk.
     */
    address public owner;

    /**
     * @inheritdoc IKiosk
     * @dev Returns the destination token (what buyers receive after migration).
     */
    function goods() external view returns (IERC20) {
        return IERC20(address(destinationToken));
    }

    /**
     * @inheritdoc IKiosk
     * @dev Delegates to the source kiosk's list price.
     */
    function listPrice() external view returns (uint256) {
        return sourceKiosk.listPrice();
    }

    /**
     * @inheritdoc IKiosk
     * @dev Delegates to the source kiosk's balance.
     */
    function balance() public view returns (uint256) {
        return sourceKiosk.balance();
    }

    /**
     * @inheritdoc IKiosk
     * @dev Delegates to the source kiosk's inventory.
     */
    function inventory() public view returns (uint256) {
        return sourceKiosk.inventory();
    }

    /**
     * @inheritdoc IKiosk
     * @dev Delegates to the source kiosk's quote function.
     */
    function quote(uint256 v) public view returns (uint256 q, bool soldOut) {
        return sourceKiosk.quote(v);
    }

    /**
     * @notice Reject unknown function calls or unexpected calldata.
     */
    fallback() external payable {
        revert UnknownFunctionCalledOrHexDataSent();
    }

    /**
     * @notice Buy goods from the kiosk by sending native tokens to the contract.
     */
    receive() external payable {
        buy();
    }

    /**
     * @inheritdoc IKiosk
     * @dev Buys from source kiosk, migrates to destination, and sends to caller.
     */
    function buy()
        public
        payable
        nonReentrant
        returns (uint256 q, bool soldOut)
    {
        // Buy source tokens from the source kiosk
        (q, soldOut) = sourceKiosk.buy{value: msg.value}();

        if (soldOut) {
            emit KioskSoldOut(msg.sender, msg.value, q);
        }
        if (q == 0) {
            revert ZeroBought();
        }

        // Approve destination token to transfer source tokens for migration
        IERC20 sourceToken = sourceKiosk.goods();
        sourceToken.approve(address(destinationToken), q);

        // Migrate source tokens to destination tokens
        destinationToken.migrate(q);

        // Transfer migrated destination tokens to caller
        IERC20(address(destinationToken)).safeTransfer(msg.sender, q);

        emit KioskBuy(msg.sender, msg.value, q);
    }

    /**
     * @inheritdoc IKiosk
     * @dev Not applicable for MigratingKiosk as it doesn't hold inventory.
     */
    function reclaim(uint256) external pure {
        revert NotSupported();
    }

    /**
     * @inheritdoc IKiosk
     * @dev Not applicable for MigratingKiosk as it doesn't hold native currency.
     */
    function collect(uint256) external pure {
        revert NotSupported();
    }

    /**
     * @notice Create a new MigratingKiosk clone.
     * @param sourceKiosk_ The kiosk from which to buy source tokens.
     * @param destinationToken_ The migratable token to receive after migration.
     * @return kiosk The newly created MigratingKiosk instance.
     */
    function create(
        IKiosk sourceKiosk_,
        IMigratable destinationToken_
    ) external returns (MigratingKiosk kiosk) {
        bytes memory initData = abi.encode(
            msg.sender,
            sourceKiosk_,
            destinationToken_
        );
        (address kioskAddress, ) = __clone(initData);
        kiosk = MigratingKiosk(payable(kioskAddress));
    }

    /// @inheritdoc Prototype
    function __initialize(bytes memory initData) public override onlyPrototype {
        (
            address creator,
            IKiosk sourceKiosk_,
            IMigratable destinationToken_
        ) = abi.decode(initData, (address, IKiosk, IMigratable));

        owner = creator;
        sourceKiosk = sourceKiosk_;
        destinationToken = destinationToken_;

        emit KioskCreated(
            creator,
            IERC20(address(destinationToken_)),
            sourceKiosk_.listPrice()
        );
    }

    /**
     * @notice Revert when an unsupported operation is called.
     */
    error NotSupported();
}
