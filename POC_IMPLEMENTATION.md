# Private Lending Protocol - SP1 ZK Proof of Concept

## Overview
This PoC demonstrates a **private lending transaction** where collateral amounts are encrypted but the protocol can verify loan validity using Succinct SP1 zero-knowledge proofs.

**Goal**: Prove that a user can borrow funds with hidden collateral, while the smart contract verifies the transaction is safe (proper LTV ratio).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER (Borrower)                          │
│  Private Data: collateral_amount, collateral_type          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ Step 1: Generate ZK Proof
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              SP1 ZK Program (Off-Chain)                     │
│                                                             │
│  Private Inputs:                                            │
│    - user_secret_key                                        │
│    - collateral_amount (hidden)                             │
│    - collateral_price                                       │
│    - debt_amount                                            │
│                                                             │
│  Computation (Hidden):                                      │
│    ✓ Prove: collateral_value >= debt * (1/max_ltv)         │
│    ✓ Prove: user owns the collateral commitment            │
│    ✓ Generate: commitment_hash, nullifier                  │
│                                                             │
│  Public Outputs:                                            │
│    - commitment_hash (new note)                             │
│    - nullifier_hash (spent note)                            │
│    - borrow_amount                                          │
│    - recipient_address                                      │
│    - is_valid: bool                                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ Step 2: Submit Proof + Public Data
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         Smart Contract (On-Chain - Mantle Testnet)         │
│                                                             │
│  AegisVault.sol:                                            │
│    1. Verify ZK proof (SP1 verifier)                        │
│    2. Check nullifier not spent                             │
│    3. Update merkle root with new commitment                │
│    4. Transfer borrowed funds to recipient                  │
│                                                             │
│  State:                                                     │
│    - merkle_root: bytes32                                   │
│    - nullifiers: mapping(bytes32 => bool)                   │
│    - commitments: array of notes                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Enhanced SP1 ZK Program (Full Lending Logic)

**Current State**: Simple LTV check  
**Target State**: Full private lending with commitments and nullifiers

#### File: `zk-program/src/main.rs`

**New Features**:
1. **Private Note System**
   - Input: Previous note (collateral commitment)
   - Output: New note (updated with debt)
   - Nullifier generation for spent notes

2. **Enhanced Validation**
   - Prove ownership of collateral (via secret key)
   - Prove LTV ratio is safe
   - Generate cryptographic commitments

3. **Public Outputs**
   - Commitment hash (for merkle tree)
   - Nullifier hash (prevent double-spend)
   - Borrow amount (visible)
   - Is valid flag

**Data Structures**:
```rust
// Private inputs (hidden from blockchain)
struct PrivateLendingInput {
    user_secret_key: [u8; 32],           // Proves ownership
    collateral_amount: u128,              // Hidden amount
    collateral_price_usd: u128,           // Oracle price (e.g., mETH/USD)
    existing_debt: u128,                  // Current debt
    new_borrow_amount: u128,              // Amount to borrow
    max_ltv_bps: u16,                     // 7500 = 75%
    note_salt: [u8; 32],                  // Randomness for commitment
}

// Public outputs (visible on-chain)
struct PublicLendingOutput {
    commitment_hash: [u8; 32],            // Hash of new collateral state
    nullifier_hash: [u8; 32],             // Hash to mark old note as spent
    recipient_address: [u8; 20],          // Where to send borrowed funds
    borrow_amount: u128,                  // Amount borrowed (public)
    is_valid: bool,                       // Proof verification result
}
```

**Core Logic**:
```rust
// 1. Verify ownership
let ownership_proof = hash(user_secret_key, collateral_amount, note_salt);

// 2. Calculate collateral value
let collateral_value = collateral_amount * collateral_price_usd;

// 3. Calculate total debt
let total_debt = existing_debt + new_borrow_amount;

// 4. Check LTV ratio (must be safe)
let max_borrow = (collateral_value * max_ltv_bps) / 10_000;
let is_safe = total_debt <= max_borrow;

// 5. Generate commitment (new note with updated debt)
let new_commitment = hash(user_secret_key, collateral_amount, total_debt, note_salt);

// 6. Generate nullifier (to mark old note as spent)
let nullifier = hash(user_secret_key, "NULLIFIER", note_salt);
```

---

### Phase 2: Smart Contract (Mantle Testnet)

#### File: `contracts/AegisVault.sol`

**Purpose**: Verify ZK proofs and manage the private lending state

**Key Components**:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";

