use serde::{Deserialize, Serialize};
use sp1_sdk::{utils, HashableKey, ProverClient, SP1Stdin};
use std::env;
use std::fs;

// Embed the compiled SP1 ELF
const ELF: &[u8] = include_bytes!("../../../zk-program/target/elf-compilation/riscv32im-succinct-zkvm-elf/release/zk-program");

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
    utils::setup_logger();

    let args: Vec<String> = env::args().collect();
    
    if args.len() < 2 {
        eprintln!("Usage:");
        eprintln!("  generate_proof deposit <amount_eth> <output_file>");
        eprintln!("  generate_proof borrow <collateral_eth> <borrow_usd> <output_file>");
        eprintln!("");
        eprintln!("Examples:");
        eprintln!("  generate_proof deposit 10 user1-deposit.proof");
        eprintln!("  generate_proof borrow 10 5000 user1-borrow.proof");
        std::process::exit(1);
    }

    let operation = &args[1];

    match operation.as_str() {
        "deposit" => {
            if args.len() < 4 {
                eprintln!("Usage: generate_proof deposit <amount_eth> <output_file>");
                std::process::exit(1);
            }
            
            let amount_eth: u128 = args[2].parse().expect("Invalid amount");
            let output_file = &args[3];
            
            generate_deposit_proof(amount_eth, output_file);
        }
        "borrow" => {
            if args.len() < 5 {
                eprintln!("Usage: generate_proof borrow <collateral_eth> <borrow_usd> <output_file>");
                std::process::exit(1);
            }
            
            let collateral_eth: u128 = args[2].parse().expect("Invalid collateral");
            let borrow_usd: u128 = args[3].parse().expect("Invalid borrow amount");
            let output_file = &args[4];
            
            generate_borrow_proof(collateral_eth, borrow_usd, output_file);
        }
        _ => {
            eprintln!("Unknown operation: {}", operation);
            eprintln!("Use 'deposit' or 'borrow'");
            std::process::exit(1);
        }
    }
}

fn generate_deposit_proof(amount_eth: u128, output_file: &str) {
    println!("\n🔐 Generating Deposit Proof");
    println!("========================================");
    println!("Amount: {} ETH", amount_eth);
    println!("Output: {}\n", output_file);

    let client = ProverClient::from_env();
    let (pk, vk) = client.setup(ELF);

    println!("📋 Verification Key: {}", vk.bytes32());
    
    // Fixed secret and salt for testing (in production, use unique values)
    let secret_key = [1u8; 32];
    let amount_wei = amount_eth * 1_000_000_000_000_000_000u128;
    let salt = [42u8; 32];

    let deposit_input = DepositInput {
        user_secret_key: secret_key,
        collateral_amount: amount_wei,
        note_salt: salt,
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&0u8); // Operation type: 0 = deposit
    stdin.write(&deposit_input);

    // Execute to get output
    println!("🔨 Executing program...");
    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    let result: DepositOutput = output.read();
    
    println!("✅ Execution complete:");
    println!("   Cycles: {}", report.total_instruction_count());
    println!("   Valid: {}", result.is_valid);
    println!("   Commitment: {:?}...", &result.commitment_hash[..8]);

    if result.is_valid != 1 {
        eprintln!("\n❌ Error: Deposit validation failed!");
        std::process::exit(1);
    }

    // Generate Groth16 proof
    println!("\n🔨 Generating Groth16 proof...");
    println!("⚠️  This may take 10-15 minutes on first run");
    println!("   Subsequent runs will be much faster (~3-5 seconds)\n");
    
    let start = std::time::Instant::now();
    let proof = client.prove(&pk, &stdin)
        .groth16()
        .run()
        .expect("Groth16 proving failed");
    
    let elapsed = start.elapsed();
    
    println!("✅ Proof generated in {:?}", elapsed);
    println!("📦 Proof size: {} bytes", proof.bytes().len());

    // Verify proof
    println!("\n🔍 Verifying proof...");
    client.verify(&proof, &vk).expect("verification failed");
    println!("✅ Proof verified successfully!");

    // Save proof
    proof.save(output_file).expect("failed to save proof");
    println!("\n💾 Proof saved to: {}", output_file);

    // Also save public values separately for contract call
    let public_values_file = format!("{}.public", output_file);
    let public_values = proof.public_values.to_vec();
    fs::write(&public_values_file, &public_values).expect("failed to save public values");
    println!("💾 Public values saved to: {}", public_values_file);

    // Save commitment for contract verification
    let commitment_hex = hex::encode(result.commitment_hash);
    let commitment_file = format!("{}.commitment", output_file);
    fs::write(&commitment_file, &commitment_hex).expect("failed to save commitment");
    println!("💾 Commitment saved to: {}", commitment_file);

    println!("\n========================================");
    println!("✅ Deposit proof ready for on-chain verification!");
    println!("========================================\n");
}

