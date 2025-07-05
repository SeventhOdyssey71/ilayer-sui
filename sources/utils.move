module ilayer::utils {

    // ======== Constants ========
    
    // const EEMPTY_VECTOR: u64 = 8001; // Unused
    const EINVALID_LENGTH: u64 = 8002;
    const EINDEX_OUT_OF_BOUNDS: u64 = 8003;

    // ======== Byte Utilities ========
    
    /// Convert bytes32 (vector<u8>) to address
    public fun bytes_to_address(bytes: vector<u8>): address {
        assert!(vector::length(&bytes) == 32, EINVALID_LENGTH);
        sui::address::from_bytes(bytes)
    }

    /// Convert address to bytes32 (vector<u8>)
    public fun address_to_bytes(addr: address): vector<u8> {
        sui::address::to_bytes(addr)
    }

    /// Slice a vector from start to end (exclusive)
    public fun slice<T: copy>(v: &vector<T>, start: u64, end: u64): vector<T> {
        assert!(start <= end, EINDEX_OUT_OF_BOUNDS);
        assert!(end <= vector::length(v), EINDEX_OUT_OF_BOUNDS);
        
        let mut result = vector::empty<T>();
        let mut i = start;
        
        while (i < end) {
            vector::push_back(&mut result, *vector::borrow(v, i));
            i = i + 1;
        };
        
        result
    }

    /// Concatenate two vectors
    public fun concat<T: copy>(v1: vector<T>, v2: vector<T>): vector<T> {
        let mut result = v1;
        vector::append(&mut result, v2);
        result
    }

    /// Convert u64 to bytes (big-endian)
    public fun u64_to_bytes(value: u64): vector<u8> {
        let mut bytes = vector::empty<u8>();
        let mut i = 8;
        
        while (i > 0) {
            i = i - 1;
            vector::push_back(&mut bytes, ((value >> (i * 8)) & 0xFF as u8));
        };
        
        bytes
    }

    /// Convert u32 to bytes (big-endian)
    public fun u32_to_bytes(value: u32): vector<u8> {
        let mut bytes = vector::empty<u8>();
        let mut i = 4;
        
        while (i > 0) {
            i = i - 1;
            vector::push_back(&mut bytes, ((value >> (i * 8)) & 0xFF as u8));
        };
        
        bytes
    }

    /// Check if two vectors are equal
    public fun vector_equals<T: drop>(v1: &vector<T>, v2: &vector<T>): bool {
        let len = vector::length(v1);
        if (len != vector::length(v2)) {
            return false
        };
        
        let mut i = 0;
        while (i < len) {
            if (vector::borrow(v1, i) != vector::borrow(v2, i)) {
                return false
            };
            i = i + 1;
        };
        
        true
    }

    /// Pad bytes to specified length (right padding with zeros)
    public fun pad_right(bytes: vector<u8>, length: u64): vector<u8> {
        let current_length = vector::length(&bytes);
        if (current_length >= length) {
            return bytes
        };
        
        let mut result = bytes;
        let padding_needed = length - current_length;
        let mut i = 0;
        
        while (i < padding_needed) {
            vector::push_back(&mut result, 0);
            i = i + 1;
        };
        
        result
    }

    /// Remove trailing zeros from bytes
    public fun trim_zeros(bytes: vector<u8>): vector<u8> {
        let len = vector::length(&bytes);
        if (len == 0) {
            return bytes
        };
        
        let mut end = len;
        while (end > 0 && *vector::borrow(&bytes, end - 1) == 0) {
            end = end - 1;
        };
        
        if (end == len) {
            bytes
        } else {
            slice(&bytes, 0, end)
        }
    }

    // ======== Order Formatting Helpers ========
    
    /// Format order ID from order hash and nonce
    public fun format_order_id(order_hash: vector<u8>, nonce: u64): vector<u8> {
        let mut id = order_hash;
        vector::append(&mut id, u64_to_bytes(nonce));
        id
    }

    /// Extract chain ID from cross-chain message
    public fun extract_chain_id(message: &vector<u8>): u32 {
        assert!(vector::length(message) >= 4, EINVALID_LENGTH);
        
        let mut chain_id = 0u32;
        let mut i = 0;
        
        while (i < 4) {
            chain_id = (chain_id << 8) | (*vector::borrow(message, i) as u32);
            i = i + 1;
        };
        
        chain_id
    }

    // ======== Testing Helpers ========
    
    #[test_only]
    public fun create_test_bytes(length: u64): vector<u8> {
        let mut bytes = vector::empty<u8>();
        let mut i = 0;
        
        while (i < length) {
            vector::push_back(&mut bytes, ((i % 256) as u8));
            i = i + 1;
        };
        
        bytes
    }

    #[test_only]
    public fun assert_vectors_equal<T: drop>(v1: &vector<T>, v2: &vector<T>) {
        assert!(vector_equals(v1, v2), 0);
    }
}