# liqueth
Monorepo for Liqueth, a decentralized Meta Hub Exchange on EVM where LQTH represents both liquidity and ownership.

### **1. Environment Setup**

#### **Install Node.js using NVM:**
```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash

# Activate NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install and use Node.js
nvm install --lts
nvm use --lts
```

#### **Clone the Repository & Install Dependencies:**
```bash
git clone https://github.com/liqueth/liqueth.git
git clone git@github.com:liqueth/liqueth.git
cd liqueth
npm install
```

Add `.env` to `.gitignore` to prevent sensitive data leaks:
```bash
echo ".env" >> .gitignore
```

### Deploy

```shell
$ forge script script/Unit.s.sol:UnitScript --rpc-url bitsy --private-key "$PRIVATE_KEY"
```

### Encode Contructor Args

```shell
cast abi-encode "constructor(address,uint256,uint256,address,address)" <holder> <supply> <chain> <bridge> <verifier>
```

### Verify Contract

```shell
forge verify-contract --chain-id 11155111 --etherscan-api-key <your key> <contract address> src/Unit.sol:Unit --constructor-args <encoded constructor args>
```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
