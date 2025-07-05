# GiftDrop CustomWallet.tsx Bug Fix

## Problem
The error occurs at line 225 in `CustomWallet.tsx`:
```typescript
const res = await signMessage({ message: ToUint8Array(message) });
```

The issue is likely that:
1. `ToUint8Array` is not defined or imported
2. The `signMessage` function expects a different format

## Solution

Replace the problematic line with one of these solutions:

### Solution 1: Use TextEncoder (Recommended)
```typescript
const message = `I'm using GiftDrop at ${now} with wallet ${address}`;
try {
  // Convert string to Uint8Array using TextEncoder
  const messageBytes = new TextEncoder().encode(message);
  const res = await signMessage({ message: messageBytes });
  if (!res?.signature) {
    throw new Error("Signature is required");
  }
  // ... rest of the code
}
```

### Solution 2: If using Sui dApp Kit
```typescript
import { useSignMessage } from '@mysten/dapp-kit';

// In your component
const { mutateAsync: signMessage } = useSignMessage();

const walletSignIn = async () => {
  const message = `I'm using GiftDrop at ${now} with wallet ${address}`;
  try {
    const res = await signMessage({ 
      message: new TextEncoder().encode(message) 
    });
    if (!res?.signature) {
      throw new Error("Signature is required");
    }
    // ... rest of the code
  } catch (error) {
    console.error('Sign message error:', error);
  }
}
```

### Solution 3: If ToUint8Array is a custom utility
```typescript
// Add this utility function if missing
function ToUint8Array(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

// Or import it if it exists elsewhere
import { ToUint8Array } from '../utils'; // adjust path as needed
```

## Full Context Fix

Here's what the complete function should look like:

```typescript
const walletSignIn = async () => {
  if (!address) {
    throw new Error("Wallet address is required");
  }
  
  const now = new Date().toISOString();
  const message = `I'm using GiftDrop at ${now} with wallet ${address}`;
  
  try {
    // Convert string to Uint8Array
    const messageBytes = new TextEncoder().encode(message);
    
    const res = await signMessage({ message: messageBytes });
    
    if (!res?.signature) {
      throw new Error("Signature is required");
    }
    
    // Process the signature
    // ... rest of your code
    
  } catch (error) {
    console.error('Failed to sign message:', error);
    throw error;
  }
};
```

## Additional Notes

1. Make sure you have the correct imports at the top of the file
2. Verify that `signMessage` is properly initialized from your wallet context
3. Check that the wallet is connected before attempting to sign
4. Handle errors appropriately for better user experience