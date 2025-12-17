# CLAUDE.md - Uniteum Protocol

> Context guide for AI-assisted development of the Uniteum algebraic liquidity protocol.

## Table of Contents

- [Overview](#overview)
- [Core Concepts](#core-concepts)
- [Architecture](#architecture)
- [Critical Invariants](#critical-invariants)
- [Contract Reference](#contract-reference)
- [Development Workflow](#development-workflow)
- [Testing Patterns](#testing-patterns)
- [Common Tasks](#common-tasks)
- [Security Considerations](#security-considerations)

---

## Overview

**Uniteum** is an algebraic liquidity protocol on Ethereum where Units are ERC-20 tokens with built-in liquidity via reciprocal relationships. The system uses symbolic algebra to represent compound units (like physical dimensions).

### What Makes It Unique

- **Built-in Liquidity**: Every unit U has a reciprocal 1/U with a constant product invariant `sqrt(u * v) = w`
- **Symbolic Algebra**: Units compose algebraically: `kg*m/s^2`, `USD*ETH`, `m^2\3`
- **Rational Exponents**: Full support for rational number exponents (e.g., `x^2\3`, `kg^-1\2`)
- **Anchored Units**: Custodial wrappers for external ERC-20 tokens (e.g., `$0xdAC17F958D2ee523a2206206994597C13D831ec7` for USDT)
- **Kiosk System**: Native currency ↔ ERC-20 trading with fixed or discount pricing

### Key Files

- **Core Protocol**: [src/Unit.sol](src/Unit.sol) - The main algebraic liquidity contract
- **Symbol System**: [src/Units.sol](src/Units.sol) - Symbol parsing and term manipulation
- **Rational Math**: [src/Rationals.sol](src/Rationals.sol) - Rational number arithmetic
- **Trading**: [src/Kiosk.sol](src/Kiosk.sol), [src/FixedKiosk.sol](src/FixedKiosk.sol), [src/DiscountKiosk.sol](src/DiscountKiosk.sol)

---

## Core Concepts

### 1. The Central Unit "1"

The identity unit is the foundation of the system:

```solidity
IUnit one = new Unit(upstreamToken);
```

- Symbol: `"1"`
- Self-reciprocal: `one.reciprocal() == one`
- All other units are created from and relate back to "1"
- Only "1" supports `migrate()` and `unmigrate()` operations

### 2. Reciprocal Relationship

Every unit has an automatically-created reciprocal:

```solidity
IUnit U = one.multiply("USD");
IUnit V = U.reciprocal();  // "1/USD"
assert(V.reciprocal() == U);
```

### 3. Constant Product Invariant

The core mathematical relationship:

```solidity
// From Unit.sol:46-47
function invariant(uint256 u, uint256 v) public pure returns (uint256 w) {
    w = Math.sqrt(u * v);  // Geometric mean
}
```

For any unit U and its reciprocal 1/U:
- `u` = total supply of U
- `v` = total supply of 1/U
- `w` = sqrt(u * v) must remain constant (or increase systematically)

### 4. The Forge Operation

The primary operation for minting/burning while maintaining invariants:

```solidity
function forge(IUnit V, int256 du, int256 dv)
    external
    returns (IUnit W, int256 dw)
```

**Parameters:**
- `V`: The second unit (often the reciprocal)
- `du`: Signed change in balance of calling unit
- `dv`: Signed change in balance of unit V
- Returns `W` (product unit, usually "1") and `dw` (change in W balance)

**Example:**
```solidity
// Mint 1000 USD and 500 1/USD, burn appropriate amount of "1"
(W, dw) = USD.forge(reciprocalUSD, 1000, 500);
// W == one, dw < 0 (burned "1" tokens)
```

### 5. Symbol Algebra

Units compose using standard algebraic notation:

```solidity
unit("kg") * unit("m") / unit("s^2")  →  unit("kg*m/s^2")
unit("ETH") * unit("USD")             →  unit("ETH*USD")
unit("m^2")                           →  unit("m^2")
unit("kg^2\\3")                       →  unit("kg^2\\3")  // Note: \\ is escape for \
```

**Normalization:**
- Symbols are automatically simplified: `"a*b/a"` → `"b"`
- Exponents are reduced: `"a^15\\6"` → `"a^5\\2"` (15/6 = 5/2)
- Terms are sorted alphabetically

### 6. Anchored Units

Wrap external ERC-20 tokens with custodial semantics:

```solidity
// Symbol format: $0x<address>
IUnit wrappedUSDT = one.multiply("$0xdAC17F958D2ee523a2206206994597C13D831ec7");

// Minting transfers underlying tokens to Unit contract
wrappedUSDT.forge(reciprocal, 1000, 1000);  // Transfers 1000 USDT from user
```

**Rules:**
- Only base units (exponent 1/1) can be anchored
- Underlying tokens are held by the Unit contract
- Symbol must start with `$0x` followed by the token address

---

## Architecture

### Contract Hierarchy

```
Prototype (factory base)
    ├─ CloneERC20 (cloneable ERC-20)
    │   └─ Unit (algebraic liquidity)
    └─ Kiosk (native ↔ ERC-20 trading)
        ├─ FixedKiosk (constant price)
        └─ DiscountKiosk (linear discount curve)
```

### Key Components

#### Unit System
- **[Unit.sol](src/Unit.sol)**: Core protocol implementing forge, invariant, unit composition
- **[IUnit.sol](src/IUnit.sol)**: Interface defining the unit operations
- **[CloneERC20.sol](src/CloneERC20.sol)**: ERC-20 base with cloning support

#### Symbol & Math Libraries
- **[Units.sol](src/Units.sol)**: Symbol parsing, term manipulation, composition
- **[Term.sol](src/Term.sol)**: Packed uint256 type for unit terms
- **[Rationals.sol](src/Rationals.sol)**: 128-bit rational number arithmetic
- **[Rational.sol](src/Rational.sol)**: 8-bit compact rational for exponents

#### Trading System
- **[Kiosk.sol](src/Kiosk.sol)**: Abstract base for selling ERC-20 for native currency
- **[FixedKiosk.sol](src/FixedKiosk.sol)**: Simple fixed-price implementation
- **[DiscountKiosk.sol](src/DiscountKiosk.sol)**: Linear discount curve with free overflow

#### Utilities
- **[Prototype.sol](src/Prototype.sol)**: Deterministic CREATE2 minimal proxy factory
- **[Mintlet.sol](src/Mintlet.sol)**: Minimalist ERC-20 token creator

### Data Structures

#### Term (packed uint256)

```
+0......0|1.........................20|21................29|30...........31+
| Symbol/Address                      |    Reserved        |   Exponent    |
| Type=0: 30-byte base symbol         |                    | Rational8     |
| Type=1: address (ERC-20 token)      |                    |               |
```

Encoding examples:
- `"kg"` → base symbol with exponent 1/1
- `"m^2"` → base symbol with exponent 2/1
- `"$0xdAC17F958D2ee523a2206206994597C13D831ec7"` → anchored USDT with exponent 1/1

#### Rational (128-bit)

```
[int128 numerator | uint128 denominator]
```

Always stored in reduced form. Examples:
- `3/4` → `{num: 3, den: 4}`
- `6/8` → `{num: 3, den: 4}` (reduced)
- `-5/2` → `{num: -5, den: 2}`

#### Rational8 (16-bit)

```
[int8 numerator | uint8 denominator]
```

Compact version for exponents in terms.

---

## Critical Invariants

### 1. Constant Product (Geometric Mean)

For any unit U and reciprocal V:

```solidity
sqrt(totalSupply(U) * totalSupply(V)) = constant (or increases via forge)
```

**Enforced by:** [Unit.sol:46-55](src/Unit.sol#L46-L55)
**Tested in:** [test/Forge.t.sol](test/Forge.t.sol)

### 2. Reciprocal Symmetry

```solidity
U.reciprocal().reciprocal() == U
```

**Enforced by:** Unit creation logic
**Tested in:** [test/Unit.t.sol](test/Unit.t.sol)

### 3. Symbol Normalization

Symbols are always in canonical form:
- Terms sorted alphabetically
- Exponents reduced to lowest terms
- Like terms merged

**Example:** `"a*b/a"` → `"b"`, `"m^4\\2"` → `"m^2"`

**Enforced by:** [Units.sol:sortAndMerge()](src/Units.sol)
**Tested in:** [test/Unit.t.sol](test/Unit.t.sol)

### 4. Reentrancy Protection

All state-changing operations use transient reentrancy guard:

```solidity
modifier nonReentrant() {
    ONE.__nonReentrantBefore();
    _;
    ONE.__nonReentrantAfter();
}
```

**Enforced by:** Guard stored on unit "1" via EIP-1153 transient storage
**Location:** [Unit.sol](src/Unit.sol) (search for `REENTRANCY_GUARD_STORAGE`)

### 5. Anchor Token Custody

For anchored units (`$0x...`):
- Underlying tokens MUST be transferred to Unit contract on mint
- Underlying tokens MUST be returned on burn
- Only base units (exponent 1/1) can be anchored

**Enforced by:** [Unit.sol migrate/unmigrate](src/Unit.sol)
**Tested in:** [test/Unit.t.sol](test/Unit.t.sol)

### 6. Total Supply of "1" Never Increases

```solidity
totalSupply("1") <= ONE_MINTED
```

The forge operation may burn "1" tokens but never mints beyond initial supply.

**Enforced by:** Forge logic in [Unit.sol](src/Unit.sol)
**Tested in:** [test/Forge.t.sol](test/Forge.t.sol)

---

## Contract Reference

### Unit.sol

**Key Functions:**

```solidity
// Create new unit by multiplying symbol
function multiply(string memory symbol_) external returns (IUnit U)

// Get product of this unit with another
function product(IUnit V) external view returns (IUnit W, bool reverse)

// Mint/burn maintaining invariant
function forge(IUnit V, int256 du, int256 dv) external returns (IUnit W, int256 dw)

// Quote forge without execution
function forgeQuote(IUnit V, int256 du, int256 dv) public view returns (IUnit W, int256 dw)

// Get current invariant state
function invariant() public view returns (uint256 u, uint256 v, uint256 w)

// Migrate underlying tokens (anchored units only, callable on "1")
function migrate(IUnit A, uint256 amount) external returns (int256 da)

// Unmigrate underlying tokens (anchored units only, callable on "1")
function unmigrate(IUnit A, uint256 amount) external returns (int256 da)
```

**Important State:**

```solidity
IUnit public reciprocal;      // The reciprocal unit (1/U)
IERC20 public anchor;         // Underlying ERC-20 (if anchored)
uint256 public ONE_MINTED;    // Initial supply of "1" (immutable)
```

### Kiosk.sol

**Abstract Base:**

```solidity
abstract contract Kiosk {
    IERC20 public goods;        // Token being sold
    uint256 public listPrice;   // Reference price
    address public owner;       // Creator/owner

    // Must be implemented by subclasses
    function quote(uint256 v) public view virtual returns (uint256 q, bool soldOut);

    // Buy goods with native currency
    function buy() public payable returns (uint256 q, bool soldOut);

    // Owner functions
    function reclaim(uint256 quantity) external onlyOwner;
    function collect(uint256 value) external onlyOwner;
}
```

### FixedKiosk.sol

**Simple fixed-price implementation:**

```solidity
function quote(uint256 v) public view override returns (uint256 q, bool soldOut) {
    q = 1 ether * v / listPrice;
    soldOut = q >= inventory();
    if (soldOut) {
        q = inventory();
    }
}
```

**Price:** Constant at `listPrice` per unit

### DiscountKiosk.sol

**Linear discount curve:**

```solidity
function quote(uint256 v) public view override returns (uint256 q, bool soldOut) {
    uint256 available = inventory();
    bool beyondCapacity = capacity < available;
    uint256 d = beyondCapacity ? 0 : capacity - available;

    // Quadratic formula from integral of linear price curve
    q = Math.sqrt(d * d + 2 ether * v * capacity / listPrice) - d;

    if (beyondCapacity) {
        q += available - capacity;  // Free region
    }
}
```

**Price Function:** `price(x) = listPrice * (1 - x/capacity)`
- Price decreases linearly as inventory approaches capacity
- Beyond capacity, excess inventory is free

**Additional State:**

```solidity
uint256 public capacity;  // Inventory level at which price → 0
```

---

## Development Workflow

### Code Style

**NatSpec Documentation:**
- Use `/** */` multi-line block notation for all NatSpec comments (never `///`)
- Always use multi-line format even for single-line comments (this is what `forge fmt` enforces)
- Include `@notice` for public descriptions
- Add `@param` and `@return` for functions with parameters/returns
- Keep comments concise and focused

**Examples:**
```solidity
/**
 * @notice ERC-20 token being sold.
 */
IERC20 public goods;

/**
 * @notice Buy goods with native tokens.
 * @param amount Quantity to purchase.
 * @return success True if purchase succeeded.
 */
function buy(uint256 amount) external returns (bool success);
```

**Important:** Always run `forge fmt` before committing to ensure consistent formatting.

### Environment Setup

```bash
# Install NVM and Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
nvm install --lts
nvm use --lts

# Clone and install
git clone git@github.com:uniteum/uniteum.git
cd uniteum
npm install
```

### Environment Variables

```bash
# Required for deployment
export tx_key=<YOUR_PRIVATE_WALLET_KEY>
export ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_API_KEY>

# Chain selection (examples)
export chain=11155111  # Sepolia
export chain=1         # Ethereum Mainnet
export chain=8453      # Base Mainnet
```

See [foundry.toml](foundry.toml) for full list of supported chains.

### Building & Testing

```bash
# Build contracts
forge build

# Run tests
forge test

# Run specific test
forge test --match-test testForgeSimple

# Run with gas report
forge test --gas-report

# Format code
forge fmt

# Gas snapshot
forge snapshot
```

### Deployment

```bash
# Deploy using script
forge script script/Unit.s.sol:UnitScript \
  --rpc-url sepolia \
  --private-key "$tx_key" \
  --broadcast

# Verify on Etherscan
forge verify-contract \
  --chain-id 11155111 \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  <contract_address> \
  src/Unit.sol:Unit \
  --constructor-args $(cast abi-encode "constructor(address)" <upstream_token>)
```

### Solidity Configuration

From [foundry.toml](foundry.toml):

```toml
solc = "0.8.30"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
via_ir = true
always_use_create_2_factory = true
```

**Key Points:**
- Requires Solidity 0.8.30+ for transient storage (EIP-1153)
- Uses Cancun EVM features
- CREATE2 used for deterministic deployments
- IR-based compilation for optimization

---

## Testing Patterns

### Pattern 1: Basic Forge Test

```solidity
function testForgeSimple() public {
    // Setup: users start with "1" tokens
    uint256 initialOne = l.balanceOf(address(alex));

    // Execute: forge to mint U and 1/U
    int256 dw = alex.forge(U, 1, 1);

    // Verify: invariant maintained
    (uint256 us, uint256 vs, uint256 ws) = U.invariant();
    uint256 expected = Math.sqrt(us * vs);
    assertEq(ws, expected, "invariant broken");

    // Cleanup: liquidate returns to initial state
    alex.liquidate(U);
    assertEq(l.balanceOf(address(alex)), initialOne);
}
```

**Key Assertion:** `sqrt(u * v) == w` after every forge operation

### Pattern 2: Symbol Normalization Test

```solidity
function testSymbolNormalization() public {
    IUnit u = one.multiply("a*b/a");
    assertEq(u.symbol(), "b", "should simplify");

    IUnit v = one.multiply("m^4\\2");  // m^(4\2) = m^(4/2)
    assertEq(v.symbol(), "m^2", "should reduce exponent");
}
```

**Key Assertion:** Symbols are always canonical form

### Pattern 3: Kiosk Quote/Buy Test

```solidity
function testKioskBuy() public {
    // Setup: create and stock kiosk
    FixedKiosk kiosk = creator.createKiosk(prototype, token, PRICE);
    creator.give(address(kiosk), 5000 ether, token);

    // Quote
    uint256 value = 1 ether;
    (uint256 expected, bool soldOut) = kiosk.quote(value);

    // Buy
    uint256 balanceBefore = token.balanceOf(address(buyer));
    buyer.buy{value: value}(kiosk);
    uint256 balanceAfter = token.balanceOf(address(buyer));

    // Verify
    assertEq(balanceAfter - balanceBefore, expected);
    assertFalse(soldOut);
}
```

**Key Assertions:**
- Quote matches actual purchase
- Balance changes correctly
- Sold out detection works

### Pattern 4: Discount Curve Test

```solidity
function testDiscountCurveProperties() public {
    DiscountKiosk kiosk = creator.createDiscountKiosk(
        prototype, token, PRICE, CAPACITY
    );
    creator.give(address(kiosk), CAPACITY, token);

    // Can buy all for half the "full price"
    uint256 fullPrice = CAPACITY * PRICE / 1 ether;
    uint256 actualCost = CAPACITY * PRICE / 2 ether;
    (uint256 q, bool soldOut) = kiosk.quote(actualCost);

    assertEq(q, CAPACITY, "should get all at half price");
    assertTrue(soldOut);
}
```

**Key Property:** Linear discount means ∫₀ᶜ p(x)dx = capacity × listPrice / 2

### Test Helpers

```solidity
// UnitUser - wraps user operations
contract UnitUser {
    function forge(IUnit U, int256 du, int256 dv)
        external returns (IUnit W, int256 dw);

    function liquidate(IUnit U)
        external returns (int256 du, int256 dv, int256 dw);

    function buy(Kiosk k) external payable returns (uint256 q, bool soldOut);
}
```

### Base Test Contracts

- **[test/Base.t.sol](test/Base.t.sol)**: Foundry base imports
- **[test/UnitBase.t.sol](test/UnitBase.t.sol)**: Unit testing setup with "1", U, V, users
- **[test/KioskBase.t.sol](test/KioskBase.t.sol)**: Kiosk testing setup

---

## Common Tasks

### Adding a New Kiosk Type

1. **Inherit from Kiosk:**

```solidity
// src/MyKiosk.sol
import {Kiosk} from "./Kiosk.sol";

contract MyKiosk is Kiosk {
    // Add custom state
    uint256 public customParameter;

    // Initialize
    function initialize(
        address creator,
        IERC20 goods_,
        uint256 listPrice_,
        uint256 customParameter_
    ) external {
        __initialize(creator, goods_, listPrice_);
        customParameter = customParameter_;
        emit KioskCreated(creator, goods_, listPrice_);
    }

    // Implement quote logic
    function quote(uint256 v)
        public view override
        returns (uint256 q, bool soldOut)
    {
        // Your pricing logic here
        // Must respect: q <= inventory()
        // soldOut = true if inventory exhausted
    }
}
```

2. **Add Tests:**

```solidity
// test/MyKiosk.t.sol
import {KioskBaseTest} from "./KioskBase.t.sol";
import {MyKiosk} from "../src/MyKiosk.sol";

contract MyKioskTest is KioskBaseTest {
    MyKiosk public prototype;

    function setUp() public override {
        super.setUp();
        prototype = new MyKiosk();
    }

    function testMyKioskQuote() public {
        // Test your quote logic
    }

    function testMyKioskBuy() public {
        // Test buy flow
    }
}
```

3. **Add Deployment Script (optional):**

```solidity
// script/MyKiosk.s.sol
import {Script} from "forge-std/Script.sol";
import {MyKiosk} from "../src/MyKiosk.sol";

contract MyKioskScript is Script {
    function run() external {
        vm.startBroadcast();
        new MyKiosk();
        vm.stopBroadcast();
    }
}
```

### Working with Unit Symbols

```solidity
// Create units programmatically
IUnit USD = one.multiply("USD");
IUnit ETH = one.multiply("ETH");
IUnit ETHUSDT = ETH.product(USD);  // "ETH*USD"

// Parse complex symbols
IUnit force = one.multiply("kg*m/s^2");

// Work with anchored tokens
IUnit wrappedUSDT = one.multiply("$0xdAC17F958D2ee523a2206206994597C13D831ec7");

// Rational exponents (use \\ in code for \)
IUnit cubicRoot = one.multiply("m^1\\3");  // m^(1\3) = m^(1/3)
```

### Forge Operations

```solidity
// Basic forge: mint equal amounts of U and 1/U
IUnit U = one.multiply("USD");
IUnit V = U.reciprocal();
(IUnit W, int256 dw) = U.forge(V, 1000 ether, 1000 ether);
// W == one, dw < 0 (burns "1" tokens)

// Asymmetric forge: different amounts
(W, dw) = U.forge(V, 2000 ether, 500 ether);

// Burn operation: use negative values
(W, dw) = U.forge(V, -1000 ether, -1000 ether);
// dw > 0 (mints "1" tokens back)

// Quote before executing
(W, int256 expectedDw) = U.forgeQuote(V, 1000 ether, 500 ether);
```

### Anchored Token Migration

```solidity
// Only callable on "1"
IUnit wrappedUSDT = one.multiply("$0xdAC17F958D2ee523a2206206994597C13D831ec7");

// Migrate in: transfer USDT to Unit contract, mint wrapped tokens
int256 da = one.migrate(wrappedUSDT, 1000e6);  // 1000 USDT
// da > 0, user receives wrapped tokens

// Migrate out: burn wrapped tokens, receive USDT
da = one.unmigrate(wrappedUSDT, 1000 ether);
// da < 0, user receives USDT
```

---

## Security Considerations

### 1. Reentrancy

**Protection:** Transient reentrancy guard (EIP-1153) on unit "1"

```solidity
modifier nonReentrant() {
    ONE.__nonReentrantBefore();
    _;
    ONE.__nonReentrantAfter();
}
```

**Why it's safe:**
- Single guard on "1" protects all units in same transaction
- Uses transient storage (cleared after transaction)
- Prevents malicious anchor token callbacks

**When reviewing code:**
- All state-changing external functions must use `nonReentrant`
- Pay special attention to anchor token interactions

### 2. Integer Overflow/Underflow

**Protection:** Solidity 0.8.30+ has built-in overflow checks

**Manual checks in critical paths:**

```solidity
function add(IUnit U, uint256 u0, int256 du) internal view returns (uint256 u1) {
    if (du < 0) {
        uint256 delta = uint256(-du);
        if (delta > u0) revert InsufficientBalance(U, delta, u0);
        u1 = u0 - delta;
    } else {
        u1 = u0 + uint256(du);
    }
}
```

**When reviewing code:**
- Watch for unsafe casts: `uint256(int256)`, `int256(uint256)`
- Verify bounds before type conversions
- Check invariant calculations don't overflow

### 3. Anchor Token Trust

**Risk:** Malicious ERC-20 tokens could:
- Revert on transfer (DoS)
- Have callbacks (reentrancy)
- Have incorrect balances (accounting errors)

**Mitigations:**
- Reentrancy guard protects against callbacks
- Use `SafeERC20` for all token interactions
- Anchor tokens should be well-audited (USDT, USDC, etc.)

**When reviewing code:**
- Never trust anchor token behavior
- Always use `safeTransfer` / `safeTransferFrom`
- Consider anchor token balance changes carefully

### 4. Invariant Manipulation

**Risk:** Attacker tries to break `sqrt(u * v) = w`

**Protections:**
- All minting/burning goes through `forge()` which enforces invariant
- Direct transfers don't affect invariant (just user balances)
- `forgeQuote()` uses same math as `forge()` (no arbitrage)

**When reviewing code:**
- Any new mint/burn logic MUST maintain invariant
- Test edge cases: huge amounts, dust amounts, zero
- Fuzz test invariant preservation

### 5. Kiosk Pricing Bugs

**Risk:** Quote calculation errors could:
- Allow buying more than inventory
- Cause integer overflow
- Give incorrect prices

**Protections:**
- Quote must respect: `q <= inventory()`
- Use Math library for sqrt, etc.
- Comprehensive tests for edge cases

**When reviewing new kiosk types:**
- Test: zero value, dust, huge amounts
- Test: empty inventory, full inventory
- Test: quote matches actual buy
- Verify: no refunds means user risk

### 6. Rational Math Precision

**Risk:** Rational arithmetic could:
- Lose precision in reduction
- Overflow in numerator/denominator
- Produce incorrect results

**Protections:**
- Always reduce to lowest terms
- Use 128-bit for intermediate calculations
- Test edge cases (large exponents, negative, zero)

**When reviewing code:**
- Check GCD algorithm correctness
- Verify reduction before storage
- Test overflow boundaries

### 7. Symbol Parsing Vulnerabilities

**Risk:** Malformed symbols could:
- Cause incorrect normalization
- Create duplicate units
- Break invariants

**Protections:**
- Symbol parsing is pure (no state changes)
- Normalization is deterministic
- Unit addresses are deterministic (CREATE2)

**When reviewing code:**
- Test malformed input: `"a*b*c/d/e"`, `"^2"`, `"$0xinvalid"`
- Verify same symbol → same address
- Check term ordering/merging logic

---

## Additional Resources

### Foundry Documentation
- [Foundry Book](https://book.getfoundry.sh/)
- [Forge Testing Guide](https://book.getfoundry.sh/forge/tests)
- [Cheatcodes Reference](https://book.getfoundry.sh/cheatcodes/)

### EIP References
- [EIP-1153: Transient Storage](https://eips.ethereum.org/EIPS/eip-1153)
- [EIP-1167: Minimal Proxy (Clones)](https://eips.ethereum.org/EIPS/eip-1167)
- [EIP-20: ERC-20 Token Standard](https://eips.ethereum.org/EIPS/eip-20)

### OpenZeppelin Contracts
- [SafeERC20](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#SafeERC20)
- [ReentrancyGuardTransient](https://docs.openzeppelin.com/contracts/5.x/api/utils#ReentrancyGuardTransient)
- [Math](https://docs.openzeppelin.com/contracts/4.x/api/utils#Math)

---

## Questions? Common Pitfalls?

### Why does `forge()` return negative `dw`?

When you mint U and 1/U, the invariant requires burning "1" tokens:
- `du > 0`, `dv > 0` → `dw < 0` (burn "1")
- `du < 0`, `dv < 0` → `dw > 0` (mint "1")

This maintains: `sqrt(u * v) = constant`

### Why use `\\` for exponent division?

Solidity strings require escaping backslashes:
- In code: `"m^1\\3"`
- Actual symbol: `"m^1\3"` (m to the 1/3 power)

### What happens if a kiosk runs out of inventory during `buy()`?

No refunds! The quote calculates based on current inventory:
- If inventory depleted, `soldOut = true`
- User receives whatever is available
- Excess ETH is NOT refunded (kept by kiosk)

### Can I create two units with the same symbol?

No. Unit addresses are deterministic (CREATE2):
- Same symbol → same salt → same address
- Attempting to create duplicate reverts
- Use `getUnit(symbol)` to get existing unit

### Why is "1" special?

The identity unit is the foundation:
- All forge operations ultimately involve "1"
- Reentrancy guard lives on "1"
- Only "1" has `migrate()` / `unmigrate()`
- Its reciprocal is itself

---

*This document is maintained for AI-assisted development. When making significant architectural changes, update this file.*
