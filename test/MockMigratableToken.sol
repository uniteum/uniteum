// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IMigratable} from "../src/IMigratable.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title MockMigratableToken
 * @notice Mock token that implements IMigratable for testing.
 * @dev Accepts an upstream token and mints/burns this token on migration.
 */
contract MockMigratableToken is ERC20, IMigratable {
    IERC20 public immutable upstreamToken;

    constructor(string memory name, IERC20 upstream) ERC20(name, name) {
        upstreamToken = upstream;
        console.log("MockMigratableToken %s created at %s", name, address(this));
    }

    /// @inheritdoc IMigratable
    function migrate(uint256 amount) external {
        // Transfer upstream tokens from caller to this contract
        upstreamToken.transferFrom(msg.sender, address(this), amount);

        // Mint equivalent amount of this token to caller
        _mint(msg.sender, amount);

        emit Migrated(address(upstreamToken), address(this), amount);
    }

    /// @inheritdoc IMigratable
    function unmigrate(uint256 amount) external {
        // Burn this token from caller
        _burn(msg.sender, amount);

        // Transfer equivalent upstream tokens back to caller
        upstreamToken.transfer(msg.sender, amount);

        emit Unmigrated(address(upstreamToken), address(this), amount);
    }
}
