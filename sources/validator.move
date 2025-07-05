module ilayer::validator {
    use sui::bcs;
    use sui::hash;
    use sui::ed25519;
    use ilayer::types::{Order, OrderRequest};

    // ======== Constants ========
    
    const DOMAIN_NAME: vector<u8> = b"iLayer";
    const DOMAIN_VERSION: vector<u8> = b"1";
    
    // ======== Error Codes ========
    
    // const EInvalidSignature: u64 = 2001; // Unused
    // const EInvalidPublicKey: u64 = 2002; // Unused
    // const ESignatureMismatch: u64 = 2003; // Unused

    // ======== Structs ========
    
    public struct DomainSeparator has store, drop, copy {
        name: vector<u8>,
        version: vector<u8>,
        chain_id: u32,
        verifying_contract: address,
    }

    // ======== Public Functions ========
    
    public fun new_domain_separator(
        chain_id: u32,
        verifying_contract: address
    ): DomainSeparator {
        DomainSeparator {
            name: DOMAIN_NAME,
            version: DOMAIN_VERSION,
            chain_id,
            verifying_contract,
        }
    }

    public fun validate_order_request(
        request: &OrderRequest,
        signature: vector<u8>,
        public_key: vector<u8>,
        domain: &DomainSeparator
    ): bool {
        // Verify the signature matches the order request
        let message = order_request_hash(request, domain);
        verify_signature(message, signature, public_key)
    }

    public fun validate_order(
        order: &Order,
        signature: vector<u8>,
        public_key: vector<u8>,
        domain: &DomainSeparator
    ): bool {
        // Verify the signature matches the order
        let message = order_hash(order, domain);
        verify_signature(message, signature, public_key)
    }

    // ======== Internal Functions ========
    
    fun order_request_hash(
        request: &OrderRequest,
        domain: &DomainSeparator
    ): vector<u8> {
        // Create structured hash similar to EIP-712
        let mut data = vector::empty<u8>();
        
        // Add domain separator
        vector::append(&mut data, domain_separator_hash(domain));
        
        // Add order request data
        vector::append(&mut data, bcs::to_bytes(request));
        
        // Return keccak256 hash
        hash::keccak256(&data)
    }

    fun order_hash(
        order: &Order,
        domain: &DomainSeparator
    ): vector<u8> {
        // Create structured hash
        let mut data = vector::empty<u8>();
        
        // Add domain separator
        vector::append(&mut data, domain_separator_hash(domain));
        
        // Add order data
        vector::append(&mut data, bcs::to_bytes(order));
        
        // Return keccak256 hash
        hash::keccak256(&data)
    }

    fun domain_separator_hash(domain: &DomainSeparator): vector<u8> {
        let mut data = vector::empty<u8>();
        
        // Structured data: name, version, chainId, verifyingContract
        vector::append(&mut data, domain.name);
        vector::append(&mut data, domain.version);
        vector::append(&mut data, bcs::to_bytes(&domain.chain_id));
        vector::append(&mut data, bcs::to_bytes(&domain.verifying_contract));
        
        hash::keccak256(&data)
    }

    fun verify_signature(
        message: vector<u8>,
        signature: vector<u8>,
        public_key: vector<u8>
    ): bool {
        // Verify ED25519 signature
        if (vector::length(&signature) != 64) {
            return false
        };
        
        if (vector::length(&public_key) != 32) {
            return false
        };
        
        ed25519::ed25519_verify(&signature, &public_key, &message)
    }

    // ======== Test Functions ========
    
    #[test_only]
    public fun test_domain_separator(): DomainSeparator {
        new_domain_separator(1, @0x1)
    }
}