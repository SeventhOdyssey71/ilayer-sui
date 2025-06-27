# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Sui Move implementation of iLayer, a cross-chain intent-based solver hub. The project has been completely rewritten from Solidity to leverage Sui's object-centric blockchain architecture.

## Key Commands

### Building and Testing
```bash
# Build all Move modules
sui move build

# Run all tests
sui move test

# Run specific test module
sui move test --filter types_tests

# Check for compilation errors
sui move build --lint
```

### Deployment
```bash
# Deploy to devnet (default)
./scripts/deploy.sh

# Deploy to testnet
NETWORK=testnet ./scripts/deploy.sh

# Deploy to mainnet with custom gas budget
NETWORK=mainnet GAS_BUDGET=200000000 ./scripts/deploy.sh
```

### Development Setup
```bash
# Initial setup (run once)
./scripts/setup.sh

# Install TypeScript dependencies
cd scripts && npm install
```

### Interacting with Contracts
```bash
# Create an order
cd scripts && npm run create-order

# Fill an order
cd scripts && npm run fill-order

# Custom TypeScript execution
cd scripts && npx ts-node your_script.ts
```

## Architecture Overview

### Core Module Structure
1. **types.move** - Base data types (Token, Order, OrderRequest)
2. **validator.move** - Signature verification using Ed25519
3. **order_hub.move** - Source chain order management
4. **order_spoke.move** - Destination chain order fulfillment
5. **cross_chain.move** - Cross-chain messaging framework
6. **executor.move** - Safe external call execution
7. **token_registry.move** - Multi-token support
8. **fee_manager.move** - Protocol fee management
9. **solver_registry.move** - Solver registration and tracking

### Key Design Patterns

1. **Object-Centric**: Orders are Sui objects with unique IDs, not mapping entries
2. **Capability-Based Access**: Use capability objects for ownership and permissions
3. **Shared Objects**: Main contracts (Hub, Spoke, Registries) are shared objects
4. **Dynamic Fields**: Extensible metadata without contract upgrades
5. **Parallel Execution**: Independent orders can be processed simultaneously

### Important Differences from EVM

1. **Addresses**: Sui uses 32-byte addresses (not 20-byte like Ethereum)
2. **No msg.value**: Use Coin<T> objects directly
3. **No Reentrancy**: Sui's model prevents reentrancy by design
4. **Signatures**: Native Ed25519 instead of ECDSA
5. **Storage**: Objects instead of contract storage slots

### Testing Approach

Tests use Sui's test scenario framework:
```move
let mut scenario = test_scenario::begin(ADMIN);
test_scenario::next_tx(&mut scenario, USER);
// ... test logic
test_scenario::end(scenario);
```

### Common Patterns

**Creating objects:**
```move
let obj = MyStruct {
    id: object::new(ctx),
    // ... fields
};
transfer::share_object(obj); // or transfer::transfer(obj, recipient)
```

**Accessing shared objects in tests:**
```move
let mut hub = test_scenario::take_shared<OrderHub>(&scenario);
// ... use hub
test_scenario::return_shared(hub);
```

**Error handling:**
```move
assert!(condition, ERROR_CODE);
```

### Environment Variables

Key environment variables (see .env.example):
- `NETWORK`: Target network (devnet/testnet/mainnet)
- `PACKAGE_ID`: Deployed package address
- `ORDER_HUB_ID`: OrderHub shared object ID
- `ORDER_SPOKE_ID`: OrderSpoke shared object ID
- `PRIVATE_KEY`: Deployer/user private key

### Debugging Tips

1. Use `sui client object <OBJECT_ID>` to inspect objects
2. Add events for important state changes
3. Use `#[test_only]` functions for test helpers
4. Check transaction effects with `sui client tx <DIGEST>`

### Security Considerations

1. Always validate signatures for orders
2. Check deadlines and timing constraints
3. Verify solver authorization
4. Validate cross-chain proofs
5. Implement proper access control with capabilities

## Module Dependencies

```
types <- validator <- order_hub
      <- order_spoke <- executor
      <- cross_chain
      <- token_registry
      <- fee_manager <- order_spoke
      <- solver_registry <- order_spoke
```

## Future Improvements

When extending this codebase:
1. Add new token types to the token registry
2. Implement additional bridge adapters in cross_chain
3. Create new example integrations like simple_swap
4. Add more sophisticated fee models
5. Implement order matching algorithms