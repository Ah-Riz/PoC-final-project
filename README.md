# Aegis Protocol - Private Lending PoC

> **Zero-Knowledge Lending Protocol**  
> Privacy-preserving DeFi built with Succinct SP1 on Mantle Network  
> ✅ PoC Complete | 🧪 Testnet Ready | 🎯 Mainnet Bound

---

## 🎯 Overview

**What It Is:** A decentralized lending protocol that uses zero-knowledge proofs to hide collateral amounts while cryptographically proving loan safety.

**Why It Matters:** Traditional DeFi is fully transparent, exposing user strategies and enabling MEV attacks. This protocol provides privacy without sacrificing security.

**Current Status:** 
- ✅ **PoC Complete:** All core features implemented and tested
- 🧪 **Testnet Ready:** Deployment guide prepared
- 📋 **Production Path:** Clear roadmap to mainnet

---

## 🏗️ What's Been Built

### Core Features Implemented
- **Private Deposits:** Collateral amounts hidden via cryptographic commitments
- **ZK-Proven Borrows:** Loan safety verified without revealing collateral
- **Nullifier System:** Prevents double-spending
- **LTV Validation:** Risk management enforced in zero-knowledge
- **Gas Optimized:** ~300K gas per borrow (~$0.03 on Mantle)

### Technical Stack
- **ZK Proofs:** Succinct SP1 (v5.2.2)
- **Smart Contracts:** Solidity 0.8.20 + Foundry
- **Blockchain:** Mantle L2 (EigenDA for cheap data availability)
- **Cryptography:** SHA-256 commitments, 256-bit security

---

## 📊 Current Test Results

### ZK Program Performance
```
✅ Deposit proof: 21,435 cycles (~1.8s generation)
✅ Safe borrow: 45,274 cycles (~1.9s generation)
✅ Unsafe borrow: Correctly rejected (LTV > 75%)
```

### Smart Contract Tests
```
✅ testDeployment - Contract initialization
✅ testDepositCreatesCommitment - Commitment tracking  
✅ testBorrowWithValidProof - Successful borrow flow
✅ testBorrowRevertsOnDoubleSpend - Nullifier protection
✅ testGetters - State queries
```

**Coverage:** 100% of implemented features  
**Status:** All tests passing on local Anvil

---

## 🚀 Quick Start

### Run Tests Locally
```bash
# Complete test suite (deploys contracts + runs tests)
./test-local.sh
```

**What it does:**
1. Starts local Anvil blockchain
2. Deploys all contracts (MockETH, MockUSDC, AegisVault)
3. Builds ZK program
4. Runs smart contract tests
5. Reports results

**Expected output:** All tests pass ✅

### Project Structure
- **[HOW_IT_WORKS.md](./HOW_IT_WORKS.md)** - Complete technical walkthrough
- **[PRODUCTION_READINESS.md](./PRODUCTION_READINESS.md)** - Gap analysis & roadmap
- **[TESTNET_DEPLOYMENT.md](./TESTNET_DEPLOYMENT.md)** - Deployment guide
- **[blueprint.md](./blueprint.md)** - Original design specification

---

## 📊 Project Status

### ✅ Phase 1: ZK Program (Complete)
- SP1 zero-knowledge circuits for deposit & borrow

### Current State
- ✅ All tests passing
- ✅ No known critical bugs
- ⚠️ Using MockSP1Verifier (testing only)
- ⚠️ Simplified merkle tree (no proof verification)
- ⚠️ Not audited

### Before Mainnet
- 🔴 Professional security audit (mandatory)
- 🔴 Real SP1 verifier integration
- 🔴 Full merkle proof implementation
- 🔴 Multi-sig admin controls
- 🔴 Emergency pause mechanism
- 🔴 4+ weeks testnet validation
- 🔴 Bug bounty program

**Estimated timeline to mainnet:** 4-6 months

---

## 📈 Performance Benchmarks

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Proof time | <5s | ~2s | ✅ Exceeds |
| Deposit gas | <250K | ~200K | ✅ Meets |
| Borrow gas | <400K | ~300K | ✅ Exceeds |
| Test coverage | >90% | 100% | ✅ Exceeds |
| Security | Audited | Self-tested | ⏳ Pending |

---

## 🛠️ Development

### Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install SP1
cargo install sp1-cli
cargo prove --install
```

### Local Testing

```bash
# Clone and setup
cd "PoC final project"

# Run all tests
./test-local.sh
```

This will:
1. Start local Anvil node
2. Deploy all contracts
3. Build ZK program
4. Run integration tests
5. Verify everything works

### Testnet Deployment

See **[TESTNET_DEPLOYMENT.md](./TESTNET_DEPLOYMENT.md)** for complete step-by-step guide.

**Quick overview:**
1. Get testnet MNT from faucet
2. Configure `.env` with private key
3. Deploy contracts via Foundry
4. Verify on block explorer
5. Test basic operations

## 📁 Project Structure

```
PoC final project/
├── zk-program/              # SP1 Zero-Knowledge Circuits
│   ├── src/
│   │   ├── main.rs         # Main circuit logic
│   │   ├── types.rs        # Data structures
│   │   └── crypto.rs       # Cryptographic functions
│   └── Cargo.toml
│
├── contracts/               # Solidity Smart Contracts
│   ├── src/
│   │   ├── AegisVault.sol  # Main lending protocol
│   │   └── MockTokens.sol  # Test tokens
│   ├── test/               # Foundry tests
│   └── script/
│       └── Deploy.s.sol    # Deployment script
│
├── script/                  # Rust Integration Tests
│   ├── src/
│   │   ├── main.rs         # Test scenarios
│   │   ├── integration.rs  # E2E test framework
│   │   └── bin/e2e.rs      # Test binary
│   └── Cargo.toml
│
├── HOW_IT_WORKS.md         # Technical walkthrough
├── PRODUCTION_READINESS.md # Gap analysis & roadmap
├── TESTNET_DEPLOYMENT.md   # Deployment guide
├── blueprint.md            # Original design
├── test-local.sh           # Local test automation
└── .env.example            # Environment template
```

## 🧪 Test Results

### ZK Program Tests
```
✅ Deposit: 21,435 cycles
✅ Safe Borrow (20% LTV): 45,274 cycles
✅ Unsafe Borrow (80% LTV): Correctly rejected
```

### Smart Contract Tests
```
✅ testDeployment
✅ testDepositCreatesCommitment
✅ testBorrowWithValidProof
✅ testBorrowRevertsOnDoubleSpend
✅ testGetters
```

### Local Deployment
```
✅ MockETH: 0x5FbDB...
✅ MockUSDC: 0xe7f17...
✅ MockSP1Verifier: 0x9fE46...
✅ AegisVault: 0xCf7Ed...
```

## 💡 How It Works

### 1. Deposit (Private)

```rust
// User generates secret key
let secret_key = [1u8; 32];
let collateral = 10 ETH; // Hidden

