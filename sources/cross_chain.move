module ilayer::cross_chain {
    use sui::object;
    use sui::table::{Self, Table};
    use sui::event;
    use sui::bcs;
    use sui::hash;

    use ilayer::types::{Order};

    // ======== Constants ========
    
    const MESSAGE_TYPE_ORDER: u8 = 1;
    const MESSAGE_TYPE_FILL: u8 = 2;
    const MESSAGE_TYPE_SETTLE: u8 = 3;

    // ======== Error Codes ========
    
    const ENotAuthorized: u64 = 7001;
    // const EInvalidChainId: u64 = 7002; // Unused
    const EInvalidMessageType: u64 = 7003;
    const EMessageAlreadyProcessed: u64 = 7004;
    const EInvalidProof: u64 = 7005;
    const EChainNotSupported: u64 = 7006;

    // ======== Structs ========
    
    public struct CrossChainManager has key {
        id: UID,
        owner: address,
        // Supported chains
        supported_chains: Table<u32, ChainInfo>,
        // Processed messages to prevent replay
        processed_messages: Table<vector<u8>, bool>,
        // Pending outbound messages
        outbound_queue: vector<OutboundMessage>,
        // Message nonce per chain
        chain_nonces: Table<u32, u64>,
    }

    public struct ChainInfo has store {
        active: bool,
        endpoint: vector<u8>, // Bridge contract address on that chain
        min_confirmations: u64,
    }

    public struct OutboundMessage has store, drop {
        destination_chain: u32,
        message_type: u8,
        payload: vector<u8>,
        nonce: u64,
    }

    public struct InboundMessage has drop {
        source_chain: u32,
        message_type: u8,
        payload: vector<u8>,
        proof: vector<u8>,
    }

    public struct MessageCap has key, store {
        id: UID,
        manager_id: ID,
        destination_chain: u32,
    }

    // ======== Events ========
    
    public struct MessageSent has copy, drop {
        destination_chain: u32,
        message_type: u8,
        nonce: u64,
        payload_hash: vector<u8>,
    }

    public struct MessageReceived has copy, drop {
        source_chain: u32,
        message_type: u8,
        payload_hash: vector<u8>,
    }

    public struct ChainAdded has copy, drop {
        chain_id: u32,
        endpoint: vector<u8>,
    }

    // ======== Initialization ========
    
    fun init(ctx: &mut TxContext) {
        let manager = CrossChainManager {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            supported_chains: table::new(ctx),
            processed_messages: table::new(ctx),
            outbound_queue: vector::empty(),
            chain_nonces: table::new(ctx),
        };
        
        transfer::share_object(manager);
    }

    // ======== Admin Functions ========
    
    public fun add_supported_chain(
        manager: &mut CrossChainManager,
        chain_id: u32,
        endpoint: vector<u8>,
        min_confirmations: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == manager.owner, ENotAuthorized);
        
        let chain_info = ChainInfo {
            active: true,
            endpoint,
            min_confirmations,
        };
        
        table::add(&mut manager.supported_chains, chain_id, chain_info);
        table::add(&mut manager.chain_nonces, chain_id, 0);
        
        event::emit(ChainAdded { chain_id, endpoint });
    }

    public fun update_chain_endpoint(
        manager: &mut CrossChainManager,
        chain_id: u32,
        new_endpoint: vector<u8>,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == manager.owner, ENotAuthorized);
        assert!(table::contains(&manager.supported_chains, chain_id), EChainNotSupported);
        
        let chain_info = table::borrow_mut(&mut manager.supported_chains, chain_id);
        chain_info.endpoint = new_endpoint;
    }

    public fun toggle_chain(
        manager: &mut CrossChainManager,
        chain_id: u32,
        active: bool,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == manager.owner, ENotAuthorized);
        assert!(table::contains(&manager.supported_chains, chain_id), EChainNotSupported);
        
        let chain_info = table::borrow_mut(&mut manager.supported_chains, chain_id);
        chain_info.active = active;
    }

    // ======== Message Sending ========
    
    public fun send_order_message(
        manager: &mut CrossChainManager,
        destination_chain: u32,
        order: &Order,
        ctx: &mut TxContext
    ): MessageCap {
        validate_chain(manager, destination_chain);
        
        let payload = bcs::to_bytes(order);
        let nonce = get_and_increment_nonce(manager, destination_chain);
        
        let message = OutboundMessage {
            destination_chain,
            message_type: MESSAGE_TYPE_ORDER,
            payload,
            nonce,
        };
        
        vector::push_back(&mut manager.outbound_queue, message);
        
        event::emit(MessageSent {
            destination_chain,
            message_type: MESSAGE_TYPE_ORDER,
            nonce,
            payload_hash: hash::keccak256(&payload),
        });
        
        MessageCap {
            id: object::new(ctx),
            manager_id: object::uid_to_inner(&manager.id),
            destination_chain,
        }
    }

    public fun send_fill_message(
        manager: &mut CrossChainManager,
        destination_chain: u32,
        order_id: vector<u8>,
        filler: address,
        ctx: &mut TxContext
    ): MessageCap {
        validate_chain(manager, destination_chain);
        
        let mut payload = order_id;
        vector::append(&mut payload, bcs::to_bytes(&filler));
        
        let nonce = get_and_increment_nonce(manager, destination_chain);
        
        let message = OutboundMessage {
            destination_chain,
            message_type: MESSAGE_TYPE_FILL,
            payload,
            nonce,
        };
        
        vector::push_back(&mut manager.outbound_queue, message);
        
        event::emit(MessageSent {
            destination_chain,
            message_type: MESSAGE_TYPE_FILL,
            nonce,
            payload_hash: hash::keccak256(&payload),
        });
        
        MessageCap {
            id: object::new(ctx),
            manager_id: object::uid_to_inner(&manager.id),
            destination_chain,
        }
    }

    // ======== Message Receiving ========
    
    public fun process_inbound_message(
        manager: &mut CrossChainManager,
        message: InboundMessage,
        _ctx: &TxContext
    ): vector<u8> {
        let InboundMessage { source_chain, message_type, payload, proof: _proof } = message;
        
        // Validate source chain
        validate_chain(manager, source_chain);
        
        // Validate message type
        assert!(
            message_type == MESSAGE_TYPE_ORDER || 
            message_type == MESSAGE_TYPE_FILL ||
            message_type == MESSAGE_TYPE_SETTLE,
            EInvalidMessageType
        );
        
        // Create message hash
        let message_hash = create_message_hash(source_chain, message_type, &payload);
        
        // Check not already processed
        assert!(
            !table::contains(&manager.processed_messages, message_hash),
            EMessageAlreadyProcessed
        );
        
        // Verify proof against bridge protocol
        assert!(
            verify_bridge_proof(&proof, message_hash, source_chain),
            EInvalidProof
        );
        
        // Mark as processed
        table::add(&mut manager.processed_messages, message_hash, true);
        
        event::emit(MessageReceived {
            source_chain,
            message_type,
            payload_hash: hash::keccak256(&payload),
        });
        
        payload
    }

    // ======== Internal Functions ========
    
    fun verify_bridge_proof(
        proof: &vector<u8>,
        message_hash: vector<u8>,
        source_chain: u32
    ): bool {
        // Verify proof structure
        if (vector::length(proof) < 100) {
            return false
        };

        // Check proof version
        let proof_version = *vector::borrow(proof, 0);
        if (proof_version != 1) {
            return false
        };

        // In production, this would:
        // 1. Parse VAA (Verifiable Action Approval) structure
        // 2. Verify guardian signatures
        // 3. Check emitter chain matches source_chain
        // 4. Verify payload hash matches message_hash
        
        // For MVP, verify basic structure and message hash presence
        let hash_found = false;
        let i = 0;
        let proof_len = vector::length(proof);
        let hash_len = vector::length(&message_hash);
        
        // Search for message hash in proof
        while (i + hash_len <= proof_len) {
            let j = 0;
            let match = true;
            while (j < hash_len) {
                if (*vector::borrow(proof, i + j) != *vector::borrow(&message_hash, j)) {
                    match = false;
                    break
                };
                j = j + 1;
            };
            if (match) {
                hash_found = true;
                break
            };
            i = i + 1;
        };

        hash_found
    }
    
    fun validate_chain(manager: &CrossChainManager, chain_id: u32) {
        assert!(table::contains(&manager.supported_chains, chain_id), EChainNotSupported);
        
        let chain_info = table::borrow(&manager.supported_chains, chain_id);
        assert!(chain_info.active, EChainNotSupported);
    }

    fun get_and_increment_nonce(
        manager: &mut CrossChainManager,
        chain_id: u32
    ): u64 {
        let nonce_ref = table::borrow_mut(&mut manager.chain_nonces, chain_id);
        let nonce = *nonce_ref;
        *nonce_ref = nonce + 1;
        nonce
    }

    fun create_message_hash(
        source_chain: u32,
        message_type: u8,
        payload: &vector<u8>
    ): vector<u8> {
        let mut data = bcs::to_bytes(&source_chain);
        vector::push_back(&mut data, message_type);
        vector::append(&mut data, *payload);
        hash::keccak256(&data)
    }

    // ======== View Functions ========
    
    public fun is_chain_supported(
        manager: &CrossChainManager,
        chain_id: u32
    ): bool {
        if (table::contains(&manager.supported_chains, chain_id)) {
            let chain_info = table::borrow(&manager.supported_chains, chain_id);
            chain_info.active
        } else {
            false
        }
    }

    public fun get_chain_info(
        manager: &CrossChainManager,
        chain_id: u32
    ): &ChainInfo {
        table::borrow(&manager.supported_chains, chain_id)
    }

    public fun get_pending_messages(
        manager: &CrossChainManager
    ): &vector<OutboundMessage> {
        &manager.outbound_queue
    }

    public fun is_message_processed(
        manager: &CrossChainManager,
        message_hash: vector<u8>
    ): bool {
        table::contains(&manager.processed_messages, message_hash)
    }
}