# Testnet Deployment Guide

Complete guide for deploying Aegis Protocol to Mantle Sepolia testnet.

---

## Prerequisites

### 1. Development Environment
```bash
# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# SP1
cargo install sp1-cli --locked
cargo prove --install
```

### 2. Network Setup

**Mantle Sepolia Configuration:**
```
RPC URL: https://rpc.sepolia.mantle.xyz
Chain ID: 5003
Currency: MNT
Explorer: https://explorer.sepolia.mantle.xyz
Faucet: https://faucet.sepolia.mantle.xyz
```

**Add to MetaMask:**
- Network Name: Mantle Sepolia
- New RPC URL: https://rpc.sepolia.mantle.xyz
- Chain ID: 5003
- Currency Symbol: MNT
- Block Explorer: https://explorer.sepolia.mantle.xyz

### 3. Get Testnet Tokens

**Option 1: Official Faucet**
```
Visit: https://faucet.sepolia.mantle.xyz
Connect wallet
Request tokens (1 MNT per request)
Wait ~1-2 minutes
```

**Option 2: Bridge from Sepolia**
```
1. Get Sepolia ETH from faucet
2. Bridge to Mantle Sepolia via official bridge
3. Wait for confirmation
```

**Check Balance:**
```bash
cast balance <YOUR_ADDRESS> --rpc-url https://rpc.sepolia.mantle.xyz
```

---

## Pre-Deployment Checklist

### Code Preparation
- [ ] All tests passing locally (`./test-local.sh`)
- [ ] Smart contracts compiled without errors
- [ ] ZK program builds successfully
- [ ] No TODO or FIXME in production code
- [ ] Version tagged in git

### Configuration
- [ ] `.env` file created with production values
- [ ] Private key secured (hardware wallet recommended)
- [ ] RPC endpoints verified and responsive
- [ ] Deployment account funded (>1 MNT)

### Documentation
- [ ] Deployment addresses will be recorded
- [ ] Transaction hashes will be saved
- [ ] Verification plan prepared
- [ ] Rollback procedure documented

---

## Deployment Steps

### Step 1: Environment Configuration

Create `.env` file:
```bash
# Network
RPC_URL=https://rpc.sepolia.mantle.xyz
CHAIN_ID=5003

# Deployer (use hardware wallet in production!)
PRIVATE_KEY=0x...

# Verification (optional)
ETHERSCAN_API_KEY=...  # If Mantle supports it

# Contracts (will be filled after deployment)
VAULT_ADDRESS=
COLLATERAL_TOKEN_ADDRESS=
DEBT_TOKEN_ADDRESS=
VERIFIER_ADDRESS=
```

**⚠️ Security Warning:**
- Never commit private keys to git
- Use hardware wallet for mainnet
- Rotate keys after deployment if compromised

### Step 2: Build and Verify Contracts

```bash
cd contracts

# Clean build
forge clean
forge build

# Verify compilation
ls -lh out/AegisVault.sol/AegisVault.json

# Check bytecode size (must be <24KB for deployment)
forge inspect AegisVault bytecode | wc -c
# Should be < ~49000 (24KB * 2 for hex)
```

### Step 3: Deploy Mock Tokens

```bash
# Deploy MockETH
forge create src/MockTokens.sol:MockETH \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Save address
export COLLATERAL_TOKEN=0x...

# Deploy MockUSDC
forge create src/MockTokens.sol:MockUSDC \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Save address
export DEBT_TOKEN=0x...

# Verify deployments
cast call $COLLATERAL_TOKEN "name()(string)" --rpc-url $RPC_URL
# Should return: "Mock ETH"

cast call $DEBT_TOKEN "symbol()(string)" --rpc-url $RPC_URL
# Should return: "USDC"
```

### Step 4: Deploy SP1 Verifier

**Option A: Use Official SP1 Verifier (Recommended)**
```bash
# Check if SP1 has deployed verifier on Mantle Sepolia
# Visit: https://docs.succinct.xyz/deployments

# If available, use that address:
export VERIFIER_ADDRESS=0x...  # Official SP1 verifier
```

