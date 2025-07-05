module ilayer::types {
    // use sui::object::ID; // Unused

    // ======== Constants ========
    
    const STATUS_NULL: u8 = 0;
    const STATUS_ACTIVE: u8 = 1;
    const STATUS_FILLED: u8 = 2;
    const STATUS_WITHDRAWN: u8 = 3;

    const TOKEN_TYPE_NULL: u8 = 0;
    const TOKEN_TYPE_NATIVE: u8 = 1;
    const TOKEN_TYPE_COIN: u8 = 2;
    const TOKEN_TYPE_NFT: u8 = 3;
    const TOKEN_TYPE_OBJECT: u8 = 4;

    // ======== Error Codes ========
    
    // const ENativeTransferFailed: u64 = 1001; // Unused
    // const EUnsupportedTransfer: u64 = 1002; // Unused
    // const EInsufficientBalance: u64 = 1003; // Unused
    const EInvalidTokenType: u64 = 1004;
    // const EInvalidStatus: u64 = 1005; // Unused

    // ======== Structs ========
    
    public struct Token has store, drop, copy {
        token_type: u8,
        // For coins: type name, for objects: object ID
        token_address: vector<u8>,
        // For NFTs and specific objects
        token_id: u64,
        amount: u64,
    }

    public struct Order has store, drop, copy {
        user: address,
        recipient: address,
        filler: address,
        inputs: vector<Token>,
        outputs: vector<Token>,
        source_chain_id: u32,
        destination_chain_id: u32,
        sponsored: bool,
        primary_filler_deadline: u64,
        deadline: u64,
        call_recipient: address,
        call_data: vector<u8>,
        call_value: u64,
    }

    public struct OrderRequest has store, drop, copy {
        deadline: u64,
        nonce: u64,
        order: Order,
    }

    // ======== Public Functions ========
    
    public fun new_token(
        token_type: u8,
        token_address: vector<u8>,
        token_id: u64,
        amount: u64
    ): Token {
        assert!(token_type <= TOKEN_TYPE_OBJECT, EInvalidTokenType);
        Token {
            token_type,
            token_address,
            token_id,
            amount,
        }
    }

    public fun new_order(
        user: address,
        recipient: address,
        filler: address,
        inputs: vector<Token>,
        outputs: vector<Token>,
        source_chain_id: u32,
        destination_chain_id: u32,
        sponsored: bool,
        primary_filler_deadline: u64,
        deadline: u64,
        call_recipient: address,
        call_data: vector<u8>,
        call_value: u64,
    ): Order {
        Order {
            user,
            recipient,
            filler,
            inputs,
            outputs,
            source_chain_id,
            destination_chain_id,
            sponsored,
            primary_filler_deadline,
            deadline,
            call_recipient,
            call_data,
            call_value,
        }
    }

    public fun new_order_request(
        deadline: u64,
        nonce: u64,
        order: Order
    ): OrderRequest {
        OrderRequest {
            deadline,
            nonce,
            order,
        }
    }

    // ======== Getter Functions ========
    
    public fun token_type(token: &Token): u8 {
        token.token_type
    }

    public fun token_address(token: &Token): &vector<u8> {
        &token.token_address
    }

    public fun token_id(token: &Token): u64 {
        token.token_id
    }

    public fun token_amount(token: &Token): u64 {
        token.amount
    }

    public fun order_user(order: &Order): address {
        order.user
    }

    public fun order_recipient(order: &Order): address {
        order.recipient
    }

    public fun order_filler(order: &Order): address {
        order.filler
    }

    public fun order_inputs(order: &Order): &vector<Token> {
        &order.inputs
    }

    public fun order_outputs(order: &Order): &vector<Token> {
        &order.outputs
    }

    public fun order_deadline(order: &Order): u64 {
        order.deadline
    }

    public fun order_primary_filler_deadline(order: &Order): u64 {
        order.primary_filler_deadline
    }

    public fun order_sponsored(order: &Order): bool {
        order.sponsored
    }

    public fun order_source_chain_id(order: &Order): u32 {
        order.source_chain_id
    }

    public fun order_destination_chain_id(order: &Order): u32 {
        order.destination_chain_id
    }

    public fun order_call_data(order: &Order): &vector<u8> {
        &order.call_data
    }

    public fun order_call_recipient(order: &Order): address {
        order.call_recipient
    }

    public fun order_call_value(order: &Order): u64 {
        order.call_value
    }

    // ======== OrderRequest Getter Functions ========
    
    public fun order_request_deadline(request: &OrderRequest): u64 {
        request.deadline
    }

    public fun order_request_nonce(request: &OrderRequest): u64 {
        request.nonce
    }

    public fun order_request_order(request: &OrderRequest): &Order {
        &request.order
    }

    // ======== Status Functions ========
    
    public fun status_null(): u8 { STATUS_NULL }
    public fun status_active(): u8 { STATUS_ACTIVE }
    public fun status_filled(): u8 { STATUS_FILLED }
    public fun status_withdrawn(): u8 { STATUS_WITHDRAWN }

    // ======== Token Type Functions ========
    
    public fun token_type_null(): u8 { TOKEN_TYPE_NULL }
    public fun token_type_native(): u8 { TOKEN_TYPE_NATIVE }
    public fun token_type_coin(): u8 { TOKEN_TYPE_COIN }
    public fun token_type_nft(): u8 { TOKEN_TYPE_NFT }
    public fun token_type_object(): u8 { TOKEN_TYPE_OBJECT }
}