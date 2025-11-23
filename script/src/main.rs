use serde::{Deserialize, Serialize};
use sp1_sdk::{utils, HashableKey, ProverClient, SP1Stdin};
use std::time::Instant;

// Embed the compiled SP1 ELF for the zk-program.
const ELF: &[u8] = include_bytes!("../../zk-program/target/elf-compilation/riscv32im-succinct-zkvm-elf/release/zk-program");

// Data structures matching the ZK program
#[derive(Serialize, Deserialize, Debug)]
struct DepositInput {
    user_secret_key: [u8; 32],
    collateral_amount: u128,
    note_salt: [u8; 32],
}

#[derive(Serialize, Deserialize, Debug)]
struct DepositOutput {
    commitment_hash: [u8; 32],
    is_valid: u8,
}

#[derive(Serialize, Deserialize, Debug)]
struct BorrowInput {
    user_secret_key: [u8; 32],
    collateral_amount: u128,
    collateral_price_usd: u128,
    existing_debt: u128,
    new_borrow_amount: u128,
    max_ltv_bps: u16,
    old_note_salt: [u8; 32],
    new_note_salt: [u8; 32],
    recipient_address: [u8; 20],
}

#[derive(Serialize, Deserialize, Debug)]
struct BorrowOutput {
    nullifier_hash: [u8; 32],
    new_commitment_hash: [u8; 32],
    recipient_address: [u8; 20],
    borrow_amount: u128,
    is_valid: u8,
}

fn main() {
    // Setup logging for SP1 SDK.
    utils::setup_logger();

    println!("\n========================================");
    println!("  Private Lending Protocol - SP1 PoC");
    println!("  Real ZK Proofs + Benchmarking");
    println!("========================================\n");

    // Check if we should run benchmarks or stress tests
    let args: Vec<String> = std::env::args().collect();
    let mode = args.get(1).map(|s| s.as_str());

    match mode {
        Some("benchmark") => run_benchmarks(),
        Some("stress") => run_stress_test(),
        Some("groth16") => test_groth16_proofs(),
        Some("fast") => run_fast_validation(),
        _ => run_basic_tests(),
    }
}

fn run_basic_tests() {
    println!("🧪 Running basic test suite...\n");

    // Test 1: Deposit Operation
    println!("[TEST 1] Testing Deposit Operation");
    println!("-----------------------------------");
    test_deposit();

    // Test 2: Safe Borrow Operation
    println!("\n[TEST 2] Testing Safe Borrow (LTV < 75%)");
    println!("------------------------------------------");
    test_safe_borrow();

    // Test 3: Unsafe Borrow Operation
    println!("\n[TEST 3] Testing Unsafe Borrow (LTV > 75%)");
    println!("--------------------------------------------");
    test_unsafe_borrow();

    println!("\n========================================");
    println!("  All Tests Completed Successfully!");
    println!("========================================\n");
}

fn test_deposit() {
    // Alice deposits 10 ETH (hidden amount)
    let secret_key = [1u8; 32]; // Alice's secret
    let collateral_amount = 10_000_000_000_000_000_000u128; // 10 ETH in wei
    let salt = [42u8; 32];

    println!("💰 Depositing collateral (amount hidden in ZK proof)...");
    println!("   Secret Key: {:?}...", &secret_key[..4]);
    println!("   Collateral: {} ETH (hidden)", collateral_amount / 1_000_000_000_000_000_000);

    let deposit_input = DepositInput {
        user_secret_key: secret_key,
        collateral_amount,
        note_salt: salt,
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&0u8); // Operation type: 0 = deposit
    stdin.write(&deposit_input);

    let client = ProverClient::from_env();

    // Execute to check cycles
    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    println!("   Execution: {} cycles", report.total_instruction_count());

    // Read output
    let result: DepositOutput = output.read();
    println!("   ✅ Valid: {}", result.is_valid);
    println!("   📝 Commitment: {:?}...", &result.commitment_hash[..8]);

    assert_eq!(result.is_valid, 1, "Deposit should be valid");

    // Generate proof
    let (pk, vk) = client.setup(ELF);
    let proof = client.prove(&pk, &stdin).run().expect("proving failed");
    println!("   🔐 Proof generated");

    // Verify proof
    client.verify(&proof, &vk).expect("verification failed");
    println!("   ✅ Proof verified successfully");

    // Save for later use
    proof.save("deposit-proof.bin").expect("failed to save proof");
}

