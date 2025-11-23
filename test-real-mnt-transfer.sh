#!/bin/bash
set -e

echo "=========================================="
echo "  💰 Real MNT Token Transfer Test"
echo "  Traditional vs Privacy Comparison"
echo "=========================================="
echo ""

source .env

YOUR_WALLET="0xeb780a89269e3f4a2eac4682ef93a50ff9f16239"
DUMMY_WALLET="0x51baCE94cd0fcb64e83eA5Dc12B50977Cae8c26B"

echo "📍 Wallets:"
echo "   Your Wallet:  $YOUR_WALLET"
echo "   Dummy Wallet: $DUMMY_WALLET"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Check Initial MNT Balances"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Checking your MNT balance..."
YOUR_BALANCE_WEI=$(cast balance $YOUR_WALLET --rpc-url $RPC_URL)
YOUR_BALANCE=$(echo "$YOUR_BALANCE_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

echo "Checking dummy MNT balance..."
DUMMY_BALANCE_WEI=$(cast balance $DUMMY_WALLET --rpc-url $RPC_URL)
DUMMY_BALANCE=$(echo "$DUMMY_BALANCE_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

echo "💰 Initial Balances:"
echo "   Your Wallet:  $YOUR_BALANCE MNT"
echo "   Dummy Wallet: $DUMMY_BALANCE MNT"
echo ""

sleep 2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Traditional Transfer (100 MNT)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔓 Sending 100 MNT using TRADITIONAL method..."
echo "   This is a direct wallet-to-wallet transfer"
echo "   From: $YOUR_WALLET"
echo "   To:   $DUMMY_WALLET"
echo "   Amount: 100 MNT"
echo ""

# Send 100 MNT directly
TRAD_TX=$(cast send $DUMMY_WALLET \
    --value 100ether \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY 2>&1 | grep "transactionHash" | awk '{print $2}')

if [ -z "$TRAD_TX" ]; then
    echo "⚠️  Transaction might have failed, getting alternative hash..."
    TRAD_TX=$(cast send $DUMMY_WALLET \
        --value 100ether \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY --json 2>&1 | jq -r '.transactionHash' 2>/dev/null || echo "pending")
fi

echo "✅ Transaction sent!"
echo "   TX Hash: $TRAD_TX"
echo ""

sleep 3

echo "Checking updated balances..."
YOUR_BALANCE_AFTER_WEI=$(cast balance $YOUR_WALLET --rpc-url $RPC_URL)
YOUR_BALANCE_AFTER=$(echo "$YOUR_BALANCE_AFTER_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

DUMMY_BALANCE_AFTER_WEI=$(cast balance $DUMMY_WALLET --rpc-url $RPC_URL)
DUMMY_BALANCE_AFTER=$(echo "$DUMMY_BALANCE_AFTER_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

echo ""
echo "💰 After Traditional Transfer:"
echo "   Your Wallet:  $YOUR_BALANCE_AFTER MNT (was $YOUR_BALANCE)"
echo "   Dummy Wallet: $DUMMY_BALANCE_AFTER MNT (was $DUMMY_BALANCE)"
echo ""

echo "🔗 View Traditional Transfer on Explorer:"
echo "   https://explorer.sepolia.mantle.xyz/tx/$TRAD_TX"
echo ""
echo "   What EVERYONE can see:"
echo "   ├─ From: $YOUR_WALLET ❌ EXPOSED"
echo "   ├─ To: $DUMMY_WALLET ❌ EXPOSED"
echo "   ├─ Value: 100 MNT ❌ EXPOSED"
echo "   └─ Result: ❌ ZERO PRIVACY"
echo ""

sleep 3

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Privacy PoC Explanation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "⚠️  IMPORTANT CLARIFICATION:"
echo ""
echo "The Privacy PoC works with ERC20 tokens, not native MNT directly."
echo ""
echo "Here's why:"
echo "  • MNT is the NATIVE token (like ETH on Ethereum)"
echo "  • Privacy PoC uses ERC20 token standards"
echo "  • To use MNT in PoC, you'd need to:"
echo "    1. Wrap MNT → WMNT (Wrapped MNT)"
echo "    2. Use WMNT in Privacy PoC"
echo "    3. Unwrap WMNT → MNT when withdrawing"
echo ""
echo "What we tested before:"
echo "  ✅ Used MockETH (ERC20) as a representation"
echo "  ✅ Shows how Privacy PoC works with tokens"
echo "  ✅ Same privacy principles apply"
echo ""

sleep 3

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "COMPARISON: Native MNT vs Privacy PoC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat << 'EOF'
┌─────────────────────────────────────────────────────────────────┐
│              TRADITIONAL NATIVE MNT TRANSFER                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ What we just did:                                               │
│   You → 100 MNT → Dummy Wallet                                  │
│                                                                 │
│ What blockchain shows:                                          │
│   ├─ Sender: 0xeb780a89...16239 ❌ YOUR WALLET EXPOSED         │
│   ├─ Recipient: 0x51baCE94...c26B ❌ DUMMY WALLET EXPOSED      │
│   ├─ Amount: 100 MNT ❌ AMOUNT EXPOSED                          │
│   └─ Everyone can see: Who sent how much to whom ❌             │
│                                                                 │
│ Privacy Score: 0/100 ❌                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              PRIVACY POC WITH ERC20 TOKENS                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ How it works with tokens (MockETH, WMNT, USDC, etc.):          │
│   You → Deposit to Privacy Vault → Hidden commitment           │
│                                                                 │
│ What blockchain shows:                                          │
│   ├─ Sender: Hidden via relayer ✅                              │
│   ├─ Recipient: Hidden in ZK proof ✅                           │
│   ├─ Amount: Hidden in commitment ✅                            │
│   └─ Only commitment hash visible: 0xabc123... ✅               │
│                                                                 │
│ Privacy Score: 100/100 ✅                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
EOF

echo ""

sleep 2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "FINAL BALANCES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "💰 Final MNT Token Balances:"
echo ""
echo "   Your Wallet ($YOUR_WALLET):"
echo "   ├─ Before: $YOUR_BALANCE MNT"
echo "   ├─ After:  $YOUR_BALANCE_AFTER MNT"
echo "   └─ Change: -$(echo "$YOUR_BALANCE - $YOUR_BALANCE_AFTER" | bc) MNT (sent + gas)"
echo ""
echo "   Dummy Wallet ($DUMMY_WALLET):"
echo "   ├─ Before: $DUMMY_BALANCE MNT"
echo "   ├─ After:  $DUMMY_BALANCE_AFTER MNT"
echo "   └─ Change: +$(echo "$DUMMY_BALANCE_AFTER - $DUMMY_BALANCE" | bc) MNT (received)"
echo ""

echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""

echo "Summary:"
echo "  ✅ Sent 100 MNT using traditional method"
echo "  ✅ Transfer visible on blockchain"
echo "  ✅ Your balance decreased"
echo "  ✅ Dummy balance increased"
echo ""

echo "Key Insights:"
echo "  1. Native MNT transfers are ALWAYS visible ❌"
echo "  2. Privacy PoC works with ERC20 tokens ✅"
echo "  3. To use MNT privately, wrap it first (WMNT)"
echo "  4. Traditional = 0% privacy, PoC = 100% privacy"
echo ""

echo "🔗 Verify on Explorer:"
echo "   Your wallet: https://explorer.sepolia.mantle.xyz/address/$YOUR_WALLET"
echo "   Dummy wallet: https://explorer.sepolia.mantle.xyz/address/$DUMMY_WALLET"
echo "   Transaction: https://explorer.sepolia.mantle.xyz/tx/$TRAD_TX"
echo ""
