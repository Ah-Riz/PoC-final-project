# Fork Testing Guide

Test Aegis Protocol against a forked Mantle Sepolia testnet locally.

## Why Fork Testing?

**Benefits:**
- ✅ Test against real SP1 verifier deployment (if exists on Mantle Sepolia)
- ✅ No testnet tokens needed
- ✅ Faster iteration (no waiting for block confirmations)
- ✅ Can test with actual network state
- ✅ Reset state anytime

## Quick Start

### Test with Fork
```bash
./test-local.sh --fork
```

or 

```bash
./test-local.sh -f
```

### Test without Fork (Local Only)
```bash
./test-local.sh
```

## What It Does

### With Fork Mode

1. **Forks Mantle Sepolia** at current block height
2. **Checks for SP1 verifier** at known addresses:
   - Groth16: `0x397A5f7f3dBd538f23DE225B51f532c34448dA9B`
   - PLONK: `0x3B6041173B80E77f038f3F2C0f9744f04837185e`
3. **Reports findings:**
   - ✓ Found = Can deploy with real ZK verification
   - ⚠ Not found = Will use MockVerifier for testing
4. **Deploys contracts** to the fork
5. **Runs tests** against forked state

### Output Example

```
╔═══════════════════════════════════════════════════╗
║  Aegis Protocol - Local End-to-End Test Suite   ║
╚═══════════════════════════════════════════════════╝

🌐 Fork mode: Will fork Mantle Sepolia testnet

🔧 Starting Anvil with Mantle Sepolia fork...
   RPC: https://rpc.sepolia.mantle.xyz
✅ Anvil running (PID: 12345)

🔍 Checking for SP1 verifier on Mantle Sepolia...
✓ Found SP1 Groth16 Verifier at 0x397A5f7f3dBd538f23DE225B51f532c34448dA9B
  This means you can deploy with REAL ZK verification!

[2/4] Deploying contracts...
✓ Contracts deployed
...
```

## What You Learn

### If SP1 Verifier Found ✅
**Means:**
- Mantle has deployed SP1 verifier to testnet
- You can deploy with **real ZK proof verification**
- Your proofs will actually be verified on-chain
- Ready for testnet deployment with security

**Next Steps:**
1. Generate real ZK proofs using SP1 SDK
2. Deploy to actual Mantle Sepolia testnet
3. Test deposit and borrow with real proofs
4. Monitor gas costs and performance

### If SP1 Verifier Not Found ⚠
**Means:**
- Mantle hasn't deployed SP1 verifier yet
- Fork testing uses MockVerifier (not secure)
- Still useful for testing contract logic
- Waiting for Mantle's SP1 integration to complete

**Next Steps:**
1. Continue testing contract functionality
2. Prepare ZK proof generation
3. Monitor Mantle documentation for SP1 deployment
4. Test testnet deployment when verifier is available

## Fork Testing vs Local Testing

| Feature | Fork Mode | Local Mode |
|---------|-----------|------------|
| Speed | Medium (RPC calls) | Fast (fully local) |
| Network state | Real Mantle Sepolia | Empty genesis |
| SP1 verifier | Check if deployed | Always mock |
| Gas costs | Real estimates | Real estimates |
| Tokens needed | None | None |
| Internet required | Yes | No |

## Advanced Usage

### Custom Fork Block
```bash
# Fork at specific block
anvil --fork-url https://rpc.sepolia.mantle.xyz \
      --fork-block-number 1234567
```

### Impersonate Accounts
```bash
# Impersonate any account (useful for testing)
cast rpc anvil_impersonateAccount <ADDRESS>
```

### Reset Fork State
```bash
# Reset to original fork state
cast rpc anvil_reset --fork-url https://rpc.sepolia.mantle.xyz
```

## Troubleshooting

### "Failed to start Anvil"
- Check `anvil-fork.log` for details
- Ensure internet connection is stable
- Verify RPC URL is accessible

### "Anvil already running"
```bash
# Kill existing Anvil
pkill -f anvil

# Then retry
./test-local.sh --fork
```

### Fork is slow
- Normal - RPC calls take time
- Use local mode for rapid iteration
- Fork mode for final validation

## When to Use Each Mode

### Use Fork Mode When:
- Testing before testnet deployment
- Verifying SP1 verifier availability
- Testing against real network state
- Validating gas costs

### Use Local Mode When:
- Rapid development iteration
- Testing contract logic changes
- No internet connection
- Just want to see tests pass quickly

## Next Steps After Fork Testing

1. **If SP1 verifier found:**
   - Generate real ZK proofs
   - Deploy to testnet
   - Test full flow with real proofs

2. **If SP1 verifier not found:**
   - Continue development
   - Test with MockVerifier
   - Wait for Mantle SP1 deployment

---

**Status:** Fork testing ready ✅  
**Mantle Sepolia RPC:** https://rpc.sepolia.mantle.xyz  
**Explorer:** https://explorer.sepolia.mantle.xyz
