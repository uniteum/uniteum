// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

/**
 * @title IMigratable
 * @notice Interface for tokens that support migration from an upstream version.
 * @dev Tokens implementing this interface can accept upstream tokens and issue
 *      an equivalent amount of this token in exchange.
 */
interface IMigratable {
    /**
     * @notice Migrate upstream tokens to this token.
     * @dev The caller must approve this contract to transfer the upstream tokens.
     *      The upstream tokens are transferred from the caller to this contract,
     *      and an equivalent amount of this token is minted/transferred to the caller.
     * @param amount The number of tokens to migrate.
     */
    function migrate(uint256 amount) external;

    /**
     * @notice Reverse migrate this token to its upstream token.
     * @dev The caller's tokens are burned/transferred to this contract,
     *      and an equivalent amount of upstream tokens is transferred to the caller.
     * @param amount The number of tokens to reverse migrate.
     */
    function unmigrate(uint256 amount) external;

    /**
     * @notice Emitted when tokens are migrated from upstream to downstream.
     * @param upstream The upstream token address (source).
     * @param downstream The downstream token address (destination).
     * @param amount The number of tokens migrated.
     */
    event Migrated(
        address indexed upstream,
        address indexed downstream,
        uint256 amount
    );

    /**
     * @notice Emitted when tokens are reverse migrated from downstream to upstream.
     * @param upstream The upstream token address (destination).
     * @param downstream The downstream token address (source).
     * @param amount The number of tokens reverse migrated.
     */
    event Unmigrated(
        address indexed upstream,
        address indexed downstream,
        uint256 amount
    );
}
