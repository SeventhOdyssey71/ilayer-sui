import { SuiClient, SuiTransactionBlockResponse } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { BCS } from '@mysten/bcs';

// Configuration
const NETWORK = process.env.NETWORK || 'devnet';
const PACKAGE_ID = process.env.PACKAGE_ID || '';
const ORDER_HUB_ID = process.env.ORDER_HUB_ID || '';

// Initialize client
const client = new SuiClient({
    url: NETWORK === 'mainnet' 
        ? 'https://fullnode.mainnet.sui.io' 
        : 'https://fullnode.devnet.sui.io'
});

// Types
interface Token {
    token_type: number;
    token_address: string;
    token_id: bigint;
    amount: bigint;
}

interface Order {
    user: string;
    recipient: string;
    filler: string;
    inputs: Token[];
    outputs: Token[];
    source_chain_id: number;
    destination_chain_id: number;
    sponsored: boolean;
    primary_filler_deadline: bigint;
    deadline: bigint;
    call_recipient: string;
    call_data: Uint8Array;
    call_value: bigint;
}

interface OrderRequest {
    deadline: bigint;
    nonce: bigint;
    order: Order;
}

// BCS serialization schema
const tokenSchema = BCS.struct('Token', {
    token_type: BCS.u8(),
    token_address: BCS.vector(BCS.u8()),
    token_id: BCS.u64(),
    amount: BCS.u64(),
});

const orderSchema = BCS.struct('Order', {
    user: BCS.address(),
    recipient: BCS.address(),
    filler: BCS.address(),
    inputs: BCS.vector(tokenSchema),
    outputs: BCS.vector(tokenSchema),
    source_chain_id: BCS.u32(),
    destination_chain_id: BCS.u32(),
    sponsored: BCS.bool(),
    primary_filler_deadline: BCS.u64(),
    deadline: BCS.u64(),
    call_recipient: BCS.address(),
    call_data: BCS.vector(BCS.u8()),
    call_value: BCS.u64(),
});

const orderRequestSchema = BCS.struct('OrderRequest', {
    deadline: BCS.u64(),
    nonce: BCS.u64(),
    order: orderSchema,
});

async function createOrder(
    keypair: Ed25519Keypair,
    orderRequest: OrderRequest,
    paymentCoinId: string
) {
    const tx = new TransactionBlock();
    
    // Serialize order request
    const serializedRequest = orderRequestSchema.serialize(orderRequest).toBytes();
    
    // Create signature
    const signature = await keypair.signData(serializedRequest);
    const publicKey = keypair.getPublicKey().toBytes();
    
    // Get clock object
    const clockId = '0x6'; // System clock object
    
    // Call create_order function
    tx.moveCall({
        target: `${PACKAGE_ID}::order_hub::create_order`,
        typeArguments: ['0x2::sui::SUI'], // Assuming SUI payment
        arguments: [
            tx.object(ORDER_HUB_ID), // OrderHub object
            tx.pure(serializedRequest), // OrderRequest
            tx.pure(signature), // Signature
            tx.pure(publicKey), // Public key
            tx.object(paymentCoinId), // Payment coin
            tx.object(clockId), // Clock
        ],
    });
    
    // Execute transaction
    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx,
    });
    
    return result;
}

// Example usage
async function main() {
    // Check required environment variables
    if (!PACKAGE_ID || !ORDER_HUB_ID) {
        console.error('Please set PACKAGE_ID and ORDER_HUB_ID environment variables');
        process.exit(1);
    }
    
    // Create keypair from private key or generate new one
    const privateKey = process.env.PRIVATE_KEY;
    const keypair = privateKey 
        ? Ed25519Keypair.fromSecretKey(Buffer.from(privateKey, 'hex'))
        : new Ed25519Keypair();
    
    const address = keypair.getPublicKey().toSuiAddress();
    console.log('Using address:', address);
    
    // Get user's coins
    const coins = await client.getCoins({
        owner: address,
        coinType: '0x2::sui::SUI',
    });
    
    if (coins.data.length === 0) {
        console.error('No SUI coins found in wallet');
        process.exit(1);
    }
    
    // Create example order
    const now = Date.now();
    const order: Order = {
        user: address,
        recipient: process.env.RECIPIENT || address,
        filler: process.env.FILLER || '0x0000000000000000000000000000000000000000000000000000000000000000',
        inputs: [{
            token_type: 2, // COIN type
            token_address: Array.from(Buffer.from('SUI', 'utf8')),
            token_id: 0n,
            amount: 1000000n, // 0.001 SUI
        }],
        outputs: [{
            token_type: 2, // COIN type
            token_address: Array.from(Buffer.from('USDC', 'utf8')),
            token_id: 0n,
            amount: 1000n,
        }],
        source_chain_id: 1,
        destination_chain_id: 2,
        sponsored: false,
        primary_filler_deadline: BigInt(now + 3600000), // 1 hour
        deadline: BigInt(now + 7200000), // 2 hours
        call_recipient: '0x0000000000000000000000000000000000000000000000000000000000000000',
        call_data: new Uint8Array(),
        call_value: 0n,
    };
    
    const orderRequest: OrderRequest = {
        deadline: BigInt(now + 300000), // 5 minutes
        nonce: BigInt(Date.now()), // Simple nonce
        order,
    };
    
    console.log('Creating order...');
    
    try {
        const result = await createOrder(
            keypair,
            orderRequest,
            coins.data[0].coinObjectId
        );
        
        console.log('Transaction successful!');
        console.log('Transaction digest:', result.digest);
        console.log('Effects:', result.effects);
        
        // Extract OrderCapability from created objects
        const createdObjects = result.effects?.created || [];
        const orderCap = createdObjects.find(obj => 
            obj.owner && 'AddressOwner' in obj.owner
        );
        
        if (orderCap) {
            console.log('Order Capability ID:', orderCap.reference.objectId);
        }
    } catch (error) {
        console.error('Error creating order:', error);
    }
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}