fn test_safe_borrow() {
    // Alice borrows 5000 USDC against 10 ETH @ $2500 = $25,000 collateral
    // LTV = 5000 / 25000 = 20% (safe, below 75%)
    let secret_key = [1u8; 32];
    let collateral_amount = 10_000_000_000_000_000_000u128; // 10 ETH
    let collateral_price = 2500_000_000u128; // $2500 (with 6 decimals)
    let borrow_amount = 5000_000_000u128; // $5000 USDC
    let old_salt = [42u8; 32];
    let new_salt = [43u8; 32];
    let recipient = [0x12u8; 20];

    println!("🏦 Attempting to borrow...");
    println!("   Collateral: 10 ETH (hidden)");
    println!("   ETH Price: $2500 (public oracle)");
    println!("   Collateral Value: $25,000 (computed in ZK)");
    println!("   Borrow Amount: $5,000 USDC (public)");
    println!("   LTV: 20% (computed in ZK)");
    println!("   Max LTV: 75%");

    let borrow_input = BorrowInput {
        user_secret_key: secret_key,
        collateral_amount,
        collateral_price_usd: collateral_price,
        existing_debt: 0,
        new_borrow_amount: borrow_amount,
        max_ltv_bps: 7500, // 75%
        old_note_salt: old_salt,
        new_note_salt: new_salt,
        recipient_address: recipient,
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&1u8); // Operation type: 1 = borrow
    stdin.write(&borrow_input);

    let client = ProverClient::from_env();

    // Execute
    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    println!("   Execution: {} cycles", report.total_instruction_count());

    // Read output
    let result: BorrowOutput = output.read();
    println!("   ✅ Valid: {}", result.is_valid);
    println!("   🔒 Nullifier: {:?}...", &result.nullifier_hash[..8]);
    println!("   📝 New Commitment: {:?}...", &result.new_commitment_hash[..8]);
    println!("   💸 Borrow Amount: {} USDC", result.borrow_amount / 1_000_000);

    assert_eq!(result.is_valid, 1, "Borrow should be valid (safe LTV)");

    // Generate and verify proof
    let (pk, vk) = client.setup(ELF);
    let proof = client.prove(&pk, &stdin).run().expect("proving failed");
    println!("   🔐 Proof generated");

    client.verify(&proof, &vk).expect("verification failed");
    println!("   ✅ Proof verified - Borrow approved!");
}

fn test_unsafe_borrow() {
    // Alice tries to borrow 20,000 USDC against 10 ETH @ $2500 = $25,000
    // LTV = 20000 / 25000 = 80% (unsafe, above 75%)
    let secret_key = [1u8; 32];
    let collateral_amount = 10_000_000_000_000_000_000u128; // 10 ETH
    let collateral_price = 2500_000_000u128; // $2500
    let borrow_amount = 20000_000_000u128; // $20,000 USDC
    let old_salt = [42u8; 32];
    let new_salt = [44u8; 32];
    let recipient = [0x12u8; 20];

    println!("🏦 Attempting to borrow (should fail)...");
    println!("   Collateral: 10 ETH (hidden)");
    println!("   ETH Price: $2500");
    println!("   Collateral Value: $25,000 (computed in ZK)");
    println!("   Borrow Amount: $20,000 USDC (public)");
    println!("   LTV: 80% (computed in ZK)");
    println!("   Max LTV: 75%");

    let borrow_input = BorrowInput {
        user_secret_key: secret_key,
        collateral_amount,
        collateral_price_usd: collateral_price,
        existing_debt: 0,
        new_borrow_amount: borrow_amount,
        max_ltv_bps: 7500, // 75%
        old_note_salt: old_salt,
        new_note_salt: new_salt,
        recipient_address: recipient,
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&1u8); // Operation type: 1 = borrow
    stdin.write(&borrow_input);

    let client = ProverClient::from_env();

    // Execute
    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    println!("   Execution: {} cycles", report.total_instruction_count());

    // Read output
    let result: BorrowOutput = output.read();
    println!("   ❌ Valid: {} (expected 0)", result.is_valid);
    println!("   Result: Borrow rejected due to unsafe LTV ratio");

    assert_eq!(result.is_valid, 0, "Borrow should be invalid (unsafe LTV)");
    println!("   ✅ Test passed - Unsafe borrow correctly rejected!");
}

// ============================================
// Fast Validation (Execution Only - No Proofs)
// ============================================

