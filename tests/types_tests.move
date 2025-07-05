#[test_only]
module ilayer::types_tests {
    use ilayer::types::{
        Self, Token, Order, OrderRequest,
        new_token, new_order, new_order_request,
        token_type, token_address, token_id, token_amount,
        order_user, order_recipient, order_deadline,
        token_type_coin, token_type_nft, status_active
    };
    use std::vector;

    #[test]
    fun test_create_token() {
        let token = new_token(
            token_type_coin(),
            b"0x123",
            0,
            1000000
        );

        assert!(token_type(&token) == token_type_coin(), 0);
        assert!(token_address(&token) == &b"0x123", 1);
        assert!(token_id(&token) == 0, 2);
        assert!(token_amount(&token) == 1000000, 3);
    }

    #[test]
    fun test_create_nft_token() {
        let token = new_token(
            token_type_nft(),
            b"0xNFT",
            12345,
            1
        );

        assert!(token_type(&token) == token_type_nft(), 0);
        assert!(token_id(&token) == 12345, 1);
        assert!(token_amount(&token) == 1, 2);
    }

    #[test]
    fun test_create_order() {
        let inputs = vector[
            new_token(token_type_coin(), b"0xSUI", 0, 1000000)
        ];
        let outputs = vector[
            new_token(token_type_coin(), b"0xUSDC", 0, 1000)
        ];

        let order = new_order(
            @0x1,                    // user
            @0x2,                    // recipient
            @0x3,                    // filler
            inputs,                  // inputs
            outputs,                 // outputs
            1,                      // source_chain_id
            2,                      // destination_chain_id
            false,                  // sponsored
            1000000,                // primary_filler_deadline
            2000000,                // deadline
            @0x0,                   // call_recipient
            vector::empty(),        // call_data
            0                       // call_value
        );

        assert!(order_user(&order) == @0x1, 0);
        assert!(order_recipient(&order) == @0x2, 1);
        assert!(order_deadline(&order) == 2000000, 2);
    }

    #[test]
    fun test_order_with_call_data() {
        let inputs = vector[
            new_token(token_type_coin(), b"0xSUI", 0, 1000000)
        ];
        let outputs = vector[
            new_token(token_type_coin(), b"0xUSDC", 0, 1000)
        ];

        let call_data = b"execute_swap";

        let order = new_order(
            @0x1,                    // user
            @0x2,                    // recipient
            @0x3,                    // filler
            inputs,                  // inputs
            outputs,                 // outputs
            1,                      // source_chain_id
            2,                      // destination_chain_id
            true,                   // sponsored
            1000000,                // primary_filler_deadline
            2000000,                // deadline
            @0x4,                   // call_recipient
            call_data,              // call_data
            100                     // call_value
        );

        assert!(types::order_sponsored(&order) == true, 0);
        assert!(types::order_call_recipient(&order) == @0x4, 1);
        assert!(types::order_call_value(&order) == 100, 2);
    }

    #[test]
    fun test_create_order_request() {
        let inputs = vector::empty();
        let outputs = vector::empty();

        let order = new_order(
            @0x1, @0x2, @0x0,
            inputs, outputs,
            1, 2,
            false,
            1000000, 2000000,
            @0x0, vector::empty(), 0
        );

        let request = new_order_request(
            3000000,    // deadline
            12345,      // nonce
            order
        );

        assert!(types::order_request_deadline(&request) == 3000000, 0);
        assert!(types::order_request_nonce(&request) == 12345, 1);
    }

    #[test]
    fun test_multiple_tokens_order() {
        let inputs = vector[
            new_token(token_type_coin(), b"0xSUI", 0, 1000000),
            new_token(token_type_nft(), b"0xNFT", 42, 1),
            new_token(token_type_coin(), b"0xUSDC", 0, 500)
        ];
        
        let outputs = vector[
            new_token(token_type_coin(), b"0xETH", 0, 100000)
        ];

        let order = new_order(
            @0x1, @0x2, @0x3,
            inputs, outputs,
            1, 2,
            false,
            1000000, 2000000,
            @0x0, vector::empty(), 0
        );

        let order_inputs = order_inputs(&order);
        assert!(vector::length(order_inputs) == 3, 0);
        
        let first_input = vector::borrow(order_inputs, 0);
        assert!(token_type(first_input) == token_type_coin(), 1);
        
        let second_input = vector::borrow(order_inputs, 1);
        assert!(token_type(second_input) == token_type_nft(), 2);
        assert!(token_id(second_input) == 42, 3);
    }

    #[test]
    fun test_status_constants() {
        assert!(types::status_null() == 0, 0);
        assert!(types::status_active() == 1, 1);
        assert!(types::status_filled() == 2, 2);
        assert!(types::status_withdrawn() == 3, 3);
    }

    #[test]
    fun test_token_type_constants() {
        assert!(types::token_type_null() == 0, 0);
        assert!(types::token_type_native() == 1, 1);
        assert!(types::token_type_coin() == 2, 2);
        assert!(types::token_type_nft() == 3, 3);
        assert!(types::token_type_object() == 4, 4);
    }

    #[test]
    #[expected_failure(abort_code = 1004)] // EInvalidTokenType
    fun test_invalid_token_type() {
        new_token(
            10, // Invalid token type
            b"0x123",
            0,
            1000
        );
    }
}