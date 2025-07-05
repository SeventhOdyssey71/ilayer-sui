import { SuiClient } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { BCS } from '@mysten/bcs';

// Configuration
const NETWORK = process.env.NETWORK || 'devnet';
const PACKAGE_ID = process.env.PACKAGE_ID || '';
const ORDER_SPOKE_ID = process.env.ORDER_SPOKE_ID || '';

// Initialize client
const client = new SuiClient({
    url: NETWORK === 'mainnet' 
        ? 'https://fullnode.mainnet.sui.io' 
        : 'https://fullnode.devnet.sui.io'
});

// Reuse types from create_order.ts
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

async function fillOrder(
    keypair: Ed25519Keypair,
    order: Order,
    orderId: string,
    proof: Uint8Array,
    outputCoinIds: string[]
) {
    const tx = new TransactionBlock();
    
    // Get clock object
    const clockId = '0x6'; // System clock object
    
    // Prepare output coins array
    const outputCoins = outputCoinIds.map(id => tx.object(id));
    
    // Call fill_order function
    tx.moveCall({
        target: `${PACKAGE_ID}::order_spoke::fill_order`,
        typeArguments: ['0x2::sui::SUI'], // Assuming SUI outputs
        arguments: [
            tx.object(ORDER_SPOKE_ID), // OrderSpoke object
            tx.pure(BCS.ser('Order', order).toBytes()), // Order
            tx.pure(Array.from(Buffer.from(orderId, 'utf8'))), // Order ID
            tx.pure(Array.from(proof)), // Proof
            tx.makeMoveVec({ objects: outputCoins }), // Output coins
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

async function main() {
    // Check required environment variables
    if (!PACKAGE_ID || !ORDER_SPOKE_ID) {
        console.error('Please set PACKAGE_ID and ORDER_SPOKE_ID environment variables');
        process.exit(1);
    }
    
    // Create keypair (solver's keypair)
    const privateKey = process.env.SOLVER_PRIVATE_KEY;
    if (!privateKey) {
        console.error('Please set SOLVER_PRIVATE_KEY environment variable');
        process.exit(1);
    }
    
    const keypair = Ed25519Keypair.fromSecretKey(Buffer.from(privateKey, 'hex'));
    const address = keypair.getPublicKey().toSuiAddress();
    console.log('Solver address:', address);
    
    // Get order details from environment or arguments
    const orderId = process.env.ORDER_ID || 'test-order-123';
    
    // Example order (in production, this would be fetched from the source chain)
    const order: Order = {
        user: process.env.ORDER_USER || '0x1',
        recipient: process.env.ORDER_RECIPIENT || '0x2',
        filler: address, // Solver is the filler
        inputs: [{
            token_type: 2, // COIN type
            token_address: Array.from(Buffer.from('SUI', 'utf8')),
            token_id: 0n,
            amount: 1000000n,
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
        primary_filler_deadline: BigInt(Date.now() + 3600000),
        deadline: BigInt(Date.now() + 7200000),
        call_recipient: '0x0000000000000000000000000000000000000000000000000000000000000000',
        call_data: new Uint8Array(),
        call_value: 0n,
    };
    
    // Get solver's output coins
    const coins = await client.getCoins({
        owner: address,
        coinType: '0x2::sui::SUI',
    });
    
    if (coins.data.length === 0) {
        console.error('No SUI coins found in solver wallet');
        process.exit(1);
    }
    
    // Select coins for output
    const outputCoinIds = coins.data
        .slice(0, order.outputs.length)
        .map(coin => coin.coinObjectId);
    
    // Create mock proof (in production, this would be from the bridge)
    const proof = new Uint8Array(64).fill(0);
    
    console.log('Filling order...');
    console.log('Order ID:', orderId);
    console.log('Output coins:', outputCoinIds);
    
    try {
        const result = await fillOrder(
            keypair,
            order,
            orderId,
            proof,
            outputCoinIds
        );
        
        console.log('Transaction successful!');
        console.log('Transaction digest:', result.digest);
        console.log('Effects:', result.effects);
        
        // Extract FillReceipt from created objects
        const createdObjects = result.effects?.created || [];
        const fillReceipt = createdObjects.find(obj => 
            obj.owner && 'AddressOwner' in obj.owner
        );
        
        if (fillReceipt) {
            console.log('Fill Receipt ID:', fillReceipt.reference.objectId);
        }
    } catch (error) {
        console.error('Error filling order:', error);
    }
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}