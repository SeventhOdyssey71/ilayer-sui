module ilayer::order_spoke {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::table::{Self, Table};
    
    use ilayer::types::{
        Self, Order,
        order_recipient, order_outputs, order_deadline,
        order_primary_filler_deadline, order_filler, order_sponsored
    };
    use ilayer::executor::{Self, ExecutorCap};

    // ======== Constants ========
    
    const CURRENT_VERSION: u64 = 1;
    const BASIS_POINTS: u64 = 10000;
    const DEFAULT_FEE: u64 = 30; // 0.3%

    // ======== Error Codes ========
    
    const ENotOwner: u64 = 4001;
    const EOrderAlreadyFilled: u64 = 4002;
    const EOrderExpired: u64 = 4003;
    const ENotPrimaryFiller: u64 = 4004;
    // const EPrimaryFillerDeadlineNotExpired: u64 = 4005; // Unused
    const EInvalidFiller: u64 = 4006;
    const EInsufficientOutputs: u64 = 4007;
    const ECallFailed: u64 = 4008;
    const ESolverNotRegistered: u64 = 4009;
    // const EInvalidProof: u64 = 4010; // Unused

    // ======== Structs ========
    
    public struct OrderSpoke has key {
        id: UID,
        version: u64,
        owner: address,
        fee_recipient: address,
        fee_basis_points: u64,
        filled_orders: Table<vector<u8>, bool>,
        solvers: Table<address, SolverInfo>,
        executor_cap: ExecutorCap,
    }

    public struct SolverInfo has store {
        active: bool,
        total_filled: u64,
        total_volume: u64,
    }

    public struct FillReceipt has key, store {
        id: UID,
        order_id: vector<u8>,
        filler: address,
        timestamp: u64,
    }

    // ======== Events ========
    
    public struct OrderFilled has copy, drop {
        order_id: vector<u8>,
        order: Order,
        filler: address,
        fee_paid: u64,
    }

    public struct SolverRegistered has copy, drop {
        solver: address,
    }

    public struct SolverDeactivated has copy, drop {
        solver: address,
    }

    public struct FeeUpdated has copy, drop {
        old_fee: u64,
        new_fee: u64,
    }

    // ======== Initialization ========
    
    fun init(ctx: &mut TxContext) {
        let executor_cap = executor::create_executor_cap(ctx);
        
        let spoke = OrderSpoke {
            id: object::new(ctx),
            version: CURRENT_VERSION,
            owner: tx_context::sender(ctx),
            fee_recipient: tx_context::sender(ctx),
            fee_basis_points: DEFAULT_FEE,
            filled_orders: table::new(ctx),
            solvers: table::new(ctx),
            executor_cap,
        };
        
        transfer::share_object(spoke);
    }

    // ======== Admin Functions ========
    
    public fun register_solver(
        spoke: &mut OrderSpoke,
        solver: address,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == spoke.owner, ENotOwner);
        
        let solver_info = SolverInfo {
            active: true,
            total_filled: 0,
            total_volume: 0,
        };
        
        table::add(&mut spoke.solvers, solver, solver_info);
        
        event::emit(SolverRegistered { solver });
    }

    public fun deactivate_solver(
        spoke: &mut OrderSpoke,
        solver: address,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == spoke.owner, ENotOwner);
        
        let solver_info = table::borrow_mut(&mut spoke.solvers, solver);
        solver_info.active = false;
        
        event::emit(SolverDeactivated { solver });
    }

    public fun set_fee(
        spoke: &mut OrderSpoke,
        new_fee: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == spoke.owner, ENotOwner);
        assert!(new_fee <= BASIS_POINTS, EInvalidFiller);
        
        event::emit(FeeUpdated {
            old_fee: spoke.fee_basis_points,
            new_fee,
        });
        
        spoke.fee_basis_points = new_fee;
    }

    // ======== Order Filling ========
    
    public fun fill_order<T>(
        spoke: &mut OrderSpoke,
        order: Order,
        order_id: vector<u8>,
        _proof: vector<u8>, // Cross-chain proof
        outputs: vector<Coin<T>>,
        clock: &Clock,
        ctx: &mut TxContext
    ): FillReceipt {
        let filler = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        
        // Validate solver
        assert!(is_solver_active(spoke, filler), ESolverNotRegistered);
        
        // Validate order not already filled
        assert!(!table::contains(&spoke.filled_orders, order_id), EOrderAlreadyFilled);
        
        // Validate order timing
        validate_fill_timing(&order, filler, current_time);
        
        // TODO: Validate cross-chain proof
        // verify_proof(proof, order_id, &order);
        
        // Process outputs
        let total_output = process_outputs(
            spoke,
            &order,
            outputs,
            ctx
        );
        
        // Update solver stats
        update_solver_stats(spoke, filler, total_output);
        
        // Mark order as filled
        table::add(&mut spoke.filled_orders, order_id, true);
        
        // Execute call if needed
        if (vector::length(types::order_call_data(&order)) > 0) {
            execute_call(spoke, &order, ctx);
        };
        
        // Create receipt
        let receipt = FillReceipt {
            id: object::new(ctx),
            order_id,
            filler,
            timestamp: current_time,
        };
        
        // Emit event
        event::emit(OrderFilled {
            order_id,
            order: order,
            filler,
            fee_paid: calculate_fee(total_output, spoke.fee_basis_points),
        });
        
        receipt
    }

    // ======== Internal Functions ========
    
    fun validate_fill_timing(
        order: &Order,
        filler: address,
        current_time: u64
    ) {
        let deadline = order_deadline(order);
        let primary_deadline = order_primary_filler_deadline(order);
        let primary_filler = order_filler(order);
        
        // Check order not expired
        assert!(current_time <= deadline, EOrderExpired);
        
        // Check primary filler period
        if (current_time <= primary_deadline) {
            assert!(
                filler == primary_filler || primary_filler == @0x0,
                ENotPrimaryFiller
            );
        };
    }

    fun process_outputs<T>(
        spoke: &OrderSpoke,
        order: &Order,
        mut outputs: vector<Coin<T>>,
        ctx: &mut TxContext
    ): u64 {
        let order_outputs = order_outputs(order);
        let recipient = order_recipient(order);
        let sponsored = order_sponsored(order);
        
        // Validate output count
        assert!(
            vector::length(&outputs) == vector::length(order_outputs),
            EInsufficientOutputs
        );
        
        let mut total_value = 0;
        let mut i = 0;
        
        while (i < vector::length(&outputs)) {
            let mut output_coin = vector::pop_back(&mut outputs);
            let _expected = vector::borrow(order_outputs, i);
            
            let amount = coin::value(&output_coin);
            total_value = total_value + amount;
            
            // Calculate fee
            let fee_amount = if (sponsored) {
                0
            } else {
                calculate_fee(amount, spoke.fee_basis_points)
            };
            
            if (fee_amount > 0) {
                let fee_coin = coin::split(&mut output_coin, fee_amount, ctx);
                transfer::public_transfer(fee_coin, spoke.fee_recipient);
            };
            
            // Transfer to recipient
            transfer::public_transfer(output_coin, recipient);
            
            i = i + 1;
        };
        
        vector::destroy_empty(outputs);
        total_value
    }

    fun execute_call(
        spoke: &mut OrderSpoke,
        order: &Order,
        ctx: &mut TxContext
    ) {
        let call_recipient = types::order_call_recipient(order);
        let call_data = *types::order_call_data(order);
        let call_value = types::order_call_value(order);
        
        if (call_recipient != @0x0) {
            // Execute the call using executor
            let success = executor::execute_call(
                &mut spoke.executor_cap,
                call_recipient,
                call_data,
                call_value,
                ctx
            );
            
            assert!(success, ECallFailed);
        };
    }

    fun is_solver_active(spoke: &OrderSpoke, solver: address): bool {
        if (table::contains(&spoke.solvers, solver)) {
            let info = table::borrow(&spoke.solvers, solver);
            info.active
        } else {
            false
        }
    }

    fun update_solver_stats(
        spoke: &mut OrderSpoke,
        solver: address,
        volume: u64
    ) {
        let info = table::borrow_mut(&mut spoke.solvers, solver);
        info.total_filled = info.total_filled + 1;
        info.total_volume = info.total_volume + volume;
    }

    fun calculate_fee(amount: u64, fee_basis_points: u64): u64 {
        (amount * fee_basis_points) / BASIS_POINTS
    }

    // ======== View Functions ========
    
    public fun is_order_filled(spoke: &OrderSpoke, order_id: vector<u8>): bool {
        table::contains(&spoke.filled_orders, order_id)
    }

    public fun get_solver_info(spoke: &OrderSpoke, solver: address): &SolverInfo {
        table::borrow(&spoke.solvers, solver)
    }

    public fun get_fee(spoke: &OrderSpoke): u64 {
        spoke.fee_basis_points
    }
}