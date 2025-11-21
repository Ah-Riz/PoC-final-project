# Deploying to Mantle Sepolia Testnet

This guide walks you through deploying the Aegis Protocol private lending PoC to Mantle Sepolia testnet.

## Prerequisites

### 1. Get Testnet MNT Tokens

**Mantle Sepolia Faucet:**
- URL: https://faucet.sepolia.mantle.xyz
- Requirements: GitHub account or Twitter
- Amount: ~1 MNT per request (sufficient for deployment)

**Steps:**
1. Visit the faucet website
2. Connect your wallet (MetaMask)
3. Complete social verification (GitHub/Twitter)
4. Request tokens
5. Wait ~1-2 minutes for tokens to arrive

### 2. Configure Wallet

Add Mantle Sepolia to MetaMask:

```
Network Name: Mantle Sepolia
RPC URL: https://rpc.sepolia.mantle.xyz  
Chain ID: 5003
Currency Symbol: MNT
Block Explorer: https://explorer.sepolia.mantle.xyz
```

### 3. Setup Environment Variables

Create `.env` file in the project root:

```bash
# Copy from example
cp .env.example .env

# Edit .env
nano .env
```

Update with your values:

```env
# Mantle Sepolia Configuration
RPC_URL=https://rpc.sepolia.mantle.xyz
PRIVATE_KEY=<your-private-key-here>

# Will be populated after deployment
VAULT=
COLLATERAL_TOKEN=
DEBT_TOKEN=
VERIFIER=
```

⚠️ **Security Warning**: Never commit `.env` file with real private keys!

---

## Deployment Steps

### Step 1: Deploy Contracts

```bash
cd contracts

# Deploy to Mantle Sepolia
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --broadcast \
  --verify \
  --etherscan-api-key $MANTLE_API_KEY

# Note: --verify is optional, Mantle Sepolia verification may not be available
```

**Expected Output:**
```
Deploying MockETH...
MockETH deployed at: 0x...
Deploying MockUSDC...
MockUSDC deployed at: 0x...
Deploying MockSP1Verifier...
MockSP1Verifier deployed at: 0x...
Deploying AegisVault...
AegisVault deployed at: 0x...

Addresses saved to .env.contracts
```

### Step 2: Verify Deployment

Check contracts on Mantle Sepolia Explorer:

```bash
# Get addresses from .env.contracts
cat contracts/.env.contracts

# Visit explorer
open https://explorer.sepolia.mantle.xyz/address/<VAULT_ADDRESS>
```

**Verification Checklist:**
- ✅ MockETH deployed and funded
- ✅ MockUSDC deployed and funded
- ✅ AegisVault has 10M USDC balance
- ✅ All contracts show code (not just ETH address)

### Step 3: Update Environment

Copy deployed addresses to main `.env`:

```bash
# Append contract addresses
cat contracts/.env.contracts >> .env

# Verify
cat .env
```

### Step 4: Test Deposit (Optional Manual Test)

You can manually test a deposit using `cast`:

```bash
# 1. Approve collateral
cast send $COLLATERAL_TOKEN \
  "approve(address,uint256)" \
  $VAULT \
  10000000000000000000 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY

# 2. Create mock proof (for testing)
# In production, this would come from the ZK prover
PROOF="0x00"
COMMITMENT="0x1234567890123456789012345678901234567890123456789012345678901234"
PUBLIC_VALUES="${COMMITMENT}01"  # commitment + is_valid(1)

# 3. Submit deposit
cast send $VAULT \
  "deposit(uint256,bytes,bytes)" \
  10000000000000000000 \
  $PROOF \
  $PUBLIC_VALUES \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $PRIVATE_KEY
```

---

## Monitoring & Debugging

### Check Contract State

```bash
# Get vault's collateral balance
cast call $VAULT \
  "getCollateralBalance()" \
  --rpc-url https://rpc.sepolia.mantle.xyz

# Get vault's debt token balance
cast call $VAULT \
  "getDebtBalance()" \
  --rpc-url https://rpc.sepolia.mantle.xyz

# Get number of commitments
cast call $VAULT \
  "getCommitmentCount()" \
  --rpc-url https://rpc.sepolia.mantle.xyz
```

### View Transactions

```bash
# Get latest transactions for vault
open "https://explorer.sepolia.mantle.xyz/address/${VAULT}/transactions"
```

### Debugging Failed Transactions

If transactions fail:

1. **Check gas:**
   ```bash
   cast balance $YOUR_ADDRESS --rpc-url https://rpc.sepolia.mantle.xyz
   ```

