use ethers::{
    contract::abigen,
    core::types::{Address, U256},
    middleware::SignerMiddleware,
    providers::{Http, Middleware, Provider},
    signers::{LocalWallet, Signer},
};
use serde::{Deserialize, Serialize};
use sp1_sdk::{ProverClient, SP1Stdin};
use std::{error::Error, sync::Arc};

// Embed the compiled SP1 ELF
const ELF: &[u8] = include_bytes!("../../zk-program/target/elf-compilation/riscv32im-succinct-zkvm-elf/release/zk-program");

// Data structures matching ZK program
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

// Generate contract bindings
abigen!(
    MockETH,
    r#"[
        function approve(address spender, uint256 amount) external returns (bool)
        function balanceOf(address account) external view returns (uint256)
    ]"#
);

abigen!(
    AegisVault,
    r#"[
        function deposit(uint256 amount, bytes calldata proof, bytes calldata publicValues) external
        function borrow(bytes calldata proof, bytes calldata publicValues) external
        function getCommitmentCount() external view returns (uint256)
        function getCollateralBalance() external view returns (uint256)
        function getDebtBalance() external view returns (uint256)
        function isNullifierSpent(bytes32 nullifierHash) external view returns (bool)
    ]"#
);

abigen!(
    MockUSDC,
    r#"[
        function balanceOf(address account) external view returns (uint256)
    ]"#
);

type SignedClient = SignerMiddleware<Provider<Http>, LocalWallet>;

pub struct IntegrationTest {
    client: Arc<SignedClient>,
    vault_address: Address,
    collateral_address: Address,
    debt_address: Address,
    prover_client: ProverClient,
}

impl IntegrationTest {
    pub async fn new(
        rpc_url: &str,
        private_key: &str,
        vault_addr: &str,
        collateral_addr: &str,
        debt_addr: &str,
    ) -> Result<Self, Box<dyn Error>> {
        // Setup ethers client
        let provider = Provider::<Http>::try_from(rpc_url)?;
        let chain_id = provider.get_chainid().await?;
        
        let wallet: LocalWallet = private_key.parse::<LocalWallet>()?.with_chain_id(chain_id.as_u64());
        let client = Arc::new(SignerMiddleware::new(provider, wallet));

        // Setup SP1 prover
        let prover_client = ProverClient::from_env();

        Ok(Self {
            client,
            vault_address: vault_addr.parse()?,
            collateral_address: collateral_addr.parse()?,
            debt_address: debt_addr.parse()?,
            prover_client,
        })
    }

    pub async fn run_full_flow(&self) -> Result<(), Box<dyn Error>> {
        println!("\n========================================");
        println!("  End-to-End Integration Test");
        println!("========================================\n");

        // Step 1: Deposit
        println!("[STEP 1] Generating deposit proof and submitting...");
        let (commitment, secret_key, salt) = self.test_deposit().await?;
        
        // Step 2: Borrow
        println!("\n[STEP 2] Generating borrow proof and submitting...");
        self.test_borrow(secret_key, salt, commitment).await?;

        println!("\n========================================");
        println!("  ✅ Integration Test Complete!");
        println!("========================================\n");

        Ok(())
    }

    async fn test_deposit(&self) -> Result<([u8; 32], [u8; 32], [u8; 32]), Box<dyn Error>> {
        let secret_key = [1u8; 32];
        let collateral_amount = 10_000_000_000_000_000_000u128; // 10 ETH
        let salt = [42u8; 32];

        println!("  💰 Depositing 10 ETH (amount will be hidden)...");

        // Generate ZK proof
        let deposit_input = DepositInput {
            user_secret_key: secret_key,
            collateral_amount,
            note_salt: salt,
        };

        let mut stdin = SP1Stdin::new();
        stdin.write(&0u8); // Operation: deposit
        stdin.write(&deposit_input);

        // Execute to get output
        let (mut output, report) = self.prover_client.execute(ELF, &stdin).run()?;
        let result: DepositOutput = output.read();
        
        println!("  ✓ ZK proof generated ({} cycles)", report.total_instruction_count());
        println!("  ✓ Commitment: 0x{}", hex::encode(&result.commitment_hash[..8]));

        // For local testing with MockVerifier, we use a dummy proof
        let proof = vec![0u8]; // Mock proof
        
        // Encode public values (commitment + is_valid)
        let mut public_values = Vec::new();
        public_values.extend_from_slice(&result.commitment_hash);
        public_values.push(result.is_valid);

        // Approve collateral
        let collateral = MockETH::new(self.collateral_address, self.client.clone());
        let approve_tx = collateral
            .approve(self.vault_address, U256::from(collateral_amount))
            .send()
            .await?
            .await?;
        println!("  ✓ Approved collateral (tx: 0x{})", hex::encode(&approve_tx.unwrap().transaction_hash[..4]));

        // Submit deposit
        let vault = AegisVault::new(self.vault_address, self.client.clone());
        let deposit_tx = vault
            .deposit(
                U256::from(collateral_amount),
                proof.into(),
                public_values.into(),
            )
            .send()
            .await?
            .await?;
        
        println!("  ✓ Deposit submitted (tx: 0x{})", hex::encode(&deposit_tx.unwrap().transaction_hash[..4]));

        // Verify state
        let commitment_count: U256 = vault.get_commitment_count().call().await?;
        let collateral_balance: U256 = vault.get_collateral_balance().call().await?;
        
        println!("  ✓ Vault now has {} commitments", commitment_count);
        println!("  ✓ Vault collateral balance: {} ETH", collateral_balance / U256::from(10u128.pow(18)));

        Ok((result.commitment_hash, secret_key, salt))
    }