fn run_fast_validation() {
    println!("⚡ Fast Validation Mode - Execution Only (No Proof Generation)\n");
    println!("========================================\n");

    let client = ProverClient::from_env();

    // Test 1: Deposit
    println!("[1/3] Validating DEPOSIT operation");
    println!("-----------------------------------");
    let start = Instant::now();
    
    let deposit_input = DepositInput {
        user_secret_key: [1u8; 32],
        collateral_amount: 10_000_000_000_000_000_000u128,
        note_salt: [42u8; 32],
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&0u8);
    stdin.write(&deposit_input);

    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    let result: DepositOutput = output.read();
    
    println!("  ✅ Execution: {:?}", start.elapsed());
    println!("  📊 Cycles: {}", report.total_instruction_count());
    println!("  ✅ Valid: {}", result.is_valid);
    println!("  📝 Commitment: {:?}...\n", &result.commitment_hash[..8]);
    
    assert_eq!(result.is_valid, 1);

    // Test 2: Safe Borrow
    println!("[2/3] Validating SAFE BORROW (LTV 20%)");
    println!("-----------------------------------");
    let start = Instant::now();
    
    let borrow_input = BorrowInput {
        user_secret_key: [1u8; 32],
        collateral_amount: 10_000_000_000_000_000_000u128,
        collateral_price_usd: 2500_000_000u128,
        existing_debt: 0,
        new_borrow_amount: 5000_000_000u128,
        max_ltv_bps: 7500,
        old_note_salt: [42u8; 32],
        new_note_salt: [43u8; 32],
        recipient_address: [0x12u8; 20],
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&1u8);
    stdin.write(&borrow_input);

    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    let result: BorrowOutput = output.read();
    
    println!("  ✅ Execution: {:?}", start.elapsed());
    println!("  📊 Cycles: {}", report.total_instruction_count());
    println!("  ✅ Valid: {}", result.is_valid);
    println!("  💸 Borrow: {} USDC\n", result.borrow_amount / 1_000_000);
    
    assert_eq!(result.is_valid, 1);

    // Test 3: Unsafe Borrow
    println!("[3/3] Validating UNSAFE BORROW (LTV 80%) - Should Reject");
    println!("-----------------------------------");
    let start = Instant::now();
    
    let borrow_input = BorrowInput {
        user_secret_key: [1u8; 32],
        collateral_amount: 10_000_000_000_000_000_000u128,
        collateral_price_usd: 2500_000_000u128,
        existing_debt: 0,
        new_borrow_amount: 20000_000_000u128, // 80% LTV
        max_ltv_bps: 7500,
        old_note_salt: [42u8; 32],
        new_note_salt: [44u8; 32],
        recipient_address: [0x12u8; 20],
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&1u8);
    stdin.write(&borrow_input);

    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    let result: BorrowOutput = output.read();
    
    println!("  ✅ Execution: {:?}", start.elapsed());
    println!("  📊 Cycles: {}", report.total_instruction_count());
    println!("  ❌ Valid: {} (expected 0)", result.is_valid);
    println!("  ✅ Correctly rejected unsafe LTV\n");
    
    assert_eq!(result.is_valid, 0);

    println!("========================================");
    println!("✅ All validations passed!");
    println!("========================================");
    println!("\n💡 This mode is FAST (~10ms total) but doesn't generate proofs.");
    println!("   For real proofs, use: cargo run --release groth16");
    println!("   (First Groth16 proof takes 10-15 min, then ~3s each)\n");
}

// ============================================
// Groth16 Proof Generation (For On-Chain)
// ============================================

