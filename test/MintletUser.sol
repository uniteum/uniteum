// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {User, TestToken} from "./User.sol";
import {Mintlet} from "../src/Mintlet.sol";

contract MintletUser is User {
    Mintlet public immutable MINTLET_PROTOTYPE;
    TestToken ignore;

    constructor(string memory name_, Mintlet mintletProtype) User(name_) {
        MINTLET_PROTOTYPE = mintletProtype;
    }

    function newMintlet(Mintlet mintlet, string memory name_, string memory symbol_, uint256 supply)
        public
        returns (Mintlet token)
    {
        token = mintlet.create(name_, symbol_, supply);
        addToken(token);
    }

    function newMintlet(string memory name_, string memory symbol_, uint256 supply) public returns (Mintlet token) {
        token = newMintlet(MINTLET_PROTOTYPE, name_, symbol_, supply);
    }
}