**Option B: Deploy Mock Verifier (Testing Only)**
```bash
# For testnet testing only - NOT SECURE FOR PRODUCTION
forge create test/AegisVault.t.sol:MockSP1Verifier \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

export VERIFIER_ADDRESS=0x...
```

**⚠️ Critical:** Mock verifier always passes verification. Use only for testing!

### Step 5: Deploy AegisVault

```bash
# Generate verification keys (these should match your ZK program)
DEPOSIT_VKEY=0x$(echo -n "DEPOSIT_VKEY_V1" | sha256sum | cut -d' ' -f1)
BORROW_VKEY=0x$(echo -n "BORROW_VKEY_V1" | sha256sum | cut -d' ' -f1)

# Deploy vault
forge create src/AegisVault.sol:AegisVault \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args \
    $VERIFIER_ADDRESS \
    $DEPOSIT_VKEY \
    $BORROW_VKEY \
    $COLLATERAL_TOKEN \
    $DEBT_TOKEN

# Save address
export VAULT_ADDRESS=0x...

# Verify deployment
cast call $VAULT_ADDRESS "owner()(address)" --rpc-url $RPC_URL
# Should return your deployer address
```

### Step 6: Initialize Vault

```bash
# Mint test tokens to deployer
cast send $COLLATERAL_TOKEN \
  "mint(address,uint256)" \
  $YOUR_ADDRESS \
  1000000000000000000000 \  # 1000 ETH
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

cast send $DEBT_TOKEN \
  "mint(address,uint256)" \
  $YOUR_ADDRESS \
  10000000000000 \  # 10M USDC (6 decimals)
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Approve vault to spend USDC
cast send $DEBT_TOKEN \
  "approve(address,uint256)" \
  $VAULT_ADDRESS \
  10000000000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Fund vault with liquidity
cast send $VAULT_ADDRESS \
  "fundVault(uint256)" \
  10000000000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Verify vault balance
cast call $VAULT_ADDRESS "getDebtBalance()(uint256)" --rpc-url $RPC_URL
# Should return: 10000000000000
```

### Step 7: Verify on Explorer

```bash
# Option 1: Manual verification
# Visit: https://explorer.sepolia.mantle.xyz/address/$VAULT_ADDRESS
# Click "Contract" tab → "Verify & Publish"
# Upload source code and compiler settings

# Option 2: Automated verification (if supported)
forge verify-contract $VAULT_ADDRESS \
  src/AegisVault.sol:AegisVault \
  --chain-id 5003 \
  --constructor-args $(cast abi-encode \
    "constructor(address,bytes32,bytes32,address,address)" \
    $VERIFIER_ADDRESS $DEPOSIT_VKEY $BORROW_VKEY \
    $COLLATERAL_TOKEN $DEBT_TOKEN)
```

### Step 8: Save Deployment Info

```bash
# Create deployment record
cat > deployment-$(date +%Y%m%d).json << EOF
{
  "network": "mantle-sepolia",
  "chainId": 5003,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "deployer": "$YOUR_ADDRESS",
  "contracts": {
    "AegisVault": "$VAULT_ADDRESS",
    "MockETH": "$COLLATERAL_TOKEN",
    "MockUSDC": "$DEBT_TOKEN",
    "SP1Verifier": "$VERIFIER_ADDRESS"
  },
  "transactions": {
    "vault_deployment": "...",
    "initial_funding": "..."
  },
  "explorer": "https://explorer.sepolia.mantle.xyz/address/$VAULT_ADDRESS"
}
EOF

# Update .env
echo "VAULT_ADDRESS=$VAULT_ADDRESS" >> .env
echo "COLLATERAL_TOKEN_ADDRESS=$COLLATERAL_TOKEN" >> .env
echo "DEBT_TOKEN_ADDRESS=$DEBT_TOKEN" >> .env
echo "VERIFIER_ADDRESS=$VERIFIER_ADDRESS" >> .env
```

---

## Post-Deployment Validation

### Smoke Tests

