// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {UnitBaseTest, Units, IUnit, console} from "./UnitBase.t.sol";
import {TestToken} from "./TestToken.sol";

/**
 * @title ForgeAnchoredCompoundTest
 * @notice This test exposes the problem with forging anchored units into compound units.
 *
 * The issue: When creating a compound unit from two anchored units (e.g., $WBTC * $WETH),
 * the underlying anchor tokens (WBTC and WETH) are transferred to the compound unit contract.
 * However, when unwinding the compound back to its constituents, the system attempts to
 * transfer the anchor tokens FROM the base unit contracts (which no longer have them),
 * causing the transaction to revert.
 */
contract ForgeAnchoredCompoundTest is UnitBaseTest {
    using Units for *;

    uint256 initialOne = 1e6;

    TestToken public wbtc;
    TestToken public weth;
    IUnit public awbtc;
    IUnit public aweth;
    IUnit public compound;

    function setUp() public virtual override {
        super.setUp();
        owen.migrate(proto1.balanceOf(address(owen)));

        // Create mock WBTC and WETH tokens
        wbtc = alex.newToken("WBTC", 1e6);
        weth = alex.newToken("WETH", 1e6);

        // Create anchored units
        awbtc = l.anchored(wbtc);
        aweth = l.anchored(weth);

        // Add tokens to alex's tracking
        alex.addToken(awbtc);
        alex.addToken(awbtc.reciprocal());
        alex.addToken(aweth);
        alex.addToken(aweth.reciprocal());

        console.log("awbtc:", address(awbtc));
        console.log("aweth:", address(aweth));
        console.log("WBTC backing token:", address(awbtc.anchor()));
        console.log("WETH backing token:", address(aweth.anchor()));
    }

    /**
     * @notice Test creating a compound from two anchored units, then unwinding it.
     * @dev This test SHOULD fail during the unwinding step because the anchor tokens
     * are in the compound contract but the system tries to transfer them from the
     * base unit contracts.
     */
    function test_ForgeAnchoredCompoundAndUnwind() public {
        // Give alex some "1" tokens
        owen.give(address(alex), initialOne, l);

        console.log("\n=== Step 1: Approve anchor tokens ===");
        alex.approve(address(awbtc), 10, wbtc);
        alex.approve(address(aweth), 20, weth);

        console.log("\n=== Step 2: Create anchored units (wrapping) ===");
        console.log("Alex WBTC balance before:", wbtc.balanceOf(address(alex)));
        console.log("Alex WETH balance before:", weth.balanceOf(address(alex)));

        // Mint some $WBTC and $WETH by depositing real tokens
        // For now, we'll forge with "1" since pure wrapping has its own issues
        alex.forge(awbtc, 10, 10); // Creates $WBTC + 1/$WBTC pair
        alex.forge(aweth, 20, 20); // Creates $WETH + 1/$WETH pair

        console.log("Alex $WBTC balance:", awbtc.balanceOf(address(alex)));
        console.log("Alex $WETH balance:", aweth.balanceOf(address(alex)));
        console.log("$WBTC contract WBTC balance:", wbtc.balanceOf(address(awbtc)));
        console.log("$WETH contract WETH balance:", weth.balanceOf(address(aweth)));

        console.log("\n=== Step 3: Create compound unit ($WBTC * $WETH) ===");

        // First, create the compound unit contract
        compound = awbtc.multiply(aweth);
        alex.addToken(compound);
        alex.addToken(compound.reciprocal());

        console.log("Compound unit address:", address(compound));
        console.log("Compound unit symbol:", compound.symbol());

        // Approve compound contract to transfer the unit tokens
        //alex.approve(address(compound), 100, awbtc);
        //alex.approve(address(compound), 100, aweth);

        // CRITICAL: The anchor unit contracts also need approval to transfer the real tokens!
        // This is because __transfer will try to move the real WBTC/WETH
        //alex.approve(address(awbtc), 100, wbtc);
        //alex.approve(address(aweth), 100, weth);

        // Forge compound: deposit 5 $WBTC and 10 $WETH to get compound
        alex.forge(awbtc, aweth, -5, -10);

        console.log("Compound unit created:", address(compound));
        console.log("Alex compound balance:", compound.balanceOf(address(alex)));
        console.log("Alex $WBTC balance after compound:", awbtc.balanceOf(address(alex)));
        console.log("Alex $WETH balance after compound:", aweth.balanceOf(address(alex)));

        // Check where the anchor tokens are now
        console.log("\n=== Checking anchor token locations ===");
        console.log("$WBTC contract WBTC balance:", wbtc.balanceOf(address(awbtc)));
        console.log("$WETH contract WETH balance:", weth.balanceOf(address(aweth)));
        console.log("Compound contract WBTC balance:", wbtc.balanceOf(address(compound)));
        console.log("Compound contract WETH balance:", weth.balanceOf(address(compound)));
        console.log("Compound contract $WBTC balance:", awbtc.balanceOf(address(compound)));
        console.log("Compound contract $WETH balance:", aweth.balanceOf(address(compound)));
        console.log("\n=== Step 4: Unwind compound back to constituents ===");
        console.log("This should FAIL because anchor tokens are in compound contract,");
        console.log("but __transfer tries to send them from base unit contracts.");

        // Try to unwind: extract 2 $WBTC and 4 $WETH from compound
        // This should revert with "ERC20: transfer amount exceeds balance" or similar
        alex.forge(awbtc, aweth, 2, 4);
    }

    /**
     * @notice Test showing that base unit redemption also fails after compound creation.
     * @dev After creating compounds, the base unit contracts don't have enough anchor tokens
     * to satisfy redemptions.
     */
    function test_AnchoredRedemptionFailsAfterCompound() public {
        // Give alex some "1" tokens
        owen.give(address(alex), initialOne, l);

        // Create anchored units
        alex.approve(address(awbtc), 100, wbtc);
        alex.forge(awbtc, 10, 10);

        console.log("Initial $WBTC balance:", awbtc.balanceOf(address(alex)));
        console.log("Initial WBTC backing:", wbtc.balanceOf(address(awbtc)));

        // Create compound using 5 $WBTC
        alex.approve(address(aweth), 100, weth);
        alex.forge(aweth, 10, 10);

        // Create the compound unit contract
        compound = awbtc.multiply(aweth);
        alex.addToken(compound);

        // Forge the compound
        alex.forge(awbtc, aweth, -5, -5);

        console.log("\nAfter compound creation:");
        console.log("Alex $WBTC balance:", awbtc.balanceOf(address(alex)));
        console.log("WBTC in $WBTC contract:", wbtc.balanceOf(address(awbtc)));
        console.log("WBTC in compound contract:", wbtc.balanceOf(address(compound)));

        // Now alex tries to burn his remaining 5 $WBTC to get WBTC back
        // This should fail because the $WBTC contract only has 5 WBTC left,
        // but the $WBTC token supply is 10
        console.log("\nTrying to redeem remaining $WBTC...");
        console.log("This may fail if not enough WBTC backing in base contract.");

        // Burn $WBTC (this works if we only burn what's left in the base contract)
        alex.forge(awbtc, -5, 0);

        console.log("\nAfter redemption:");
        console.log("WBTC returned to Alex:", wbtc.balanceOf(address(alex)));
    }
}
