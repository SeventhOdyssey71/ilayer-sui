module ilayer::fee_manager {
    use std::vector;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::sui::SUI;

    // ======== Constants ========
    
    const BASIS_POINTS: u64 = 10000;
    const MAX_FEE: u64 = 1000; // 10%
    const DEFAULT_PROTOCOL_FEE: u64 = 30; // 0.3%
    const DEFAULT_SOLVER_FEE: u64 = 20; // 0.2%

    // ======== Error Codes ========
    
    const ENotAuthorized: u64 = 9001;
    const EFeeTooHigh: u64 = 9002;
    const EInsufficientBalance: u64 = 9003;
    const EInvalidRecipient: u64 = 9004;

    // ======== Structs ========
    
    public struct FeeManager has key {
        id: UID,
        owner: address,
        protocol_fee_recipient: address,
        protocol_fee_basis_points: u64,
        solver_fee_basis_points: u64,
        // Accumulated fees by token type
        fee_balances: Table<vector<u8>, Balance<SUI>>,
        // Total fees collected
        total_fees_collected: u64,
        // Fee splits by address
        fee_splits: Table<address, u64>,
    }

    public struct FeeConfig has store, copy, drop {
        protocol_fee_basis_points: u64,
        solver_fee_basis_points: u64,
        total_fee_basis_points: u64,
    }

    // ======== Events ========
    
    public struct FeeCollected has copy, drop {
        token_type: vector<u8>,
        amount: u64,
        protocol_fee: u64,
        solver_fee: u64,
    }

    public struct FeeWithdrawn has copy, drop {
        recipient: address,
        token_type: vector<u8>,
        amount: u64,
    }

    public struct FeeUpdated has copy, drop {
        fee_type: vector<u8>,
        old_value: u64,
        new_value: u64,
    }

    // ======== Initialization ========
    
    fun init(ctx: &mut TxContext) {
        let fee_manager = FeeManager {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            protocol_fee_recipient: tx_context::sender(ctx),
            protocol_fee_basis_points: DEFAULT_PROTOCOL_FEE,
            solver_fee_basis_points: DEFAULT_SOLVER_FEE,
            fee_balances: table::new(ctx),
            total_fees_collected: 0,
            fee_splits: table::new(ctx),
        };
        
        transfer::share_object(fee_manager);
    }

    // ======== Public Functions ========
    
    /// Calculate fees for an order
    public fun calculate_fees(
        fee_manager: &FeeManager,
        amount: u64,
        is_sponsored: bool
    ): (u64, u64, u64) {
        if (is_sponsored) {
            return (0, 0, 0)
        };
        
        let protocol_fee = (amount * fee_manager.protocol_fee_basis_points) / BASIS_POINTS;
        let solver_fee = (amount * fee_manager.solver_fee_basis_points) / BASIS_POINTS;
        let total_fee = protocol_fee + solver_fee;
        
        (total_fee, protocol_fee, solver_fee)
    }

    /// Collect fees from an order
    public fun collect_fees<T>(
        fee_manager: &mut FeeManager,
        payment: &mut Coin<T>,
        amount: u64,
        is_sponsored: bool,
        solver: address,
        ctx: &mut TxContext
    ): (u64, u64) {
        let (total_fee, protocol_fee, solver_fee) = calculate_fees(fee_manager, amount, is_sponsored);
        
        if (total_fee == 0) {
            return (0, 0)
        };
        
        // Split the fee from payment
        let fee_coin = coin::split(payment, total_fee, ctx);
        let fee_balance = coin::into_balance(fee_coin);
        
        // Store fee balance
        let token_type = b"SUI"; // In production, get actual token type
        if (!table::contains(&fee_manager.fee_balances, token_type)) {
            table::add(&mut fee_manager.fee_balances, token_type, balance::zero<SUI>());
        };
        
        let stored_balance = table::borrow_mut(&mut fee_manager.fee_balances, token_type);
        balance::join(stored_balance, fee_balance);
        
        // Update fee splits
        update_fee_split(fee_manager, fee_manager.protocol_fee_recipient, protocol_fee);
        update_fee_split(fee_manager, solver, solver_fee);
        
        // Update total collected
        fee_manager.total_fees_collected = fee_manager.total_fees_collected + total_fee;
        
        // Emit event
        event::emit(FeeCollected {
            token_type,
            amount: total_fee,
            protocol_fee,
            solver_fee,
        });
        
        (protocol_fee, solver_fee)
    }

    /// Withdraw accumulated fees
    public fun withdraw_fees(
        fee_manager: &mut FeeManager,
        token_type: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Check authorization
        assert!(
            table::contains(&fee_manager.fee_splits, sender) && 
            *table::borrow(&fee_manager.fee_splits, sender) > 0,
            ENotAuthorized
        );
        
        // Get claimable amount
        let claimable = *table::borrow(&fee_manager.fee_splits, sender);
        
        // Check balance available
        assert!(table::contains(&fee_manager.fee_balances, token_type), EInsufficientBalance);
        let balance = table::borrow_mut(&mut fee_manager.fee_balances, token_type);
        let available = balance::value(balance);
        
        assert!(available >= claimable, EInsufficientBalance);
        
        // Withdraw balance
        let withdraw_balance = balance::split(balance, claimable);
        let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
        
        // Reset fee split
        *table::borrow_mut(&mut fee_manager.fee_splits, sender) = 0;
        
        // Transfer to recipient
        transfer::public_transfer(withdraw_coin, recipient);
        
        // Emit event
        event::emit(FeeWithdrawn {
            recipient,
            token_type,
            amount: claimable,
        });
    }

    // ======== Admin Functions ========
    
    public fun set_protocol_fee(
        fee_manager: &mut FeeManager,
        new_fee: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == fee_manager.owner, ENotAuthorized);
        assert!(new_fee <= MAX_FEE, EFeeTooHigh);
        
        let old_fee = fee_manager.protocol_fee_basis_points;
        fee_manager.protocol_fee_basis_points = new_fee;
        
        event::emit(FeeUpdated {
            fee_type: b"protocol",
            old_value: old_fee,
            new_value: new_fee,
        });
    }

    public fun set_solver_fee(
        fee_manager: &mut FeeManager,
        new_fee: u64,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == fee_manager.owner, ENotAuthorized);
        assert!(new_fee <= MAX_FEE, EFeeTooHigh);
        
        let old_fee = fee_manager.solver_fee_basis_points;
        fee_manager.solver_fee_basis_points = new_fee;
        
        event::emit(FeeUpdated {
            fee_type: b"solver",
            old_value: old_fee,
            new_value: new_fee,
        });
    }

    public fun set_protocol_fee_recipient(
        fee_manager: &mut FeeManager,
        new_recipient: address,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == fee_manager.owner, ENotAuthorized);
        assert!(new_recipient != @0x0, EInvalidRecipient);
        
        fee_manager.protocol_fee_recipient = new_recipient;
    }

    // ======== Internal Functions ========
    
    fun update_fee_split(
        fee_manager: &mut FeeManager,
        recipient: address,
        amount: u64
    ) {
        if (!table::contains(&fee_manager.fee_splits, recipient)) {
            table::add(&mut fee_manager.fee_splits, recipient, 0);
        };
        
        let current = table::borrow_mut(&mut fee_manager.fee_splits, recipient);
        *current = *current + amount;
    }

    // ======== View Functions ========
    
    public fun get_fee_config(fee_manager: &FeeManager): FeeConfig {
        FeeConfig {
            protocol_fee_basis_points: fee_manager.protocol_fee_basis_points,
            solver_fee_basis_points: fee_manager.solver_fee_basis_points,
            total_fee_basis_points: fee_manager.protocol_fee_basis_points + fee_manager.solver_fee_basis_points,
        }
    }

    public fun get_claimable_fees(
        fee_manager: &FeeManager,
        address: address
    ): u64 {
        if (table::contains(&fee_manager.fee_splits, address)) {
            *table::borrow(&fee_manager.fee_splits, address)
        } else {
            0
        }
    }

    public fun get_total_fees_collected(fee_manager: &FeeManager): u64 {
        fee_manager.total_fees_collected
    }

    public fun get_protocol_fee_recipient(fee_manager: &FeeManager): address {
        fee_manager.protocol_fee_recipient
    }
}