fn generate_borrow_proof(collateral_eth: u128, borrow_usd: u128, output_file: &str) {
    println!("\n🔐 Generating Borrow Proof");
    println!("========================================");
    println!("Collateral: {} ETH", collateral_eth);
    println!("Borrow: ${} USDC", borrow_usd);
    println!("Output: {}\n", output_file);

    let client = ProverClient::from_env();
    let (pk, vk) = client.setup(ELF);

    println!("📋 Verification Key: {}", vk.bytes32());

    // Calculate LTV
    let eth_price = 2500u128; // $2500 per ETH
    let collateral_value = collateral_eth * eth_price;
    let ltv_bps = (borrow_usd * 10000) / collateral_value;
    
    println!("\n📊 Loan Details:");
    println!("   Collateral Value: ${}", collateral_value);
    println!("   Borrow Amount: ${}", borrow_usd);
    println!("   LTV: {}%", ltv_bps / 100);
    println!("   Max LTV: 75%");

    if ltv_bps > 7500 {
        eprintln!("\n❌ Error: LTV too high! {}% > 75%", ltv_bps / 100);
        std::process::exit(1);
    }

    let secret_key = [1u8; 32];
    let collateral_wei = collateral_eth * 1_000_000_000_000_000_000u128;
    let eth_price_scaled = eth_price * 1_000_000u128; // 6 decimals
    let borrow_scaled = borrow_usd * 1_000_000u128; // 6 decimals
    let old_salt = [42u8; 32];
    let new_salt = [43u8; 32];
    let recipient = [0x12u8; 20];

    let borrow_input = BorrowInput {
        user_secret_key: secret_key,
        collateral_amount: collateral_wei,
        collateral_price_usd: eth_price_scaled,
        existing_debt: 0,
        new_borrow_amount: borrow_scaled,
        max_ltv_bps: 7500,
        old_note_salt: old_salt,
        new_note_salt: new_salt,
        recipient_address: recipient,
    };

    let mut stdin = SP1Stdin::new();
    stdin.write(&1u8); // Operation type: 1 = borrow
    stdin.write(&borrow_input);

    // Execute to get output
    println!("\n🔨 Executing program...");
    let (mut output, report) = client.execute(ELF, &stdin).run().expect("execution failed");
    let result: BorrowOutput = output.read();
    
    println!("✅ Execution complete:");
    println!("   Cycles: {}", report.total_instruction_count());
    println!("   Valid: {}", result.is_valid);
    println!("   Nullifier: {:?}...", &result.nullifier_hash[..8]);
    println!("   New Commitment: {:?}...", &result.new_commitment_hash[..8]);

    if result.is_valid != 1 {
        eprintln!("\n❌ Error: Borrow validation failed!");
        std::process::exit(1);
    }

    // Generate Groth16 proof
    println!("\n🔨 Generating Groth16 proof...");
    println!("⚠️  This may take 10-15 minutes on first run");
    println!("   Subsequent runs will be much faster (~3-5 seconds)\n");
    
    let start = std::time::Instant::now();
    let proof = client.prove(&pk, &stdin)
        .groth16()
        .run()
        .expect("Groth16 proving failed");
    
    let elapsed = start.elapsed();
    
    println!("✅ Proof generated in {:?}", elapsed);
    println!("📦 Proof size: {} bytes", proof.bytes().len());

    // Verify proof
    println!("\n🔍 Verifying proof...");
    client.verify(&proof, &vk).expect("verification failed");
    println!("✅ Proof verified successfully!");

    // Save proof
    proof.save(output_file).expect("failed to save proof");
    println!("\n💾 Proof saved to: {}", output_file);

    // Save public values
    let public_values_file = format!("{}.public", output_file);
    let public_values = proof.public_values.to_vec();
    fs::write(&public_values_file, &public_values).expect("failed to save public values");
    println!("💾 Public values saved to: {}", public_values_file);

    // Save nullifier and commitment
    let nullifier_hex = hex::encode(result.nullifier_hash);
    let nullifier_file = format!("{}.nullifier", output_file);
    fs::write(&nullifier_file, &nullifier_hex).expect("failed to save nullifier");
    println!("💾 Nullifier saved to: {}", nullifier_file);

    let commitment_hex = hex::encode(result.new_commitment_hash);
    let commitment_file = format!("{}.commitment", output_file);
    fs::write(&commitment_file, &commitment_hex).expect("failed to save commitment");
    println!("💾 Commitment saved to: {}", commitment_file);

    println!("\n========================================");
    println!("✅ Borrow proof ready for on-chain verification!");
    println!("========================================\n");
}
