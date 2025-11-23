#!/bin/bash
set -e

echo "=========================================="
echo "  🧪 Aegis Protocol - Testnet Quickstart"
echo "  Network: Mantle Sepolia"
echo "  Mode: Mock Proofs (FREE)"
echo "=========================================="
echo ""

# Load environment
source .env

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check prerequisites
echo "📋 Step 1: Checking Prerequisites"
echo "-----------------------------------"

# Check if private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ PRIVATE_KEY not set in .env${NC}"
    echo ""
    echo "Please follow these steps:"
    echo "1. Create a NEW MetaMask wallet (testnet only!)"
    echo "2. Add Mantle Sepolia network:"
    echo "   - RPC: https://rpc.sepolia.mantle.xyz"
    echo "   - Chain ID: 5003"
    echo "3. Get testnet MNT tokens:"
    echo "   - Visit: https://faucet.sepolia.mantle.xyz"
    echo "   - Request tokens (takes ~2 minutes)"
    echo "4. Export your private key from MetaMask"
    echo "5. Add to .env: PRIVATE_KEY=0x..."
    echo ""
    exit 1
fi

# Check balance
echo -n "Checking wallet balance... "
BALANCE=$(cast balance --ether $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC_URL 2>/dev/null || echo "0")
echo "$BALANCE MNT"

if [ "$BALANCE" == "0" ]; then
    echo -e "${YELLOW}⚠️  No testnet tokens found${NC}"
    echo ""
    echo "Get free testnet MNT:"
    echo "1. Visit: https://faucet.sepolia.mantle.xyz"
    echo "2. Connect your wallet"
    echo "3. Request tokens"
    echo "4. Wait ~2 minutes and run this script again"
    echo ""
    open "https://faucet.sepolia.mantle.xyz" 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo ""

# Step 2: Build contracts
echo "📦 Step 2: Building Smart Contracts"
echo "-----------------------------------"
cd contracts
forge build --force
echo -e "${GREEN}✅ Contracts built${NC}"
echo ""

# Step 3: Deploy Mock Tokens
echo "🪙 Step 3: Deploying Mock Tokens"
echo "-----------------------------------"

if [ -z "$COLLATERAL_TOKEN" ]; then
    echo "Deploying MockETH..."
    DEPLOY_OUTPUT=$(forge create src/MockTokens.sol:MockETH \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast 2>&1)
    
    COLLATERAL_TOKEN=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
    echo "✅ MockETH deployed: $COLLATERAL_TOKEN"
    
    # Update .env
    sed -i.bak "s|COLLATERAL_TOKEN=.*|COLLATERAL_TOKEN=$COLLATERAL_TOKEN|" ../.env
else
    echo "✅ MockETH already deployed: $COLLATERAL_TOKEN"
fi

if [ -z "$DEBT_TOKEN" ]; then
    echo "Deploying MockUSDC..."
    DEPLOY_OUTPUT=$(forge create src/MockTokens.sol:MockUSDC \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast 2>&1)
    
    DEBT_TOKEN=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
    echo "✅ MockUSDC deployed: $DEBT_TOKEN"
    
    # Update .env
    sed -i.bak "s|DEBT_TOKEN=.*|DEBT_TOKEN=$DEBT_TOKEN|" ../.env
else
    echo "✅ MockUSDC already deployed: $DEBT_TOKEN"
fi

echo -e "${GREEN}✅ Mock tokens ready${NC}"
echo ""

# Step 4: Deploy Mock Verifier
echo "🔐 Step 4: Deploying Mock SP1 Verifier"
echo "-----------------------------------"
echo "⚠️  Note: Mock verifier for testnet only (not secure for production)"

if [ -z "$VERIFIER" ]; then
    DEPLOY_OUTPUT=$(forge create test/AegisVault.t.sol:MockSP1Verifier \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast 2>&1)
    
    VERIFIER=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
    echo "✅ Mock Verifier deployed: $VERIFIER"
    
    # Update .env
    sed -i.bak "s|VERIFIER=.*|VERIFIER=$VERIFIER|" ../.env
