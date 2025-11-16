# Aegis SP1 PoC – LTV Safety Check

This document explains how to use the Aegis SP1 proof-of-concept (PoC), how it works under the hood, and how the same pattern can be extended to work on Mantle EVM.

The PoC implements a **loan-to-value (LTV) safety check** inside the SP1 zkVM, and drives it from a host-side Rust script.

---

## 1. Overview

The PoC demonstrates the core idea behind Aegis:

- Users have a **position** with:
  - `collateral_value` (e.g. mETH value in some unit)
  - `debt_value` (e.g. stablecoin debt)
  - `max_ltv_bps` (max LTV in basis points, 10_000 = 100%)
- The zk-program checks whether the position is **safe**:

  ```text
  debt_value * 10_000 <= collateral_value * max_ltv_bps
  ```

- If the inequality holds (and inputs are valid), it outputs `is_safe = 1`, otherwise `0`.
- The host script:
  - Embeds the compiled zk-program ELF
  - Sends a `PositionInput` into the zkVM
  - Executes the program, generates a proof, and verifies it locally

Later, the same proof can be made **EVM-verifiable on Mantle** using SP1’s on-chain verifiers.

---

## 2. Project Layout

At the time of this PoC the relevant folders are:

- **`blueprint.md`**
  - High-level design of Aegis Protocol.
- **`zk-program/`**
  - SP1 **guest program** (zkVM code) that implements the LTV safety check.
- **`script/`**
  - SP1 **host script** (Rust binary) that runs the guest program, provides inputs, and generates/verifies proofs.

---

## 3. Prerequisites

You need the following on your machine:

- **Rust toolchain** (with `cargo`).
- **Succinct SP1 toolchain** (`cargo prove`, `sp1-zkvm` toolchain) installed and configured.
- **C/C++ build tools** (on macOS: Xcode Command Line Tools or full Xcode), so crates like `sp1-core-machine` can compile.
- **Docker** is *not* required for this PoC, because we use the default SP1 prover mode (core STARK). For on-chain Groth16/Plonk proofs, Docker or the SP1 prover network would be required.

Sanity checks:

```bash
rustc -V
cargo -V
# SP1 toolchain (example; details depend on your install method):
# cargo prove -h
```

On macOS, if you hit errors like `fatal error: 'cassert' file not found`, install or fix Command Line Tools:

```bash
xcode-select --install
# If needed:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## 4. Building the zk-program (guest)

Path: `zk-program/`

Cargo manifest (simplified):

```toml
[package]
name = "zk-program"
version = "0.1.0"
edition = "2021"

[dependencies]
sp1-zkvm = "4.0.0"
serde = { version = "1.0", features = ["derive"] }
```

The guest program entrypoint (`zk-program/src/main.rs`):

```rust
#![no_main]
sp1_zkvm::entrypoint!(main);

const BPS_DENOMINATOR: u128 = 10_000;

