// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMigratable} from "./IMigratable.sol";

/**
 * @title IUnit — A universal liquidity system based on symbolic units.
 * @notice A Unit (U) is an ERC-20 token with built-in liquidity via reciprocal minting/burning.
 * The identity unit {one()} aka {1} is the universal liquidity token around which a unit and its reciprocal pivot.
 * Units support a {forge} operation that mints/burns combinations of 1, U, and 1/U to maintain a constant product invariant.
 * If a unit goes up in price, its reciprocal goes down, and vice versa.
 * Some units are anchored to external ERC-20 tokens, to integrate the system with the broader ERC-20 ecosystem.
 *
 * A Unit symbolically represents a unit of measure, such as a a physical dimension, abstract quantity, linked ERC-20 token, or compound units.
 * It supports rational powers of base units and algebraic composition such as product and reciprocal.
 * A base unit has two varieties: anchored or unanchored.
 *
 * An anchored unit is a 1:1 custodial owner of an external ERC-20 token
 *   Its symbol is the Ethereum address of the external token prefixed with '$'.
 *   Examples: $0xdAC17F958D2ee523a2206206994597C13D831ec7 (USDT), $0x1f9840a85d5af5bf1d1762f925bdaddc4201f984 (UNI)
 *
 * An unanchored base unit has no associated external token.
 *   Its symbol is an unbroken sequence of the following characters: 'a'-'z', 'A'-'Z', '0'-'9', '_', '-', '.'
 *   Symbols are case sensitive and are limited to 30 characters.
 *   Examples: kg, KG, kG, Kg, m, s, MSFT, USD, _, -, ., example.com, QmFzZTY0IGVuY29kZWQgdW5pdA
 *   Note: unanchored base units have no inherent connection to real world entities.
 *         MSFT IS NOT inherently connected to Microsoft stock.
 *         kg IS NOT inherently connected to the concept of a kilogram.
 *
 * A pure power unit, aka term, is a base unit raised to a power using a combination of '^' and '1/' notation
 *   Division in exponents uses the '\' character instead of the '/ to simplify parsing
 *   Powers can be rational fractions represented using '\' for division in the exponent
 *     Examples: kg^2, 1/s, 1/m^2, 1/T^1\4, 1/$0xdAC17F958D2ee523a2206206994597C13D831ec7^3\7
 *   Operations within terms:
 *     ^ power
 *     \ divide
 * Compound units are products of pure power units separated by '*' or '/'
 *   Examples: kg*m/s^2, MSFT/USD, 1/foo^2\5/bar^7\9
 *   Operations combining terms:
 *     * multiply
 *     / divide
 *
 * @dev Version scope (v1)
 * - Value constraints exist between a Unit and its reciprocal, and between an anchored token and its anchor.
 * - Powers/exponentials (e.g., constraining value across A and A^k like power perpetuals) are
 *   not enforced; this may be future work.
 *
 * @dev Non-promissory hypotheses (for readers' intuition; not guarantees)
 * - As anchored collateral and unanchored participation grow, the value of "1" may tend to reflect
 *   aggregate system value (anchored + unanchored).
 * - With many diverse Units, "1" may exhibit reduced volatility via diversification effects.
 *
 * @dev Safety
 * - Anchored units are custodial: underlying tokens are held by this contract.
 * - This system uses no price oracles or off-chain dependencies.
 *
 * @dev Reentrancy Protection
 * All state-changing functions use a transient reentrancy guard stored on the "1" unit
 * per EIP-1153. This protects against malicious anchor token callbacks.
 * @custom:security Uses transient storage; requires EVM version Cancun or later
 *
 * @dev Internal Function Naming Convention
 * Functions prefixed with __ are restricted to calls from other Units in the same system (same ONE).
 * These are used for cross-unit operations during forge.
 */
interface IUnit is IERC20Metadata, IMigratable {
    /**
     * @notice Compute the constant product invariant for a reciprocal pair.
     * The implied price for the unit is w/u, and w/v for its reciprocal.
     * @param u Total supply of a unit.
     * @param v Total supply of its reciprocal.
     * @return w sqrt(u * v).
     */
    function invariant(uint256 u, uint256 v) external view returns (uint256 w);