**Test 1: Check Contract State**
```bash
# Verify vault owner
cast call $VAULT_ADDRESS "owner()(address)" --rpc-url $RPC_URL

# Check token addresses
cast call $VAULT_ADDRESS "collateralToken()(address)" --rpc-url $RPC_URL
cast call $VAULT_ADDRESS "debtToken()(address)" --rpc-url $RPC_URL

# Verify balances
cast call $VAULT_ADDRESS "getDebtBalance()(uint256)" --rpc-url $RPC_URL
```

**Test 2: Test Deposit (Mock Proof)**
```bash
# For testing only - use real proofs in production!

# Create mock commitment
COMMITMENT=0x$(openssl rand -hex 32)

# Approve collateral
cast send $COLLATERAL_TOKEN \
  "approve(address,uint256)" \
  $VAULT_ADDRESS \
  10000000000000000000 \  # 10 ETH
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Create public values (commitment + is_valid)
PUBLIC_VALUES="${COMMITMENT}01"

# Submit deposit
cast send $VAULT_ADDRESS \
  "deposit(uint256,bytes,bytes)" \
  10000000000000000000 \
  0x00 \
  $PUBLIC_VALUES \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Verify commitment added
cast call $VAULT_ADDRESS "getCommitmentCount()(uint256)" --rpc-url $RPC_URL
# Should return: 1
```

**Test 3: Monitor Events**
```bash
# Watch for Deposit events
cast logs \
  --address $VAULT_ADDRESS \
  --rpc-url $RPC_URL \
  | grep "Deposit"

# Check merkle root updated
cast call $VAULT_ADDRESS "merkleRoot()(bytes32)" --rpc-url $RPC_URL
```

### Integration Tests

**Run Full Test Suite Against Deployed Contracts:**
```bash
cd ../script

# Update .env with deployed addresses
export VAULT_ADDRESS=$VAULT_ADDRESS
export COLLATERAL_TOKEN_ADDRESS=$COLLATERAL_TOKEN
export DEBT_TOKEN_ADDRESS=$DEBT_TOKEN

# Note: Integration tests require real SP1 proof generation
# This may fail if using MockVerifier
# cargo test --release -- --test-threads=1
```

---

## Monitoring Setup

### Event Monitoring

```bash
# Create monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
VAULT=$1
RPC=$2

echo "Monitoring $VAULT..."
while true; do
  # Get latest block
  BLOCK=$(cast block-number --rpc-url $RPC)
  
  # Get commitment count
  COUNT=$(cast call $VAULT "getCommitmentCount()(uint256)" --rpc-url $RPC)
  
  # Get balances
  COLLATERAL=$(cast call $VAULT "getCollateralBalance()(uint256)" --rpc-url $RPC)
  DEBT=$(cast call $VAULT "getDebtBalance()(uint256)" --rpc-url $RPC)
  
  echo "[Block $BLOCK] Commitments: $COUNT | Collateral: $COLLATERAL | Debt: $DEBT"
  sleep 30
done
EOF

chmod +x monitor.sh
./monitor.sh $VAULT_ADDRESS $RPC_URL
```

### Health Checks

```bash
# Create health check script
cat > healthcheck.sh << 'EOF'
#!/bin/bash
set -e

VAULT=$1
RPC=$2

# Check 1: Contract is reachable
echo -n "Contract reachable: "
cast code $VAULT --rpc-url $RPC > /dev/null && echo "✓" || echo "✗"

# Check 2: Owner is set
echo -n "Owner configured: "
OWNER=$(cast call $VAULT "owner()(address)" --rpc-url $RPC)
[ "$OWNER" != "0x0000000000000000000000000000000000000000" ] && echo "✓" || echo "✗"

# Check 3: Has liquidity
echo -n "Has liquidity: "
BALANCE=$(cast call $VAULT "getDebtBalance()(uint256)" --rpc-url $RPC)
[ "$BALANCE" -gt 0 ] && echo "✓" || echo "✗"

# Check 4: Verifier is set
echo -n "Verifier configured: "
VERIFIER=$(cast call $VAULT "verifier()(address)" --rpc-url $RPC)
[ "$VERIFIER" != "0x0000000000000000000000000000000000000000" ] && echo "✓" || echo "✗"

echo "Health check complete"
EOF

chmod +x healthcheck.sh
./healthcheck.sh $VAULT_ADDRESS $RPC_URL
```

