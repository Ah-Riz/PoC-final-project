# 🚀 How to Use Your ZK Privacy PoC

**Network:** Mantle Sepolia Testnet  
**Status:** ✅ Live and Ready  
**Your Contracts:**
- Vault: `0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9`
- MockETH: `0xBed33F5eE4c637878155d60f1bc59c83eDA440bD`
- MockUSDC: `0x4Fc1b1cFD7a0B819952a6922cA695CF3C4DCC0E0`

---

## 📋 **Table of Contents**

1. [Quick Start (5 minutes)](#quick-start)
2. [Test Private Deposits](#test-deposits)
3. [Test Private Borrows](#test-borrows)
4. [View on Explorer](#view-explorer)
5. [Advanced Usage](#advanced)
6. [Share with Others](#share)

---

## 🚀 Quick Start {#quick-start}

### **1. Check Your Deployment**

```bash
# View your deployed contracts
cat .env | grep -E "(VAULT|COLLATERAL|DEBT|VERIFIER)"

# Check vault liquidity
cast call 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  "getDebtBalance()(uint256)" \
  --rpc-url https://rpc.sepolia.mantle.xyz

# Result: Should show 10000000000000 (10M USDC)
```

### **2. Get Test Tokens**

```bash
# Mint 100 MockETH to your address
cast send 0xBed33F5eE4c637878155d60f1bc59c83eDA440bD \
  "mint(address,uint256)" \
  YOUR_ADDRESS \
  100000000000000000000 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key YOUR_KEY

# Check balance
cast call 0xBed33F5eE4c637878155d60f1bc59c83eDA440bD \
  "balanceOf(address)(uint256)" \
  YOUR_ADDRESS \
  --rpc-url https://rpc.sepolia.mantle.xyz
```

---

## 💰 Test Private Deposits {#test-deposits}

### **Method 1: Using Scripts (Easiest)**

```bash
cd script

# Run full integration test
cargo run --release --bin e2e

# This will:
# 1. Generate ZK proofs for deposit
# 2. Create private commitment
# 3. Submit to vault
# 4. Verify on-chain
```

### **Method 2: Manual Test**

```bash
# 1. Approve collateral
cast send 0xBed33F5eE4c637878155d60f1bc59c83eDA440bD \
  "approve(address,uint256)" \
  0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  10000000000000000000 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key YOUR_KEY

# 2. Generate proof offline
cd script
cargo run --release --bin generate_proof deposit \
  --amount 10000000000000000000 \
  --secret YOUR_SECRET

# 3. Submit deposit with proof
# (Use the output from step 2)
```

### **What Happens:**

```
✅ Public on Explorer:
   - You sent 10 ETH to vault
   - A commitment hash was added
   - Transaction hash visible

🔐 Hidden (Private):
   - Your total balance
   - Your commitment = hash(secret + amount)
   - Link to future transactions
```

---

## 🏦 Test Private Borrows {#test-borrows}

### **Full Borrow Test**

```bash
cd script

# Test borrowing with ZK proofs
cargo run --release --bin e2e

# Or test specific scenarios:
cargo test --release test_borrow_with_collateral
```

### **What Happens:**

```
✅ Public on Explorer:
   - Someone received USDC from vault
   - A nullifier was used (prevents double-spend)
   - New commitment created

🔐 Hidden (Private):
   - Who provided collateral
   - How much collateral backs this
   - Total debt amount
   - Link between deposit and borrow
```

---

## 🔍 View on Explorer {#view-explorer}

### **Your Contracts:**

```bash
# Vault (main contract)
https://explorer.sepolia.mantle.xyz/address/0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9

# MockETH (collateral token)
https://explorer.sepolia.mantle.xyz/address/0xBed33F5eE4c637878155d60f1bc59c83eDA440bD

# MockUSDC (debt token)
https://explorer.sepolia.mantle.xyz/address/0x4Fc1b1cFD7a0B819952a6922cA695CF3C4DCC0E0
```

### **What to Look For:**

**Deposit Events:**
```
Event: Deposit(bytes32 commitment, uint256 timestamp)
✅ Visible: Commitment hash
❌ Hidden: Amount, user identity
```

**Borrow Events:**
```
Event: Borrow(bytes32 nullifier, bytes32 newCommitment, ...)
✅ Visible: Nullifiers, commitments
❌ Hidden: Collateral amount, who borrowed
```

---

## 🧪 Advanced Usage {#advanced}

### **1. Run Specific Tests**

```bash
cd script

# Test only transfers
cargo run --release --bin test_transfer

# Test with different amounts
cargo run --release --bin generate_proof deposit \
  --amount 5000000000000000000 \
  --secret "my_secret_key_123"

# Test multiuser scenarios
./test-multiuser.sh
```

### **2. Generate Proofs Locally**

```bash
cd script

# Generate deposit proof
cargo run --release --bin generate_proof deposit \
  --amount AMOUNT_IN_WEI \
  --secret YOUR_SECRET_KEY

# Generate borrow proof
cargo run --release --bin generate_proof borrow \
  --collateral AMOUNT \
  --debt AMOUNT \
  --ltv 8000  # 80% LTV
```

### **3. Interact with Smart Contracts Directly**

```bash
# Check commitment count
cast call 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  "getCommitmentCount()(uint256)" \
  --rpc-url https://rpc.sepolia.mantle.xyz

# Get specific commitment
cast call 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  "getCommitment(uint256)(bytes32)" \
  0 \
  --rpc-url https://rpc.sepolia.mantle.xyz

# Check if nullifier is spent
cast call 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  "isNullifierSpent(bytes32)(bool)" \
  NULLIFIER_HASH \
  --rpc-url https://rpc.sepolia.mantle.xyz
```

### **4. Monitor Events**

```bash
# Watch for new deposits
cast logs \
  --address 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  | grep "Deposit"

# Watch for borrows
cast logs \
  --address 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  | grep "Borrow"
```

---

## 👥 Share with Others {#share}

### **For Testers:**

Share this information:

```
🧪 Test My ZK Privacy Protocol on Mantle Sepolia!

Network: Mantle Sepolia
Chain ID: 5003
RPC: https://rpc.sepolia.mantle.xyz

Contracts:
- Vault: 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9
- MockETH: 0xBed33F5eE4c637878155d60f1bc59c83eDA440bD
- MockUSDC: 0x4Fc1b1cFD7a0B819952a6922cA695CF3C4DCC0E0

How to test:
1. Add Mantle Sepolia to MetaMask
2. Get testnet MNT from faucet
3. Mint test tokens (see docs)
4. Try private deposits/borrows

Features:
✅ Private balances (ZK proofs)
✅ Hidden collateral-debt links
✅ Commitment-based privacy
✅ Mock proofs (fast testing)
```

### **Quick Test Script for Users:**

```bash
#!/bin/bash
# test-user-flow.sh

echo "🧪 Testing ZK Privacy Protocol"
echo ""

# 1. Mint tokens
echo "1. Minting 10 MockETH..."
cast send 0xBed33F5eE4c637878155d60f1bc59c83eDA440bD \
  "mint(address,uint256)" \
  $YOUR_ADDRESS \
  10000000000000000000 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $YOUR_KEY

# 2. Approve
echo "2. Approving vault..."
cast send 0xBed33F5eE4c637878155d60f1bc59c83eDA440bD \
  "approve(address,uint256)" \
  0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  10000000000000000000 \
  --rpc-url https://rpc.sepolia.mantle.xyz \
  --private-key $YOUR_KEY

echo ""
echo "✅ Ready! Now run integration tests:"
echo "cd script && cargo run --release --bin e2e"
```

---

## 📊 Understanding the Output

### **When You Run Tests:**

```
[Test 1/3] Valid Transfer - Execution
  ✅ Execution: 39ms
  ✅ Valid: 1
  🔐 Transfer Hash: 0x8f696f3d...
  🔒 Sender Commitment: 0x3cf7076d...
```

**What This Means:**
- `Execution: 39ms` - ZK proof verification time (fast!)
- `Valid: 1` - Transaction approved by ZK circuit
- `Transfer Hash` - Unique identifier (can't be linked to you)
- `Sender Commitment` - Your encrypted balance

### **On Block Explorer:**

```
Transaction: 0xabc123...def789
From: 0xYourAddress
To: 0x9a10dEeDE...  (Vault)
Value: 10 ETH
```

**What's Hidden:**
- Your total balance
- Your borrowing capacity
- Link to previous transactions
- Connection to future borrows

---

## 🎯 Common Use Cases

### **Use Case 1: Anonymous Borrowing**

```bash
# 1. Alice deposits 10 ETH privately
# 2. Bob borrows 5K USDC
# 3. No one knows Bob used Alice's collateral!

cd script
cargo run --release --bin e2e
```

### **Use Case 2: Privacy-Preserving Lending**

```bash
# Lenders fund vault publicly
# Borrowers use privately
# Observers can't track individual loans

./test-multiuser.sh
```

### **Use Case 3: Demo for Investors**

```bash
# Show live testnet deployment
# Demonstrate privacy features
# Explain ZK proof generation

./testnet-quickstart.sh
```

---

## 🐛 Troubleshooting

### **Issue: Transaction Fails**

```bash
# Check gas balance
cast balance YOUR_ADDRESS --rpc-url https://rpc.sepolia.mantle.xyz

# Check token approval
cast call 0xBed33F5eE4c637878155d60f1bc59c83eDA440bD \
  "allowance(address,address)(uint256)" \
  YOUR_ADDRESS \
  0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  --rpc-url https://rpc.sepolia.mantle.xyz
```

### **Issue: Proof Generation Slow**

```bash
# Use mock proofs for testing
export SP1_PROVER=mock

# For production proofs
export SP1_PROVER=network
export SP1_PRIVATE_KEY=your-key
```

### **Issue: Can't See Contracts**

```bash
# Verify deployment
cat .env

# Check if contracts exist
cast code 0x9a10dEeDE493f86382Cb340E0c1942991C0DE5B9 \
  --rpc-url https://rpc.sepolia.mantle.xyz
```

---

## 📚 Next Steps

### **For Demo:**
1. ✅ Run `./testnet-quickstart.sh`
2. ✅ Show explorer transactions
3. ✅ Explain privacy features
4. ✅ Share contract addresses

### **For Development:**
1. Add more test cases
2. Optimize gas costs
3. Add frontend UI
4. Deploy to more testnets

### **For Production:**
1. Security audit
2. Switch to network prover (real Groth16)
3. Deploy on mainnet
4. Marketing & launch

---

## 🎉 Success Metrics

**Your PoC Successfully Demonstrates:**
- ✅ ZK proof generation (SP1)
- ✅ On-chain verification
- ✅ Private commitments
- ✅ Balance privacy
- ✅ Testnet deployment
- ✅ Integration tests

**You're Ready For:**
- Demo to investors
- User testing
- Security audit prep
- Mainnet planning

---

**Need Help?**
- Read: `TESTING_GUIDE.md`
- Check: `TESTNET_DEPLOYMENT_SUCCESS.md`
- View: `docs/aegis-architecture.md`

🚀 **Your ZK Privacy Protocol is Live!**
