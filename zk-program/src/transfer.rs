use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TransferInput {
    // Sender info (private)
    pub sender_secret: [u8; 32],
    pub sender_balance: u128,
    
    // Transfer details (private)
    pub transfer_amount: u128,
    pub token_address: [u8; 20],
    pub recipient_address: [u8; 20],
    
    // Metadata (optional, private)
    pub memo: [u8; 32],
    pub nonce: u64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TransferOutput {
    // Public outputs (hashed for privacy)
    pub transfer_hash: [u8; 32],      // Hash of all transfer data
    pub sender_commitment: [u8; 32],  // Commitment to sender
    pub is_valid: u8,                 // 1 if valid, 0 if not
}

pub fn verify_transfer(input: &TransferInput) -> TransferOutput {
    use sha2::{Sha256, Digest};
    
    // Validation 1: Check sufficient balance
    let has_sufficient_balance = input.sender_balance >= input.transfer_amount;
    
    // Validation 2: Check non-zero amount
    let is_nonzero_amount = input.transfer_amount > 0;
    
    // Validation 3: Check recipient is not zero address
    let is_valid_recipient = input.recipient_address != [0u8; 20];
    
    // Overall validity
    let is_valid = if has_sufficient_balance && is_nonzero_amount && is_valid_recipient {
        1u8
    } else {
        0u8
    };
    
    // Create sender commitment (hash of sender secret + balance)
    let mut sender_hasher = Sha256::new();
    sender_hasher.update(&input.sender_secret);
    sender_hasher.update(&input.sender_balance.to_le_bytes());
    let sender_commitment: [u8; 32] = sender_hasher.finalize().into();
    
    // Create transfer hash (hash of all transfer details)
    // This proves transfer happened without revealing details
    let mut transfer_hasher = Sha256::new();
    transfer_hasher.update(&sender_commitment);
    transfer_hasher.update(&input.transfer_amount.to_le_bytes());
    transfer_hasher.update(&input.token_address);
    transfer_hasher.update(&input.recipient_address);
    transfer_hasher.update(&input.memo);
    transfer_hasher.update(&input.nonce.to_le_bytes());
    let transfer_hash: [u8; 32] = transfer_hasher.finalize().into();
    
    TransferOutput {
        transfer_hash,
        sender_commitment,
        is_valid,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_transfer() {
        let input = TransferInput {
            sender_secret: [1u8; 32],
            sender_balance: 1000,
            transfer_amount: 100,
            token_address: [0x1u8; 20],
            recipient_address: [0x2u8; 20],
            memo: [0u8; 32],
            nonce: 1,
        };
        
        let output = verify_transfer(&input);
        assert_eq!(output.is_valid, 1);
    }

    #[test]
    fn test_insufficient_balance() {
        let input = TransferInput {
            sender_secret: [1u8; 32],
            sender_balance: 50,
            transfer_amount: 100,
            token_address: [0x1u8; 20],
            recipient_address: [0x2u8; 20],
            memo: [0u8; 32],
            nonce: 1,
        };
        
        let output = verify_transfer(&input);
        assert_eq!(output.is_valid, 0);
    }

    #[test]
    fn test_zero_amount() {
        let input = TransferInput {
            sender_secret: [1u8; 32],
            sender_balance: 1000,
            transfer_amount: 0,
            token_address: [0x1u8; 20],
            recipient_address: [0x2u8; 20],
            memo: [0u8; 32],
            nonce: 1,
        };
        
        let output = verify_transfer(&input);
        assert_eq!(output.is_valid, 0);
    }
}