contract AegisVault {
    // SP1 Proof Verifier
    ISP1Verifier public verifier;
    bytes32 public programVKey; // Verification key for our ZK program
    
    // State Management
    bytes32 public merkleRoot;                          // Root of commitment tree
    mapping(bytes32 => bool) public nullifiers;         // Spent notes
    bytes32[] public commitments;                       // All notes
    
    // Asset Management
    IERC20 public collateralToken;  // e.g., mETH
    IERC20 public debtToken;        // e.g., USDC
    
    // Events
    event Deposit(bytes32 indexed commitment, uint256 amount);
    event Borrow(bytes32 indexed nullifier, bytes32 newCommitment, 
                 address recipient, uint256 amount);
    
    // Core Functions
    
    /// @notice Deposit collateral (creates initial commitment)
    function deposit(uint256 amount, bytes32 commitment, bytes calldata proof) external {
        // 1. Transfer collateral from user
        collateralToken.transferFrom(msg.sender, address(this), amount);
        
        // 2. Verify ZK proof (proves commitment is valid)
        require(verifyProof(proof, commitment), "Invalid proof");
        
        // 3. Add commitment to tree
        commitments.push(commitment);
        merkleRoot = updateMerkleRoot(commitment);
        
        emit Deposit(commitment, amount);
    }
    
    /// @notice Borrow against hidden collateral
    function borrow(
        bytes calldata zkProof,
        bytes32 nullifierHash,
        bytes32 newCommitment,
        address recipient,
        uint256 borrowAmount
    ) external {
        // 1. Check nullifier not already spent (prevent double-borrow)
        require(!nullifiers[nullifierHash], "Note already spent");
        
        // 2. Verify ZK proof
        // Proof shows: "I have collateral X, borrowing Y is safe, 
        //               and I'm creating new commitment Z"
        bytes memory publicInputs = abi.encode(
            nullifierHash,
            newCommitment,
            recipient,
            borrowAmount
        );
        
        require(
            verifier.verifyProof(programVKey, publicInputs, zkProof),
            "Invalid ZK proof"
        );
        
        // 3. Mark old note as spent
        nullifiers[nullifierHash] = true;
        
        // 4. Add new commitment (updated with debt)
        commitments.push(newCommitment);
        merkleRoot = updateMerkleRoot(newCommitment);
        
        // 5. Transfer borrowed funds
        debtToken.transfer(recipient, borrowAmount);
        
        emit Borrow(nullifierHash, newCommitment, recipient, borrowAmount);
    }
    
    function updateMerkleRoot(bytes32 commitment) internal returns (bytes32) {
        // Simplified: just hash all commitments
        // Production: use incremental merkle tree
        return keccak256(abi.encodePacked(merkleRoot, commitment));
    }
}
```

---

### Phase 3: Prover Script (Generate & Submit Proofs)

#### File: `script/src/main.rs`

**Enhanced to handle full lending flow**:

```rust
// Scenario: Alice deposits 10 mETH, borrows 5000 USDC
// The blockchain never learns she has 10 mETH

fn main() {
    // Step 1: Generate deposit proof
    let deposit_result = prove_deposit(
        secret_key,
        10_000_000_000_000_000_000u128, // 10 mETH (hidden)
        "alice_note_1".as_bytes(),
    );
    
    println!("Deposit commitment: {:?}", deposit_result.commitment);
    
    // Step 2: Submit deposit to contract
    submit_deposit_transaction(
        deposit_result.commitment,
        deposit_result.proof,
    );
    
    // Step 3: Generate borrow proof
    let borrow_result = prove_borrow(
        secret_key,
        10_000_000_000_000_000_000u128,  // 10 mETH (still hidden)
        2500_000_000u128,                 // mETH price: $2500
        0u128,                            // No existing debt
        5000_000_000u128,                 // Borrow 5000 USDC
        7500u16,                          // Max LTV: 75%
        "alice_note_1".as_bytes(),
        "alice_note_2".as_bytes(),
    );
    
    println!("Borrow proof valid: {}", borrow_result.is_valid);
    println!("New commitment: {:?}", borrow_result.commitment);
    
    // Step 4: Submit borrow to contract
    submit_borrow_transaction(
        borrow_result.nullifier,
        borrow_result.commitment,
        "0xRecipientAddress",
        5000_000_000u128,
        borrow_result.proof,
    );
    
    println!("✅ Borrowed 5000 USDC with hidden collateral!");
}
```

---

## Deployment Plan (Mantle Sepolia Testnet)

### Prerequisites

1. **Mantle Sepolia Testnet Setup**
   - RPC: `https://rpc.sepolia.mantle.xyz`
   - Chain ID: 5003
   - Faucet: https://faucet.sepolia.mantle.xyz

2. **Required Tools**
   - Rust + Cargo (for SP1)
   - Foundry (for Solidity contracts)
   - SP1 SDK: `cargo install sp1-cli`

### Step-by-Step Deployment

#### 1. Build ZK Program
```bash
cd zk-program
cargo build --release --target riscv32im-succinct-zkvm-elf
```

#### 2. Generate Verification Key
```bash
cd script
cargo run --release -- generate-vkey
# Outputs: program_vkey.txt
```

