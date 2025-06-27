module ilayer::token_registry {
    use std::vector;
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;

    // ======== Error Codes ========
    
    const ENotOwner: u64 = 6001;
    const ETokenAlreadyRegistered: u64 = 6002;
    const ETokenNotRegistered: u64 = 6003;
    const EInvalidTokenType: u64 = 6004;

    // ======== Structs ========
    
    public struct TokenRegistry has key {
        id: UID,
        owner: address,
        // Map token type string to TokenInfo
        tokens: Table<String, TokenInfo>,
        // Map chain ID to supported tokens
        chain_tokens: Table<u32, vector<String>>,
    }

    public struct TokenInfo has store, copy, drop {
        symbol: String,
        decimals: u8,
        token_type: u8, // From types module
        // Chain ID -> Token address on that chain
        addresses: Table<u32, vector<u8>>,
        active: bool,
    }

    public struct TokenRegistered has copy, drop {
        token_type: String,
        symbol: String,
        chain_id: u32,
    }

    public struct TokenDeactivated has copy, drop {
        token_type: String,
    }

    // ======== Initialization ========
    
    fun init(ctx: &mut TxContext) {
        let registry = TokenRegistry {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            tokens: table::new(ctx),
            chain_tokens: table::new(ctx),
        };
        
        transfer::share_object(registry);
    }

    // ======== Public Functions ========
    
    public fun register_token(
        registry: &mut TokenRegistry,
        token_type_str: String,
        symbol: String,
        decimals: u8,
        token_type: u8,
        chain_id: u32,
        address: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.owner, ENotOwner);
        
        if (!table::contains(&registry.tokens, token_type_str)) {
            // Create new token info
            let mut token_info = TokenInfo {
                symbol,
                decimals,
                token_type,
                addresses: table::new(ctx),
                active: true,
            };
            
            table::add(&mut token_info.addresses, chain_id, address);
            table::add(&mut registry.tokens, token_type_str, token_info);
            
            // Add to chain tokens
            if (!table::contains(&registry.chain_tokens, chain_id)) {
                table::add(&mut registry.chain_tokens, chain_id, vector::empty());
            };
            
            let chain_tokens = table::borrow_mut(&mut registry.chain_tokens, chain_id);
            vector::push_back(chain_tokens, token_type_str);
            
        } else {
            // Update existing token info
            let token_info = table::borrow_mut(&mut registry.tokens, token_type_str);
            
            if (!table::contains(&token_info.addresses, chain_id)) {
                table::add(&mut token_info.addresses, chain_id, address);
                
                // Add to chain tokens if not already there
                if (!table::contains(&registry.chain_tokens, chain_id)) {
                    table::add(&mut registry.chain_tokens, chain_id, vector::empty());
                };
                
                let chain_tokens = table::borrow_mut(&mut registry.chain_tokens, chain_id);
                if (!vector::contains(chain_tokens, &token_type_str)) {
                    vector::push_back(chain_tokens, token_type_str);
                };
            };
        };
        
        event::emit(TokenRegistered {
            token_type: token_type_str,
            symbol,
            chain_id,
        });
    }

    public fun deactivate_token(
        registry: &mut TokenRegistry,
        token_type: String,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.owner, ENotOwner);
        assert!(table::contains(&registry.tokens, token_type), ETokenNotRegistered);
        
        let token_info = table::borrow_mut(&mut registry.tokens, token_type);
        token_info.active = false;
        
        event::emit(TokenDeactivated { token_type });
    }

    public fun update_token_address(
        registry: &mut TokenRegistry,
        token_type: String,
        chain_id: u32,
        new_address: vector<u8>,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.owner, ENotOwner);
        assert!(table::contains(&registry.tokens, token_type), ETokenNotRegistered);
        
        let token_info = table::borrow_mut(&mut registry.tokens, token_type);
        
        if (table::contains(&token_info.addresses, chain_id)) {
            *table::borrow_mut(&mut token_info.addresses, chain_id) = new_address;
        } else {
            table::add(&mut token_info.addresses, chain_id, new_address);
        };
    }

    // ======== View Functions ========
    
    public fun get_token_info(
        registry: &TokenRegistry,
        token_type: String
    ): &TokenInfo {
        assert!(table::contains(&registry.tokens, token_type), ETokenNotRegistered);
        table::borrow(&registry.tokens, token_type)
    }

    public fun get_token_address(
        registry: &TokenRegistry,
        token_type: String,
        chain_id: u32
    ): vector<u8> {
        let token_info = get_token_info(registry, token_type);
        
        if (table::contains(&token_info.addresses, chain_id)) {
            *table::borrow(&token_info.addresses, chain_id)
        } else {
            vector::empty()
        }
    }

    public fun is_token_active(
        registry: &TokenRegistry,
        token_type: String
    ): bool {
        if (table::contains(&registry.tokens, token_type)) {
            let token_info = table::borrow(&registry.tokens, token_type);
            token_info.active
        } else {
            false
        }
    }

    public fun get_chain_tokens(
        registry: &TokenRegistry,
        chain_id: u32
    ): vector<String> {
        if (table::contains(&registry.chain_tokens, chain_id)) {
            *table::borrow(&registry.chain_tokens, chain_id)
        } else {
            vector::empty()
        }
    }

    // ======== Helper Functions ========
    
    public fun create_token_type_string(prefix: vector<u8>, suffix: vector<u8>): String {
        let mut full = prefix;
        vector::append(&mut full, suffix);
        string::utf8(full)
    }
}