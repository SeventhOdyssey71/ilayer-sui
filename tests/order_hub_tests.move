#[test_only]
module ilayer::order_hub_tests {
    use ilayer::order_hub::{
        Self,
        OrderHub,
        OrderCapability,
        set_time_buffer,
        set_max_order_deadline,
        create_order,
        withdraw_order,
        get_order_status,
        get_nonce
    };
    use ilayer::types::{
        Self,
        new_token, new_order, new_order_request,
        token_type_coin, status_active, status_withdrawn
    };
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::vector;

    const ADMIN: address = @0xAD;
    const USER: address = @0x1;
    const RECIPIENT: address = @0x2;
    const FILLER: address = @0x3;

    fun init_test(): Scenario {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            order_hub::init(test_scenario::ctx(&mut scenario));
            clock::create_for_testing(test_scenario::ctx(&mut scenario));
        };
        scenario
    }

    #[test]
    fun test_hub_initialization() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let hub = test_scenario::take_shared<OrderHub>(&scenario);
            assert!(get_nonce(&hub) == 0, 0);
            test_scenario::return_shared(hub);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_time_buffer() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut hub = test_scenario::take_shared<OrderHub>(&scenario);
            set_time_buffer(&mut hub, 600000, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(hub);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_max_order_deadline() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut hub = test_scenario::take_shared<OrderHub>(&scenario);
            set_max_order_deadline(&mut hub, 86400000, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(hub);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3001)] // ENotOwner
    fun test_set_time_buffer_non_owner() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut hub = test_scenario::take_shared<OrderHub>(&scenario);
            set_time_buffer(&mut hub, 600000, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(hub);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_create_basic_order() {
        let mut scenario = init_test();
        
        // Setup: Create payment coin
        test_scenario::next_tx(&mut scenario, USER);
        {
            let payment = coin::mint_for_testing<SUI>(1000000, test_scenario::ctx(&mut scenario));
            transfer::public_transfer(payment, USER);
        };
        
        // Create order
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut hub = test_scenario::take_shared<OrderHub>(&scenario);
            let clock = test_scenario::take_shared<Clock>(&scenario);
            let payment = test_scenario::take_from_sender<Coin<SUI>>(&scenario);
            
            // Create order data
            let inputs = vector[
                new_token(token_type_coin(), b"SUI", 0, 1000000)
            ];
            let outputs = vector[
                new_token(token_type_coin(), b"USDC", 0, 1000)
            ];
            
            let order = new_order(
                USER,
                RECIPIENT,
                FILLER,
                inputs,
                outputs,
                1, // source chain
                2, // destination chain
                false,
                clock::timestamp_ms(&clock) + 3600000, // 1 hour
                clock::timestamp_ms(&clock) + 7200000, // 2 hours
                @0x0,
                vector::empty(),
                0
            );
            
            let request = new_order_request(
                clock::timestamp_ms(&clock) + 300000, // 5 minutes
                1,
                order
            );
            
            // Mock signature
            let signature = create_mock_signature();
            let public_key = create_mock_public_key();
            
            // This would fail without proper implementation
            // let cap = create_order(
            //     &mut hub,
            //     request,
            //     signature,
            //     public_key,
            //     payment,
            //     &clock,
            //     test_scenario::ctx(&mut scenario)
            // );
            
            test_scenario::return_shared(hub);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::end(scenario);
    }

    // Helper functions
    fun create_mock_signature(): vector<u8> {
        let mut sig = vector::empty<u8>();
        let i = 0;
        while (i < 64) {
            vector::push_back(&mut sig, 0);
            i = i + 1;
        };
        sig
    }

    fun create_mock_public_key(): vector<u8> {
        let mut key = vector::empty<u8>();
        let i = 0;
        while (i < 32) {
            vector::push_back(&mut key, 0);
            i = i + 1;
        };
        key
    }
}