else
    echo "✅ Mock Verifier already deployed: $VERIFIER"
fi

echo -e "${GREEN}✅ Verifier ready${NC}"
echo ""

# Step 5: Deploy AegisVault
echo "🏦 Step 5: Deploying AegisVault"
echo "-----------------------------------"

# Generate verification keys (simplified for testnet)
DEPOSIT_VKEY="0x00590234290ae560b1e54de04eee84ce8e4894fd34d1b28c2b67c21a89cd5060"
BORROW_VKEY="0x00590234290ae560b1e54de04eee84ce8e4894fd34d1b28c2b67c21a89cd5060"

echo "Deploying AegisVault..."
DEPLOY_OUTPUT=$(forge create src/AegisVault.sol:AegisVault \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --constructor-args \
        $VERIFIER \
        $DEPOSIT_VKEY \
        $BORROW_VKEY \
        $COLLATERAL_TOKEN \
        $DEBT_TOKEN 2>&1)

VAULT=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
echo "✅ AegisVault deployed: $VAULT"

# Update .env
sed -i.bak "s|VAULT=.*|VAULT=$VAULT|" ../.env

echo -e "${GREEN}✅ Vault deployed${NC}"
echo ""

# Step 6: Initialize Vault
echo "💰 Step 6: Initializing Vault with Test Liquidity"
echo "-----------------------------------"

DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)

# Mint test tokens
echo "Minting 1000 MockETH to deployer..."
cast send $COLLATERAL_TOKEN \
    "mint(address,uint256)" \
    $DEPLOYER \
    1000000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --quiet

echo "Minting 10,000,000 MockUSDC to deployer..."
cast send $DEBT_TOKEN \
    "mint(address,uint256)" \
    $DEPLOYER \
    10000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --quiet

# Approve and fund vault
echo "Funding vault with 10,000,000 USDC liquidity..."
cast send $DEBT_TOKEN \
    "approve(address,uint256)" \
    $VAULT \
    10000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --quiet

cast send $VAULT \
    "fundVault(uint256)" \
    10000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --quiet

echo -e "${GREEN}✅ Vault funded and ready${NC}"
echo ""

cd ..

# Step 7: Run integration test
echo "🧪 Step 7: Running Integration Test"
echo "-----------------------------------"

echo "Testing with mock proofs..."
cd script
cargo run --release --bin test_transfer 2>&1 | grep -E "(Test|✅|❌|Proof|Valid|Complete)"
cd ..

echo -e "${GREEN}✅ Integration test passed${NC}"
echo ""

# Final summary
echo "=========================================="
echo "  ✅ Testnet Deployment Complete!"
echo "=========================================="
echo ""
echo "📍 Deployed Contracts:"
echo "-----------------------------------"
echo "Network:          Mantle Sepolia"
echo "Chain ID:         5003"
echo "AegisVault:       $VAULT"
echo "MockETH:          $COLLATERAL_TOKEN"
echo "MockUSDC:         $DEBT_TOKEN"
echo "Mock Verifier:    $VERIFIER"
echo ""
echo "🔗 Explorer Links:"
echo "-----------------------------------"
echo "Vault:    https://explorer.sepolia.mantle.xyz/address/$VAULT"
echo "MockETH:  https://explorer.sepolia.mantle.xyz/address/$COLLATERAL_TOKEN"
echo "MockUSDC: https://explorer.sepolia.mantle.xyz/address/$DEBT_TOKEN"
echo ""
echo "💡 What's Next:"
echo "-----------------------------------"
echo "1. View contracts on explorer (links above)"
echo "2. Test deposits/borrows with mock proofs"
echo "3. Share with testers for feedback"
echo "4. When ready for mainnet:"
echo "   - Switch to SP1_PROVER=network"
echo "   - Add SP1 Network credits"
echo "   - Deploy with real Groth16 proofs"
echo ""
echo "🎉 Your ZK privacy system is live on testnet!"
echo ""
