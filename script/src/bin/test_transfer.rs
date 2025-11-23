use serde::{Deserialize, Serialize};
use sp1_sdk::{utils, HashableKey, ProverClient, SP1Stdin};
use std::time::Instant;

// Embed the compiled SP1 ELF
const ELF: &[u8] = include_bytes!("../../../zk-program/target/elf-compilation/riscv32im-succinct-zkvm-elf/release/zk-program");

#[derive(Serialize, Deserialize, Debug, Clone)]
struct TransferInput {
    sender_secret: [u8; 32],
    sender_balance: u128,
    transfer_amount: u128,
    token_address: [u8; 20],
    recipient_address: [u8; 20],
    memo: [u8; 32],
    nonce: u64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct TransferOutput {
    transfer_hash: [u8; 32],
    sender_commitment: [u8; 32],
    is_valid: u8,
}

fn main() {
    // Load .env file to get SP1_PROVER and SP1_PRIVATE_KEY
    dotenvy::dotenv().ok();
    
    utils::setup_logger();

    println!("\n========================================");
    println!("  Private Transfer - ZK Proof Demo");
    println!("  Fast Execution + Groth16 Proof");
    println!("========================================\n");

    // Check prover mode
    let prover_mode = std::env::var("SP1_PROVER").unwrap_or_else(|_| "mock".to_string());
    println!("🔧 Prover Mode: {}\n", prover_mode);

    let client = ProverClient::from_env();
    let (pk, vk) = client.setup(ELF);

    println!("📋 Verification Key: {}\n", vk.bytes32());

    // Test 1: Valid transfer (execution only)
    println!("[Test 1/3] Valid Transfer - Execution");
    println!("-----------------------------------");
    
    let transfer1 = TransferInput {
        sender_secret: [1u8; 32],
        sender_balance: 1000_000_000, // 1000 tokens
        transfer_amount: 100_000_000,  // 100 tokens
        token_address: [0x1u8; 20],
        recipient_address: [0x2u8; 20],
        memo: [0u8; 32],
        nonce: 1,
    };

    let mut stdin1 = SP1Stdin::new();
    stdin1.write(&2u8); // Operation type: 2 = transfer
    stdin1.write(&transfer1);

    println!("  📤 Sender Balance: {} tokens", transfer1.sender_balance / 1_000_000);
    println!("  💸 Transfer Amount: {} tokens", transfer1.transfer_amount / 1_000_000);
    println!("  📍 Recipient: {:?}...\n", &transfer1.recipient_address[..4]);

    let start = Instant::now();
    let proof1 = client.prove(&pk, &stdin1).run().expect("proving failed");
    let mut output1 = proof1.public_values.clone();
    let result1: TransferOutput = output1.read();

    println!("  ✅ Execution: {:?}", start.elapsed());
    println!("  ✅ Valid: {}", result1.is_valid);
    println!("  🔐 Transfer Hash: 0x{}", hex::encode(&result1.transfer_hash[..8]));
    println!("  🔒 Sender Commitment: 0x{}", hex::encode(&result1.sender_commitment[..8]));

    assert_eq!(result1.is_valid, 1, "Valid transfer should pass");

    // Test 2: Insufficient balance
    println!("\n[Test 2/3] Insufficient Balance - Should Fail");
    println!("-----------------------------------");
    
    let transfer2 = TransferInput {
        sender_secret: [1u8; 32],
        sender_balance: 50_000_000,    // 50 tokens
        transfer_amount: 100_000_000,   // 100 tokens (more than balance!)
        token_address: [0x1u8; 20],
        recipient_address: [0x2u8; 20],
        memo: [0u8; 32],
        nonce: 2,
    };

    let mut stdin2 = SP1Stdin::new();
    stdin2.write(&2u8);
    stdin2.write(&transfer2);

    println!("  📤 Sender Balance: {} tokens", transfer2.sender_balance / 1_000_000);
    println!("  💸 Transfer Amount: {} tokens (TOO MUCH!)\n", transfer2.transfer_amount / 1_000_000);

    let start = Instant::now();
    let proof2 = client.prove(&pk, &stdin2).run().expect("proving failed");
    let mut output2 = proof2.public_values.clone();
    let result2: TransferOutput = output2.read();

    println!("  ✅ Execution: {:?}", start.elapsed());
    println!("  ❌ Valid: {} (expected 0)", result2.is_valid);
    println!("  ✅ Correctly rejected insufficient balance!");

    assert_eq!(result2.is_valid, 0, "Insufficient balance should fail");

    // Test 3: Generate real Groth16 proof using SP1 Network
    println!("\n[Test 3/3] Generate Groth16 Proof (SP1 Network)");
    println!("-----------------------------------");
    
    let transfer3 = TransferInput {
        sender_secret: [1u8; 32],
        sender_balance: 1000_000_000, // 1000 tokens
        transfer_amount: 250_000_000,  // 250 tokens
        token_address: [0x1u8; 20],
        recipient_address: [0x3u8; 20],
        memo: *b"Private transfer with ZK proof!!", // 32 bytes
        nonce: 3,
    };

    let mut stdin3 = SP1Stdin::new();
    stdin3.write(&2u8);
    stdin3.write(&transfer3);

    println!("  💸 Transfer: 250 tokens");
    println!("  📝 Memo: \"Private transfer with ZK proof!!\"");
    println!("  🌐 Using SP1 Network Prover (cloud-based)");
    println!("  ⏱️  Expected time: ~30-60 seconds\n");

    let start = Instant::now();
    
    // Generate Groth16 proof using SP1 Network
    println!("  🔄 Submitting to SP1 Network...");
    let groth16_proof = client.prove(&pk, &stdin3)
        .groth16()
        .run()
        .expect("Groth16 proving failed");
    
    let elapsed = start.elapsed();

    println!("  ✅ Proof generated in {:?}!", elapsed);
    println!("  📦 Proof size: {} bytes", groth16_proof.bytes().len());

    // Verify proof
    println!("\n  🔍 Verifying proof...");
    client.verify(&groth16_proof, &vk).expect("verification failed");
    println!("  ✅ Proof verified successfully!");

    // Save proof
    groth16_proof.save("transfer-groth16.proof").expect("failed to save proof");
    println!("\n  💾 Proof saved to: transfer-groth16.proof");

    // Decode output
    let mut output3 = groth16_proof.public_values.clone();
    let result3: TransferOutput = output3.read();

    println!("  🔐 Transfer Hash: 0x{}", hex::encode(&result3.transfer_hash[..16]));
    println!("  🔒 Sender Commitment: 0x{}", hex::encode(&result3.sender_commitment[..16]));
    println!("  ✅ Valid: {}", result3.is_valid);

    println!("\n========================================");
    println!("✅ All Transfer Tests Complete!");
    println!("========================================");
    println!("\n💡 Key Features Demonstrated:");
    println!("  ✅ Private transfers (amounts hidden)");
    println!("  ✅ Balance validation in ZK");
    println!("  ✅ Transfer hash commitment");
    println!("  ✅ Real Groth16 proofs (384 bytes)");
    println!("  ✅ Fast execution (<60s with network prover)");
    println!("  ✅ Ready for on-chain verification\n");
}
