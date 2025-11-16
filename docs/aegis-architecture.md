# Aegis Architecture – Real-World Implementation on Mantle

This document describes how to implement the Aegis Protocol architecture in a realistic deployment on **Mantle EVM**, including:

- On-chain smart contracts
- Off-chain backend / relayer
- Frontend + client-side prover using SP1

It builds on the SP1 PoC in `docs/aegis-sp1-poc.md` and shows how to move from a local LTV check to a production-grade system.

---

## 1. High-Level System Overview

At a high level, Aegis consists of three layers:

- **On-Chain (Mantle EVM)**
  - Smart contracts that hold assets, track commitments / Merkle roots, and verify SP1 proofs.
- **Off-Chain Backend / Relayer**
  - Indexes on-chain events, maintains Merkle trees, and serves data (Merkle proofs, note sets) to clients.
- **Frontend + Client-Side Prover**
  - Browser or desktop client that interacts with the user’s wallet, builds private circuit inputs, runs SP1 proving, and sends proofs to Mantle.

### 1.1 Core Ideas

- **Privacy**: Positions (collateral, debt, PnL) are represented as **notes/commitments**, not raw balances.
- **Correctness**: All state-changing actions (borrow, repay, withdraw) are accompanied by an SP1 proof that enforces Aegis’ rules (LTV, interest accrual, Merkle membership, etc.).
- **Data Availability**: Relayers and/or EigenDA provide access to historical commitments and Merkle trees.

---

## 2. On-Chain Architecture (Mantle EVM)

On-chain, you typically have the following contracts:

- **AegisVault**
  - Holds collateral (e.g. mETH) and debt assets (e.g. stablecoin).
  - Maintains a mapping from **Merkle roots** to the current tree state.
  - Exposes entrypoints like `deposit`, `borrowWithProof`, `repayWithProof`, `withdrawWithProof`.

- **NoteRegistry / Commitment Tree**
  - Tracks **note commitments** emitted by deposit/borrow/repay/withdraw.
  - Maintains the canonical Merkle root that off-chain relayers agree on.
  - Can be a dedicated contract or logically part of `AegisVault`.

- **SP1Verifier / SP1Gateway**
  - Verifies **Groth16/Plonk proofs** produced by SP1.
  - Holds verifying keys associated with the deployed zk-program ELF.
  - Exposes a function such as:

    ```solidity
    interface ISp1Verifier {
        function verify(bytes calldata proof, bytes calldata publicValues)
            external
            view
            returns (bool);
    }
    ```

- **Token Adapters / Asset Modules**
  - Optional helper contracts that wrap mETH, stablecoin(s), or other RWAs.
  - Enforce protocol-specific rules (e.g. whitelisted assets, rate models).

- **Governance / Parameter Manager**
  - Stores risk parameters (LTV caps, rate models, pause flags).
  - May be a simple multisig or a full DAO module.

### 2.1 Smart Contract Responsibilities

- **AegisVault**
  - Custody: holds user collateral and debt asset balances.
  - Cross-check: accepts or rejects actions based on SP1 proofs.
  - Accounting: updates global and per-user accounting variables (e.g. total debt, reserves, yields).

- **Note/Merkle Tree Module**
  - Emits events like `CommitmentAdded(bytes32 commitment, uint256 index)`.
  - Tracks the latest Merkle root for the commitment tree.
  - Enforces that nullifiers (spent notes) cannot be reused.

- **SP1Verifier**
  - Stateless: given `(proof, publicValues)`, returns whether the proof is valid.
  - Tied to a specific zk-program version; upgrading circuits typically means deploying a new verifier.

---

## 3. Off-Chain Backend / Relayer

The backend/relayer is a critical component that glues on-chain state to client-side proving.

### 3.1 Responsibilities

- **Event Indexing**
  - Subscribe to Mantle logs (e.g. via JSON-RPC or a node provider).
  - Index events like `CommitmentAdded`, `NullifierUsed`, `RootUpdated` from Aegis contracts.

- **Merkle Tree Maintenance**
  - Reconstruct the Merkle tree of note commitments from on-chain events.
  - Keep track of **all intermediate roots** and a mapping from note index to its Merkle path.

- **Data Availability APIs**
  - Provide REST or GraphQL APIs for clients, e.g.:
    - `GET /tree/latest-root`
    - `GET /tree/proof?index=<i>`
    - `GET /notes?owner=<publicKeyHint>` (if you use extra indexing hints)

