// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {IUnit, IMigratable, IERC20} from "./IUnit.sol";
import {CloneERC20, Prototype} from "./CloneERC20.sol";
import {Units, Term} from "./Units.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TransientSlot} from "@openzeppelin/contracts/utils/TransientSlot.sol";

/**
 * @title IUnit — A universal liquidity system based on symbolic units.
 * See {IUnit} for details.
 */
contract Unit is CloneERC20, IUnit {
    using Units for *;
    using SafeERC20 for IERC20;
    using TransientSlot for *;

    /// @notice The ERC-20 symbol for the central 1 token.
    string public constant ONE_SYMBOL = "1";

    /// @notice The ERC-20 symbol for the central 1 token.
    string public constant NAME_PREFIX = "Uniteum 0.1 ";

    /// @notice The total original supply of {1} minted.
    /// @dev The total supply of {1} will never exceed this value.
    uint256 public immutable ONE_MINTED;

    /// @notice The central 1 unit.
    Unit private immutable ONE = this;

    /// @inheritdoc IUnit
    IUnit public reciprocal;

    /// @inheritdoc IUnit
    IERC20 public anchor;

    /// @inheritdoc IUnit
    function one() public view returns (IUnit) {
        return ONE;
    }

    /// @inheritdoc IUnit
    function invariant(uint256 u, uint256 v) public pure returns (uint256 w) {
        w = Math.sqrt(u * v);
    }

    /// @inheritdoc IUnit
    function invariant() public view notOne returns (uint256 u, uint256 v, uint256 w) {
        u = totalSupply();
        v = reciprocal.totalSupply();
        w = invariant(u, v);
    }

    /// @inheritdoc IUnit
    function invariant(IUnit V) public view returns (IUnit W, uint256 u, uint256 v, uint256 w) {
        if (address(V) == address(this)) {
            revert DuplicateUnits();
        } else if (address(V) == address(reciprocal)) {
            W = one();
            (u, v, w) = invariant();
        } else {
            (W,) = product(V);
            u = this.balanceOf(address(W));
            v = V.balanceOf(address(W));
            w = invariant(u, v);
        }
    }

    /// @inheritdoc IUnit
    /// @dev Revert if called on 1 via call to invariant().
    function forgeQuote(int256 du, int256 dv) public view returns (int256 dw) {
        (uint256 u0, uint256 v0, uint256 w0) = invariant();

        uint256 u1 = add(this, u0, du);
        uint256 v1 = add(reciprocal, v0, dv);
        uint256 w1 = invariant(u1, v1);

        // forge-lint: disable-next-line(unsafe-typecast)
        dw = int256(w0) - int256(w1);
        // Double dw if no anchor tokens are involved to keep the invariant balanced.
        if (address(anchor) == address(0) && address(reciprocal.anchor()) == address(0)) {
            dw *= 2;
        }
    }

    /// @inheritdoc IUnit
    /// @dev Revert if called on 1 via call to invariant().
    function forgeQuote(IUnit V, int256 du, int256 dv) public view returns (IUnit W, int256 dw) {
        if (address(V) == address(reciprocal)) {
            W = one();
            dw = forgeQuote(du, dv);
        } else {
            uint256 u0;
            uint256 v0;
            uint256 w0;
            (W, u0, v0, w0) = invariant(V);

            uint256 u1 = add(this, u0, -du);
            uint256 v1 = add(V, v0, -dv);
            uint256 w1 = invariant(u1, v1);

            // forge-lint: disable-next-line(unsafe-typecast)
            dw = 2 * (int256(w1) - int256(w0));
        }
    }

    /// @inheritdoc IUnit
    /// @dev This function must be non-reentrant to thwart malicious anchor tokens.
    /// @dev Revert if called on 1 via call to invariant().
    function forge(int256 du, int256 dv) external nonReentrant returns (int256 dw) {
        dw = forgeQuote(du, dv); // Also check for notOne.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (du < 0) this.__burn(msg.sender, uint256(-du));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dv < 0) Unit(address(reciprocal)).__burn(msg.sender, uint256(-dv));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dw < 0) ONE.__burn(msg.sender, uint256(-dw));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (du > 0) this.__mint(msg.sender, uint256(du));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dv > 0) Unit(address(reciprocal)).__mint(msg.sender, uint256(dv));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dw > 0) ONE.__mint(msg.sender, uint256(dw));
        emit Forge(msg.sender, this, du, dv, dw);
    }

    //// @inheritdoc IUnit
    /// @dev This function must be non-reentrant to thwart malicious anchor tokens.
    /// @dev Revert if called on 1 via call to invariant().
    function forge(IUnit V, int256 du, int256 dv) external nonReentrant returns (IUnit W, int256 dw) {
        (W, dw) = forgeQuote(V, du, dv); // Also check for notOne.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (du < 0) this.__transfer(msg.sender, address(W), uint256(-du));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dv < 0) Unit(address(V)).__transfer(msg.sender, address(W), uint256(-dv));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dw < 0) Unit(address(W)).__burn(msg.sender, uint256(-dw));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (du > 0) this.__transfer(address(W), msg.sender, uint256(du));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dv > 0) Unit(address(V)).__transfer(address(W), msg.sender, uint256(dv));
        // forge-lint: disable-next-line(unsafe-typecast)
        if (dw > 0) Unit(address(W)).__mint(msg.sender, uint256(dw));
        emit Forge(msg.sender, this, du, dv, dw);
    }

    /**
     * @notice Burn units of the holder.
     * @dev - Only Units with the same 1 can call this function.
     * @param from The holder of the burned units.
     * @param to The holder of the burned units.
     * @param units The number of units to burn.
     */
    function __transfer(address from, address to, uint256 units) public onlyUnit {
        _transfer(from, to, units);
    }

    /**
     * @notice Burn units of the holder.
     * @dev - Only Units with the same 1 can call this function.
     * @param holder The holder of the burned units.
     * @param units The number of units to burn.
     */
    function __burn(address holder, uint256 units) public onlyUnit {
        _burn(holder, units);
    }

    /**
     * @notice Mint units for the holder.
     * @dev - Only Units with the same 1 can call this function.
     * @param holder The recipient of the minted units.
     * @param units The number of units to mint.
     */
    function __mint(address holder, uint256 units) public onlyUnit {
        // If this Unit wraps an external token, get wrapped tokens from the holder.
        if (address(anchor) != address(0)) {
            anchor.safeTransferFrom(holder, address(this), units);
        }
        _mint(holder, units);
    }

    /**
     * @notice Safely computes an updated supply of tokens and reverts if the supply would be negative.
     * @param U The unit whose supply is being calculated. For errors only.
     * @param u0 The current supply of U.
     * @param du The change in the supply of U.
     * @return u1 The updated supply of U.
     */
    function add(IUnit U, uint256 u0, int256 du) private pure returns (uint256 u1) {
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 u = int256(u0) + du;
        if (u < 0) {
            revert NegativeSupply(U, u);
        }
        // forge-lint: disable-next-line(unsafe-typecast)
        u1 = uint256(u);
    }

    /**
     * @dev Only one() can call this method.
     * @param canonical expression defining the unit.
     */
    function __initialize(string memory canonical) internal {
        _symbol = canonical;
        _name = string.concat(NAME_PREFIX, canonical);
        Term[] memory terms = canonical.parseTerms();
        if (terms.length == 1) {
            anchor = IERC20(terms[0].anchor());
        }
        (address reciprocalAddress,) = __clone(bytes(terms.reciprocal().sortAndMerge().symbol()));
        reciprocal = IUnit(reciprocalAddress);
    }

    /// @inheritdoc Prototype
    function __initialize(bytes memory initData) public virtual override onlyPrototype {
        __initialize(string(initData));
    }

    /// @inheritdoc IUnit
    function product(string memory expression) public view returns (IUnit unit, string memory canonical) {
        Term[] memory terms = symbol().parseTerms().product(expression.parseTerms().sortAndMerge());
        if (terms.length > 0) {
            terms = terms.sortAndMerge();
        }
        canonical = terms.symbol();
        if (terms.length == 0) {
            unit = one();
        } else {
            (address unitAddress,) = __predict(bytes(canonical));
            unit = IUnit(unitAddress);
        }
    }

    /// @inheritdoc IUnit
    function multiply(string memory expression) public returns (IUnit unit) {
        string memory canonical;
        (unit, canonical) = product(expression);
        if (address(unit).code.length == 0) {
            __clone(bytes(canonical));
        }
    }

    /// @inheritdoc IUnit
    function anchoredSymbol(IERC20 token) public pure returns (string memory s) {
        s = address(token).withExponent(Units.ONE_RATIONAL_8).symbol();
    }

    /// @inheritdoc IUnit
    function anchoredPredict(IERC20 token) external view returns (IUnit unit, string memory canonical) {
        (unit, canonical) = product(anchoredSymbol(token));
    }

    /// @inheritdoc IUnit
    function anchored(IERC20 token) external returns (IUnit unit) {
        unit = multiply(anchoredSymbol(token));
    }

    /// @dev Mapping of multipliers to their product units.
    mapping(IUnit => IUnit) private _products;

    /// @inheritdoc IUnit
    function product(IUnit multiplier) public view returns (IUnit unit, string memory canonical) {
        unit = _products[multiplier];
        if (address(unit) != address(0)) {
            canonical = unit.symbol();
        } else {
            (unit, canonical) = product(multiplier.symbol());
        }
    }

    /// @inheritdoc IUnit
    function multiply(IUnit multiplier) public returns (IUnit unit) {
        unit = _products[multiplier];
        if (address(unit) == address(0)) {
            unit = multiply(multiplier.symbol());
            _products[multiplier] = unit;
        }
    }

    modifier onlyUnit() {
        _onlyUnit();
        _;
    }

    function _onlyUnit() private view {
        // Revert if the caller does not have the same address as predicted by its hash.
        // Prevent malicious actors from calling protected functions.
        if ((msg.sender != PROTOTYPE) && (!Prototype(PROTOTYPE).isClone(msg.sender))) {
            revert Unauthorized();
        }
    }

    modifier onlyOne() {
        _onlyOne();
        _;
    }

    function _onlyOne() private view {
        if (this != one()) {
            revert FunctionNotCalledOnOne();
        }
    }

    modifier notOne() {
        _notOne();
        _;
    }

    function _notOne() private view {
        if (this == one()) {
            revert FunctionCalledOnOne();
        }
    }

    // The following reentrancy code was modified from openzeppelin.storage.ReentrancyGuardTransient
    // It uses transient boolean storage on {one()} to prevent reentrancy on all units during a transaction.
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuardTransient")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        ONE.__nonReentrantBefore();
    }

    function _nonReentrantAfter() private {
        ONE.__nonReentrantAfter();
    }

    function __nonReentrantBefore() public onlyOne {
        if (REENTRANCY_GUARD_STORAGE.asBoolean().tload()) {
            revert ReentryForbidden();
        }

        // Any calls to nonReentrant after this point will fail
        REENTRANCY_GUARD_STORAGE.asBoolean().tstore(true);
    }

    function __nonReentrantAfter() public onlyOne {
        REENTRANCY_GUARD_STORAGE.asBoolean().tstore(false);
    }

    IERC20 public immutable UPSTREAM_ONE;

    /// @inheritdoc IMigratable
    function migrate(uint256 units) external onlyOne {
        UPSTREAM_ONE.safeTransferFrom(msg.sender, address(this), units);
        _mint(msg.sender, units);
    }

    /// @inheritdoc IMigratable
    function unmigrate(uint256 units) external onlyOne {
        _burn(msg.sender, units);
        UPSTREAM_ONE.safeTransferFrom(address(this), msg.sender, units);
    }

    constructor(IERC20 upstream) CloneERC20(ONE_SYMBOL, ONE_SYMBOL) {
        reciprocal = this;
        _symbol = ONE_SYMBOL;
        _name = string.concat(NAME_PREFIX, ONE_SYMBOL);
        UPSTREAM_ONE = upstream;
        emit UnitCreate(this, anchor, bytes32(0), _symbol);
    }
}