    /**
     * @notice Return the constant product invariant for a reciprocal pair.
     * @return u Total supply of the unit.
     * @return v Total supply of its reciprocal.
     * @return w sqrt(u * v).
     */
    function invariant() external view returns (uint256 u, uint256 v, uint256 w);

    /**
     * @notice Return the constant product invariant for a pair.
     * @param V The invariant pair for this unit.
     * @return W Product of this unit and V.
     * @return u Total supply of the unit.
     * @return v Total supply of its reciprocal.
     * @return w sqrt(u * v).
     */
    function invariant(IUnit V) external view returns (IUnit W, uint256 u, uint256 v, uint256 w);

    /**
     * @notice Compute the change of the caller's 1 balance that would result from forging this unit.
     *
     * @dev Invariant solver for the forge operation.
     * Given signed changes to the caller's balances of the unit `du` and its reciprocal `dv`,
     * this function computes the signed change to 1 `dw` required to preserve the
     * constant-product relationship across the triad (U, 1/U, 1).
     *
     * Sign convention:
     *  - Positive values mint units to the caller.
     *  - Negative values burn units from the caller.
     *
     * @param V Other unit.
     * @param du Signed change of the caller's unit balance.
     * @param dv Signed change of the caller's reciprocal balance.
     * @return W Product of this unit and V.
     * @return dw Signed change of caller's 1 balance.
     */
    function forgeQuote(IUnit V, int256 du, int256 dv) external view returns (IUnit W, int256 dw);

    /**
     * @notice Compute the change of the caller's 1 balance that would result from forging this unit.
     *
     * @dev Invariant solver for the forge operation.
     * Given signed changes to the caller's balances of the unit `du` and its reciprocal `dv`,
     * this function computes the signed change to 1 `dw` required to preserve the
     * constant-product relationship across the triad (U, 1/U, 1).
     *
     * Sign convention:
     *  - Positive values mint units to the caller.
     *  - Negative values burn units from the caller.
     *
     * @param du Signed change of the caller's unit balance.
     * @param dv Signed change of the caller's reciprocal balance.
     * @return dw Signed change of caller's 1 balance.
     */
    function forgeQuote(int256 du, int256 dv) external view returns (int256 dw);

    /**
     * @notice Mint/burn combinations of this unit, its reciprocal and 1.
     * @dev
     * Uses {forgeQuote} to compute the necessary deltas to maintain the invariant,
     * then mints/burns the corresponding amounts of du, dv, and dw for the caller.
     * To mint an anchored unit, even if it participates as the reciprocal,
     * the caller must approve transferring the anchor token to the unit:
     *     u.anchor().approve(address(u)), uint256(du));
     *
     * @param V Other unit.
     * @param du Signed delta of the unit U.
     * @param dv Signed delta of the unit 1/U.
     * @return W Product of this unit and V.
     * @return dw Signed delta of 1 minted/burned for the caller.
     */
    function forge(IUnit V, int256 du, int256 dv) external returns (IUnit W, int256 dw);

    /**
     * @notice Mint/burn combinations of this unit, its reciprocal and 1.
     * @dev
     * Uses {forgeQuote} to compute the necessary deltas to maintain the invariant,
     * then mints/burns the corresponding amounts of du, dv, and dw for the caller.
     * To mint an anchored unit, even if it participates as the reciprocal,
     * the caller must approve transferring the anchor token to the unit:
     *     u.anchor().approve(address(u)), uint256(du));
     *
     * @param du Signed delta of the unit U.
     * @param dv Signed delta of the unit 1/U.
     * @return dw Signed delta of 1 minted/burned for the caller.
     */
    function forge(int256 du, int256 dv) external returns (int256 dw);

    /**
     * @notice Predict the address of the IUnit resulting from multiplying by a symbolic expression.
     * @dev View-only; does not create the unit. Use {multiply} to create if needed.
     * @param expression a string representation of the unit.
     * @return unit the IUnit for the given expression.
     * @return symbol the canonical form of the string representation of the unit.
     */
    function product(string memory expression) external view returns (IUnit unit, string memory symbol);

    /**
     * @notice Create a new unit if it does not exist, or return existing unit.
     * @dev Creates the unit by multiplying this unit with the expression.
     * @param expression a string representation of the unit to multiply by.
     * @return unit the IUnit with the resulting symbol.
     */
    function multiply(string memory expression) external returns (IUnit unit);

