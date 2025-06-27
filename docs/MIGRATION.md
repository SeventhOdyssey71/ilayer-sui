# Migration Guide: EVM to Sui

This guide helps developers understand the key changes when migrating from the EVM implementation to Sui.

## Core Concept Mappings

### Storage Model

**EVM:**
```solidity
mapping(bytes32 => Status) public orders;
mapping(address => mapping(uint64 => bool)) public requestNonces;
```

**Sui:**
```move
public struct OrderHub has key {
    orders: Table<ID, OrderInfo>,
    request_nonces: Table<address, Table<u64, bool>>,
}
```

### Token Representation

**EVM:**
```solidity
struct Token {
    Type tokenType;
    bytes32 tokenAddress;
    uint256 tokenId;
    uint256 amount;
}
```

**Sui:**
```move
public struct Token has store, drop, copy {
    token_type: u8,
    token_address: vector<u8>,
    token_id: u64,
    amount: u64,
}
```

### Order Creation

**EVM:**
```solidity
function createOrder(
    OrderRequest memory request,
    bytes[] memory permits,
    bytes memory signature,
    bytes calldata options
) external payable
```

**Sui:**
```move
public fun create_order<T>(
    hub: &mut OrderHub,
    request: OrderRequest,
    signature: vector<u8>,
    public_key: vector<u8>,
    payment: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext
): OrderCapability
```

## Key Differences

### 1. Object Ownership

**EVM:** Orders tracked by mapping, no direct ownership
**Sui:** Orders are objects with capabilities for ownership

### 2. Gas Payment

**EVM:** `msg.value` for native token, separate approval for ERC20
**Sui:** Direct `Coin<T>` object transfer

### 3. Signature Verification

**EVM:** EIP-712 structured data signing
**Sui:** Native Ed25519 signatures with BCS serialization

### 4. Cross-Chain Messaging

**EVM:** LayerZero OApp integration
**Sui:** Modular bridge adapter pattern

### 5. Access Control

**EVM:** `onlyOwner` modifiers, role-based access
**Sui:** Capability objects, witness patterns

## Code Migration Examples

### Creating an Order

**EVM JavaScript:**
```javascript
const order = {
    user: userAddress,
    recipient: recipientAddress,
    inputs: [{
        tokenType: 2, // ERC20
        tokenAddress: tokenAddr,
        tokenId: 0,
        amount: ethers.parseEther("1.0")
    }],
    // ... other fields
};

const signature = await signer.signTypedData(domain, types, order);
await orderHub.createOrder(orderRequest, permits, signature, options);
```

**Sui TypeScript:**
```typescript
const order: Order = {
    user: userAddress,
    recipient: recipientAddress,
    inputs: [{
        token_type: 2, // COIN
        token_address: Array.from(Buffer.from('SUI', 'utf8')),
        token_id: 0n,
        amount: 1000000n
    }],
    // ... other fields
};

const serialized = orderSchema.serialize(order).toBytes();
const signature = await keypair.signData(serialized);

tx.moveCall({
    target: `${PACKAGE_ID}::order_hub::create_order`,
    arguments: [
        tx.object(ORDER_HUB_ID),
        tx.pure(serialized),
        tx.pure(signature),
        tx.pure(publicKey),
        tx.object(coinId),
        tx.object(clockId)
    ]
});
```

### Handling Tokens

**EVM:**
```solidity
IERC20(token).safeTransferFrom(user, address(this), amount);
```

**Sui:**
```move
let balance = coin::into_balance(payment);
// Balance is now held by the module
```

### Events

**EVM:**
```solidity
emit OrderCreated(orderId, nonce, order, msg.sender);
```

**Sui:**
```move
event::emit(OrderCreated {
    order_id,
    nonce,
    order,
    creator: tx_context::sender(ctx),
});
```

## Testing Migration

### EVM Foundry Tests
```solidity
function test_createOrder() public {
    vm.prank(user);
    orderHub.createOrder(request, permits, signature, options);
}
```

### Sui Move Tests
```move
#[test]
fun test_create_order() {
    let mut scenario = test_scenario::begin(USER);
    // ... test implementation
}
```

## Deployment Differences

### EVM Deployment
```bash
forge script Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

### Sui Deployment
```bash
sui client publish --gas-budget 100000000
```

## Common Pitfalls

1. **Address Format**: Sui uses 32-byte addresses (0x prefixed), not 20-byte like Ethereum
2. **No Reentrancy**: Sui's object model prevents reentrancy by design
3. **No Global Variables**: No `msg.sender`, use `tx_context::sender(ctx)`
4. **Object Lifecycle**: Objects must be explicitly transferred or shared
5. **Type Parameters**: Generic types must be specified at call time

## Best Practices for Sui

1. Use capability objects for access control
2. Leverage parallel execution with independent objects
3. Minimize shared object contention
4. Use witness patterns for type safety
5. Implement proper object cleanup to avoid storage bloat

## Resources

- [Sui Documentation](https://docs.sui.io)
- [Move Language Book](https://move-book.com)
- [Sui Patterns](https://docs.sui.io/guides/developer/app-examples)