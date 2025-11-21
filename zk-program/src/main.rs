#![no_main]
sp1_zkvm::entrypoint!(main);

mod types;
mod crypto;

use types::*;
use crypto::*;

const BPS_DENOMINATOR: u128 = 10_000;

/// Main entry point for the ZK program
/// Reads operation type and dispatches to appropriate handler
pub fn main() {
    // Read operation type: 0 = deposit, 1 = borrow
    let operation_type: u8 = sp1_zkvm::io::read::<u8>();

    match operation_type {
        0 => handle_deposit(),
        1 => handle_borrow(),
        _ => {
            // Invalid operation, output failure
            let output = DepositOutput {
                commitment_hash: [0u8; 32],
                is_valid: 0,
            };
            sp1_zkvm::io::commit(&output);
        }
    }
}

/// Handle deposit operation - create initial commitment
fn handle_deposit() {
    let input = sp1_zkvm::io::read::<DepositInput>();

    // Validate inputs
    if input.collateral_amount == 0 {
        let output = DepositOutput {
            commitment_hash: [0u8; 32],
            is_valid: 0,
        };
        sp1_zkvm::io::commit(&output);
        return;
    }

    // Generate commitment hash for the deposit
    // Commitment = hash(secret_key, collateral_amount, debt=0, salt)
    let commitment_hash = hash_commitment(
        &input.user_secret_key,
        input.collateral_amount,
        0, // Initial deposit has zero debt
        &input.note_salt,
    );

    let output = DepositOutput {
        commitment_hash,
        is_valid: 1,
    };

    sp1_zkvm::io::commit(&output);
}

/// Handle borrow operation - prove LTV is safe and generate new commitment
fn handle_borrow() {
    let input = sp1_zkvm::io::read::<BorrowInput>();

    // Step 1: Generate nullifier for old note (marks it as spent)
    let nullifier_hash = hash_nullifier(&input.user_secret_key, &input.old_note_salt);

    // Step 2: Calculate new total debt
    let new_total_debt = input.existing_debt.saturating_add(input.new_borrow_amount);

    // Step 3: Verify LTV ratio is safe
    let is_ltv_safe = check_ltv(
        input.collateral_amount,
        input.collateral_price_usd,
        new_total_debt,
        input.max_ltv_bps,
    );

    // Step 4: Generate new commitment with updated debt
    let new_commitment_hash = hash_commitment(
        &input.user_secret_key,
        input.collateral_amount,
        new_total_debt,
        &input.new_note_salt,
    );

    // Step 5: Create output
    let output = BorrowOutput {
        nullifier_hash,
        new_commitment_hash,
        recipient_address: input.recipient_address,
        borrow_amount: input.new_borrow_amount,
        is_valid: if is_ltv_safe { 1 } else { 0 },
    };

    sp1_zkvm::io::commit(&output);
}

/// Check if the LTV (Loan-to-Value) ratio is safe
/// Returns true if debt is within acceptable limits
fn check_ltv(
    collateral_amount: u128,
    collateral_price_usd: u128,
    total_debt: u128,
    max_ltv_bps: u16,
) -> bool {
    // Validate inputs
    if collateral_amount == 0 || collateral_price_usd == 0 {
        return false;
    }

    if max_ltv_bps as u128 > BPS_DENOMINATOR {
        return false;
    }

    // To avoid overflow, we rearrange the formula:
    // Instead of: debt <= (collateral * price * max_ltv) / 10000
    // We use: debt * 10000 <= collateral * price * max_ltv
    
    // Note: collateral_amount is in wei (18 decimals)
    // collateral_price_usd is in 6 decimals
    // total_debt is in 6 decimals
    // We need to normalize: divide collateral by 1e18 to get ETH, multiply by price
    // Final collateral_value and debt should be in same units (USD with 6 decimals)
    
    // Normalize collateral to ETH (remove 18 decimals)
    let collateral_eth = collateral_amount / 1_000_000_000_000_000_000;
    
    // Calculate collateral value in USD (both in 6 decimals now)
    let collateral_value_usd = collateral_eth.saturating_mul(collateral_price_usd);
    
    // Calculate max allowed debt
    let max_allowed_debt = collateral_value_usd
        .saturating_mul(max_ltv_bps as u128)
        .saturating_div(BPS_DENOMINATOR);

    // Check if debt is within limits
    total_debt <= max_allowed_debt
}