- **EigenDA / DA Integration (later)**
  - Periodically write batched commitments and Merkle roots to EigenDA.
  - Expose references (like DA hashes or block IDs) back to on-chain or to clients.

### 3.2 Example API Endpoints

An example JSON REST API might provide:

- `GET /status`
  - Returns current synced block, latest Merkle root, and indexer health.

- `GET /tree/root`
  - Response: `{ "root": "0x...", "height": 32 }`

- `GET /tree/proof?index=123`
  - Response: `{ "path": ["0x...", "0x...", ...], "indices": [0,1,...], "root": "0x..." }`

- `GET /notes/by-commitment?commitment=0x...`
  - Optionally returns metadata if stored (e.g. timestamp, block number).

These APIs are used by the frontend/client to obtain Merkle inclusion proofs and current roots before proving.

---

## 4. Frontend + Client-Side Prover

The frontend is where users interact with Aegis, usually via a web app (React, Next.js, etc.) and a Mantle-compatible wallet (e.g. MetaMask).

### 4.1 Responsibilities

- **Wallet Integration**
  - Connect to Mantle via wallet.
  - Sign EVM transactions (deposits, borrowWithProof, etc.).

- **State Fetching**
  - Read on-chain state via JSON-RPC or a provider library.
  - Fetch Merkle data via the backend APIs.

- **Prover Integration (SP1)**
  - Build the private inputs for the zk-program (e.g. note secrets, `PositionInput`).
  - Run SP1 in the browser or in a native helper (WebAssembly or native binary), depending on UX and performance.
  - Generate a Groth16/Plonk proof and public values.

- **Transaction Construction**
  - Encode `proof` and `publicValues` as calldata.
  - Call the relevant Aegis contract function (e.g., `borrowWithProof`).

### 4.2 Example UI Flows

#### 4.2.1 Deposit Flow

1. **User picks asset and amount** in the UI (e.g. 10 mETH).
2. Frontend:
   - Calls `approve` on the mETH token for `AegisVault`.
   - Calls `AegisVault.deposit(amount)`.
3. Contract:
   - Transfers mETH from user to vault.
   - Computes a new note commitment (using a circuit or off-chain logic) and emits `CommitmentAdded`.
4. Relayer:
   - Indexes `CommitmentAdded` and updates the Merkle tree.

Because deposit can be simple and fully public (0 debt), it may not require a heavy circuit. In more advanced designs, the `deposit` itself is also privately proven.

#### 4.2.2 Borrow Flow (with zk proof)

1. **User wants to borrow** against mETH collateral.
2. Frontend:
   - Queries the relayer to get the **Merkle path** for the collateral note.
   - Reads protocol parameters (e.g., `max_ltv_bps`) from on-chain.
   - Builds a `PositionInput` (similar to the PoC) plus any additional private inputs required by the borrow circuit (e.g., note secrets, new note commitments).
3. Prover (client-side):
   - Runs the SP1 borrow circuit program.
   - Circuit checks:
     - The note is in the Merkle tree (Merkle inclusion).
     - The position respects the LTV and risk parameters.
     - The nullifiers and new notes are consistent.
   - Produces a **Groth16/Plonk proof** and public values (at minimum, `is_safe = 1`, plus any necessary public commitments like new root or note commitments).
4. Frontend:
   - Packages `(proof, publicValues)` into a transaction.
   - Calls `AegisVault.borrowWithProof(proof, publicValues)` on Mantle.
5. On-chain:
   - `AegisVault` calls `SP1Verifier.verify(proof, publicValues)`.
   - If valid and `is_safe == 1`, the contract:
     - Marks old notes as spent (via nullifiers).
     - Adds new notes/commitments.
     - Updates Merkle root.
     - Mints or transfers debt asset to the user.

This is the real-world version of the **PoC LTV check**, enforced through SP1 proofs.

---

## 5. End-to-End Mantle Example (from PoC to Production)

This section ties the current PoC to an end-to-end Mantle deployment.

### 5.1 Current PoC (Local)

- Guest: `zk-program` implementing an LTV check using `PositionInput`:
  - `collateral_value`
  - `debt_value`
  - `max_ltv_bps`
- Host: `script` proving and verifying locally with SP1 core prover.
- Output: `is_safe` printed in your terminal.

### 5.2 Extending the PoC for Mantle

