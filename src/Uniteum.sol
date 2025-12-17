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
    /// @notice Total fixed supply: 1 billion tokens with 18 decimals.
    uint256 constant ONE_MINTED = 1e9 ether;

    /**
     * @notice Deploys primordial "1" and mints initial supply to deployer.
     * @dev Mints ONE_MINTED tokens to msg.sender. No further minting possible.
     */
    constructor() ERC20("Uniteum 0.0 1", "1") {
        _mint(msg.sender, ONE_MINTED);
    }
}
