// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Prototype} from "./Prototype.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CloneERC20
 * @notice ERC-20 base contract with support for minimal proxy cloning (EIP-1167).
 * @dev
 * Combines OpenZeppelin's ERC20 standard implementation with the Prototype
 * cloning pattern, enabling gas-efficient deployment of multiple ERC-20 tokens
 * that share the same implementation logic but maintain isolated storage.
 *
 * **Key Design Pattern:**
 * Standard ERC-20 implementations store name and symbol as immutables set during
 * construction. This prevents cloning because minimal proxies (EIP-1167) delegate
 * all logic via DELEGATECALL and cannot have their own constructor parameters.
 *
 * CloneERC20 solves this by:
 * 1. Storing name and symbol in regular storage variables (_name, _symbol)
 * 2. Overriding name() and symbol() accessors to read from storage
 * 3. Allowing these values to be set during __initialize() on each clone
 *
 * **Usage Pattern:**
 * ```solidity
 * // 1. Deploy prototype
 * MyToken prototype = new MyToken("PROTO", "PROTO");
 *
 * // 2. Create clones with custom metadata
 * bytes memory initData = abi.encode(creator, "Token A", "TKA");
 * (address tokenA, ) = prototype.__clone(initData);
 *
 * initData = abi.encode(creator, "Token B", "TKB");
 * (address tokenB, ) = prototype.__clone(initData);
 *
 * // 3. Each clone has its own name/symbol but shares logic
 * assert(MyToken(tokenA).name() == "Token A");
 * assert(MyToken(tokenB).name() == "Token B");
 * ```
 *
 * **Storage Layout:**
 * Each clone maintains its own:
 * - _name: Token name (settable during initialization)
 * - _symbol: Token symbol (settable during initialization)
 * - _balances: Mapping of account balances (ERC20 inherited)
 * - _allowances: Mapping of allowances (ERC20 inherited)
 * - _totalSupply: Total token supply (ERC20 inherited)
 *
 * **Why Empty String Constructor:**
 * The ERC20 base constructor is passed empty strings because:
 * - Those values would only affect the prototype contract itself
 * - Clones override name() and symbol() to read from their own storage
 * - This prevents confusion between prototype metadata and clone metadata
 *
 * **Inheritance Chain:**
 * CloneERC20 → ERC20 (OpenZeppelin) + Prototype (factory pattern)
 *
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
abstract contract CloneERC20 is ERC20, Prototype {
    // ============ State Variables ============

    /**
     * @dev Token name, settable during clone initialization.
     *
     *      Unlike standard ERC-20 implementations where name is immutable,
     *      this is stored in a regular storage slot to allow each clone to
     *      have its own name without requiring constructor parameters.
     *
     *      Set during __initialize() on each clone.
     */
    string internal _name;

    /**
     * @dev Token symbol, settable during clone initialization.
     *
     *      Unlike standard ERC-20 implementations where symbol is immutable,
     *      this is stored in a regular storage slot to allow each clone to
     *      have its own symbol without requiring constructor parameters.
     *
     *      Set during __initialize() on each clone.
     */
    string internal _symbol;

    // ============ Constructor ============

    /**
     * @notice Initializes the prototype implementation with name and symbol.
     * @dev
     * **Important:** These parameters only affect the prototype contract itself,
     * NOT the clones. Each clone sets its own _name and _symbol during __initialize().
     *
     * The ERC20 base constructor receives empty strings ("", "") because:
     * 1. We override name() and symbol() to read from storage instead
     * 2. The prototype's metadata is rarely used (clones are what matter)
     * 3. This keeps the pattern consistent across prototype and clones
     *
     * **For derived contracts:**
     * Pass descriptive metadata for the prototype (often "PROTO" or similar)
     * to distinguish it from actual clone instances.
     *
     * @param name_ Name for the prototype implementation.
     * @param symbol_ Symbol for the prototype implementation.
     */
    constructor(string memory name_, string memory symbol_) ERC20("", "") {
        _name = name_;
        _symbol = symbol_;
    }

    // ============ ERC-20 Metadata Overrides ============

    /**
     * @notice Returns the name of the token.
     * @dev Overrides ERC20.name() to read from storage instead of immutables.
     *
     *      **On the prototype:** Returns the name set in constructor.
     *      **On clones:** Returns the name set during __initialize().
     *
     *      This allows each clone to have distinct metadata while sharing
     *      the same implementation logic.
     *
     * @return The token name.
     */
    function name() public view virtual override(ERC20) returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token.
     * @dev Overrides ERC20.symbol() to read from storage instead of immutables.
     *
     *      **On the prototype:** Returns the symbol set in constructor.
     *      **On clones:** Returns the symbol set during __initialize().
     *
     *      This allows each clone to have distinct metadata while sharing
     *      the same implementation logic.
     *
     * @return The token symbol.
     */
    function symbol() public view virtual override(ERC20) returns (string memory) {
        return _symbol;
    }
}
