# iLayer Sui Deployment Guide

## Deployment Summary

The iLayer Sui contracts have been successfully deployed to Sui testnet. This document contains all the necessary information for interacting with the deployed contracts.

## Deployed Contract Addresses

### Package ID
- **Package**: `0x73ea741025291eecc52c9efca3f63611bb8b0d4744f69a5865e5c15b0359ea74`

### Core Contracts (Shared Objects)

1. **OrderHub**: `0xe8e66ff8077ad0776ed577e08cda9587b9a3d3928fad38a4020f95dc7ea35cd6`
   - Manages order creation on source chains
   - Handles order validation and fee collection

2. **OrderSpoke**: `0x268b3e8fb9e63a09d5d8ed9f652a8c7f4b479b29b5819c99fb9b3dc05a32c75e`
   - Manages order fulfillment on destination chains
   - Handles solver registration and order execution

3. **SolverRegistry**: `0x5795653f81352e26fcd213653221b1fc8b0ab141c0b54b5631ba0469cf3c5ca8`
   - Tracks registered solvers
   - Manages solver capabilities and statistics

4. **TokenRegistry**: `0x1acced0cbffcd83b96cb87c5a27a088e982c1b0c2a82a87819a8b4f088f1e4ef`
   - Manages supported tokens across chains
   - Stores token metadata and addresses

5. **FeeManager**: `0xcf199d03e35a5fa8d5f5fb598c8b0d9cd4ca0084d5acb48b0e43b680f1e1e5a4`
   - Handles fee calculation and distribution
   - Manages protocol and solver fees

6. **CrossChainManager**: `0xe7e0c6c0a7509cc2c98ef1eae37a0ff2429ae65c4c8a121b91541d7386e581c9`
   - Manages cross-chain messaging
   - Handles chain configurations

7. **SimpleSwap**: `0x3a93fb750cfbf1cd319a32402f58f87be5a6367a721b49710aa06afc63dcc631`
   - Example DEX integration
   - Demonstrates order execution

### Admin Objects

- **UpgradeCap**: `0xba5eef4c91ccbf13f47602c9e897902e588d41e13e76e5ec0dfef670e301232f`
  - Owner: `0x33a514d95ba2f0a4cd334d00a7d82120af22ce51cf53f4b3d41026733fb48eeb`

## Deployment Transaction

- **Transaction Digest**: `BvWgC5VcTzZJm6qD7zcSiNiFJcdcdrBgW9YRVJXqYQvD`
- **Checkpoint**: `212503111`
- **Timestamp**: `1751018672879` (Unix ms)
- **Gas Cost**: `210287880` MIST

## Interacting with the Contracts

### Prerequisites

1. Install Sui CLI
2. Configure your wallet
3. Ensure you have SUI tokens for gas

### Basic Operations

#### 1. Register as a Solver

```bash
sui client call \
    --package 0x73ea741025291eecc52c9efca3f63611bb8b0d4744f69a5865e5c15b0359ea74 \
    --module solver_registry \
    --function register_solver \
    --args 0x5795653f81352e26fcd213653221b1fc8b0ab141c0b54b5631ba0469cf3c5ca8 \
    --gas-budget 10000000
```

#### 2. Create an Order

```bash
sui client call \
    --package 0x73ea741025291eecc52c9efca3f63611bb8b0d4744f69a5865e5c15b0359ea74 \
    --module order_hub \
    --function create_order \
    --args [ORDER_HUB_ID] [ORDER_REQUEST] [SIGNATURE] [PUBLIC_KEY] [PAYMENT_COIN] [CLOCK] \
    --gas-budget 50000000
```

#### 3. Fill an Order

```bash
sui client call \
    --package 0x73ea741025291eecc52c9efca3f63611bb8b0d4744f69a5865e5c15b0359ea74 \
    --module order_spoke \
    --function fill_order \
    --args [ORDER_SPOKE_ID] [ORDER] [ORDER_ID] [PROOF] [OUTPUTS] [CLOCK] \
    --gas-budget 50000000
```

### Using the Interaction Script

A helper script is provided at `scripts/interact.sh`:

```bash
cd scripts
./interact.sh
```

This provides a menu-driven interface for common operations.

## Configuration Files

### Environment Variables (.env)

All deployment addresses and configuration values are stored in `.env`:

```bash
source .env
echo $PACKAGE_ID  # Package ID
echo $ORDER_HUB_ID  # OrderHub address
# ... etc
```

### Network Configuration

- **Network**: Sui Testnet
- **RPC URL**: https://sui-testnet.nodeinfra.com
- **WebSocket**: wss://sui-testnet.nodeinfra.com/websocket

## Module List

The following modules are included in the package:

1. `types` - Core data structures
2. `order_hub` - Source chain order management
3. `order_spoke` - Destination chain order fulfillment
4. `validator` - Signature validation
5. `executor` - Safe external call execution
6. `fee_manager` - Fee management
7. `solver_registry` - Solver registration
8. `token_registry` - Token management
9. `cross_chain` - Cross-chain messaging
10. `utils` - Utility functions
11. `simple_swap` - Example DEX integration

## Fee Structure

- **Default Protocol Fee**: 0.3% (30 basis points)
- **Default Solver Fee**: 0.2% (20 basis points)
- **Default Order Fee**: 0.3% (30 basis points)

## Security Considerations

1. All admin functions are restricted to the contract owner
2. Solvers must be registered before filling orders
3. Orders are validated using Ed25519 signatures
4. Cross-chain proofs are required for order fulfillment

## Next Steps

1. Register tokens in the TokenRegistry
2. Register solvers in the SolverRegistry
3. Configure cross-chain connections
4. Set up monitoring for events
5. Implement custom solver strategies

## Support

For questions or issues:
- Check the documentation in `/docs`
- Review test files in `/tests`
- Examine example implementations in `/sources/examples`