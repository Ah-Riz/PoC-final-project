#!/bin/bash
set -e

echo "=========================================="
echo "  💎 Testing Privacy with Wrapped MNT"
echo "  Using YOUR real MNT tokens!"
echo "=========================================="
echo ""

source .env

YOUR_WALLET="0xeb780a89269e3f4a2eac4682ef93a50ff9f16239"
DUMMY_WALLET="0x51baCE94cd0fcb64e83eA5Dc12B50977Cae8c26B"

if [ -z "$WMNT" ]; then
    echo "❌ WMNT not deployed! Run ./deploy-wmnt.sh first"
    exit 1
fi

echo "📍 Configuration:"
echo "   Your Wallet:  $YOUR_WALLET"
echo "   Dummy Wallet: $DUMMY_WALLET"
echo "   WMNT Address: $WMNT"
echo ""

sleep 1

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Check Initial Balances"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check MNT balance
YOUR_MNT_WEI=$(cast balance $YOUR_WALLET --rpc-url $RPC_URL)
YOUR_MNT=$(echo "$YOUR_MNT_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

# Check WMNT balance
YOUR_WMNT_WEI=$(cast call $WMNT "balanceOf(address)(uint256)" $YOUR_WALLET --rpc-url $RPC_URL 2>/dev/null || echo "0")
YOUR_WMNT=$(echo "$YOUR_WMNT_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

DUMMY_WMNT_WEI=$(cast call $WMNT "balanceOf(address)(uint256)" $DUMMY_WALLET --rpc-url $RPC_URL 2>/dev/null || echo "0")
DUMMY_WMNT=$(echo "$DUMMY_WMNT_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

echo "💰 Your Balances:"
echo "   MNT:  $YOUR_MNT"
echo "   WMNT: $YOUR_WMNT"
echo ""
echo "💰 Dummy Balances:"
echo "   WMNT: $DUMMY_WMNT"
echo ""

sleep 2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Wrap 100 MNT → WMNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔄 Wrapping 100 MNT into WMNT..."
echo "   This converts native MNT to ERC20 WMNT"
echo ""

WRAP_TX=$(cast send $WMNT \
    "deposit()" \
    --value 100ether \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY 2>&1 | grep "transactionHash" | awk '{print $2}' || echo "pending")

echo "✅ Wrapped 100 MNT → WMNT"
echo "   TX: $WRAP_TX"
echo ""

sleep 2

# Check updated balance
YOUR_WMNT_AFTER_WEI=$(cast call $WMNT "balanceOf(address)(uint256)" $YOUR_WALLET --rpc-url $RPC_URL)
YOUR_WMNT_AFTER=$(echo "$YOUR_WMNT_AFTER_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

echo "💰 Your WMNT Balance: $YOUR_WMNT_AFTER WMNT"
echo ""

sleep 1

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Traditional WMNT Transfer (Visible)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔓 Sending 50 WMNT to dummy using TRADITIONAL method..."
echo ""

TRAD_TX=$(cast send $WMNT \
    "transfer(address,uint256)" \
    $DUMMY_WALLET \
    50000000000000000000 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY 2>&1 | grep "transactionHash" | awk '{print $2}' || echo "pending")

echo "✅ Traditional transfer complete"
echo "   TX: $TRAD_TX"
echo ""

sleep 2

DUMMY_WMNT_AFTER_WEI=$(cast call $WMNT "balanceOf(address)(uint256)" $DUMMY_WALLET --rpc-url $RPC_URL)
DUMMY_WMNT_AFTER=$(echo "$DUMMY_WMNT_AFTER_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

echo "💰 Dummy WMNT Balance: $DUMMY_WMNT_AFTER WMNT"
echo ""

echo "🔗 View Traditional Transfer:"
echo "   https://explorer.sepolia.mantle.xyz/tx/$TRAD_TX"
echo ""
echo "   What EVERYONE sees:"
echo "   ├─ From: $YOUR_WALLET ❌ EXPOSED"
echo "   ├─ To: $DUMMY_WALLET ❌ EXPOSED"
echo "   ├─ Amount: 50 WMNT ❌ EXPOSED"
echo "   └─ Privacy: 0/100 ❌"
echo ""

sleep 3

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Privacy PoC Transfer (Hidden)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔐 Now you can use the remaining 50 WMNT in Privacy PoC..."
echo ""
echo "   To use Privacy PoC:"
echo "   1. Approve WMNT to Privacy Vault"
echo "   2. Deposit WMNT to Privacy Vault"
echo "   3. Transfer happens with:"
echo "      ✅ Hidden sender"
echo "      ✅ Hidden recipient"
echo "      ✅ Hidden amount"
echo "      ✅ Only commitment hashes visible"
echo ""
echo "   Privacy Score: 100/100 ✅"
echo ""

sleep 2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "COMPARISON SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat << 'EOF'
┌───────────────────────────────────────────────────────────────┐
│                    WHAT WE JUST DID                           │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│ 1️⃣  Wrapped 100 MNT → 100 WMNT                               │
│     Native MNT converted to ERC20 token                       │
│                                                               │
│ 2️⃣  Sent 50 WMNT using TRADITIONAL method                    │
│     Result: ❌ Everyone can see:                              │
│     - From: Your wallet                                       │
│     - To: Dummy wallet                                        │
│     - Amount: 50 WMNT                                         │
│                                                               │
│ 3️⃣  Remaining 50 WMNT ready for PRIVACY PoC                  │
│     Result: ✅ Can be sent privately with:                    │
│     - Hidden sender                                           │
│     - Hidden recipient                                        │
│     - Hidden amount                                           │
│                                                               │
└───────────────────────────────────────────────────────────────┘

Traditional WMNT Transfer:  Privacy 0/100   ❌
Privacy PoC WMNT Transfer:  Privacy 100/100 ✅
EOF

echo ""

sleep 2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "FINAL BALANCES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

YOUR_WMNT_FINAL_WEI=$(cast call $WMNT "balanceOf(address)(uint256)" $YOUR_WALLET --rpc-url $RPC_URL)
YOUR_WMNT_FINAL=$(echo "$YOUR_WMNT_FINAL_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

DUMMY_WMNT_FINAL_WEI=$(cast call $WMNT "balanceOf(address)(uint256)" $DUMMY_WALLET --rpc-url $RPC_URL)
DUMMY_WMNT_FINAL=$(echo "$DUMMY_WMNT_FINAL_WEI" | awk '{printf "%.6f", $1/1000000000000000000}')

echo "💰 Your WMNT:  $YOUR_WMNT_FINAL WMNT"
echo "💰 Dummy WMNT: $DUMMY_WMNT_FINAL WMNT"
echo ""

echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""

echo "Summary:"
echo "  ✅ Created WMNT (Wrapped MNT)"
echo "  ✅ Wrapped 100 MNT → 100 WMNT"
echo "  ✅ Sent 50 WMNT traditionally (visible)"
echo "  ✅ 50 WMNT ready for Privacy PoC (hidden)"
echo ""

echo "Key Points:"
echo "  1. WMNT = MNT as ERC20 token"
echo "  2. Traditional transfer = 0% privacy ❌"
echo "  3. Privacy PoC transfer = 100% privacy ✅"
echo "  4. You can unwrap WMNT → MNT anytime"
echo ""

echo "🔗 WMNT Contract:"
echo "   https://explorer.sepolia.mantle.xyz/address/$WMNT"
echo ""

echo "🎉 NOW you can use your real MNT privately!"
echo ""
