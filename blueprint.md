# **Aegis Protocol: Technical Blueprint**

Version: 1.0  
Status: DRAFT  
Project: A Private, Yield-Bearing Money Market on Mantle

## **1\. Executive Summary**

### **1.1. Mission**

To build the first on-chain, fully private, yield-bearing money market. Aegis Protocol allows users to deposit yield-bearing collateral (like Mantle's mETH), earn yield, and take overcollateralized loans, all without exposing any link between their deposits, loans, or addresses.

### **1.2. The Problem**

DeFi is fundamentally transparent. This is a critical failure for institutional, high-net-worth, and strategy-driven users.

* **No Financial Privacy:** Loan sizes, collateral types, and liquidation points are public.  
* **PnL & Strategy Leakage:** Competitors can see and front-run your financial activities.  
* **Compliance Barrier:** A lack of privacy prevents compliant-conscious entities from engaging, while a lack of *any* verification prevents regulated assets from ever entering.

### **1.3. The Solution: Aegis Protocol**

Aegis is not a simple "mixer \+ lending" protocol. It is a **lending protocol built *inside* a shielded pool**, based on ZK-SNARKs (Zero-Knowledge Succinct Non-Interactive Arguments of Knowledge).  
It allows users to perform core money market actions (deposit, borrow, repay, withdraw) where the link between the action and the user is broken. The protocol's core "flywheel" is built around mETH, allowing for **private leveraged staking**.

### **1.4. The Mantle Advantage**

This protocol is **only economically viable on Mantle** for three specific reasons:

1. **Modular DA (EigenDA):** ZK-based protocols generate massive amounts of state/proof data. Posting this as calldata to L1 is prohibitively expensive. Mantle's use of EigenDA for data availability makes publishing this data orders of magnitude cheaper.  
2. **ZK-Optimized Architecture:** Mantle's transition to a ZK-rollup (using Succinct's SP1) means the base layer is optimized for the most expensive part of this protocol: **on-chain proof verification**.  
3. **Native Yield-Bearing LST (mETH):** mETH provides the perfect native collateral. The protocol can accrue mETH staking yield *inside* the private pool, creating a powerful, capital-efficient, and private flywheel effect.

## **2\. Core Architecture**

