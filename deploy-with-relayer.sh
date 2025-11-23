#!/bin/bash
set -e

echo "=========================================="
echo "  🚀 Deploy Private Vault + Relayer"
echo "  Combined Privacy System"
echo "=========================================="
echo ""

source .env

echo "Step 1: Build Updated Contract"
echo "-----------------------------------"
cd contracts
forge build --force
echo "✅ Contract built with relayer feature"
echo ""
cd ..

sleep 2

echo "Step 2: Deploy Updated AegisVault"
echo "-----------------------------------"
echo "Deploying to Mantle Sepolia..."
echo ""

# Use existing tokens and verifier
COLLATERAL="0xBed33F5eE4c637878155d60f1bc59c83eDA440bD"
DEBT="0x4Fc1b1cFD7a0B819952a6922cA695CF3C4DCC0E0"
VERIFIER="0xAa1136B014CCF4D17169A148c4Da9E81dAA572E0"

# Dummy vkeys (same as before)
DEPOSIT_VKEY="0x0000000000000000000000000000000000000000000000000000000000000001"
BORROW_VKEY="0x0000000000000000000000000000000000000000000000000000000000000002"

DEPLOY_OUTPUT=$(cd contracts && forge create src/AegisVault.sol:AegisVault \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --constructor-args \
        $VERIFIER \
        $DEPOSIT_VKEY \
        $BORROW_VKEY \
        $COLLATERAL \
        $DEBT 2>&1)

NEW_VAULT=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$NEW_VAULT" ]; then
    echo "❌ Deployment failed"
    exit 1
fi

echo "✅ New Vault deployed: $NEW_VAULT"
echo ""

# Update .env
sed -i.bak "s|VAULT=.*|VAULT=$NEW_VAULT|" .env

sleep 2

echo "Step 3: Fund New Vault"
echo "-----------------------------------"

# Mint USDC for funding
echo "Minting USDC for liquidity..."
cast send $DEBT \
    "mint(address,uint256)" \
    $(cast wallet address --private-key $PRIVATE_KEY) \
    10000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --quiet

sleep 1

# Approve and fund
echo "Funding vault with 10M USDC..."
cast send $DEBT \
    "approve(address,uint256)" \
    $NEW_VAULT \
    10000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --quiet

cast send $NEW_VAULT \
    "fundVault(uint256)" \
    10000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --quiet

echo "✅ Vault funded"
echo ""

sleep 2

echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "📍 Contract Addresses:"
echo "  New Vault:     $NEW_VAULT"
echo "  MockETH:       $COLLATERAL"
echo "  MockUSDC:      $DEBT"
echo "  Verifier:      $VERIFIER"
echo ""
echo "🔗 Explorer:"
echo "  https://explorer.sepolia.mantle.xyz/address/$NEW_VAULT"
echo ""
echo "🎉 Ready to test relayer feature!"
echo ""
