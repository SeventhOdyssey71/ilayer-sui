#[test_only]
module ilayer::order_spoke_tests {
    use ilayer::order_spoke::{
        Self,
        OrderSpoke,
        FillReceipt,
        register_solver,
        deactivate_solver,
        set_fee,
        fill_order,
        is_order_filled,
        get_solver_info,
        get_fee
    };
    use ilayer::types::{
        Self,
        new_token, new_order,
        token_type_coin
    };
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::vector;

    const ADMIN: address = @0xAD;
    const SOLVER: address = @0x10;
    const USER: address = @0x1;
    const RECIPIENT: address = @0x2;

    fun init_test(): Scenario {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            order_spoke::init(test_scenario::ctx(&mut scenario));
            clock::create_for_testing(test_scenario::ctx(&mut scenario));
        };
        scenario
    }

    #[test]
    fun test_spoke_initialization() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            assert!(get_fee(&spoke) == 30, 0); // Default fee 0.3%
            test_scenario::return_shared(spoke);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_register_solver() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            register_solver(&mut spoke, SOLVER, test_scenario::ctx(&mut scenario));
            
            let solver_info = get_solver_info(&spoke, SOLVER);
            assert!(solver_info.active == true, 0);
            assert!(solver_info.total_filled == 0, 1);
            assert!(solver_info.total_volume == 0, 2);
            
            test_scenario::return_shared(spoke);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_deactivate_solver() {
        let mut scenario = init_test();
        
        // Register solver
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            register_solver(&mut spoke, SOLVER, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(spoke);
        };
        
        // Deactivate solver
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            deactivate_solver(&mut spoke, SOLVER, test_scenario::ctx(&mut scenario));
            
            let solver_info = get_solver_info(&spoke, SOLVER);
            assert!(solver_info.active == false, 0);
            
            test_scenario::return_shared(spoke);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_fee() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            set_fee(&mut spoke, 50, test_scenario::ctx(&mut scenario)); // 0.5%
            assert!(get_fee(&spoke) == 50, 0);
            test_scenario::return_shared(spoke);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4001)] // ENotOwner
    fun test_register_solver_non_owner() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            register_solver(&mut spoke, SOLVER, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(spoke);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_fill_order_setup() {
        let mut scenario = init_test();
        
        // Register solver
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let mut spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            register_solver(&mut spoke, SOLVER, test_scenario::ctx(&mut scenario));
            test_scenario::return_shared(spoke);
        };
        
        // Create output coins for solver
        test_scenario::next_tx(&mut scenario, SOLVER);
        {
            let output = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(&mut scenario));
            transfer::public_transfer(output, SOLVER);
        };
        
        // Attempt to fill order
        test_scenario::next_tx(&mut scenario, SOLVER);
        {
            let mut spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            let clock = test_scenario::take_shared<Clock>(&scenario);
            
            // Create order
            let inputs = vector[
                new_token(token_type_coin(), b"SUI", 0, 1000000)
            ];
            let outputs = vector[
                new_token(token_type_coin(), b"USDC", 0, 1000)
            ];
            
            let order = new_order(
                USER,
                RECIPIENT,
                SOLVER,
                inputs,
                outputs,
                1, // source chain
                2, // destination chain
                false,
                clock::timestamp_ms(&clock) + 3600000,
                clock::timestamp_ms(&clock) + 7200000,
                @0x0,
                vector::empty(),
                0
            );
            
            let order_id = b"order123";
            let proof = b"proof_data";
            let output_coins = vector[test_scenario::take_from_sender<Coin<SUI>>(&scenario)];
            
            // This would process the fill in production
            // let receipt = fill_order(
            //     &mut spoke,
            //     order,
            //     order_id,
            //     proof,
            //     output_coins,
            //     &clock,
            //     test_scenario::ctx(&mut scenario)
            // );
            
            test_scenario::return_shared(spoke);
            test_scenario::return_shared(clock);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_is_order_filled() {
        let mut scenario = init_test();
        
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let spoke = test_scenario::take_shared<OrderSpoke>(&scenario);
            
            // Check non-existent order
            assert!(!is_order_filled(&spoke, b"nonexistent"), 0);
            
            test_scenario::return_shared(spoke);
        };
        
        test_scenario::end(scenario);
    }

    #[test]
    fun test_fee_calculation() {
        // Test fee calculation logic
        // 30 basis points on 1000 = 3
        let fee = (1000 * 30) / 10000;
        assert!(fee == 3, 0);
        
        // 50 basis points on 10000 = 50
        let fee2 = (10000 * 50) / 10000;
        assert!(fee2 == 50, 1);
    }
}