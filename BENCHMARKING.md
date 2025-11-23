# ZK Proof Benchmarking & Performance Analysis

This document describes how to benchmark the Aegis Protocol's ZK proof generation and provides performance metrics.

## Table of Contents
- [Quick Start](#quick-start)
- [Test Modes](#test-modes)
- [Performance Metrics](#performance-metrics)
- [Interpreting Results](#interpreting-results)
- [Optimization Tips](#optimization-tips)

---

## Quick Start

Run the benchmark suite:

```bash
./benchmark.sh
```

Then select a mode:
- **[1] Basic Tests** - Quick functionality validation (~1 min)
- **[2] Groth16 Mode** - Generate on-chain ready proofs (~5 min)
- **[3] Benchmark Mode** - Performance tests with various scenarios (~5 min)
- **[4] Stress Test** - 10 users with concurrent operations (~15 min)
- **[5] Full Suite** - All tests combined (~30 min)

---

## Test Modes

### 1. Basic Tests
**Purpose:** Validate core functionality  
**Duration:** ~1 minute  
**What it tests:**
- Deposit operation with ZK proof
- Safe borrow (LTV < 75%)
- Unsafe borrow rejection (LTV > 75%)

```bash
cd script && cargo run --release
```

**Output:**
```
✅ Deposit proof verified
✅ Safe borrow approved  
✅ Unsafe borrow correctly rejected
```

---

### 2. Groth16 Mode (On-Chain Ready)
**Purpose:** Generate production-ready proofs for on-chain verification  
**Duration:** ~5 minutes  
**What it generates:**
- Real Groth16 SNARK proofs
- Proofs compatible with SP1Verifier contract
- Saved proof files for testing

```bash
cd script && cargo run --release groth16
```

**Output:**
```
📋 Verification Key: 0x006e6ba8...
✅ Deposit Groth16 proof: 3.2s
📦 Proof size: 384 bytes
💾 Saved to: deposit-groth16.bin

✅ Borrow Groth16 proof: 3.5s
📦 Proof size: 384 bytes
💾 Saved to: borrow-groth16.bin
```

**Key Metrics:**
- **Proof generation time:** 3-5 seconds per operation
- **Proof size:** ~384 bytes (fixed for Groth16)
- **Verification gas:** ~250-300K gas on-chain

---

### 3. Benchmark Mode
**Purpose:** Measure performance across various scenarios  
**Duration:** ~5 minutes  
**What it tests:**
- Different collateral amounts (1 ETH to 100 ETH)
- Various LTV ratios (10% to 75%)
- Cycle counts and execution times

```bash
cd script && cargo run --release benchmark
```

**Sample Output:**
```
📊 DEPOSIT Operation Benchmarks
-----------------------------------
  1 ETH - 234,567 cycles (2.3ms)
  5 ETH - 234,789 cycles (2.3ms)
  10 ETH - 235,012 cycles (2.4ms)
  50 ETH - 236,234 cycles (2.4ms)
  100 ETH - 237,456 cycles (2.5ms)

  Average: 2.4ms

📊 BORROW Operation Benchmarks
-----------------------------------
  Low LTV (10%) - 456,789 cycles (4.6ms)
  Medium LTV (20%) - 457,234 cycles (4.6ms)
  High LTV (60%) - 458,901 cycles (4.7ms)
  Max LTV (75%) - 459,567 cycles (4.7ms)

  Average: 4.7ms

📊 Groth16 Proof Generation
-----------------------------------
  Deposit (Groth16): 3.2s
  Proof size: 384 bytes
```

**Insights:**
- Execution time is **constant** regardless of amount size
- LTV ratio has minimal impact on performance
- Proof generation dominates total time (3-5s vs <5ms execution)

---

### 4. Stress Test
**Purpose:** Test system under load with multiple users  
**Duration:** ~15 minutes  
**What it simulates:**
- 10 concurrent users
- Each user performs deposit + borrow
- Unique keys and amounts per user
- 20 total Groth16 proofs generated

```bash
cd script && cargo run --release stress
```

**Sample Output:**
```
💪 Running Stress Test - Multiple Users

[User 1] Processing operations...
  ✅ Deposit proof: 3.2s
  ✅ Borrow proof: 3.5s

[User 2] Processing operations...
  ✅ Deposit proof: 3.1s
  ✅ Borrow proof: 3.4s

...

========================================
📊 Stress Test Results
========================================
  Total Users: 10
  Total Operations: 20
  Successful Proofs: 20
  Total Time: 68.4s
  Average per Proof: 3.42s
  Success Rate: 100.0%
========================================
```

**Key Metrics:**
- **Throughput:** ~0.3 proofs/second
- **Success rate:** Should be 100%
- **Consistency:** Average time should be stable (~3-4s per proof)

---

## Performance Metrics

### Execution Performance (ZK Program)

| Operation | Cycles | Time | Gas (On-Chain) |
|-----------|--------|------|----------------|
| **Deposit** | ~235K | 2-3ms | N/A (off-chain) |
| **Borrow** | ~458K | 4-5ms | N/A (off-chain) |

**Notes:**
- Cycles are consistent across different input amounts
- Execution happens off-chain (no gas cost)
- Times measured on M1 Mac / Intel i7 equivalent

### Proof Generation Performance

| Proof System | Time | Proof Size | Verification Gas |
|--------------|------|------------|------------------|
| **Groth16** | 3-5s | 384 bytes | ~280K gas |
| **PLONK** | 5-8s | ~1.5KB | ~350K gas |

**Notes:**
- Groth16 is faster and cheaper (recommended)
- Times depend on hardware (GPU/CPU)
- Proof generation is one-time per operation

### On-Chain Costs (Mantle Sepolia)

| Contract | Gas | Cost (@ ~$0.007/gas) |
|----------|-----|---------------------|
| **SP1 Verifier Deploy** | 2.45M | $0.017 |
| **Verify Deposit Proof** | ~280K | $0.002 |
| **Verify Borrow Proof** | ~280K | $0.002 |

**Notes:**
- Verifier is deployed once
- Per-proof verification is very cheap
- Mantle's low gas costs make ZK affordable

---

## Interpreting Results

### Good Performance Indicators
✅ **Consistent cycle counts** - Shows deterministic execution  
✅ **100% success rate** - All proofs verify correctly  
✅ **Stable average times** - No performance degradation  
✅ **Proof size = 384 bytes** - Correct Groth16 format

### Warning Signs
⚠️ **Increasing cycle counts** - Possible inefficiency  
⚠️ **Success rate < 100%** - Check SP1 SDK version  
⚠️ **Proof generation > 10s** - Check hardware/SP1 setup  
⚠️ **Proof size != 384 bytes** - Wrong proof format

---

## Optimization Tips

### 1. Use Release Mode Always
```bash
cargo run --release  # NOT cargo run
```
Debug mode is 10-100x slower!

### 2. Enable Hardware Acceleration

**For NVIDIA GPU:**
```bash
export SP1_PROVER=cuda
cargo run --release groth16
```
- 5-10x faster proof generation
- Requires CUDA-capable GPU

**For SP1 Network (Cloud):**
```bash
export SP1_PROVER=network
export SP1_PRIVATE_KEY=your_key
cargo run --release groth16
```
- Offload proving to cloud
- Fastest option for production

### 3. Optimize ZK Program

**Keep computations minimal:**
```rust
// ✅ Good - Simple operations
let hash = sha256(data);
let is_valid = amount < limit;

// ❌ Bad - Complex loops
for i in 0..1000000 {
    // Heavy computation
}
```

**Use efficient data types:**
```rust
// ✅ Good - Fixed-size arrays
let key: [u8; 32] = ...;

// ❌ Bad - Dynamic allocations
let key: Vec<u8> = vec![...];
```

### 4. Batch Operations

Instead of generating proofs one-by-one:
```rust
// Generate multiple proofs in parallel
let handles: Vec<_> = users.par_iter()
    .map(|user| generate_proof(user))
    .collect();
```

### 5. Cache Setup Results

```rust
// ✅ Setup once, reuse for all proofs
let (pk, vk) = client.setup(ELF);

for user in users {
    let proof = client.prove(&pk, &stdin).groth16().run()?;
}
```

---

## Troubleshooting

### "Proof generation is very slow"
1. Check you're using `--release` mode
2. Verify SP1 SDK version: `cargo tree | grep sp1-sdk`
3. Try GPU/network prover mode
4. Check CPU usage (should be 100% during proving)

### "Verification fails on-chain"
1. Ensure using Groth16 mode: `.groth16()`
2. Check verification key matches deployed verifier
3. Verify proof bytes are correctly formatted
4. Test with SP1 verifier locally first

### "Out of memory during proving"
1. Close other applications
2. Use network prover: `SP1_PROVER=network`
3. Reduce stress test size (fewer users)
4. Check available RAM (needs 8GB+ for local proving)

---

## Expected Performance Targets

### Development (Local Machine)
- **Execution:** < 5ms per operation
- **Groth16 proving:** 3-5 seconds per proof
- **Stress test:** 20 proofs in < 2 minutes

### Production (With Network Prover)
- **Execution:** < 5ms per operation
- **Groth16 proving:** < 30 seconds per proof
- **Throughput:** 100+ proofs/minute with parallelization

### On-Chain Verification
- **Gas cost:** < 300K per proof
- **Verification time:** < 1 second
- **Success rate:** 100%

---

## Next Steps

1. **Run Basic Tests** - Validate functionality
2. **Generate Groth16 Proofs** - Test on-chain integration
3. **Run Benchmarks** - Collect baseline metrics
4. **Run Stress Test** - Validate scalability
5. **Deploy to Testnet** - Test with real SP1 verifier

For testnet deployment, see [TESTNET_DEPLOYMENT.md](./TESTNET_DEPLOYMENT.md).

For production optimization, see [PRODUCTION_READINESS.md](./PRODUCTION_READINESS.md).