pub fn main() {
    let input = sp1_zkvm::io::read::<PositionInput>();

    let inputs_valid = input.collateral_value > 0 && input.max_ltv_bps as u128 <= BPS_DENOMINATOR;

    let lhs = input.debt_value.saturating_mul(BPS_DENOMINATOR);
    let rhs = input
        .collateral_value
        .saturating_mul(input.max_ltv_bps as u128);

    let is_safe: u8 = if inputs_valid && lhs <= rhs { 1 } else { 0 };

    sp1_zkvm::io::commit(&is_safe);
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct PositionInput {
    pub collateral_value: u128,
    pub debt_value: u128,
    pub max_ltv_bps: u16,
}
```

### 4.1 What this logic does

- **Inputs**: a `PositionInput` struct is read from the host using `sp1_zkvm::io::read`.
- **Validation**:
  - `collateral_value > 0` (zero collateral positions are always unsafe).
  - `max_ltv_bps <= 10_000` (no more than 100%).
- **LTV check**:
  - We compare `debt_value / collateral_value` against `max_ltv_bps / 10_000` **without division** by cross-multiplying:

    ```text
    debt_value * 10_000 <= collateral_value * max_ltv_bps
    ```

  - `saturating_mul` is used to prevent arithmetic overflow from panicking the VM.
- **Output**:
  - If inputs are valid and the inequality holds, commit `is_safe = 1`.
  - Otherwise commit `is_safe = 0`.
  - This `is_safe` is a **public output** of the zk-program.

### 4.2 Building the guest program

From the project root:

```bash
cd zk-program
cargo prove build
```

This compiles the Rust guest into an SP1 ELF, typically at a path like:

```text
zk-program/target/elf-compilation/
  riscv32im-succinct-zkvm-elf/release/zk-program
```

The host script includes this ELF at compile time.

---

## 5. Running the host script (prover)

Path: `script/`

Cargo manifest (simplified):

```toml
[package]
name = "zk-script"
version = "0.1.0"
edition = "2021"

[dependencies]
sp1-sdk = "5.2.2"
serde = { version = "1.0", features = ["derive"] }
```

Core of `script/src/main.rs`:

```rust
use serde::{Deserialize, Serialize};
use sp1_sdk::{utils, ProverClient, SP1Stdin, SP1ProofWithPublicValues};

// Embed the compiled SP1 ELF for the zk-program.
const ELF: &[u8] = include_bytes!(
    "../../zk-program/target/elf-compilation/riscv32im-succinct-zkvm-elf/release/zk-program"
);

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
        collateral_value: 100_000_000u128, // e.g. 100 units with 1e6 decimals
        debt_value: 60_000_000u128,        // 60 units
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
```

### 5.1 What the host does step-by-step

1. **Embed the ELF**
   - `include_bytes!` embeds the guest ELF into the binary at compile time.
   - This ensures the host and guest are always in sync (no need to ship the ELF separately).

2. **Construct a `PositionInput`**
   - Hard-coded example values:
     - `collateral_value = 100_000_000`
     - `debt_value = 60_000_000`
     - `max_ltv_bps = 7500`
   - These represent, e.g., 100 units of collateral, 60 units of debt, 75% max LTV.

3. **Write inputs into `SP1Stdin`**
   - `SP1Stdin` is a serialization-friendly input stream for the zkVM.
   - `stdin.write(&input)` serializes the Rust struct into the format that matches `sp1_zkvm::io::read::<PositionInput>()` inside the guest.

4. **Execute the guest program**
   - `client.execute(ELF, &stdin).run()` runs the zkVM without generating a proof.
   - Returns an execution report containing stats like `total_instruction_count` (cycle count).

5. **Generate a proof (core STARK)**
   - `client.setup(ELF)` computes proving and verifying keys for this ELF.
   - `client.prove(&pk, &stdin).run()` produces an SP1 proof and `SP1PublicValues`.
   - This uses the **core prover mode** (default STARK proofs); no Docker required.

6. **Read public values**
   - The guest committed a single `u8` (`is_safe`).
   - `proof.public_values.read()` reads that value back in the host.

7. **Verify the proof**
   - `client.verify(&proof, &vk)` checks that the proof is valid for this ELF and public values.
   - If verification fails, the script panics.

8. **Optional: serialize / deserialize the proof**
   - `proof.save("proof-with-public-values.bin")` writes the proof + public values to disk.
   - `SP1ProofWithPublicValues::load(...)` loads it back.
   - The script verifies the loaded proof to demonstrate portability.

### 5.2 Running the host script

From the project root:

```bash
cd script
cargo run --release
```

You should see output similar to:

```text
executed program with 4981 cycles
generated proof
is_safe (1 = safe, 0 = unsafe): 1
successfully generated and verified proof for the program
successfully verified loaded proof
```

This confirms that:

- The zk-program ran inside SP1.
- A proof was generated and verified.
- For the given `PositionInput`, the position is considered **safe**.

> Note: At this stage, inputs are hard-coded in `script/src/main.rs`. You can tweak them directly in code to experiment with safe vs unsafe positions.

---

## 6. Why this works (zkVM + LTV safety)

Conceptually, the proof states:

> “There exists a private `PositionInput` such that when the SP1 program is run on it, the public output `is_safe` equals this value, and the program’s logic enforces the LTV rule.”

Key points:

- The guest program is deterministic and fully specified (no dynamic code loading).
- The SP1 zkVM guarantees that:
  - The program really executed on the provided `PositionInput`.
  - The committed `is_safe` is exactly what the program computed.
- A verifier (off-chain now, on-chain later) doesn’t see the private values directly, but learns the correctness of `is_safe` relative to the program.

In this PoC, we only commit a single public value (`is_safe`), but the same pattern can be extended to:

- Commit note commitments, Merkle roots, nullifiers, etc.
- Commit aggregate risk metrics.
- Keep user positions fully private while exposing only what the smart contract needs (e.g., that a borrow/repay action is safe).

---

## 7. How this maps to Mantle EVM (example)

This PoC currently verifies proofs **off-chain** in the Rust host. To make it work on **Mantle EVM**, we need to:

1. Generate **EVM-verifiable proofs** (Groth16 or Plonk) instead of only core STARK proofs.
2. Deploy SP1’s **verifier contracts** on Mantle.
3. Have an Aegis vault contract call the verifier and enforce `is_safe == 1` before updating state.

### 7.1 Generating EVM-friendly proofs

SP1 supports different proof types:

- **Core (default)** – what this PoC uses now (good for local verification).
- **Compressed** – constant-size STARK proofs.
- **Groth16 / Plonk** – SNARK proofs suitable for EVM verification.

From the SP1 docs (proof types):

```rust
// Core (default)
let client = ProverClient::from_env();
client.prove(&pk, &stdin).run().unwrap();

// Compressed
client.prove(&pk, &stdin).compressed().run().unwrap();

// Groth16
client.prove(&pk, &stdin).groth16().run().unwrap();

// PLONK
client.prove(&pk, &stdin).plonk().run().unwrap();
```

For EVM, you typically choose **Groth16 (recommended)** or **PLONK**. These modes usually require Docker (or access to Succinct’s prover network) because they run heavy recursive circuits and SNARK provers.

In this PoC, the only code change in `script/src/main.rs` to move towards Mantle compatibility is switching:

```rust
let mut proof = client
    .prove(&pk, &stdin)
    .run()?;         // core
```

to:

```rust
let mut proof = client
    .prove(&pk, &stdin)
    .groth16()       // or .plonk()
    .run()?;
```

The rest of the logic (reading `is_safe` from `public_values`) remains the same.

### 7.2 Deploying an SP1 verifier on Mantle

Succinct provides Solidity contracts ("SP1 verifier gateway") that can verify Groth16/Plonk proofs produced by SP1.

At a high level, the on-chain setup on Mantle would be:

1. Import or deploy the SP1 verifier contracts (e.g., from `sp1-contracts`).
2. Configure a verifier instance for your specific program ELF and proof type.
3. Deploy your Aegis vault contract that depends on that verifier.

This typically looks like (conceptually, using Foundry or Hardhat):

- Deploy `SP1Verifier` (Groth16 or Plonk variant) to Mantle.
- Register the verifying key for your `zk-program` ELF.
- Expose a function like:

  ```solidity
  interface ISp1Verifier {
      function verify(bytes calldata proof, bytes calldata publicValues)
          external
          view
          returns (bool);
  }
  ```

The exact ABI depends on the SP1 contracts, but conceptually you pass:

- `proof`: the Groth16/Plonk proof bytes from the Rust host.
- `publicValues`: ABI-encoded public outputs (e.g., the `is_safe` flag and any other public data you decide to commit).

### 7.3 Example: Aegis-like vault on Mantle

Imagine a simplified `AegisVault` on Mantle that enforces `is_safe == 1` via an SP1 verifier.

Assume the SP1 guest commits **only** `is_safe` as a public value (as in this PoC), and everything else (`PositionInput`, notes, etc.) remains private.

High-level Solidity sketch:

```solidity
// Pseudo-code: interface to SP1 verifier deployed on Mantle.
interface ISp1Verifier {
    function verify(bytes calldata proof, bytes calldata publicValues)
        external
        view
        returns (bool);
}

contract AegisVault {
    ISp1Verifier public sp1Verifier;

    constructor(address _verifier) {
        sp1Verifier = ISp1Verifier(_verifier);
    }

    // Borrow function gated by a zk proof of LTV safety.
    function borrowWithProof(
        bytes calldata proof,
        bytes calldata publicValues
    ) external {
        // 1. Verify the SP1 proof on-chain.
        bool ok = sp1Verifier.verify(proof, publicValues);
        require(ok, "invalid zk proof");

        // 2. Decode public values. In this PoC, we only have is_safe (u8).
        //    Encode/decode format must match how SP1PublicValues is serialized
        //    on the Rust side. For illustration, we assume it is a single byte.
        require(publicValues.length == 1, "invalid public values");
        uint8 isSafe = uint8(bytes1(publicValues[0]));
        require(isSafe == 1, "unsafe position");

        // 3. If needed, update user balances/notes.
        //    At this stage, the contract knows that there exists a private
        //    PositionInput that satisfies the LTV rule. More complex versions
        //    would tie this to commitments and Merkle roots in blueprint.md.

        // TODO: implement actual accounting / note updates.
    }
}
```

End-to-end flow:

1. **Off-chain (client)**
   - User constructs a private `PositionInput`.
   - User runs the SP1 host client (similar to `script`) to produce a Groth16/Plonk proof with public `is_safe`.
   - If `is_safe == 1`, the client sends `(proof, publicValues)` to the AegisVault contract on Mantle.

2. **On-chain (Mantle EVM)**
   - `AegisVault.borrowWithProof` calls `sp1Verifier.verify`.
   - If the proof is valid and `isSafe == 1`, the contract updates balances / notes.
   - The on-chain logic never sees the raw `collateral_value` or `debt_value`; it only sees that they satisfy the LTV constraint according to the audited SP1 program.

This mirrors the **core Aegis idea** from `blueprint.md`: actions are performed inside a private zk circuit, and the Mantle smart contract only checks **validity**, not raw positions.

---

## 8. Summary and next steps

- You now have a working SP1 PoC that:
  - Encodes an Aegis-style LTV safety check in a zkVM guest program.
  - Proves and verifies correctness using the SP1 SDK in Rust.
  - Produces a public `is_safe` flag that can be used by smart contracts.
- To move towards a full Aegis MVP on Mantle:
  - Extend the circuit to handle notes, Merkle trees, and real asset values.
  - Switch to Groth16/Plonk proof types and deploy SP1 verifier contracts on Mantle.
  - Wire the proof verification into an `AegisVault` contract that gates borrow/repay flows on `is_safe == 1`.

This PoC is intentionally minimal but already captures the **core invariant** of a lending protocol: _only allow positions that satisfy a chosen LTV rule, proven in zero-knowledge_.
