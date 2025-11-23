#!/bin/bash
set -e

echo "=========================================="
echo "  🚀 Deploy Wrapped MNT (WMNT)"
echo "  So you can use real MNT privately!"
echo "=========================================="
echo ""

source .env

cd contracts

echo "Step 1: Compiling WMNT contract..."
forge build --force
echo "✅ Compiled"
echo ""

sleep 1

echo "Step 2: Deploying WMNT to Mantle Sepolia..."
echo ""

DEPLOY_OUTPUT=$(forge create src/WrappedMNT.sol:WrappedMNT \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast 2>&1)

WMNT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

if [ -z "$WMNT_ADDRESS" ]; then
    echo "❌ Deployment failed"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo "✅ WMNT Deployed: $WMNT_ADDRESS"
echo ""

cd ..

# Save to .env
if grep -q "^WMNT=" .env; then
    sed -i.bak "s|^WMNT=.*|WMNT=$WMNT_ADDRESS|" .env
else
    echo "WMNT=$WMNT_ADDRESS" >> .env
fi

echo "✅ Saved to .env"
echo ""

sleep 1

echo "=========================================="
echo "✅ WMNT Deployment Complete!"
echo "=========================================="
echo ""
echo "📍 Contract Address:"
echo "   $WMNT_ADDRESS"
echo ""
echo "🔗 Explorer:"
echo "   https://explorer.sepolia.mantle.xyz/address/$WMNT_ADDRESS"
echo ""
echo "🎉 Now you can:"
echo "   1. Wrap your MNT → WMNT"
echo "   2. Use WMNT in Privacy PoC"
echo "   3. Unwrap WMNT → MNT when done"
echo ""
echo "Next: Run ./test-wmnt-privacy.sh to test it!"
echo ""