    /**
     * @notice Predict the unit resulting from multiplying this unit by another unit.
     * @dev View-only; uses cached product mapping when available, otherwise computes from symbols.
     * Does not create the unit. Use {multiply} to create if needed.
     * @param multiplier The right-hand unit operand.
     * @return unit The IUnit representing the product.
     * @return symbol the canonical form of the string representation of the unit.
     */
    function product(IUnit multiplier) external view returns (IUnit unit, string memory symbol);

    /**
     * @notice Create or return the product of this unit with another unit.
     * @dev Creates the product unit if it doesn't exist, caches the mapping for future calls.
     * @param multiplier The right-hand unit operand.
     * @return product The new or existing IUnit representing the product.
     */
    function multiply(IUnit multiplier) external returns (IUnit product);

    /**
     * @notice Predict the address of an anchored unit.
     * @param token to be anchored to.
     * @return unit the IUnit anchored to the given token.
     * @return symbol the canonical form of the string representation of the unit.
     */
    function anchoredPredict(IERC20 token) external view returns (IUnit unit, string memory symbol);

    /**
     * @notice Create an anchored unit if it does not exist.
     * @param token to be anchored to.
     * @return unit the IUnit anchored to the given token.
     */
    function anchored(IERC20 token) external returns (IUnit unit);

    /**
     * @notice Return the symbol for an anchored token.
     *   Example: $0xdAC17F958D2ee523a2206206994597C13D831ec7 (USDT)
     * @param token to be anchored to.
     * @return symbol the canonical form of the string representation of the unit.
     */
    function anchoredSymbol(IERC20 token) external pure returns (string memory symbol);

    /**
     * @notice The identity unit "1".
     * @dev Also the implementation and deployer for all other units, which are clones.
     */
    function one() external view returns (IUnit);

    /**
     * @return The IUnit representing the reciprocal of this unit.
     */
    function reciprocal() external view returns (IUnit);

    /**
     * @return root The IUnit representing the sqrt of this unit.
     * @return symbol the canonical form of the string representation of the unit.
     * Symbol is only returned if the root is not known to be deployed.
     */
    function sqrt() external view returns (IUnit root, string memory symbol);

    /**
     * @return The external token, if any, anchored to this unit.
     */
    function anchor() external view returns (IERC20);

    /**
     * @dev Revert when called with duplicate units.
     */
    error DuplicateUnits();

    /**
     * @dev Revert when called on 1.
     */
    error FunctionCalledOnOne();

    /**
     * @dev Revert when called on anything but 1.
     */
    error FunctionNotCalledOnOne();

    /**
     * @dev Revert when a negative supply would result from an operation.
     * @param unit The unit that would have negative supply.
     * @param supply The calculated negative supply value.
     */
    error NegativeSupply(IUnit unit, int256 supply);

    /**
     * @dev Reentrant calls are forbidden.
     */
    error ReentryForbidden();

    /**
     * @notice Emit on unit creation.
     * @param unit The created unit.
     * @param hash used to compute the address of the unit.
     * @param symbol The symbol of the the unit.
     */
    event UnitCreate(IUnit indexed unit, IERC20 indexed anchor, bytes32 indexed hash, string symbol);

    /**
     * @notice Emit when a holder calls forge.
     * @param holder The address whose balances were updated.
     * @param unit   The unit doing the forge.
     * @param du     signed change to the holder's balance of the unit.
     * @param dv     signed change to the holder's balance of the reciprocal unit.
     * @param dw     signed change to the holder's balance of 1.
     */
    event Forge(address indexed holder, IUnit indexed unit, int256 du, int256 dv, int256 dw);

    /**
     * @notice Emitted when tokens are migrated into the system.
     * @param user The address migrating tokens.
     * @param amount Amount of tokens migrated.
     */
    event Migrate(address indexed user, uint256 amount);

    /**
     * @notice Emitted when tokens are unmigrated from the system.
     * @param user The address unmigrating tokens.
     * @param amount Amount of tokens unmigrated.
     */
    event Unmigrate(address indexed user, uint256 amount);
}