#### 3. Deploy Smart Contract
```bash
cd contracts
forge create AegisVault \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY \
  --constructor-args $SP1_VERIFIER_ADDRESS $PROGRAM_VKEY
```

#### 4. Run Test Flow
```bash
# Terminal 1: Generate proofs
cd script
cargo run --release -- test-lending-flow

# Terminal 2: Monitor contract
cast logs --rpc-url https://rpc.sepolia.mantle.xyz \
  --address $AEGIS_VAULT_ADDRESS
```

---

## Test Scenarios

### Test 1: Valid Borrow (Should Succeed)
```
Collateral: 10 mETH @ $2500 = $25,000
Borrow: $5,000 USDC
LTV: 20% (safe, below 75% max)
Expected: ✅ Proof verifies, funds transferred
```

### Test 2: Over-Leveraged Borrow (Should Fail)
```
Collateral: 10 mETH @ $2500 = $25,000
Borrow: $20,000 USDC
LTV: 80% (unsafe, above 75% max)
Expected: ❌ Proof fails, transaction reverts
```

### Test 3: Double-Spend Prevention
```
1. Borrow $5,000 (generates nullifier_1)
2. Try to borrow again with same note
Expected: ❌ Contract rejects (nullifier already spent)
```

### Test 4: Privacy Verification
```
Observer sees on-chain:
  - Commitment: 0x1a2b3c... (meaningless hash)
  - Borrow: 5000 USDC
  - Recipient: 0xAlice...
  
Observer CANNOT see:
  - Collateral amount (10 mETH is hidden)
  - Collateral type (could be anything)
  - Previous transactions by this user
```

---

## Success Metrics

1. ✅ **Functional**: Deposit → Borrow flow works end-to-end
2. ✅ **Private**: Collateral amounts are never revealed on-chain
3. ✅ **Secure**: Invalid LTV ratios are rejected by proof verification
4. ✅ **Verifiable**: Anyone can verify proofs without learning private data
5. ✅ **Testnet**: Deployed and working on Mantle Sepolia

---

## Next Steps (Post-PoC)

1. **Merkle Tree Integration**: Full tree-based note system (not just sequential)
2. **Oracle Integration**: Real-time price feeds (RedStone on Mantle)
3. **Repay Function**: Close loans and unlock collateral
4. **Gas Optimization**: Reduce proof verification costs
5. **UI/UX**: Web interface for generating proofs in browser (Wasm)
6. **Mainnet**: Deploy to Mantle L2 with audits

---

## File Structure Changes

```
PoC final project/
├── zk-program/
│   ├── src/
│   │   ├── main.rs              [MODIFY] - Enhanced with full lending logic
│   │   ├── types.rs             [NEW] - Data structures
│   │   └── crypto.rs            [NEW] - Hash functions for commitments
│   └── Cargo.toml               [MODIFY] - Add crypto dependencies
│
├── script/
│   ├── src/
│   │   ├── main.rs              [MODIFY] - Full flow orchestration
│   │   ├── prover.rs            [NEW] - Proof generation helpers
│   │   └── testnet.rs           [NEW] - Testnet interaction
│   └── Cargo.toml               [MODIFY] - Add ethers-rs
│
├── contracts/
│   ├── src/
│   │   ├── AegisVault.sol       [NEW] - Main lending contract
│   │   ├── interfaces/
│   │   │   └── ISP1Verifier.sol [NEW] - SP1 verifier interface
│   │   └── test/
│   │       └── AegisVault.t.sol [NEW] - Contract tests
│   ├── foundry.toml             [NEW] - Foundry config
│   └── remappings.txt           [NEW] - Import paths
│
└── POC_IMPLEMENTATION.md        [THIS FILE]
```

---

## Timeline Estimate

- **Week 1**: Implement enhanced ZK program + local testing
- **Week 2**: Smart contract development + Foundry tests
- **Week 3**: Integration + testnet deployment
- **Week 4**: End-to-end testing + documentation

---

## Resources

- SP1 Documentation: https://docs.succinct.xyz
- Mantle Sepolia: https://docs.mantle.xyz/network/for-devs/testnet
- SP1 Contracts: https://github.com/succinctlabs/sp1-contracts-foundry
- Example Private Lending: https://github.com/privacy-scaling-explorations

---

## Questions / Decisions Needed

1. **Collateral Token**: Use actual mETH on testnet or mock ERC20?
2. **Debt Token**: Use USDC on testnet or deploy mock stablecoin?
3. **Oracle**: Hardcoded prices for PoC or integrate RedStone?
4. **UI**: Command-line only or build basic web interface?

---

**Status**: 📝 Design Complete - Ready for Implementation  
**Next Action**: Review this plan, then start with Phase 1 (ZK Program)