1. **Upgrade the proof type**
   - Switch from `.prove(&pk, &stdin).run()` to `.prove(&pk, &stdin).groth16().run()` or `.plonk()` in `script/src/main.rs`.
   - Use SP1’s instructions for generating EVM-friendly proofs (Groth16/Plonk).

2. **Align public values with on-chain needs**
   - Currently, the zk-program only commits `is_safe`.
   - For the full protocol, you may commit:
     - The new Merkle root.
     - Commitment hashes of new notes.
     - Nullifiers for spent notes.
   - Design `SP1PublicValues` so it maps clearly to a Solidity struct or encoded bytes.

3. **Deploy SP1 verifier contracts on Mantle**
   - Build or import `SP1Verifier` contracts targeting your chosen SNARK (Groth16/Plonk).
   - Deploy to Mantle testnet/mainnet.
   - Register verifying keys for your `zk-program` ELF.

4. **Implement Aegis contracts**
   - Implement `AegisVault` and optional `NoteRegistry` with:
     - Functions like `borrowWithProof(bytes proof, bytes publicValues)`.
     - Internal calls to `SP1Verifier.verify`.
     - Logic to update commitments, nullifiers, and Merkle roots.

5. **Stand up the relayer**
   - Implement an indexer (e.g., in TypeScript/Node or Rust) that:
     - Listens to Mantle logs.
     - Maintains Merkle trees.
     - Serves a REST/GraphQL API to the frontend.

6. **Integrate the frontend**
   - Build a React/Next.js app that:
     - Connects to Mantle via wallet.
     - Fetches Merkle proofs from the relayer.
     - Runs SP1 proving (with a WebAssembly or native helper) using Aegis circuits.
     - Submits `proof` and `publicValues` to `AegisVault`.

### 5.3 Example User Story

> "Alice wants to borrow privately against her mETH on Mantle."

1. Alice deposits mETH through the Aegis UI.
2. A commitment for her collateral position is added on-chain.
3. The relayer indexes this, updates the Merkle tree, and exposes the new root.
4. Alice opens the **Borrow** screen:
   - The frontend fetches the Merkle path for her note.
   - The frontend constructs `PositionInput` based on off-chain pricing (e.g., from an oracle).
5. Alice clicks **Generate Proof**:
   - The client runs SP1 locally, proving that her position respects the LTV rule and other constraints.
   - The proof includes public `is_safe = 1` and updated commitments/roots.
6. The frontend sends an EVM transaction to `AegisVault.borrowWithProof` on Mantle.
7. `AegisVault` calls `SP1Verifier.verify`:
   - If valid and `is_safe == 1`, the contract updates state and sends stablecoins to Alice.

From Mantle’s perspective, it only sees a proof and some commitments, not Alice’s raw collateral and debt values.

---

## 6. Deployment & Operations Considerations

- **Mantle Environment**
  - Start on Mantle testnet for integration and audits.
  - Use Mantle RPC endpoints and explorers for monitoring.

- **Relayer Reliability**
  - Run multiple relayers for redundancy.
  - Consider open-sourcing the Merkle indexer so others can run independent instances.

- **Prover UX**
  - Proving can take seconds to tens of seconds depending on circuit size and hardware.
  - Consider a dual mode:
    - Local browser proving for maximum privacy.
    - Optional remote prover (e.g., SP1’s prover network) for low-power devices.

- **Upgradability**
  - Circuits may evolve (bugfixes, optimizations, new features).
  - Plan for:
    - Versioned ELF / verifying keys.
    - Contract-level versioning of verifiers.
    - Migration paths for existing positions.

---

## 7. Summary

To implement the Aegis architecture in a real setting on Mantle:

- **On-chain** contracts hold assets, maintain note commitments and Merkle roots, and verify SP1 proofs.
- An **off-chain relayer** maintains Merkle trees and exposes data needed for proving.
- A **frontend + client-side prover** builds private inputs, runs SP1 circuits, and submits proofs to Mantle.

The current SP1 PoC in this repository focuses on one core invariant: **LTV safety**. A real deployment extends this by:

- Richer circuits (notes, Merkle trees, interest, liquidations).
- EVM-verifiable proof types (Groth16/Plonk).
- Full-stack integration across frontend, backend, and Mantle contracts.

This document should give you a concrete blueprint for turning the local PoC into a full Aegis MVP on Mantle.
