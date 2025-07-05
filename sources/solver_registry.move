module ilayer::solver_registry {
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};

    // ======== Constants ========
    
    const MIN_SOLVER_STAKE: u64 = 1000000000; // 1 SUI
    const DEFAULT_COOLDOWN_PERIOD: u64 = 86400000; // 24 hours in ms
    const MAX_SOLVER_NAME_LENGTH: u64 = 64;

    // ======== Error Codes ========
    
    const ENotAuthorized: u64 = 10001;
    const ESolverAlreadyRegistered: u64 = 10002;
    const ESolverNotFound: u64 = 10003;
    const ESolverNotActive: u64 = 10004;
    const EInsufficientStake: u64 = 10005;
    const ECooldownNotExpired: u64 = 10006;
    const ENameTooLong: u64 = 10007;

    // ======== Structs ========
    
    public struct SolverRegistry has key {
        id: UID,
        owner: address,
        solvers: Table<address, SolverInfo>,
        solver_count: u64,
        active_solver_count: u64,
        min_stake: u64,
        cooldown_period: u64,
        total_volume: u64,
        total_orders_filled: u64,
    }

    public struct SolverInfo has store, copy, drop {
        name: String,
        active: bool,
        stake_amount: u64,
        registered_at: u64,
        last_deactivated: u64,
        orders_filled: u64,
        total_volume: u64,
        success_rate: u64, // Basis points (0-10000)
        metadata: vector<u8>,
    }

    public struct SolverCapability has key, store {
        id: UID,
        solver: address,
        registry_id: ID,
    }

    // ======== Events ========
    
    public struct SolverRegistered has copy, drop {
        solver: address,
        name: String,
        stake_amount: u64,
        timestamp: u64,
    }

    public struct SolverDeactivated has copy, drop {
        solver: address,
        timestamp: u64,
        reason: vector<u8>,
    }

    public struct SolverReactivated has copy, drop {
        solver: address,
        timestamp: u64,
    }

    public struct SolverUpdated has copy, drop {
        solver: address,
        field: vector<u8>,
        old_value: vector<u8>,
        new_value: vector<u8>,
    }

    public struct SolverStatsUpdated has copy, drop {
        solver: address,
        orders_filled: u64,
        total_volume: u64,
        success_rate: u64,
    }

    // ======== Initialization ========
    
    fun init(ctx: &mut TxContext) {
        let registry = SolverRegistry {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            solvers: table::new(ctx),
            solver_count: 0,
            active_solver_count: 0,
            min_stake: MIN_SOLVER_STAKE,
            cooldown_period: DEFAULT_COOLDOWN_PERIOD,
            total_volume: 0,
            total_orders_filled: 0,
        };
        
        transfer::share_object(registry);
    }

    // ======== Public Functions ========
    
    /// Register a new solver
    public fun register_solver(
        registry: &mut SolverRegistry,
        name: String,
        stake_amount: u64,
        metadata: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ): SolverCapability {
        let solver = tx_context::sender(ctx);
        
        // Validations
        assert!(!table::contains(&registry.solvers, solver), ESolverAlreadyRegistered);
        assert!(stake_amount >= registry.min_stake, EInsufficientStake);
        assert!(string::length(&name) <= MAX_SOLVER_NAME_LENGTH, ENameTooLong);
        
        let current_time = clock::timestamp_ms(clock);
        
        let solver_info = SolverInfo {
            name,
            active: true,
            stake_amount,
            registered_at: current_time,
            last_deactivated: 0,
            orders_filled: 0,
            total_volume: 0,
            success_rate: 10000, // Start with 100% success rate
            metadata,
        };
        
        table::add(&mut registry.solvers, solver, solver_info);
        registry.solver_count = registry.solver_count + 1;
        registry.active_solver_count = registry.active_solver_count + 1;
        
        event::emit(SolverRegistered {
            solver,
            name,
            stake_amount,
            timestamp: current_time,
        });
        
        SolverCapability {
            id: object::new(ctx),
            solver,
            registry_id: object::uid_to_inner(&registry.id),
        }
    }

    /// Deactivate a solver
    public fun deactivate_solver(
        registry: &mut SolverRegistry,
        solver: address,
        reason: vector<u8>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(
            tx_context::sender(ctx) == registry.owner || 
            tx_context::sender(ctx) == solver,
            ENotAuthorized
        );
        assert!(table::contains(&registry.solvers, solver), ESolverNotFound);
        
        let solver_info = table::borrow_mut(&mut registry.solvers, solver);
        assert!(solver_info.active, ESolverNotActive);
        
        solver_info.active = false;
        solver_info.last_deactivated = clock::timestamp_ms(clock);
        registry.active_solver_count = registry.active_solver_count - 1;
        
        event::emit(SolverDeactivated {
            solver,
            timestamp: clock::timestamp_ms(clock),
            reason,
        });
    }

    /// Reactivate a solver after cooldown
    public fun reactivate_solver(
        registry: &mut SolverRegistry,
        cap: &SolverCapability,
        clock: &Clock,
        ctx: &TxContext
    ) {
        assert!(cap.solver == tx_context::sender(ctx), ENotAuthorized);
        assert!(table::contains(&registry.solvers, cap.solver), ESolverNotFound);
        
        let solver_info = table::borrow_mut(&mut registry.solvers, cap.solver);
        assert!(!solver_info.active, ESolverNotActive);
        
        let current_time = clock::timestamp_ms(clock);
        assert!(
            current_time >= solver_info.last_deactivated + registry.cooldown_period,
            ECooldownNotExpired
        );
        
        solver_info.active = true;
        registry.active_solver_count = registry.active_solver_count + 1;
        
        event::emit(SolverReactivated {
            solver: cap.solver,
            timestamp: current_time,
        });
    }

    /// Update solver performance stats
    public fun update_solver_stats(
        registry: &mut SolverRegistry,
        solver: address,
        order_volume: u64,
        success: bool
    ) {
        assert!(table::contains(&registry.solvers, solver), ESolverNotFound);
        
        let solver_info = table::borrow_mut(&mut registry.solvers, solver);
        
        // Update order count and volume
        solver_info.orders_filled = solver_info.orders_filled + 1;
        solver_info.total_volume = solver_info.total_volume + order_volume;
        
        // Update success rate (exponential moving average)
        let new_result = if (success) { 10000 } else { 0 };
        solver_info.success_rate = (solver_info.success_rate * 9 + new_result) / 10;
        
        // Update global stats
        registry.total_orders_filled = registry.total_orders_filled + 1;
        registry.total_volume = registry.total_volume + order_volume;
        
        event::emit(SolverStatsUpdated {
            solver,
            orders_filled: solver_info.orders_filled,
            total_volume: solver_info.total_volume,
            success_rate: solver_info.success_rate,
        });
    }

    /// Update solver metadata
    public fun update_solver_metadata(
        registry: &mut SolverRegistry,
        cap: &SolverCapability,
        new_metadata: vector<u8>,
        ctx: &TxContext
    ) {
        assert!(cap.solver == tx_context::sender(ctx), ENotAuthorized);
        assert!(table::contains(&registry.solvers, cap.solver), ESolverNotFound);
        
        let solver_info = table::borrow_mut(&mut registry.solvers, cap.solver);
        let old_metadata = solver_info.metadata;
        solver_info.metadata = new_metadata;
        
        event::emit(SolverUpdated {
            solver: cap.solver,
            field: b"metadata",
            old_value: old_metadata,
            new_value: new_metadata,
        });
    }

    // ======== Admin Functions ========
    
    public fun set_min_stake(
        registry: &mut SolverRegistry,
        new_min_stake: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.owner, ENotAuthorized);
        registry.min_stake = new_min_stake;
    }

    public fun set_cooldown_period(
        registry: &mut SolverRegistry,
        new_cooldown: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.owner, ENotAuthorized);
        registry.cooldown_period = new_cooldown;
    }

    // ======== View Functions ========
    
    public fun is_solver_active(
        registry: &SolverRegistry,
        solver: address
    ): bool {
        if (table::contains(&registry.solvers, solver)) {
            let info = table::borrow(&registry.solvers, solver);
            info.active
        } else {
            false
        }
    }

    public fun get_solver_info(
        registry: &SolverRegistry,
        solver: address
    ): &SolverInfo {
        assert!(table::contains(&registry.solvers, solver), ESolverNotFound);
        table::borrow(&registry.solvers, solver)
    }

    public fun get_solver_count(registry: &SolverRegistry): (u64, u64) {
        (registry.solver_count, registry.active_solver_count)
    }

    public fun get_total_stats(registry: &SolverRegistry): (u64, u64) {
        (registry.total_orders_filled, registry.total_volume)
    }

    public fun get_min_stake(registry: &SolverRegistry): u64 {
        registry.min_stake
    }

    public fun get_cooldown_period(registry: &SolverRegistry): u64 {
        registry.cooldown_period
    }
}