# Uniteum

Uniteum is an algebraic liquidity protocol on Ethereum where units are ERC-20 tokens with built-in liquidity via reciprocal relationships.

## Overview

- **Built-in Liquidity**: Every unit U has a reciprocal 1/U with constant product invariant `u * v = w^2`
- **Symbolic Algebra**: Units compose algebraically: `kg*m/s^2`, `m^2\3`
- **Rational Exponents**: Full support for rational exponents (e.g., `x^2\3`, `kg^-1\2`)
- **Anchored Units**: Custodial wrappers for external ERC-20 tokens (e.g., `$0xdAC17F958D2ee523a2206206994597C13D831ec7` for USDT)
- **Kiosk System**: Native currency ↔ ERC-20 trading with fixed or discount pricing

For comprehensive documentation, see [CLAUDE.md](CLAUDE.md).

## Quick Start

```bash
# Clone and install
git clone git@github.com:uniteum/uniteum.git
cd uniteum

# Build
forge build

# Test
forge test
```

## Environment Setup

### Environment Variables

Set these in your `.bashrc` or `.zshrc`:

```bash
# Required for deployment (keep secure!)
export tx_key=<YOUR_PRIVATE_WALLET_KEY>
export ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_API_KEY>

# Chain selection (optional)
export chain=11155111  # Sepolia testnet
# export chain=1       # Ethereum mainnet
# export chain=8453    # Base
# export chain=137     # Polygon
```

Get your ETHERSCAN_API_KEY at [Etherscan](https://etherscan.io/myaccount).

## Development

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testForgeSimple

# Run with gas report
forge test --gas-report

# Run with verbosity
forge test -vvv
```

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

## Deployment

### Deploy to Testnet (Sepolia)

```bash
chain=11155111
forge script script/Unit.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Comprehensive protocol documentation
- [Foundry Book](https://book.getfoundry.sh/) - Foundry development framework

## Security

This codebase uses:
- Solidity 0.8.30+ with built-in overflow checks
- EIP-1153 transient storage for reentrancy protection
- Deterministic CREATE2 deployments

See [CLAUDE.md](CLAUDE.md) for detailed security considerations.

## License

See [LICENSE.Uniteum](LICENSE.Uniteum) file for details.