The system is composed of three main layers: **On-Chain Contracts (Mantle EVM)**, **ZK-Circuits (The Logic)**, and the **Client-Side Prover (User's Browser)**.

### **2.1. Architectural Diagram (Conceptual)**

\+-------------------------------------------------------------+  
| User's Browser (Client-Side)                                |  
|                                                             |  
|   \+-----------------+     \+------------------------------+  |  
|   |  Aegis Web UI   |     | Wasm/JS Prover (Generates    |  |  
|   | (React/Vue)     |     | ZK-SNARK Proofs for Deposit, |  |  
|   \+-----------------+     | Borrow, Repay, Withdraw)     |  |  
|                           \+------------------------------+  |  
|                                |                          |  
\+--------------------------------|----------------------------+  
                                 | (Transaction \+ Proof)  
                                 v  
\+-------------------------------------------------------------+  
| Mantle L2 EVM (On-Chain)                                    |  
|                                                             |  
|   \+-------------------------------------------------------+ |  
|   | AegisVault.sol (Main Contract)                        | |  
|   |                                                       | |  
|   | \- Holds all Token Liquidity (mETH, USDC)              | |  
|   | \- Stores Merkle Root (bytes32) & Nullifiers (mapping) | |  
|   |                                                       | |  
|   | \+ function deposit(...)                               | |  
|   | \+ function borrow(...)  \<-----+                       | |  
|   | \+ function repay(...)         |                       | |  
|   | \+ function withdraw(...)      |                       | |  
|   |                               |                       | |  
|   \+-------------------------------|-----------------------+ |  
|                                   |                         |  
|   \+-----------------+     \+-----------------+     \+-------+ |  
|   | Verifier.sol    |     | PriceOracle.sol |     |  ...  | |  
|   | (Verifies ZK-   |     | (e.g., RedStone) |     | Adapters| |  
|   | SNARK proof)    |     | (Provides mETH  |     | (mETH,  | |  
|   |                 |     | price)          |     | USDC)   | |  
|   \+-----------------+     \+-----------------+     \+-------+ |  
\+-------------------------------------------------------------+  
                                 |  
                                 | (Proof/State Data)  
                                 v  
\+-------------------------------------------------------------+  
| Mantle DA Layer (EigenDA)                                   |  
|                                                             |  
| \- Stores the full Merkle Tree of commitments (notes).       |  
| \- Stores historical proofs/data for client-side syncing.    |  
| \- This is a \*cheap\* data store, making the system viable.   |  
|                                                             |  
\+-------------------------------------------------------------+

## **3\. System Components (Deep Dive)**

### **3.1. On-Chain Contracts (Solidity)**

#### **AegisVault.sol**

This is the single entry-point and state-holder for the protocol.

* **State:**  
  * bytes32 public merkleRoot: The current root of the Merkle tree of all private "notes" (commitments).  
  * mapping(bytes32 \=\> bool) public nullifiers: A list of all *spent* notes to prevent double-spending.  
  * address public verifier: The address of the Verifier.sol contract.  
  * address public oracle: The address of the Price Oracle.  
  * mapping(address \=\> address) public tokenAdapters: Maps token addresses to their adapter contracts.  
* **Key Functions:**  
  * deposit(IERC20 \_token, uint256 \_amount, bytes32 \_commitment, bytes calldata \_proof):  
    1. Verifies the \_proof using the verifier contract.  
    2. Transfers \_amount of \_token from the user.  
    3. Calls \_insertCommitment(\_commitment) to update the merkleRoot.  
  * borrow(bytes calldata \_proof, BorrowData calldata \_data):  
    1. BorrowData contains public inputs: recipientAddress, borrowAmount, nullifierHash, newCommitmentHash, oracleData.  
    2. **Oracle Check:** Verifies the oracleData with the PriceOracle.sol to ensure the price is fresh.  
    3. **Nullifier Check:** Checks nullifiers\[\_data.nullifierHash\] \== false.  
    4. **Proof Check:** Calls verifier.verifyProof(\_proof, \_publicInputs). The ZK-proof *itself* contains the LTV logic.  
    5. If all pass:  
       * Marks nullifiers\[\_data.nullifierHash\] \= true.  
       * Updates merkleRoot with \_data.newCommitmentHash.  
       * Transfers \_data.borrowAmount of stablecoin to \_data.recipientAddress.  
  * repay(...): Similar logic, takes stablecoins back, creates a new note.  
  * withdraw(...): Similar logic, nullifies the user's note, sends them their collateral.

#### **Verifier.sol**

* This contract is **auto-generated** by the ZK-SNARK toolchain (e.g., circom \-\> snarkjs export-verifier).  
* Its sole purpose is to expose a function verifyProof(bytes calldata proof, uint256\[\] publicInputs) that returns true or false.

### **3.2. ZK-Circuits (The "Business Logic")**

This is the most critical part of the protocol, written in **Circom** or **Noir**. These circuits define the *rules* of the system.  
A "note" (commitment) will be a hash(privateKey, assetType, amount, debtAmount).

#### **deposit Circuit**

 * **Purpose:** Prove that a new commitment (with zero initial debt) was created correctly.  
 * **Private Inputs:** privateKey, assetType, amount.  
 * **Public Inputs:** commitmentHash.  
 * **Logic:** commitmentHash \=== hash(privateKey, assetType, amount, 0).

#### **borrow Circuit (The Core Circuit)**

* **Purpose:** Prove that a user is authorized to borrow a specific amount.  
* **Private Inputs:**  
  * oldNote: {privateKey, collateralAsset, collateralAmount, debtAmount}  
  * merklePath: The path to prove oldNote's commitment is in the merkleRoot.  
  * newNote: {newPrivateKey, collateralAsset, collateralAmount, newDebtAmount}  
* **Public Inputs:**  
  * merkleRoot: The current root of the vault.  
  * nullifierHash: The hash of the oldNote (to be spent).  
  * newCommitmentHash: The hash of the newNote.  
  * recipientAddress: The address to receive the borrowed funds.  
  * borrowAmount: The amount of stablecoin to borrow.  
  * oraclePrice: The price of the collateral (e.g., mETH/USDC).  
* **Logic (Constraints):**  
  1. **Prove Ownership:** nullifierHash \=== hash(oldNote.privateKey, oldNote...).  
  2. **Prove State Inclusion:** checkMerkleProof(oldNote.commitment, merklePath, merkleRoot) \=== true.  
  3. **Prove Math:** newNote.newDebtAmount \=== oldNote.debtAmount \+ borrowAmount.  
  4. **Prove LTV (The Rule):**  
     * collateralValue \= oldNote.collateralAmount \* oraclePrice  
     * newTotalDebt \= newNote.newDebtAmount \* stablecoinPrice (1)  
     * collateralValue \* MAX\_LTV\_RATIO \> newTotalDebt (e.g., MAX\_LTV\_RATIO \= 0.75).  
  5. **Prove New State:** newCommitmentHash \=== hash(newNote.newPrivateKey, newNote...).

## **4\. Key User Flows (Step-by-Step)**

### **4.1. Flow: Private Deposit**

1. **User (Alice, Wallet 1):** Wants to deposit 100 mETH.  
2. **UI:** Alice connects Wallet 1, types "100 mETH".  
3. **Client-Side:** The UI generates a new privateKey. It calls the deposit circuit to generate a ZK-proof and a commitmentHash.  
4. **On-Chain:** Alice's Wallet 1 submits the deposit transaction, which:  
   * Approves the AegisVault to spend 100 mETH.  
   * Calls AegisVault.deposit(mETH, 100, commitmentHash, proof).  
5. **Result:** The protocol holds 100 mETH. The public sees Wallet 1 deposited. Alice's browser prompts her to save her **Aegis Note** (the private key and note data).

### **4.2. Flow: Private Borrow**

1. **User (Alice, Wallet 2):** Wants to borrow 50k USDC to a new, unfunded wallet (Wallet 2).  
2. **UI:** Alice connects Wallet 2 (for gas) and *imports* her "Aegis Note" into the UI.  
3. **Client-Side:**  
   * The UI fetches the latest merkleRoot from AegisVault and oraclePrice from the oracle.  
   * It uses this data, plus her private note, to generate the complex borrow proof in Wasm (this may take 10-30 seconds).  
   * The publicInputs will specify recipientAddress \= Wallet 2 and borrowAmount \= 50,000.  
4. **On-Chain:** Alice's Wallet 2 sends the borrow transaction (with the proof).  
5. **Result:** The AegisVault verifies the proof and sends 50,000 USDC to Wallet 2\.  
   * **Privacy Achieved:** The public sees the Aegis protocol send 50k to a brand-new wallet. There is **zero on-chain link** to Wallet 1 or the 100 mETH deposit.

## **5\. Technical Challenges & Solutions**

### **5.1. Challenge: ZK-Oracle Integration**

* **Problem:** How does a ZK-circuit, which is pure math, trust a real-time mETH price?  
* **Solution:** The price is *not* a private input.  
  1. The user's client fetches a signed price update from the oracle (e.g., RedStone).  
  2. This oraclePrice and signature are passed as **public inputs** to the circuit.  
  3. The AegisVault.sol contract *also* verifies this signature and its timestamp, e.g., oracle.verify(oraclePrice, signature, timestamp).  
  4. The ZK-circuit simply proves: "My LTV calculation is valid *given this exact oraclePrice*." The contract proves "*This oraclePrice* is valid."

### **5.2. Challenge: State & Merkle Tree Sync**

* **Problem:** To create a merklePath, the client needs to know the *entire tree* of commitments. This is a massive state that can't live on-chain.  
* **Solution (The Mantle Advantage):**  
  1. The AegisVault contract emits an event CommitmentAdded(bytes32 commitment, uint256 index).  
  2. A trusted (or decentralized) "Relayer" service listens for these events, rebuilds the tree, and **publishes the full tree data to EigenDA** (which is cheap).  
  3. The client-side UI fetches the full tree from EigenDA nodes to sync its state, allowing it to build proofs without trusting a centralized server.

### **5.3. Challenge: Private Liquidations**

* **Problem:** How do you liquidate a position you can't see?  
* **Solution (V1 \- Self-Healing):**  
  * This is the most elegant solution. The mETH collateral is yield-bearing. The protocol *socializes* the mETH yield across all deposited mETH.  
  * This yield is first used to automatically pay down the *interest* on all outstanding loans.  
  * **Result:** As long as the mETH staking yield is higher than the borrow interest rate, positions are *self-healing* and will rarely, if ever, face liquidation. This creates a "safe" leveraged staking product.  
* **Solution (V2 \- ZK-Liquidations):**  
  * A liquidator can "ping" any note in the tree by submitting a ZK-proof.  
  * Liquidator proves(this note at index X, when checked against the current oraclePrice, is under-collateralized).  
  * If the proof is valid, the contract liquidates that (still private) note, pays the liquidator, and socializes the profit/loss. This is complex but trustless.

## **6\. Security & Compliance**

### **6.1. Security**

* **Circuit Audits:** The ZK-circuits are the primary attack surface. They must be audited by specialists (e.g., ZK-specific audit firms) to check for soundness errors.  
* **Contract Audits:** Standard Solidity audits for the vault, with a focus on re-entrancy and proof-verification logic.  
* **Trusted Setup:** The initial ZK-SNARK (e.g., Groth16) "toxic waste" must be generated via a secure, multi-party computation (MPC) ceremony.

### **6.2. Compliance (V2 \- "Aegis Pro")**

* The protocol can be made regulator-friendly without compromising user-to-user privacy.  
* **zkKYC:** Integrate a service like zkMe (already on Mantle).  
* **New Circuit Rule:** The borrow and withdraw circuits are modified to require an additional private input: a valid, signed "KYC SBT" from a trusted issuer.  
* **Logic:** Prove(I own my note... AND I own a valid KYC token).  
* **Result:** The protocol is now compliant (all users are verified), but no one can see *which* user is making *which* transaction. This is the "holy grail" for institutional adoption.

## **7\. Roadmap & Milestones**

* **M1 (Devnet):**  
  * Build deposit & withdraw circuits (Circom/Noir).  
  * Deploy AegisVault with basic Merkle tree logic.  
  * Build client-side prover for simple private transfers.  
  * **Goal:** A basic shielded pool for mETH.  
* **M2 (Testnet):**  
  * Build the borrow & repay circuits.  
  * Integrate RedStone oracle (both in-circuit and on-chain).  
  * Test EigenDA data publishing for state-sync.  
  * **Goal:** A working private money market.  
* **M3 (Testnet):**  
  * Implement mETH yield-accrual logic (V1 Liquidations).  
  * Incentive/Tokenomics design.  
  * Begin external audits of all circuits.  
  * **Goal:** Feature-complete, pre-audit, private leveraged staking.  
* **M4 (Mainnet):**  
  * Launch MPC trusted setup ceremony.  
  * Deploy audited contracts to Mantle Mainnet.  
  * Launch with mETH / USDC pool and bootstrap liquidity via MNT incentives.  
* **M5 (V2):**  
  * Implement zkKYC for "Aegis Pro" compliant pools.  
  * Add support for other Mantle RWA-backed collateral.

## **8. Feasibility & Implementation Notes**

### **8.1. Overall Feasibility**

- **Technical viability:** The design is implementable on Mantle EVM using existing tooling (Circom/Noir circuits, Groth16/Plonk-style SNARKs, on-chain verifiers, and oracle integrations like RedStone). The note-commitment + Merkle tree + nullifier pattern is well understood and has precedent in other shielded pool and private transfer systems.
- **Complexity level:** This is a **non-trivial, multi-phase ZK protocol**, not a simple lending fork. It realistically requires dedicated Solidity + ZK engineers, infra (relayers, DA indexing), and multiple audit cycles. It is feasible as a Mantle-native flagship protocol, but must be shipped in stages (M1–M5) as already outlined.

### **8.2. Recommended MVP Scope (Devnet/Testnet)**

For an initial launch (M1–M2), a constrained scope keeps the build realistic while demonstrating the core innovation (private leveraged staking inside a shielded pool):

- **Assets:**
  - **Collateral:** mETH only.
  - **Debt asset:** A single stablecoin (e.g., USDC or a Mantle-native stable).
- **Circuits (V1):**
  - deposit, withdraw, and internal private transfer circuits.
  - a simplified borrow/repay circuit with **fixed** parameters (MAX_LTV, interest rate, oracle source) hardcoded or stored as public inputs.
- **Liquidations:**
  - Implement **V1 self-healing** only (socialized mETH yield paying down interest).
  - No V2 zk-liquidations in MVP; instead, use conservative MAX_LTV and borrow APR plus an emergency pause/parameter update mechanism (governance or multisig) for risk management.
- **State sync & data availability:**
  - For early devnet, a **centralized relayer/indexer** can maintain the Merkle tree from `CommitmentAdded` events and expose it via an API.
  - EigenDA integration can be introduced at M2 as the canonical, censorship-resistant data store once the core flows are stable.
- **Compliance:**
  - Defer zkKYC / "Aegis Pro" circuits to M5.
  - Design circuits with an **extension point** for an extra private input (e.g., `kycSBT`) so that V2 can be added without redesigning the entire system.

### **8.3. Key Technical Risks & Constraints**

- **Proving time & UX:**
  - The borrow circuit (Merkle inclusion + LTV math + note updates) will be relatively heavy. Browser-side proving can easily take **10–30 seconds** on consumer hardware.
  - Mitigations: keep the Merkle tree depth modest (e.g., 2^32 leaves or less), reuse common gadgets, and prefer proof systems with fast proving for the chosen circuit size.
- **Gas costs & verifier parameters:**
  - On-chain verification cost depends on proving system and circuit size. Mantle's lower gas and ZK-optimized stack help, but the verifier must still be tuned (minimal public inputs, lean circuits) to ensure borrowing and withdrawing remain economically viable.
- **Merkle tree & relayer liveness:**
  - Clients depend on a relayer/EigenDA combo to fetch the full tree and build Merkle paths.
  - The protocol must clearly define **fallback behavior** if the relayer is offline (e.g., multiple independent relayers, or a client mode that reconstructs the tree directly from Mantle logs at higher latency).
- **Economic soundness of "self-healing":**
  - V1 assumes mETH yield is generally **greater than or equal to** the borrow interest rate.
  - Risk controls: conservative MAX_LTV, conservative borrow APR, and a clear path to add V2 zk-liquidations before scaling TVL on mainnet.
- **Trusted setup & ceremony:**
  - If Groth16 is used, multiple circuits imply either a multi-circuit ceremony or a universal setup via a different proving system.
  - The MPC ceremony and verifier deployment should be treated as explicit preconditions for M4 (Mainnet) rather than afterthoughts.

### **8.4. Mantle-Specific Considerations**

- **EigenDA dependency:**
  - EigenDA is a strong fit for publishing Merkle tree snapshots and historical state, but the protocol should not be blocked on it for devnet. M1 can rely on a simpler indexer while keeping the EigenDA integration behind a clean abstraction.
- **ZK-optimized base layer:**
  - Mantle's ZK-rollup architecture and cheaper DA make on-chain verification and proof/data publishing materially more affordable than L1, which is what unlocks this design economically.
- **Native LST (mETH):**
  - mETH's staking yield is what powers the self-healing mechanism and the leveraged staking flywheel. Risk parameters (LTV, borrow APR, reserve factor) should be calibrated specifically to **Mantle's expected mETH yield profile**, not generic LST assumptions.

**Summary:** The Aegis Protocol, as described, is **doable** on Mantle and technically sound as a long-term design. A realistic path is to ship a tightly scoped MVP (M1–M2) with mETH-only collateral, simple self-healing, and a single stablecoin market, then iteratively add EigenDA-backed state sync, zk-liquidations, and zkKYC in later milestones.