fn test_groth16_proofs() {
    println!("🔐 Testing Groth16 Proof Generation (On-Chain Ready)\n");
    println!("========================================\n");

    let client = ProverClient::from_env();
    let (pk, vk) = client.setup(ELF);
    
    println!("📋 Verification Key (bytes32): {}\n", vk.bytes32());

    // Test Deposit with Groth16
    println!("[1/2] Generating Groth16 proof for DEPOSIT");
    println!("-------------------------------------------");
    let deposit_start = Instant::now();
    
    let secret_key = [1u8; 32];
    let collateral_amount = 10_000_000_000_000_000_000u128; // 10 ETH
    let salt = [42u8; 32];

    let deposit_input = DepositInput {
        user_secret_key: secret_key,
        collateral_amount,
        note_salt: salt,
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&0u8);
    stdin.write(&deposit_input);

    // Generate Groth16 proof
    println!("🔨 Generating proof...");
    let proof = client.prove(&pk, &stdin)
        .groth16()
        .run()
        .expect("Groth16 proving failed");
    
    let deposit_time = deposit_start.elapsed();
    println!("✅ Deposit Groth16 proof: {:?}", deposit_time);
    println!("📦 Proof size: {} bytes", proof.bytes().len());
    
    // Verify
    client.verify(&proof, &vk).expect("verification failed");
    println!("✅ Proof verified!\n");

    // Save for contract deployment
    proof.save("deposit-groth16.bin").expect("failed to save");
    println!("💾 Saved to: deposit-groth16.bin\n");

    // Test Borrow with Groth16
    println!("[2/2] Generating Groth16 proof for BORROW");
    println!("-------------------------------------------");
    let borrow_start = Instant::now();
    
    let borrow_input = BorrowInput {
        user_secret_key: secret_key,
        collateral_amount: 10_000_000_000_000_000_000u128,
        collateral_price_usd: 2500_000_000u128,
        existing_debt: 0,
        new_borrow_amount: 5000_000_000u128,
        max_ltv_bps: 7500,
        old_note_salt: [42u8; 32],
        new_note_salt: [43u8; 32],
        recipient_address: [0x12u8; 20],
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&1u8);
    stdin.write(&borrow_input);

    println!("🔨 Generating proof...");
    let proof = client.prove(&pk, &stdin)
        .groth16()
        .run()
        .expect("Groth16 proving failed");
    
    let borrow_time = borrow_start.elapsed();
    println!("✅ Borrow Groth16 proof: {:?}", borrow_time);
    println!("📦 Proof size: {} bytes", proof.bytes().len());
    
    client.verify(&proof, &vk).expect("verification failed");
    println!("✅ Proof verified!\n");

    proof.save("borrow-groth16.bin").expect("failed to save");
    println!("💾 Saved to: borrow-groth16.bin\n");

    println!("========================================");
    println!("✅ Groth16 proofs ready for on-chain verification!");
    println!("========================================\n");
}

// ============================================
// Benchmarking Suite
// ============================================

fn run_benchmarks() {
    println!("⚡ Running Performance Benchmarks\n");
    println!("========================================\n");

    let client = ProverClient::from_env();
    let (pk, _vk) = client.setup(ELF);

    // Test various collateral amounts
    let test_amounts = vec![
        (1_000_000_000_000_000_000u128, "1 ETH"),
        (5_000_000_000_000_000_000u128, "5 ETH"),
        (10_000_000_000_000_000_000u128, "10 ETH"),
        (50_000_000_000_000_000_000u128, "50 ETH"),
        (100_000_000_000_000_000_000u128, "100 ETH"),
    ];

    println!("📊 DEPOSIT Operation Benchmarks");
    println!("-----------------------------------");
    
    let mut deposit_times = Vec::new();
    
    for (amount, label) in &test_amounts {
        let start = Instant::now();
        
        let deposit_input = DepositInput {
            user_secret_key: [1u8; 32],
            collateral_amount: *amount,
            note_salt: [42u8; 32],
        };

        let mut stdin = SP1Stdin::new();
        stdin.write(&0u8);
        stdin.write(&deposit_input);

        // Execute only (no proof) for cycle count
        let (_, report) = client.execute(ELF, &stdin).run().expect("execution failed");
        let exec_time = start.elapsed();
        
        deposit_times.push(exec_time);
        
        println!("  {} - {} cycles ({:?})", 
            label, 
            report.total_instruction_count(),
            exec_time
        );
    }

    let avg_deposit = deposit_times.iter().sum::<std::time::Duration>() / deposit_times.len() as u32;
    println!("\n  Average: {:?}\n", avg_deposit);

    // Test various borrow scenarios
    let borrow_scenarios = vec![
        (10u128, 2500u128, 1000u128, "Low LTV (10%)"),
        (10u128, 2500u128, 5000u128, "Medium LTV (20%)"),
        (10u128, 2500u128, 15000u128, "High LTV (60%)"),
        (10u128, 2500u128, 18750u128, "Max LTV (75%)"),
    ];

    println!("📊 BORROW Operation Benchmarks");
    println!("-----------------------------------");
    
    let mut borrow_times = Vec::new();
    
    for (eth_amount, price, borrow_usd, label) in &borrow_scenarios {
        let start = Instant::now();
        
        let borrow_input = BorrowInput {
            user_secret_key: [1u8; 32],
            collateral_amount: eth_amount * 1_000_000_000_000_000_000u128,
            collateral_price_usd: price * 1_000_000u128,
            existing_debt: 0,
            new_borrow_amount: borrow_usd * 1_000_000u128,
            max_ltv_bps: 7500,
            old_note_salt: [42u8; 32],
            new_note_salt: [43u8; 32],
            recipient_address: [0x12u8; 20],
        };

        let mut stdin = SP1Stdin::new();
        stdin.write(&1u8);
        stdin.write(&borrow_input);

        let (_, report) = client.execute(ELF, &stdin).run().expect("execution failed");
        let exec_time = start.elapsed();
        
        borrow_times.push(exec_time);
        
        println!("  {} - {} cycles ({:?})", 
            label,
            report.total_instruction_count(),
            exec_time
        );
    }

    let avg_borrow = borrow_times.iter().sum::<std::time::Duration>() / borrow_times.len() as u32;
    println!("\n  Average: {:?}\n", avg_borrow);

    // Groth16 proof generation benchmark
    println!("📊 Groth16 Proof Generation");
    println!("-----------------------------------");
    
    let deposit_input = DepositInput {
        user_secret_key: [1u8; 32],
        collateral_amount: 10_000_000_000_000_000_000u128,
        note_salt: [42u8; 32],
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&0u8);
    stdin.write(&deposit_input);

    let start = Instant::now();
    let proof = client.prove(&pk, &stdin)
        .groth16()
        .run()
        .expect("proving failed");
    let groth16_time = start.elapsed();
    
    println!("  Deposit (Groth16): {:?}", groth16_time);
    println!("  Proof size: {} bytes", proof.bytes().len());

    println!("\n========================================");
    println!("✅ Benchmarks Complete!");
    println!("========================================\n");
}

