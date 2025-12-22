// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {BaseTest} from "./Base.t.sol";
import {MintletUser} from "./MintletUser.sol";
import {Mintlet} from "../src/Mintlet.sol";
import {Prototype} from "../src/Prototype.sol";

contract MintletTest is BaseTest {
    uint256 constant TOTAL_SUPPLY_1 = 1 ether;
    string constant TOKEN_NAME_1 = "First";
    string constant TOKEN_SYMBOL_1 = "FIRST";
    uint256 constant TOTAL_SUPPLY_2 = 2 ether;
    string constant TOKEN_NAME_2 = "Second";
    string constant TOKEN_SYMBOL_2 = "SECOND";
    string constant USER_NAME = "MintletUser";
    Mintlet public mintletPrototype;
    MintletUser public mintletUser;

    function setUp() public virtual override {
        mintletPrototype = new Mintlet{salt: 0x0}();
        mintletUser = newMintletUser();
    }

    function newMintletUser() public returns (MintletUser user) {
        user = new MintletUser(USER_NAME, mintletPrototype);
    }

    function test_NewMintlet() public returns (Mintlet mintlet1) {
        mintlet1 = mintletUser.newMintlet(TOKEN_NAME_1, TOKEN_SYMBOL_1, TOTAL_SUPPLY_1);
        assertEq(mintlet1.name(), TOKEN_NAME_1);
        assertEq(mintlet1.symbol(), TOKEN_SYMBOL_1);
        assertEq(mintlet1.totalSupply(), TOTAL_SUPPLY_1, "total supply");
        assertEq(mintlet1.balanceOf(address(mintletUser)), TOTAL_SUPPLY_1, "balance of creator");
    }

    function test_CloneCanCreate() public returns (Mintlet mintlet1, Mintlet mintlet2) {
        mintlet1 = mintletUser.newMintlet(TOKEN_NAME_1, TOKEN_SYMBOL_1, TOTAL_SUPPLY_1);
        mintlet2 = mintletUser.newMintlet(mintlet1, TOKEN_NAME_2, TOKEN_SYMBOL_2, TOTAL_SUPPLY_2);
        assertEq(mintlet2.name(), TOKEN_NAME_2);
        assertEq(mintlet2.symbol(), TOKEN_SYMBOL_2);
        assertEq(mintlet2.totalSupply(), TOTAL_SUPPLY_2, "total supply");
        assertEq(mintlet2.balanceOf(address(mintletUser)), TOTAL_SUPPLY_2, "balance 2 of creator");
    }

    function test_CreateIdempotent() public returns (Mintlet mintlet1, Mintlet mintlet2) {
        mintlet1 = mintletUser.newMintlet(TOKEN_NAME_1, TOKEN_SYMBOL_1, TOTAL_SUPPLY_1);
        mintlet2 = mintletUser.newMintlet(TOKEN_NAME_1, TOKEN_SYMBOL_1, TOTAL_SUPPLY_1);
        assertEq(address(mintlet1), address(mintlet2), "mintlet create not idempotent");
        assertEq(mintlet1.balanceOf(address(mintletUser)), TOTAL_SUPPLY_1, "balance of creator");
    }

    function test_SelfCreateIdempotent() public returns (Mintlet mintlet1, Mintlet mintlet2) {
        mintlet1 = mintletUser.newMintlet(TOKEN_NAME_1, TOKEN_SYMBOL_1, TOTAL_SUPPLY_1);
        mintlet2 = mintletUser.newMintlet(mintlet1, TOKEN_NAME_1, TOKEN_SYMBOL_1, TOTAL_SUPPLY_1);
        assertEq(address(mintlet1), address(mintlet2), "mintlet create not idempotent");
    }

    function test_OutsideInitializeReverts() public returns (Mintlet mintlet1) {
        mintlet1 = mintletUser.newMintlet(TOKEN_NAME_1, TOKEN_SYMBOL_1, TOTAL_SUPPLY_1);
        bytes memory initData = abi.encode(TOKEN_NAME_2, TOKEN_SYMBOL_2, TOTAL_SUPPLY_2);
        vm.expectRevert(Prototype.Unauthorized.selector);
        mintlet1.__initialize(initData);
    }
}
