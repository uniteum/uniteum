// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Prototype
 * @notice Base contract for self-cloning minimal proxy implementations.
 * @dev
 * The contract deployed as the Prototype acts as:
 *   - the reference implementation with canonical storage, and
 *   - a factory that deterministically deploys minimal proxy clones of itself.
 *
 * Each clone:
 *   - delegates all logic to the Prototype,
 *   - uses its own storage,
 *   - preserves the caller’s msg.sender,
 *   - inherits the same immutable PROTOTYPE address.
 *
 * All clones are deployed with CREATE2 using salts derived from initialization
 * data, ensuring predictable, repeatable addresses.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
abstract contract Prototype {
    /**
     * @notice Address of the original Prototype implementation.
     * @dev Clones inherit this immutable value; on the Prototype it equals address(this).
     */
    address internal immutable PROTOTYPE = address(this);

    /**
     * @dev Mapping used to record whether an address was deployed as a clone.
     *      Maps clone address → CREATE2 salt.
     */
    mapping(address => bytes32) private salts;

    /**
     * @notice Returns true if `check` is a clone of this Prototype.
     * @param check Address to examine.
     * @return yes True if the address was deployed as a clone.
     */
    function isClone(address check) public view returns (bool yes) {
        yes = address(this) == PROTOTYPE ? salts[check] != 0x0 : Prototype(PROTOTYPE).isClone(check);
    }

    /**
     * @notice Returns the immutable Prototype address.
     * @dev Identical for both the implementation and all clones.
     */
    function prototype() public view returns (address) {
        return PROTOTYPE;
    }

    /**
     * @notice Predicts the clone address for a given salt.
     * @param newSalt The CREATE2 salt that will be used.
     * @return predicted The deterministic clone address.
     */
    function __predict(bytes32 newSalt) public view returns (address predicted) {
        predicted = Clones.predictDeterministicAddress(PROTOTYPE, newSalt, PROTOTYPE);
    }

    /**
     * @notice Predicts the clone address for initialization data.
     * @dev Salt is derived from `keccak256(initData)`.
     * @param initData Initialization calldata for the clone.
     * @return predicted Deterministic clone address.
     * @return newSalt The CREATE2 salt derived from initData.
     */
    function __predict(bytes memory initData) public view returns (address predicted, bytes32 newSalt) {
        newSalt = keccak256(abi.encode(initData));
        predicted = __predict(newSalt);
    }

    /**
     * @notice Deploys a deterministic minimal proxy clone.
     * @dev
     * On the Prototype:
     *   - Computes salt from initData.
     *   - Deploys clone if it does not already exist.
     *   - Calls __initialize(initData) on the new clone.
     *
     * On a clone:
     *   - Forwards the request back to the Prototype.
     *
     * @param initData Initialization data passed to the clone.
     * @return instance The deployed clone address.
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
     * @dev Must be implemented by derived classes.
     *      Only callable by the Prototype.
     * @param initData ABI-encoded initialization parameters.
     */
    function __initialize(bytes memory initData) public virtual;

    /**
     * @notice Restricts calls to the Prototype implementation.
     */
    modifier onlyPrototype() {
        _onlyPrototype();
        _;
    }

    /**
     * @dev Reverts if msg.sender is not the Prototype implementation.
     */
    function _onlyPrototype() internal view {
        if (msg.sender != PROTOTYPE) {
            revert Unauthorized();
        }
    }

    /**
     * @notice Error raised when a caller lacks permission.
     */
    error Unauthorized();
}