// ============================================
// Stress Test - Multiple Users
// ============================================

fn run_stress_test() {
    println!("💪 Running Stress Test - Multiple Users\n");
    println!("========================================\n");

    let client = ProverClient::from_env();
    let (pk, vk) = client.setup(ELF);

    let num_users = 10;
    let mut total_time = std::time::Duration::ZERO;
    let mut successful_proofs = 0;

    println!("🏦 Simulating {} concurrent users...\n", num_users);

    for i in 0..num_users {
        let user_id = i + 1;
        println!("[User {}] Processing operations...", user_id);
        
        // Each user has unique secret key
        let mut secret_key = [0u8; 32];
        secret_key[0] = i as u8;
        
        // Randomize amounts
        let collateral = (i as u128 + 1) * 1_000_000_000_000_000_000u128; // 1-10 ETH
        let borrow = ((i as u128 + 1) * 1000) * 1_000_000u128; // 1000-10000 USDC
        
        // Deposit
        let start = Instant::now();
        let deposit_input = DepositInput {
            user_secret_key: secret_key,
            collateral_amount: collateral,
            note_salt: secret_key, // Use secret as salt for uniqueness
        };

        let mut stdin = SP1Stdin::new();
        stdin.write(&0u8);
        stdin.write(&deposit_input);

        match client.prove(&pk, &stdin).groth16().run() {
            Ok(proof) => {
                match client.verify(&proof, &vk) {
                    Ok(_) => {
                        successful_proofs += 1;
                        let elapsed = start.elapsed();
                        total_time += elapsed;
                        println!("  ✅ Deposit proof: {:?}", elapsed);
                    }
                    Err(e) => println!("  ❌ Verification failed: {}", e),
                }
            }
            Err(e) => println!("  ❌ Proving failed: {}", e),
        }

        // Borrow
        let start = Instant::now();
        let borrow_input = BorrowInput {
            user_secret_key: secret_key,
            collateral_amount: collateral,
            collateral_price_usd: 2500_000_000u128,
            existing_debt: 0,
            new_borrow_amount: borrow,
            max_ltv_bps: 7500,
            old_note_salt: secret_key,
            new_note_salt: [secret_key[0], secret_key[1], 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            recipient_address: [secret_key[0]; 20],
        };

        let mut stdin = SP1Stdin::new();
        stdin.write(&1u8);
        stdin.write(&borrow_input);

        match client.prove(&pk, &stdin).groth16().run() {
            Ok(proof) => {
                match client.verify(&proof, &vk) {
                    Ok(_) => {
                        successful_proofs += 1;
                        let elapsed = start.elapsed();
                        total_time += elapsed;
                        println!("  ✅ Borrow proof: {:?}", elapsed);
                    }
                    Err(e) => println!("  ❌ Verification failed: {}", e),
                }
            }
            Err(e) => println!("  ❌ Proving failed: {}", e),
        }
        
        println!();
    }

    let avg_time = total_time / (successful_proofs as u32);
    
    println!("========================================");
    println!("📊 Stress Test Results");
    println!("========================================");
    println!("  Total Users: {}", num_users);
    println!("  Total Operations: {}", num_users * 2);
    println!("  Successful Proofs: {}", successful_proofs);
    println!("  Total Time: {:?}", total_time);
    println!("  Average per Proof: {:?}", avg_time);
    println!("  Success Rate: {:.1}%", (successful_proofs as f64 / (num_users * 2) as f64) * 100.0);
    println!("========================================\n");
}
