use serde::{Deserialize, Serialize};

/// Input for deposit operation (initial commitment creation)
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DepositInput {
    /// User's secret key (proves ownership)
    pub user_secret_key: [u8; 32],
    /// Amount of collateral being deposited (hidden)
    pub collateral_amount: u128,
    /// Random salt for commitment uniqueness
    pub note_salt: [u8; 32],
}

/// Input for borrow operation (full private lending)
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct BorrowInput {
    /// User's secret key (proves ownership of old note)
    pub user_secret_key: [u8; 32],
    /// Amount of collateral (hidden)
    pub collateral_amount: u128,
    /// Price of collateral in USD (e.g., mETH price)
    pub collateral_price_usd: u128,
    /// Existing debt amount
    pub existing_debt: u128,
    /// New amount to borrow
    pub new_borrow_amount: u128,
    /// Maximum LTV ratio in basis points (7500 = 75%)
    pub max_ltv_bps: u16,
    /// Salt from old note
    pub old_note_salt: [u8; 32],
    /// Salt for new note
    pub new_note_salt: [u8; 32],
    /// Recipient address for borrowed funds
    pub recipient_address: [u8; 20],
}

/// Public output from deposit proof
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DepositOutput {
    /// Commitment hash (to be stored on-chain)
    pub commitment_hash: [u8; 32],
    /// Whether the deposit is valid
    pub is_valid: u8,
}

/// Public output from borrow proof
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct BorrowOutput {
    /// Hash of the old note being spent (nullifier)
    pub nullifier_hash: [u8; 32],
    /// New commitment hash (with updated debt)
    pub new_commitment_hash: [u8; 32],
    /// Address to receive borrowed funds
    pub recipient_address: [u8; 20],
    /// Amount being borrowed
    pub borrow_amount: u128,
    /// Whether the borrow is valid (LTV safe)
    pub is_valid: u8,
}

/// Represents a private note (commitment)
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Note {
    pub user_secret_key: [u8; 32],
    pub collateral_amount: u128,
    pub debt_amount: u128,
    pub salt: [u8; 32],
}
