module ilayer::executor {
    use sui::event;

    // ======== Error Codes ========
    
    const ENotAuthorized: u64 = 5001;
    // const ECallFailed: u64 = 5002; // Unused
    const EInvalidTarget: u64 = 5003;

    // ======== Structs ========
    
    public struct ExecutorCap has key, store {
        id: UID,
        authorized_callers: vector<address>,
    }

    public struct CallExecuted has copy, drop {
        target: address,
        data_length: u64,
        value: u64,
        success: bool,
    }

    // ======== Public Functions ========
    
    public fun create_executor_cap(ctx: &mut TxContext): ExecutorCap {
        ExecutorCap {
            id: object::new(ctx),
            authorized_callers: vector[tx_context::sender(ctx)],
        }
    }

    public fun add_authorized_caller(
        cap: &mut ExecutorCap,
        caller: address,
        ctx: &TxContext
    ) {
        assert!(is_authorized(cap, tx_context::sender(ctx)), ENotAuthorized);
        
        if (!vector::contains(&cap.authorized_callers, &caller)) {
            vector::push_back(&mut cap.authorized_callers, caller);
        };
    }

    public fun remove_authorized_caller(
        cap: &mut ExecutorCap,
        caller: address,
        ctx: &TxContext
    ) {
        assert!(is_authorized(cap, tx_context::sender(ctx)), ENotAuthorized);
        
        let (found, index) = vector::index_of(&cap.authorized_callers, &caller);
        if (found) {
            vector::remove(&mut cap.authorized_callers, index);
        };
    }

    public fun execute_call(
        cap: &mut ExecutorCap,
        target: address,
        data: vector<u8>,
        value: u64,
        ctx: &mut TxContext
    ): bool {
        assert!(is_authorized(cap, tx_context::sender(ctx)), ENotAuthorized);
        assert!(target != @0x0, EInvalidTarget);
        
        // In Sui, we can't make arbitrary calls like in EVM
        // Instead, we would use programmable transactions
        // This is a simplified version that emits an event
        
        // In production, this would:
        // 1. Use programmable transaction blocks
        // 2. Call specific entry functions on target modules
        // 3. Handle different types of operations
        
        let success = true; // Simplified for now
        
        event::emit(CallExecuted {
            target,
            data_length: vector::length(&data),
            value,
            success,
        });
        
        success
    }

    public fun execute_batch_calls(
        cap: &mut ExecutorCap,
        targets: vector<address>,
        datas: vector<vector<u8>>,
        values: vector<u64>,
        ctx: &mut TxContext
    ): vector<bool> {
        assert!(is_authorized(cap, tx_context::sender(ctx)), ENotAuthorized);
        
        let len = vector::length(&targets);
        assert!(
            len == vector::length(&datas) && len == vector::length(&values),
            EInvalidTarget
        );
        
        let mut results = vector::empty<bool>();
        let mut i = 0;
        
        while (i < len) {
            let target = *vector::borrow(&targets, i);
            let data = *vector::borrow(&datas, i);
            let value = *vector::borrow(&values, i);
            
            let success = execute_call(cap, target, data, value, ctx);
            vector::push_back(&mut results, success);
            
            i = i + 1;
        };
        
        results
    }

    // ======== Internal Functions ========
    
    fun is_authorized(cap: &ExecutorCap, caller: address): bool {
        vector::contains(&cap.authorized_callers, &caller)
    }

    // ======== View Functions ========
    
    public fun get_authorized_callers(cap: &ExecutorCap): &vector<address> {
        &cap.authorized_callers
    }

    public fun is_caller_authorized(cap: &ExecutorCap, caller: address): bool {
        is_authorized(cap, caller)
    }

    // ======== Test Functions ========
    
    #[test_only]
    public fun test_create_cap(ctx: &mut TxContext): ExecutorCap {
        create_executor_cap(ctx)
    }
}