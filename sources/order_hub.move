module ilayer::order_hub {
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::dynamic_field;
    use sui::table::{Self, Table};
    use sui::sui::SUI;
    
    use ilayer::types::{
        Self, Order, OrderRequest, Token,
        order_user, order_recipient, order_inputs, order_deadline,
        order_primary_filler_deadline, order_sponsored,
        token_type_coin, status_active, status_filled, status_withdrawn
    };
    use ilayer::validator::{Self, DomainSeparator};

    // ======== Constants ========
    
    const CURRENT_VERSION: u64 = 1;
    const DEFAULT_MAX_ORDER_DEADLINE: u64 = 2592000000; // 30 days in ms
    const DEFAULT_TIME_BUFFER: u64 = 300000; // 5 minutes in ms

    // ======== Error Codes ========
    
    const ENotOwner: u64 = 3001;
    const EInvalidDeadline: u64 = 3002;
    const EOrderExpired: u64 = 3003;
    const EOrderNotActive: u64 = 3004;
    const EOrderCannotBeWithdrawn: u64 = 3005;
    const EOrderCannotBeFilled: u64 = 3006;
    const ERequestNonceReused: u64 = 3007;
    const ERequestExpired: u64 = 3008;
    const EInvalidOrderSignature: u64 = 3009;
    const EInvalidSourceChain: u64 = 3010;
    const EPrimaryFillerExpired: u64 = 3011;
    const EInsufficientFunds: u64 = 3012;

    // ======== Structs ========
    
    public struct OrderHub has key {
        id: UID,
        version: u64,
        owner: address,
        max_order_deadline: u64,
        time_buffer: u64,
        nonce: u64,
        orders: Table<ID, OrderInfo>,
        request_nonces: Table<address, Table<u64, bool>>,
        domain_separator: DomainSeparator,
        // Token balances stored by order ID and token type
        // Note: In production, we'd need a more sophisticated approach
        // to handle multiple token types
        balances: Table<ID, Balance<SUI>>,
    }

    public struct OrderInfo has store {
        order: Order,
        status: u8,
        nonce: u64,
        created_at: u64,
        creator: address,
    }

    public struct TokenBalance<phantom T> has store {
        token_type: vector<u8>,
        balance: Balance<T>,
    }

    public struct OrderCapability has key, store {
        id: UID,
        order_id: ID,
        hub_id: ID,
    }

    // ======== Events ========
    
    public struct OrderCreated has copy, drop {
        order_id: ID,
        nonce: u64,
        order: Order,
        creator: address,
    }

    public struct OrderWithdrawn has copy, drop {
        order_id: ID,
        caller: address,
    }

    public struct OrderSettled has copy, drop {
        order_id: ID,
        order: Order,
    }

    public struct TimeBufferUpdated has copy, drop {
        old_value: u64,
        new_value: u64,
    }

    public struct MaxOrderDeadlineUpdated has copy, drop {
        old_value: u64,
        new_value: u64,
    }

    // ======== Initialization ========
    
    fun init(ctx: &mut TxContext) {
        let hub = OrderHub {
            id: object::new(ctx),
            version: CURRENT_VERSION,
            owner: tx_context::sender(ctx),
            max_order_deadline: DEFAULT_MAX_ORDER_DEADLINE,
            time_buffer: DEFAULT_TIME_BUFFER,
            nonce: 0,
            orders: table::new(ctx),
            request_nonces: table::new(ctx),
            domain_separator: validator::new_domain_separator(
                1, // Sui chain ID
                @ilayer
            ),
            balances: table::new(ctx),
        };
        
        transfer::share_object(hub);
    }

    // ======== Admin Functions ========
    
    public fun set_time_buffer(
        hub: &mut OrderHub,
        new_time_buffer: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == hub.owner, ENotOwner);
        
        event::emit(TimeBufferUpdated {
            old_value: hub.time_buffer,
            new_value: new_time_buffer,
        });
        
        hub.time_buffer = new_time_buffer;
    }

    public fun set_max_order_deadline(
        hub: &mut OrderHub,
        new_max_deadline: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == hub.owner, ENotOwner);
        
        event::emit(MaxOrderDeadlineUpdated {
            old_value: hub.max_order_deadline,
            new_value: new_max_deadline,
        });
        
        hub.max_order_deadline = new_max_deadline;
    }

    // ======== Order Creation ========
    
    public fun create_order(
        hub: &mut OrderHub,
        request: OrderRequest,
        signature: vector<u8>,
        public_key: vector<u8>,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): OrderCapability {
        let order = types::order_request_order(&request);
        let user = order_user(order);
        let current_time = clock::timestamp_ms(clock);
        
        // Validate request
        validate_request(hub, &request, current_time);
        
        // Validate signature
        assert!(
            validator::validate_order_request(
                &request,
                signature,
                public_key,
                &hub.domain_separator
            ),
            EInvalidOrderSignature
        );
        
        // Validate order
        validate_order(hub, order, current_time);
        
        // Mark nonce as used
        mark_nonce_used(hub, user, types::order_request_nonce(&request), ctx);
        
        // Increment global nonce
        hub.nonce = hub.nonce + 1;
        let order_nonce = hub.nonce;
        
        // Create order ID
        let order_uid = object::new(ctx);
        let order_id = object::uid_to_inner(&order_uid);
        
        // Store order info
        let order_info = OrderInfo {
            order: *order,
            status: status_active(),
            nonce: order_nonce,
            created_at: current_time,
            creator: tx_context::sender(ctx),
        };
        
        table::add(&mut hub.orders, order_id, order_info);
        
        // Handle token deposits
        process_deposits(hub, order_id, order, payment, ctx);
        
        // Create capability
        let cap = OrderCapability {
            id: order_uid,
            order_id,
            hub_id: object::uid_to_inner(&hub.id),
        };
        
        // Emit event
        event::emit(OrderCreated {
            order_id,
            nonce: order_nonce,
            order: *order,
            creator: tx_context::sender(ctx),
        });
        
        cap
    }

    // ======== Order Management ========
    
    public fun withdraw_order(
        hub: &mut OrderHub,
        cap: OrderCapability,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let OrderCapability { id, order_id, hub_id } = cap;
        object::delete(id);
        
        assert!(hub_id == object::uid_to_inner(&hub.id), ENotOwner);
        
        let order_info = table::borrow_mut(&mut hub.orders, order_id);
        let order = &order_info.order;
        
        // Check if order can be withdrawn
        assert!(order_info.status == status_active(), EOrderNotActive);
        
        let current_time = clock::timestamp_ms(clock);
        let can_withdraw = current_time > order_deadline(order) + hub.time_buffer;
        
        assert!(can_withdraw, EOrderCannotBeWithdrawn);
        
        // Update status
        order_info.status = status_withdrawn();
        
        // Return tokens to user
        return_tokens(hub, order_id, order_user(order), ctx);
        
        // Emit event
        event::emit(OrderWithdrawn {
            order_id,
            caller: tx_context::sender(ctx),
        });
    }

    public fun settle_order(
        hub: &mut OrderHub,
        order_id: ID,
        proof: vector<u8>, // Cross-chain proof
        ctx: &mut TxContext
    ) {
        let order_info = table::borrow_mut(&mut hub.orders, order_id);
        
        // Verify order can be settled
        assert!(order_info.status == status_active(), EOrderNotActive);
        
        // TODO: Verify cross-chain proof
        // This would integrate with a bridge protocol
        
        // Update status
        order_info.status = status_filled();
        
        // Emit event
        event::emit(OrderSettled {
            order_id,
            order: order_info.order,
        });
    }

    // ======== Internal Functions ========
    
    fun validate_request(
        hub: &OrderHub,
        request: &OrderRequest,
        current_time: u64
    ) {
        let user = order_user(types::order_request_order(request));
        let nonce = types::order_request_nonce(request);
        let deadline = types::order_request_deadline(request);
        
        // Check nonce not reused
        if (table::contains(&hub.request_nonces, user)) {
            let user_nonces = table::borrow(&hub.request_nonces, user);
            assert!(!table::contains(user_nonces, nonce), ERequestNonceReused);
        };
        
        // Check request not expired
        assert!(current_time <= deadline, ERequestExpired);
    }

    fun validate_order(
        hub: &OrderHub,
        order: &Order,
        current_time: u64
    ) {
        let deadline = order_deadline(order);
        let primary_deadline = order_primary_filler_deadline(order);
        
        // Check deadlines
        assert!(deadline <= current_time + hub.max_order_deadline, EInvalidDeadline);
        assert!(primary_deadline <= deadline, EInvalidDeadline);
        
        // Check not expired
        assert!(current_time < deadline, EOrderExpired);
        
        // Validate source chain
        assert!(types::order_source_chain_id(order) == 1, EInvalidSourceChain);
    }

    fun mark_nonce_used(
        hub: &mut OrderHub,
        user: address,
        nonce: u64,
        ctx: &mut TxContext
    ) {
        if (!table::contains(&hub.request_nonces, user)) {
            table::add(&mut hub.request_nonces, user, table::new(ctx));
        };
        
        let user_nonces = table::borrow_mut(&mut hub.request_nonces, user);
        table::add(user_nonces, nonce, true);
    }

    fun process_deposits(
        hub: &mut OrderHub,
        order_id: ID,
        order: &Order,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // For simplicity, assuming SUI deposits only
        // In production, would handle multiple tokens
        
        let balance = coin::into_balance(payment);
        
        if (!table::contains(&hub.balances, order_id)) {
            table::add(&mut hub.balances, order_id, balance::zero<SUI>());
        };
        
        let stored_balance = table::borrow_mut(&mut hub.balances, order_id);
        balance::join(stored_balance, balance);
    }

    fun return_tokens(
        hub: &mut OrderHub,
        order_id: ID,
        user: address,
        ctx: &mut TxContext
    ) {
        // Return tokens to user
        if (table::contains(&hub.balances, order_id)) {
            let balance = table::remove(&mut hub.balances, order_id);
            
            // Convert balance back to coin and transfer
            let coin = coin::from_balance(balance, ctx);
            transfer::public_transfer(coin, user);
        };
    }

    // ======== View Functions ========
    
    public fun get_order_info(hub: &OrderHub, order_id: ID): &OrderInfo {
        table::borrow(&hub.orders, order_id)
    }

    public fun get_order_status(hub: &OrderHub, order_id: ID): u8 {
        let info = table::borrow(&hub.orders, order_id);
        info.status
    }

    public fun get_nonce(hub: &OrderHub): u64 {
        hub.nonce
    }
}