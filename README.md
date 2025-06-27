# iLayer on Sui

> A cross-chain intent-based solver hub primitive built on Sui blockchain

[![License: BSL 1.1](https://img.shields.io/badge/License-BSL%201.1-blue.svg)](https://mariadb.com/bsl11/)
[![Sui](https://img.shields.io/badge/Sui-Move-4A90E2)](https://sui.io)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Testing](#testing)
- [Deployment](#deployment)
- [Documentation](#documentation)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## 🌟 Overview

iLayer on Sui is a complete rewrite of the original Ethereum/EVM-based iLayer protocol, leveraging Sui's unique object-centric blockchain architecture to provide a more efficient and scalable cross-chain trading infrastructure.

### What is iLayer?

iLayer is a cross-chain intent-based solver hub that enables:
- **Seamless Cross-chain Swaps**: Trade tokens across different blockchains without manual bridging
- **Intent-based Trading**: Express what you want, let solvers figure out how to execute it
- **Gasless Transactions**: Recipients don't need gas tokens on the destination chain
- **Optimal Execution**: Solvers compete to provide the best rates and execution

## ✨ Features

### Core Features
- 🔄 **Cross-chain Token Swaps**: Swap any token across supported chains
- 🎯 **Intent-based Orders**: Define desired outcomes, not execution paths  
- 💎 **Multi-token Support**: Coins, NFTs, and custom Sui objects
- ⛽ **Gas Sponsorship**: Optional gas-free transactions for recipients
- 🤖 **Solver Network**: Decentralized network of solvers for optimal execution
- 🔒 **Non-custodial**: Users maintain control of assets until execution

### Technical Features
- 🚀 **Parallel Execution**: Process multiple orders simultaneously
- 📦 **Object-centric Design**: Orders as first-class Sui objects
- 🔑 **Capability-based Security**: Fine-grained access control
- 🌉 **Modular Bridge Support**: Integrate any cross-chain messaging protocol
- 📊 **On-chain Analytics**: Track solver performance and protocol metrics
- 🧩 **Composable**: Integrate with other Sui protocols seamlessly

## 🏗 Architecture

### Core Modules

| Module | Description |
|--------|-------------|
| `types.move` | Core data structures (Token, Order, OrderRequest) |
| `validator.move` | Ed25519 signature verification and validation |
| `order_hub.move` | Source chain order management and escrow |
| `order_spoke.move` | Destination chain order fulfillment |
| `executor.move` | Safe external call execution framework |
| `cross_chain.move` | Cross-chain messaging abstraction |
| `token_registry.move` | Multi-token and multi-chain support |
| `fee_manager.move` | Protocol fee collection and distribution |
| `solver_registry.move` | Solver registration and performance tracking |
| `utils.move` | Utility functions and helpers |

### Key Design Principles

1. **Object-Centric Model**
   - Orders are Sui objects with unique IDs
   - Direct ownership and transfer capabilities
   - No mapping limitations

2. **Parallel Processing**
   - Independent orders execute simultaneously
   - No global state contention
   - Optimal throughput

3. **Security First**
   - Native Ed25519 signatures
   - Capability-based permissions
   - Built-in reentrancy protection

## 🚀 Getting Started

### Prerequisites

- [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) (latest version)
- [Node.js](https://nodejs.org/) (v16 or higher)
- [Git](https://git-scm.com/)

### Quick Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/SeventhOdyssey71/ilayer-sui.git
   cd ilayer-sui
   ```

2. **Run setup script**
   ```bash
   ./scripts/setup.sh
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Build the project**
   ```bash
   sui move build
   ```

## 💻 Usage

### Creating an Order

```typescript
// Example: Create a cross-chain swap order
const order = {
    user: "0x...",
    recipient: "0x...",
    inputs: [{
        token_type: 2, // COIN
        token_address: "SUI",
        amount: 1000000n // 1 SUI
    }],
    outputs: [{
        token_type: 2, // COIN
        token_address: "USDC",
        amount: 1000n // 1000 USDC
    }],
    source_chain_id: 1,
    destination_chain_id: 2,
    deadline: Date.now() + 7200000 // 2 hours
};

// Sign and submit order
npm run create-order
```

### Filling an Order (Solver)

```typescript
// Solvers monitor events and fill profitable orders
npm run fill-order
```

### Interacting via CLI

```bash
# Deploy contracts
./scripts/deploy.sh

# Create order
cd scripts && npm run create-order

# Fill order
cd scripts && npm run fill-order
```

## 🧪 Testing

### Run All Tests
```bash
sui move test
```

### Run Specific Test Module
```bash
sui move test --filter types_tests
```

### Test Coverage
```bash
sui move test --coverage
```

### Integration Tests
```bash
cd scripts && npm test
```

## 📦 Deployment

### Deploy to Devnet (Default)
```bash
./scripts/deploy.sh
```

### Deploy to Testnet
```bash
NETWORK=testnet ./scripts/deploy.sh
```

### Deploy to Mainnet
```bash
NETWORK=mainnet GAS_BUDGET=200000000 ./scripts/deploy.sh
```

### Post-Deployment

After deployment, update your `.env` file with:
- `PACKAGE_ID`: The deployed package address
- `ORDER_HUB_ID`: OrderHub shared object ID  
- `ORDER_SPOKE_ID`: OrderSpoke shared object ID
- Other module object IDs

## 📚 Documentation

### Core Documentation
- [Architecture Overview](docs/ARCHITECTURE.md) - Detailed system architecture
- [Migration Guide](docs/MIGRATION.md) - Migrating from EVM to Sui
- [API Reference](docs/API.md) - Module function documentation
- [Integration Guide](docs/INTEGRATION.md) - How to integrate with iLayer

### Developer Resources
- [CLAUDE.md](CLAUDE.md) - AI assistant guidance
- [Examples](sources/examples/) - Example integrations
- [Scripts](scripts/) - Deployment and interaction scripts

## 🔒 Security

### Security Features
- ✅ Ed25519 signature verification
- ✅ Capability-based access control
- ✅ Deadline and timing enforcement
- ✅ Reentrancy protection via object model
- ✅ Safe token transfer patterns
- ✅ Solver authorization and staking

### Audits
- [ ] Formal verification (planned)
- [ ] Third-party security audit (planned)

### Bug Bounty
Report security vulnerabilities to: security@ilayer.io

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Move best practices
- Add comprehensive tests
- Update documentation
- Ensure all tests pass

## 📄 License

This project is licensed under the Business Source License 1.1 - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Website**: [ilayer.io](https://ilayer.io)
- **Documentation**: [docs.ilayer.io](https://docs.ilayer.io)
- **Twitter**: [@iLayer_io](https://twitter.com/iLayer_io)
- **Discord**: [Join our community](https://discord.gg/ilayer)

---

<p align="center">
  Built by the 4dummies team, devs on<a href="https://sui.io">Sui</a>
</p>
