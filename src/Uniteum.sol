// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Uniteum
 * @notice Primordial Uniteum token - the foundational "1" unit.
 *
 * @dev Simple ERC20 implementation that mints a fixed supply of 1 billion "1" tokens
 * to bootstrap the Uniteum algebraic liquidity protocol. This primordial version
 * establishes the identity unit before migrating to the full Unit.sol implementation
 * with forge operations and reciprocal relationships.
 *
 * For more information: https://uniteum.one
 * ENS namespace: uniteum.eth
 *
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
contract Uniteum is ERC20 {
    string constant NAME = "Uniteum 0.0 1";

    string constant SYMBOL = "1";

    /**
     * @notice Total minted supply: 1 billion tokens with 18 decimals.
     */
    uint256 constant MAX_SUPPLY = 1e9 ether;

    /**
     * @notice Total minted supply: 1 billion tokens with 18 decimals.
     */
    address constant ISSUER = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    /**
     * @notice Deploys primordial "1" and mints MAX_SUPPLY to ISSUER.
     * @dev No further minting possible.
     */
    constructor() ERC20(NAME, SYMBOL) {
        _mint(ISSUER, MAX_SUPPLY);
    }
}