---

## Troubleshooting

### Issue: Transaction Reverts

**Check gas price:**
```bash
cast gas-price --rpc-url $RPC_URL
```

**Simulate transaction:**
```bash
cast call $VAULT_ADDRESS \
  "deposit(uint256,bytes,bytes)" \
  10000000000000000000 \
  0x00 \
  $PUBLIC_VALUES \
  --from $YOUR_ADDRESS \
  --rpc-url $RPC_URL
```

**Check error message:**
```bash
cast run <TX_HASH> --rpc-url $RPC_URL
```

### Issue: Proof Verification Fails

**Check verifier address:**
```bash
cast call $VAULT_ADDRESS "verifier()(address)" --rpc-url $RPC_URL
```

**Verify vkeys match:**
```bash
cast call $VAULT_ADDRESS "depositVkey()(bytes32)" --rpc-url $RPC_URL
cast call $VAULT_ADDRESS "borrowVkey()(bytes32)" --rpc-url $RPC_URL
```

### Issue: Insufficient Balance

**Check vault liquidity:**
```bash
cast call $VAULT_ADDRESS "getDebtBalance()(uint256)" --rpc-url $RPC_URL
```

**Add more liquidity:**
```bash
cast send $VAULT_ADDRESS "fundVault(uint256)" <AMOUNT> \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

---

## Security Checklist

### Pre-Launch
- [ ] Code reviewed by 2+ developers
- [ ] All tests passing
- [ ] No hardcoded private keys
- [ ] Access controls implemented
- [ ] Emergency pause mechanism tested

### Post-Launch
- [ ] Deployment addresses published
- [ ] Explorer verification complete
- [ ] Monitoring alerts configured
- [ ] Incident response plan ready
- [ ] Bug bounty considered

### Ongoing
- [ ] Monitor daily for unusual activity
- [ ] Test emergency procedures monthly
- [ ] Keep dependencies updated
- [ ] Maintain communication channels

---

## Rollback Procedure

### If Critical Bug Found

**1. Immediate Actions:**
```bash
# Pause contract (if pause function exists)
cast send $VAULT_ADDRESS "pause()" \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Alert users via all channels
# Document the issue
```

**2. Assessment:**
- Determine severity
- Check if funds at risk
- Estimate time to fix

**3. Communication:**
- Public announcement of issue
- Timeline for fix
- User impact assessment

**4. Fix & Redeploy:**
- Fix bug in code
- Deploy new version
- Migrate state if possible
- Resume operations

---

## Next Steps After Testnet

### Week 1-2: Beta Testing
- Invite trusted users
- Monitor usage patterns
- Collect feedback
- Fix minor issues

### Week 3-4: Public Testing
- Open to all testnet users
- Stress testing
- Documentation improvements
- UI/UX refinements

### Week 5-6: Audit Preparation
- Code freeze
- Documentation finalization
- Prepare for audit
- Bug bounty program

### Week 7-12: Security Audit
- Professional audit
- Fix findings
- Re-audit if needed
- Public report

### Week 13+: Mainnet Preparation
- Final testing
- Deployment planning
- Legal/compliance review
- Mainnet deployment

---

## Resources

**Mantle Documentation:**
- Developer Docs: https://docs.mantle.xyz
- Faucet: https://faucet.sepolia.mantle.xyz
- Explorer: https://explorer.sepolia.mantle.xyz

**SP1 Documentation:**
- Docs: https://docs.succinct.xyz
- Verifier Deployments: https://docs.succinct.xyz/deployments

**Support:**
- Mantle Discord: https://discord.gg/mantle
- SP1 Discord: https://discord.gg/succinct

---

**Status:** Ready for testnet deployment ✅