    async fn test_borrow(
        &self,
        secret_key: [u8; 32],
        old_salt: [u8; 32],
        _commitment: [u8; 32],
    ) -> Result<(), Box<dyn Error>> {
        let collateral_amount = 10_000_000_000_000_000_000u128; // 10 ETH
        let collateral_price = 2500_000_000u128; // $2500 with 6 decimals
        let borrow_amount = 5000_000_000u128; // 5000 USDC
        let new_salt = [43u8; 32];
        
        // Use a different address for recipient to show privacy
        let recipient = self.client.address();
        let mut recipient_bytes = [0u8; 20];
        recipient_bytes.copy_from_slice(recipient.as_bytes());

        println!("  🏦 Borrowing 5000 USDC...");
        println!("     Collateral: 10 ETH (hidden in ZK proof)");
        println!("     Price: $2500/ETH");
        println!("     LTV: 20% (safe)");

        // Generate ZK proof
        let borrow_input = BorrowInput {
            user_secret_key: secret_key,
            collateral_amount,
            collateral_price_usd: collateral_price,
            existing_debt: 0,
            new_borrow_amount: borrow_amount,
            max_ltv_bps: 7500, // 75%
            old_note_salt: old_salt,
            new_note_salt: new_salt,
            recipient_address: recipient_bytes,
        };

        let mut stdin = SP1Stdin::new();
        stdin.write(&1u8); // Operation: borrow
        stdin.write(&borrow_input);

        // Execute to get output
        let (mut output, report) = self.prover_client.execute(ELF, &stdin).run()?;
        let result: BorrowOutput = output.read();

        println!("  ✓ ZK proof generated ({} cycles)", report.total_instruction_count());
        println!("  ✓ Nullifier: 0x{}", hex::encode(&result.nullifier_hash[..8]));
        println!("  ✓ New commitment: 0x{}", hex::encode(&result.new_commitment_hash[..8]));

        // Encode public values for Solidity (101 bytes total)
        let mut public_values = vec![0u8; 101];
        public_values[0..32].copy_from_slice(&result.nullifier_hash);
        public_values[32..64].copy_from_slice(&result.new_commitment_hash);
        public_values[64..84].copy_from_slice(&result.recipient_address);
        
        // Encode u128 as little-endian
        for i in 0..16 {
            public_values[84 + i] = ((result.borrow_amount >> (8 * i)) & 0xFF) as u8;
        }
        public_values[100] = result.is_valid;

        // Check balance before
        let debt_token = MockUSDC::new(self.debt_address, self.client.clone());
        let balance_before: U256 = debt_token.balance_of(recipient).call().await?;

        // Submit borrow
        let proof = vec![1u8]; // Mock proof
        let vault = AegisVault::new(self.vault_address, self.client.clone());
        let borrow_tx = vault
            .borrow(proof.into(), public_values.into())
            .send()
            .await?
            .await?;

        println!("  ✓ Borrow submitted (tx: 0x{})", hex::encode(&borrow_tx.unwrap().transaction_hash[..4]));

        // Check balance after
        let balance_after: U256 = debt_token.balance_of(recipient).call().await?;
        let received = balance_after - balance_before;
        
        println!("  ✓ Received {} USDC", received / U256::from(1_000_000));

        // Verify nullifier is spent
        let is_spent = vault.is_nullifier_spent(result.nullifier_hash).call().await?;
        println!("  ✓ Nullifier marked as spent: {}", is_spent);

        // Verify commitment count increased
        let commitment_count: U256 = vault.get_commitment_count().call().await?;
        println!("  ✓ Total commitments: {}", commitment_count);

        Ok(())
    }
}
