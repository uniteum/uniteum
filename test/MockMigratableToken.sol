// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMigratable} from "../src/IMigratable.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title MockMigratableToken
 * @notice Mock token that implements IMigratable for testing.
 * @dev Accepts an upstream token and mints/burns this token on migration.
 */
contract MockMigratableToken is ERC20, IMigratable {
    using SafeERC20 for IERC20;

    IERC20 public immutable UPSTREAM_TOKEN;

    constructor(string memory name, IERC20 upstream) ERC20(name, name) {
        UPSTREAM_TOKEN = upstream;
        console.log("MockMigratableToken %s created at %s", name, address(this));
    }

    /// @inheritdoc IMigratable
    function migrate(uint256 amount) external {
        // Transfer upstream tokens from caller to this contract
        UPSTREAM_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        // Mint equivalent amount of this token to caller
        _mint(msg.sender, amount);

        emit Migrated(address(UPSTREAM_TOKEN), address(this), amount);
    }

    /// @inheritdoc IMigratable
    function unmigrate(uint256 amount) external {
        // Burn this token from caller
        _burn(msg.sender, amount);

        // Transfer equivalent upstream tokens back to caller
        UPSTREAM_TOKEN.safeTransfer(msg.sender, amount);

        emit Unmigrated(address(UPSTREAM_TOKEN), address(this), amount);
    }
}