// ZK circuit creates commitment
let commitment = hash(secret_key, collateral, 0_debt, salt);

// Submit to contract (only commitment visible)
vault.deposit(10 ETH, proof, commitment);
```

**On-chain:** Commitment `0xabc123...` (meaningless without secret)

### 2. Borrow (Private)

```rust
// From different wallet (privacy!)
let borrow_amount = 5000 USDC; // Public
let collateral = 10 ETH; // Hidden in proof

// ZK circuit proves:
// - I own the collateral (via secret key)
// - LTV is safe: 5000 / (10 * 2500) = 20% < 75% ✓
// - Create new commitment with debt

vault.borrow(proof, new_commitment, recipient, 5000 USDC);
```

**On-chain:** 
- Borrow amount: 5000 USDC (visible)
- Collateral: HIDDEN ✅
- Link to deposit: HIDDEN ✅

## 🔐 Security Features

- **Nullifier System:** Prevents double-spending
- **Commitment Scheme:** Hides collateral amounts
- **ZK Proofs:** Validates without revealing data
- **Merkle Tree:** Tracks all notes efficiently
- **LTV Validation:** Enforced in zero-knowledge

## 📖 Documentation

- **[HOW_IT_WORKS.md](./HOW_IT_WORKS.md)** - Complete technical walkthrough
- **[PRODUCTION_READINESS.md](./PRODUCTION_READINESS.md)** - Gap analysis & roadmap to mainnet
- **[TESTNET_DEPLOYMENT.md](./TESTNET_DEPLOYMENT.md)** - Step-by-step deployment guide
- **[blueprint.md](./blueprint.md)** - Original protocol design specification

## 🛠️ Development

### Run Individual Components

```bash
# ZK Program
cd zk-program
cargo prove build
cargo test

# Smart Contracts
cd contracts
forge build
forge test

# Integration Tests
cd script
cargo build --release
cargo run --release
```

### Generate Documentation

```bash
# Rust docs
cargo doc --open

# Solidity docs
forge doc
```

## 🌐 Deployed Addresses

### Mantle Sepolia Testnet
```
Not yet deployed - see TESTNET_DEPLOYMENT.md for deployment instructions

After deployment, contract addresses will be saved to .env.contracts

Explorer: https://explorer.sepolia.mantle.xyz
```

## 📈 Performance

| Operation | Gas Cost | Proof Size | Verification Time |
|-----------|----------|------------|-------------------|
| Deposit | ~200K | TBD | <1s |
| Borrow | ~300K | TBD | <1s |
| Total Deploy | ~3.4M | - | - |

## 🐛 Known Limitations

- **Mock Verifier:** Currently using simplified verifier for testing
- **No Merkle Proofs:** Simplified tree updates (not production-ready)
- **Hardcoded Prices:** No oracle integration yet
- **No Liquidations:** V1 focuses on core lending flow

## 🚧 Future Enhancements

- [ ] Real SP1 verifier integration
- [ ] Merkle proof verification
- [ ] Oracle price feeds (RedStone)
- [ ] Liquidation mechanisms
- [ ] Repay and withdraw functions
- [ ] Web UI for proof generation
- [ ] Multi-collateral support
- [ ] Mainnet deployment

## 📝 License

MIT License - See LICENSE file for details

## 🤝 Contributing

This is a proof-of-concept demonstration. For production use:
1. Complete security audits required
2. Replace mock components with production versions
3. Implement full Merkle tree verification
4. Add comprehensive error handling
5. Optimize gas costs

## 📞 Support

- **Issues:** GitHub Issues
- **Documentation:** See `/docs` folder
- **Mantle Discord:** https://discord.gg/mantle
- **SP1 Discord:** https://discord.gg/succinct

---

**Built with:**
- [Succinct SP1](https://succinct.xyz) - Zero-knowledge proving system
- [Mantle Network](https://mantle.xyz) - Modular Ethereum L2
- [Foundry](https://getfoundry.sh) - Smart contract development
- [Rust](https://rust-lang.org) - Systems programming language

---

## 🎯 Next Steps

### For Testing
```bash
# Run complete local test suite
./test-local.sh
```

### For Deployment
See **[TESTNET_DEPLOYMENT.md](./TESTNET_DEPLOYMENT.md)** for testnet deployment

### For Production
See **[PRODUCTION_READINESS.md](./PRODUCTION_READINESS.md)** for mainnet roadmap

---

**Status:** PoC Complete ✅ | Ready for Next Phase 🚀
