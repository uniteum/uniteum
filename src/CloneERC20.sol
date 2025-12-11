// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Prototype} from "./Prototype.sol";
import {ERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CloneERC20
 * @notice ERC-20 base contract that supports cloning by allowing name and symbol
 *         to be assigned during clone initialization rather than at construction.
 * @dev Used as the base class for cloneable token factories.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
abstract contract CloneERC20 is ERC20, Prototype {
    /**
     * @dev Storage for ERC-20 metadata, settable during clone initialization.
     */
    string internal _name;
    string internal _symbol;

    /**
     * @notice Sets the implementation-level name and symbol.
     * @dev Clones will override these values in their own initialization step.
     *      The ERC20 base constructor is given empty strings because metadata
     *      is resolved through overridden accessors.
     * @param name_ Implementation name.
     * @param symbol_ Implementation symbol.
     */
    constructor(string memory name_, string memory symbol_) ERC20("", "") {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @inheritdoc IERC20Metadata
     */
    function name() public view virtual override(ERC20) returns (string memory) {
        return _name;
    }

    /**
     * @inheritdoc IERC20Metadata
     */
    function symbol() public view virtual override(ERC20) returns (string memory) {
        return _symbol;
    }
}
