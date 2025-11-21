use serde::{Deserialize, Serialize};
use sp1_sdk::{utils, ProverClient, SP1Stdin};

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
    println!("========================================\n");

    // Test 1: Deposit Operation
    println!("\n[TEST 1] Testing Deposit Operation");
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
    let mut proof = client.prove(&pk, &stdin).run().expect("proving failed");
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
