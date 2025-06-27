# iLayer on Sui - Architecture Overview

## Introduction

iLayer on Sui is a complete reimplementation of the iLayer protocol, leveraging Sui's unique blockchain architecture to provide a more efficient and scalable cross-chain trading infrastructure.

## Key Architectural Differences from EVM

### 1. Object-Centric Design

**EVM Implementation:**
- Orders stored in contract mappings
- State changes require contract storage updates
- Sequential processing limitations

**Sui Implementation:**
- Orders are first-class objects with unique IDs
- Parallel execution of independent orders
- Direct ownership and transfer capabilities

### 2. Native Capabilities

**EVM Implementation:**
- Custom signature verification (EIP-712)
- Manual access control implementation
- Gas sponsorship through meta-transactions

**Sui Implementation:**
- Native Ed25519 signature support
- Capability-based access control
- Built-in gas sponsorship mechanisms

### 3. Asset Handling

**EVM Implementation:**
- Separate interfaces for different token standards (ERC20, ERC721, ERC1155)
- Complex approval patterns
- Manual balance tracking

**Sui Implementation:**
- Unified object model for all assets
- Direct object transfers
- Native balance tracking through Sui's object system

## Module Architecture

### Core Modules

#### 1. `types.move`
- Defines core data structures (Token, Order, OrderRequest)
- Provides type constants and error codes
- Implements getter functions for struct fields

#### 2. `validator.move`
- Handles signature verification
- Implements domain separation for security
- Provides order and request validation

#### 3. `order_hub.move`
- Manages order creation on source chain
- Handles token deposits and escrow
- Implements order lifecycle (active, filled, withdrawn)
- Integrates with cross-chain messaging

#### 4. `order_spoke.move`
- Manages order fulfillment on destination chain
- Handles solver registration and management
- Implements fee collection and distribution
- Executes arbitrary calls via Executor

#### 5. `executor.move`
- Provides safe external call execution
- Implements capability-based authorization
- Supports batch operations

#### 6. `cross_chain.move`
- Manages cross-chain message passing
- Handles chain configuration
- Implements message verification and replay protection

#### 7. `token_registry.move`
- Maintains supported token mappings
- Handles multi-chain token addresses
- Provides token metadata storage

## Data Flow

### Order Creation Flow

1. **User Signs Order**
   - User creates OrderRequest with order details
   - Signs using Ed25519 keypair
   - Includes deadline and nonce for security

2. **Submit to OrderHub**
   - Validates signature and order parameters
   - Deposits input tokens into escrow
   - Creates OrderCapability for user
   - Emits OrderCreated event

3. **Cross-Chain Message**
   - OrderHub sends message via cross_chain module
   - Message includes order details and proof
   - Destination chain receives and validates

### Order Fulfillment Flow

1. **Solver Identifies Opportunity**
   - Monitors OrderCreated events
   - Evaluates profitability
   - Prepares output tokens

2. **Fill Order on Spoke**
   - Solver calls fill_order with outputs
   - Validates solver authorization
   - Transfers outputs to recipient
   - Collects protocol fees

3. **Settlement Confirmation**
   - Fill confirmation sent back to source chain
   - OrderHub updates order status
   - Releases solver's claim on inputs

## Security Model

### 1. Signature Verification
- All orders require valid Ed25519 signatures
- Domain separation prevents cross-protocol attacks
- Nonce system prevents replay attacks

### 2. Access Control
- Capability objects for order ownership
- Admin functions protected by ownership checks
- Solver registry for authorized fillers

### 3. Timing Controls
- Primary filler exclusivity period
- Order expiration enforcement
- Withdrawal time buffer

### 4. Asset Security
- Direct object ownership model
- No approval vulnerabilities
- Atomic transfers

## Scalability Features

### 1. Parallel Execution
- Independent orders process simultaneously
- No global state contention
- Efficient resource utilization

### 2. Object Storage
- Orders stored as individual objects
- Efficient indexing and retrieval
- Automatic garbage collection

### 3. Dynamic Fields
- Extensible order metadata
- Future-proof design
- No contract upgrades needed

## Integration Points

### 1. Bridge Protocols
- Modular cross-chain messaging
- Support for multiple bridges
- Proof verification framework

### 2. DEX Integration
- Executor module for external calls
- Programmable transaction support
- Composable with other protocols

### 3. Solver Infrastructure
- Standardized interfaces
- Performance tracking
- Fee optimization

## Future Enhancements

### 1. Advanced Features
- Multi-hop order routing
- Conditional order execution
- Batch order processing

### 2. Optimization
- Gas optimization strategies
- Order matching algorithms
- Liquidity aggregation

### 3. Ecosystem Integration
- Native Sui DeFi protocols
- Cross-chain liquidity pools
- Advanced order types