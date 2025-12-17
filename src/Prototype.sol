// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Prototype
 * @notice Base contract for self-cloning minimal proxy implementations using EIP-1167.
 * @dev
 * The contract deployed as the Prototype acts as:
 *   - the reference implementation with canonical logic, and
 *   - a factory that deterministically deploys minimal proxy clones of itself.
 *
 * Each clone:
 *   - delegates all logic to the Prototype via DELEGATECALL,
 *   - maintains its own isolated storage,
 *   - preserves the original msg.sender through the proxy,
 *   - inherits the same immutable PROTOTYPE address.
 *
 * **Deterministic Deployment:**
 * All clones are deployed with CREATE2 using salts derived from initialization
 * data via keccak256(abi.encode(initData)), ensuring predictable, repeatable
 * addresses. Calling __clone with identical initData will return the same
 * address without redeploying.
 *
 * **Usage Pattern:**
 * 1. Deploy Prototype implementation contract
 * 2. Call __clone(initData) to create instances
 * 3. Each clone is automatically initialized via __initialize(initData)
 * 4. Clones can call __clone to create more clones (forwarded to Prototype)
 *
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
abstract contract Prototype {
    // ============ State Variables ============

    /**
     * @notice Address of the original Prototype implementation.
     * @dev Clones inherit this immutable value through bytecode; on the Prototype
     *      itself it equals address(this). This creates a shared reference point
     *      for all clones to delegate calls to and query state from.
     *
     *      Immutables are embedded in bytecode during deployment, so each clone's
     *      bytecode contains the Prototype address even though storage is separate.
     */
    address internal immutable PROTOTYPE = address(this);

    /**
     * @dev Registry mapping clone addresses to their CREATE2 salts.
     *      Only populated on the Prototype contract, not on clones.
     *
     *      Maps: clone address → CREATE2 salt
     *
     *      A non-zero value indicates the address was deployed as a valid clone.
     *      Used by isClone() for verification and to prevent duplicate deployments.
     */
    mapping(address => bytes32) private salts;

    // ============ View Functions ============

    /**
     * @notice Returns true if `check` is a clone of this Prototype.
     * @dev When called on the Prototype: checks the salts registry directly.
     *      When called on a clone: delegates to the Prototype for verification.
     *
     *      This pattern ensures a single source of truth (the Prototype's registry)
     *      while allowing verification from any context.
     *
     * @param check Address to examine.
     * @return yes True if the address was deployed as a clone via __clone().
     */
    function isClone(address check) public view returns (bool yes) {
        yes = address(this) == PROTOTYPE ? salts[check] != 0x0 : Prototype(PROTOTYPE).isClone(check);
    }

    /**
     * @notice Returns the immutable Prototype address.
     * @dev Identical for both the implementation and all clones because it reads
     *      from the immutable PROTOTYPE field embedded in bytecode.
     *
     *      Useful for:
     *      - Accessing the canonical registry (salts mapping)
     *      - Delegating operations back to the implementation
     *      - Verifying clone authenticity
     *
     * @return The address of the Prototype implementation contract.
     */
    function prototype() public view returns (address) {
        return PROTOTYPE;
    }

    /**
     * @notice Predicts the clone address for a given salt.
     * @dev Uses OpenZeppelin's Clones library to compute the deterministic address
     *      based on the Prototype address and salt. This is a view function that
     *      does not deploy anything.
     *
     *      The address is computed as: CREATE2(PROTOTYPE, salt, PROTOTYPE, initcode)
     *      where the deployer is the Prototype itself.
     *
     * @param newSalt The CREATE2 salt that will be used.
     * @return predicted The deterministic clone address that would be deployed.
     */
    function __predict(bytes32 newSalt) public view returns (address predicted) {
        predicted = Clones.predictDeterministicAddress(PROTOTYPE, newSalt, PROTOTYPE);
    }

    /**
     * @notice Predicts the clone address for initialization data.
     * @dev Salt is deterministically derived from initData as:
     *      keccak256(abi.encode(initData))
     *
     *      Note: abi.encode is used (not abi.encodePacked) to ensure proper
     *      ABI encoding with type information, preventing collisions.
     *
     *      This overload is the primary entry point for predicting addresses
     *      when you have initialization parameters but not a precomputed salt.
     *
     * @param initData Initialization calldata for the clone.
     * @return predicted Deterministic clone address.
     * @return newSalt The CREATE2 salt derived from initData.
     */
    function __predict(bytes memory initData) public view returns (address predicted, bytes32 newSalt) {
        newSalt = keccak256(abi.encode(initData));
        predicted = __predict(newSalt);
    }

    // ============ Factory Functions ============

    /**
     * @notice Deploys a deterministic minimal proxy clone.
     * @dev
     * **When called on the Prototype:**
     *   1. Computes salt from keccak256(abi.encode(initData))
     *   2. Predicts clone address using CREATE2 formula
     *   3. If no code at address: deploys clone, records salt, calls __initialize
     *   4. If code exists: returns existing address (idempotent)
     *   5. Calls __initialize(initData) on newly deployed clones only
     *
     * **When called on a clone:**
     *   - Forwards the request back to PROTOTYPE.__clone(initData)
     *   - This enables clones to create other clones transparently
     *
     * **Idempotency:**
     * Calling __clone with the same initData multiple times returns the same
     * address. Only the first call performs deployment and initialization.
     *
     * **Security:**
     * Only the Prototype can call __initialize due to onlyPrototype modifier.
     * Clones cannot initialize themselves or other clones directly.
     *
     * @param initData Initialization data passed to the clone's __initialize.
     * @return instance The deployed (or existing) clone address.
     * @return newSalt The CREATE2 salt used for deterministic deployment.
     */
    function __clone(bytes memory initData) public returns (address instance, bytes32 newSalt) {
        if (address(this) == PROTOTYPE) {
            (instance, newSalt) = __predict(initData);

            if (instance.code.length == 0) {
                instance = Clones.cloneDeterministic(PROTOTYPE, newSalt);
                salts[instance] = newSalt;
                Prototype(instance).__initialize(initData);
            }
        } else {
            (instance, newSalt) = Prototype(PROTOTYPE).__clone(initData);
        }
    }

    /**
     * @notice Initialize a newly deployed clone.
     * @dev **Must be implemented by derived classes.**
     *
     *      **Security considerations:**
     *      - MUST use the onlyPrototype modifier to prevent unauthorized calls
     *      - SHOULD validate initData to prevent malicious initialization
     *      - SHOULD consider using a reentrancy guard if calling external contracts
     *      - MUST NOT assume msg.sender is the end user (it's always PROTOTYPE)
     *
     *      **Initialization pattern:**
     *      Decode initData, set storage variables, emit events. The actual user
     *      who called __clone is typically encoded in initData, not msg.sender.
     *
     *      **Called automatically** by __clone during clone deployment.
     *
     * @param initData ABI-encoded initialization parameters.
     */
    function __initialize(bytes memory initData) public virtual;

    // ============ Internal Functions ============

    /**
     * @notice Restricts calls to the Prototype implementation contract only.
     * @dev Applied to __initialize to ensure only the Prototype can initialize
     *      new clones during deployment. Prevents external actors or clones
     *      themselves from calling initialization logic.
     *
     *      Uses internal _onlyPrototype() for the actual check.
     */
    modifier onlyPrototype() {
        _onlyPrototype();
        _;
    }

    /**
     * @dev Reverts if msg.sender is not the Prototype implementation.
     *
     *      This check ensures that only the factory (Prototype) can call
     *      protected functions, preventing unauthorized initialization or
     *      configuration of clones.
     *
     *      Reverts with Unauthorized() custom error for gas efficiency.
     */
    function _onlyPrototype() internal view {
        if (msg.sender != PROTOTYPE) {
            revert Unauthorized();
        }
    }

    // ============ Errors ============

    /**
     * @notice Error raised when a caller lacks permission to execute a protected function.
     * @dev Thrown by the onlyPrototype modifier when msg.sender != PROTOTYPE.
     *      Custom errors are more gas-efficient than require strings.
     */
    error Unauthorized();
}
