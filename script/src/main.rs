use serde::{Deserialize, Serialize};
use sp1_sdk::{utils, ProverClient, SP1Stdin, SP1ProofWithPublicValues};

// Embed the compiled SP1 ELF for the zk-program.
const ELF: &[u8] = include_bytes!("../../zk-program/target/elf-compilation/riscv32im-succinct-zkvm-elf/release/zk-program");

#[derive(Serialize, Deserialize)]
struct PositionInput {
    collateral_value: u128,
    debt_value: u128,
    max_ltv_bps: u16,
}

fn main() {
    // Setup logging for SP1 SDK.
    utils::setup_logger();

    // Example safe position: 100 collateral, 60 debt, max LTV 75%.
    let input = PositionInput {
        collateral_value: 100_000_000u128, // e.g. 100 USDC with 1e6 decimals
        debt_value: 60_000_000u128,        // 60 USDC
        max_ltv_bps: 7500,                 // 75%
    };

    // Prepare stdin for the zk program.
    let mut stdin = SP1Stdin::new();
    stdin.write(&input);

    // Create a prover client from the environment.
    let client = ProverClient::from_env();

    // First just execute the program (no proof) to check behavior and cycle count.
    let (_, report) = client.execute(ELF, &stdin).run().expect("failed to execute program");
    println!("executed program with {} cycles", report.total_instruction_count());

    // Now generate a proof using the default (core) prover, which doesn't require Docker.
    let (pk, vk) = client.setup(ELF);
    let mut proof = client
        .prove(&pk, &stdin)
        .run()
        .expect("failed to generate proof");

    println!("generated proof");

    // Read the public output committed by the guest program.
    let is_safe: u8 = proof.public_values.read();
    println!("is_safe (1 = safe, 0 = unsafe): {}", is_safe);

    // Verify the proof.
    client
        .verify(&proof, &vk)
        .expect("verification of proof failed");

    println!("successfully generated and verified proof for the program");

    // Optionally, round-trip serialize the proof to a file.
    proof
        .save("proof-with-public-values.bin")
        .expect("saving proof failed");

    let loaded_proof = SP1ProofWithPublicValues::load("proof-with-public-values.bin")
        .expect("loading proof failed");

    client
        .verify(&loaded_proof, &vk)
        .expect("verification of loaded proof failed");

    println!("successfully verified loaded proof");
}
