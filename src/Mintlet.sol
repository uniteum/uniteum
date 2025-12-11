// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {CloneERC20, Prototype} from "./CloneERC20.sol";

/**
 * @title Mintlet
 * @notice Minimalist fixed-supply ERC-20 creator. A single call to {create}
 *         deploys a new ERC-20 clone and mints the entire supply to the caller.
 * @dev Simple, UI-free token creation suitable for direct use from Etherscan.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
contract Mintlet is CloneERC20 {
    /**
     * @notice Sets the name and symbol of the Mintlet implementation contract.
     * @dev Clones will override these with their own values during initialization.
     */
    constructor() CloneERC20("Mintlet - a minimalist token creator", "Mintlet") {}

    /**
     * @notice Create a new Mintlet token and mint the full supply to the caller.
     * @param name_ The ERC-20 token name.
     * @param symbol_ The ERC-20 token symbol.
     * @param supply The fixed total supply (minted entirely to the caller).
     * @return token The newly created Mintlet ERC-20 clone.
     */
    function create(string memory name_, string memory symbol_, uint256 supply) external returns (Mintlet token) {
        // forge-lint: disable-next-line(asm-keccak256)
        bytes memory initData = abi.encode(msg.sender, name_, symbol_, supply);
        (address tokenAddress,) = __clone(initData);
        token = Mintlet(tokenAddress);
    }

    /**
     * @inheritdoc Prototype
     * @dev Decodes initialization calldata for a new clone and mints its supply.
     */
    function __initialize(bytes memory initData) public virtual override onlyPrototype {
        (address creator, string memory name_, string memory symbol_, uint256 supply) =
            abi.decode(initData, (address, string, string, uint256));

        _name = name_;
        _symbol = symbol_;
        _mint(creator, supply);

        emit MintletCreated(msg.sender, this, name_, symbol_, supply);
    }

    /**
     * @notice Emitted when a new Mintlet ERC-20 token is created.
     * @param creator Address receiving the full minted supply.
     * @param mintlet The deployed Mintlet clone.
     * @param name The token name used by the clone.
     * @param symbol The token symbol used by the clone.
     * @param supply The fixed total supply minted to the creator.
     */
    event MintletCreated(
        address indexed creator, Mintlet indexed mintlet, string name, string indexed symbol, uint256 supply
    );
}
