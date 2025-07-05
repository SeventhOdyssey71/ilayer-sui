module ilayer::simple_swap {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;
    
    use ilayer::types::{Token, token_type_coin};

    // ======== Constants ========
    
    const EXCHANGE_RATE_PRECISION: u64 = 1000000; // 6 decimals
    const DEFAULT_EXCHANGE_RATE: u64 = 1000; // 0.001 (1 SUI = 1000 USDC)

    // ======== Error Codes ========
    
    const EInsufficientInput: u64 = 11001;
    const EInsufficientLiquidity: u64 = 11002;
    const EInvalidPair: u64 = 11003;
    const ESlippageExceeded: u64 = 11004;

    // ======== Structs ========
    
    /// Simple AMM pool for demonstration
    public struct SwapPool<phantom CoinA, phantom CoinB> has key {
        id: UID,
        reserve_a: Balance<CoinA>,
        reserve_b: Balance<CoinB>,
        total_swaps: u64,
        total_volume_a: u64,
        total_volume_b: u64,
    }

    public struct SwapExecuted has copy, drop {
        pool_id: address,
        input_amount: u64,
        output_amount: u64,
        is_a_to_b: bool,
    }

    // ======== Initialization ========
    
    public fun create_pool<CoinA, CoinB>(
        initial_a: Coin<CoinA>,
        initial_b: Coin<CoinB>,
        ctx: &mut TxContext
    ) {
        let pool = SwapPool {
            id: object::new(ctx),
            reserve_a: coin::into_balance(initial_a),
            reserve_b: coin::into_balance(initial_b),
            total_swaps: 0,
            total_volume_a: 0,
            total_volume_b: 0,
        };
        
        transfer::share_object(pool);
    }

    // ======== Public Functions ========
    
    /// Swap CoinA for CoinB
    public fun swap_a_to_b<CoinA, CoinB>(
        pool: &mut SwapPool<CoinA, CoinB>,
        input: Coin<CoinA>,
        min_output: u64,
        ctx: &mut TxContext
    ): Coin<CoinB> {
        let input_amount = coin::value(&input);
        assert!(input_amount > 0, EInsufficientInput);
        
        // Calculate output using constant product formula
        let output_amount = calculate_output(
            input_amount,
            balance::value(&pool.reserve_a),
            balance::value(&pool.reserve_b)
        );
        
        assert!(output_amount >= min_output, ESlippageExceeded);
        assert!(output_amount <= balance::value(&pool.reserve_b), EInsufficientLiquidity);
        
        // Update reserves
        balance::join(&mut pool.reserve_a, coin::into_balance(input));
        let output_balance = balance::split(&mut pool.reserve_b, output_amount);
        
        // Update stats
        pool.total_swaps = pool.total_swaps + 1;
        pool.total_volume_a = pool.total_volume_a + input_amount;
        
        // Emit event
        event::emit(SwapExecuted {
            pool_id: object::id_to_address(&object::uid_to_inner(&pool.id)),
            input_amount,
            output_amount,
            is_a_to_b: true,
        });
        
        coin::from_balance(output_balance, ctx)
    }

    /// Swap CoinB for CoinA
    public fun swap_b_to_a<CoinA, CoinB>(
        pool: &mut SwapPool<CoinA, CoinB>,
        input: Coin<CoinB>,
        min_output: u64,
        ctx: &mut TxContext
    ): Coin<CoinA> {
        let input_amount = coin::value(&input);
        assert!(input_amount > 0, EInsufficientInput);
        
        // Calculate output using constant product formula
        let output_amount = calculate_output(
            input_amount,
            balance::value(&pool.reserve_b),
            balance::value(&pool.reserve_a)
        );
        
        assert!(output_amount >= min_output, ESlippageExceeded);
        assert!(output_amount <= balance::value(&pool.reserve_a), EInsufficientLiquidity);
        
        // Update reserves
        balance::join(&mut pool.reserve_b, coin::into_balance(input));
        let output_balance = balance::split(&mut pool.reserve_a, output_amount);
        
        // Update stats
        pool.total_swaps = pool.total_swaps + 1;
        pool.total_volume_b = pool.total_volume_b + input_amount;
        
        // Emit event
        event::emit(SwapExecuted {
            pool_id: object::id_to_address(&object::uid_to_inner(&pool.id)),
            input_amount,
            output_amount,
            is_a_to_b: false,
        });
        
        coin::from_balance(output_balance, ctx)
    }

    /// Add liquidity to the pool
    public fun add_liquidity<CoinA, CoinB>(
        pool: &mut SwapPool<CoinA, CoinB>,
        coin_a: Coin<CoinA>,
        coin_b: Coin<CoinB>,
        ctx: &TxContext
    ) {
        balance::join(&mut pool.reserve_a, coin::into_balance(coin_a));
        balance::join(&mut pool.reserve_b, coin::into_balance(coin_b));
    }

    // ======== Helper Functions ========
    
    /// Calculate output amount using constant product formula
    /// output = (input * reserve_out) / (reserve_in + input)
    fun calculate_output(
        input_amount: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        let input_with_fee = input_amount * 997; // 0.3% fee
        let numerator = input_with_fee * reserve_out;
        let denominator = (reserve_in * 1000) + input_with_fee;
        numerator / denominator
    }

    /// Calculate required input for desired output
    public fun calculate_input_for_output(
        output_amount: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        let numerator = reserve_in * output_amount * 1000;
        let denominator = (reserve_out - output_amount) * 997;
        (numerator / denominator) + 1
    }

    // ======== View Functions ========
    
    public fun get_reserves<CoinA, CoinB>(
        pool: &SwapPool<CoinA, CoinB>
    ): (u64, u64) {
        (
            balance::value(&pool.reserve_a),
            balance::value(&pool.reserve_b)
        )
    }

    public fun get_exchange_rate<CoinA, CoinB>(
        pool: &SwapPool<CoinA, CoinB>
    ): u64 {
        let (reserve_a, reserve_b) = get_reserves(pool);
        if (reserve_a == 0) {
            return 0
        };
        (reserve_b * EXCHANGE_RATE_PRECISION) / reserve_a
    }

    public fun get_pool_stats<CoinA, CoinB>(
        pool: &SwapPool<CoinA, CoinB>
    ): (u64, u64, u64) {
        (pool.total_swaps, pool.total_volume_a, pool.total_volume_b)
    }

    // ======== Integration with iLayer ========
    
    /// This function can be called by the Executor module
    public fun execute_swap_for_order<CoinA, CoinB>(
        pool: &mut SwapPool<CoinA, CoinB>,
        input: Coin<CoinA>,
        min_output: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let output = swap_a_to_b(pool, input, min_output, ctx);
        transfer::public_transfer(output, recipient);
    }
}