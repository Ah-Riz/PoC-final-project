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