2. **Simulate transaction:**
   ```bash
   cast call $VAULT "deposit(...)" \
     --from $YOUR_ADDRESS \
     --rpc-url https://rpc.sepolia.mantle.xyz
   ```

3. **Check contract state:**
   ```bash
   cast storage $VAULT 0 --rpc-url https://rpc.sepolia.mantle.xyz
   ```

---

## Running Full E2E Test on Testnet

Once deployed, run the integration test:

```bash
cd script

# Build the test binary
cargo build --release --bin e2e

# Run against testnet (ensure .env has testnet config)
cargo run --release --bin e2e
```

**Expected Flow:**
1. ✅ Generate deposit ZK proof
2. ✅ Submit deposit transaction to Mantle Sepolia  
3. ✅ Wait for confirmation (~2 seconds)
4. ✅ Generate borrow ZK proof
5. ✅ Submit borrow transaction
6. ✅ Verify USDC received
7. ✅ Check nullifier marked as spent

---

## Cost Estimation

Typical gas costs on Mantle Sepolia:

| Operation | Gas Used | Cost (MNT) | Notes |
|-----------|----------|------------|-------|
| Deploy MockETH | ~990K | ~0.001 | One-time |
| Deploy MockUSDC | ~990K | ~0.001 | One-time |
| Deploy AegisVault | ~1.4M | ~0.002 | One-time |
| Deposit | ~200K | ~0.0002 | Per deposit |
| Borrow | ~300K | ~0.0003 | Per borrow |
| **Total Deployment** | ~3.4M | **~0.004 MNT** | |

💰 **1 MNT from faucet is more than enough for full testing!**

---

## Privacy Verification on Block Explorer

### What You Should See:

**Deposit Transaction:**
- ✅ From: Your wallet address
- ✅ To: AegisVault contract
- ✅ Method: `deposit`
- ❌ **NOT visible:** Exact collateral amount (hidden in proof)
- ✅ Visible: Commitment hash (meaningless without secret key)

**Borrow Transaction:**
- ✅ From: Different wallet (privacy!)
- ✅ To: AegisVault contract
- ✅ Method: `borrow`
- ✅ Visible: Borrowed amount (5000 USDC - public)
- ✅ Visible: Nullifier hash
- ❌ **NOT visible:** Link to deposit transaction
- ❌ **NOT visible:** Collateral amount

**Privacy Achieved!** 🎉  
An observer cannot determine:
- How much collateral backs the borrow
- Which deposit corresponds to which borrow
- The identity link between wallets

---

## Troubleshooting

### "Insufficient Funds" Error
```bash
# Check balance
cast balance $YOUR_ADDRESS --rpc-url https://rpc.sepolia.mantle.xyz

# Get more from faucet
open https://faucet.sepolia.mantle.xyz
```

### "Invalid Proof" Error
- Ensure public values match Rust serialization format
- Check endianness (little-endian for u128)
- Verify commitment/nullifier hashes

### "Transaction Reverted" Error
```bash
# Get detailed error
cast run <TX_HASH> --rpc-url https://rpc.sepolia.mantle.xyz
```

### Contract Not Showing Code
- Wait 30-60 seconds after deployment
- Refresh block explorer page
- Check transaction receipt for deployment address

---

## Next Steps

After successful testnet deployment:

1. **Share Results**
   - Post deployment addresses in docs
   - Share explorer links showing privacy
   - Document any issues encountered

2. **Performance Testing**
   - Measure actual gas costs
   - Test with different collateral amounts
   - Verify proof generation times

3. **Mainnet Preparation**
   - Security audit contracts
   - Optimize gas usage
   - Implement real SP1 verifier (not mock)
   - Add proper access controls

---

## Deployed Contract Addresses (Update After Deployment)

```
Network: Mantle Sepolia (Chain ID: 5003)

MockETH: 0x________________
MockUSDC: 0x________________  
MockSP1Verifier: 0x________________
AegisVault: 0x________________

Explorer: https://explorer.sepolia.mantle.xyz

Deployment Date: ___________
Deployer: 0x________________
```

---

## Resources

- **Mantle Docs:** https://docs.mantle.xyz
- **Mantle Sepolia Explorer:** https://explorer.sepolia.mantle.xyz
- **Mantle Faucet:** https://faucet.sepolia.mantle.xyz
- **SP1 Documentation:** https://docs.succinct.xyz
- **Foundry Book:** https://book.getfoundry.sh

---

**Ready to deploy? Start with Step 1!** 🚀
