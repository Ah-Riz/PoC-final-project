use sha2::{Digest, Sha256};

/// Hash a note to create a commitment
/// commitment = hash(secret_key || collateral_amount || debt_amount || salt)
pub fn hash_commitment(
    secret_key: &[u8; 32],
    collateral_amount: u128,
    debt_amount: u128,
    salt: &[u8; 32],
) -> [u8; 32] {
    let mut hasher = Sha256::new();
    
    hasher.update(secret_key);
    hasher.update(collateral_amount.to_le_bytes());
    hasher.update(debt_amount.to_le_bytes());
    hasher.update(salt);
    
    let result = hasher.finalize();
    result.into()
}

/// Hash to create a nullifier (marks note as spent)
/// nullifier = hash(secret_key || "NULLIFIER" || salt)
pub fn hash_nullifier(secret_key: &[u8; 32], salt: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    
    hasher.update(secret_key);
    hasher.update(b"NULLIFIER");
    hasher.update(salt);
    
    let result = hasher.finalize();
    result.into()
}

/// Verify ownership of a note
/// Returns true if the provided secret can generate the commitment
pub fn verify_note_ownership(
    secret_key: &[u8; 32],
    collateral_amount: u128,
    debt_amount: u128,
    salt: &[u8; 32],
    expected_commitment: &[u8; 32],
) -> bool {
    let computed = hash_commitment(secret_key, collateral_amount, debt_amount, salt);
    computed == *expected_commitment
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_commitment_deterministic() {
        let secret = [1u8; 32];
        let salt = [2u8; 32];
        let amount = 1000u128;
        let debt = 500u128;

        let hash1 = hash_commitment(&secret, amount, debt, &salt);
        let hash2 = hash_commitment(&secret, amount, debt, &salt);

        assert_eq!(hash1, hash2, "Hash should be deterministic");
    }

    #[test]
    fn test_nullifier_deterministic() {
        let secret = [1u8; 32];
        let salt = [2u8; 32];

        let null1 = hash_nullifier(&secret, &salt);
        let null2 = hash_nullifier(&secret, &salt);

        assert_eq!(null1, null2, "Nullifier should be deterministic");
    }

    #[test]
    fn test_different_secrets_different_commitments() {
        let secret1 = [1u8; 32];
        let secret2 = [2u8; 32];
        let salt = [3u8; 32];
        let amount = 1000u128;
        let debt = 0u128;

        let hash1 = hash_commitment(&secret1, amount, debt, &salt);
        let hash2 = hash_commitment(&secret2, amount, debt, &salt);

        assert_ne!(hash1, hash2, "Different secrets should produce different hashes");
    }

    #[test]
    fn test_ownership_verification() {
        let secret = [1u8; 32];
        let salt = [2u8; 32];
        let amount = 1000u128;
        let debt = 500u128;

        let commitment = hash_commitment(&secret, amount, debt, &salt);

        assert!(
            verify_note_ownership(&secret, amount, debt, &salt, &commitment),
            "Should verify correct ownership"
        );

        let wrong_secret = [99u8; 32];
        assert!(
            !verify_note_ownership(&wrong_secret, amount, debt, &salt, &commitment),
            "Should reject wrong secret"
        );
    }
}
