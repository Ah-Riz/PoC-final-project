# How to Get Mantle Sepolia Testnet Tokens

## Option 1: Official Faucet (Easiest)
**URL:** https://faucet.sepolia.mantle.xyz

1. Connect MetaMask
2. Click "Request Tokens"
3. Wait ~2 minutes
4. Receive 1 MNT

---

## Option 2: Bridge from Sepolia ETH

If faucet is empty, you can bridge from Ethereum Sepolia:

### Step A: Get Sepolia ETH
Choose any of these faucets:
- **Alchemy:** https://sepoliafaucet.com/
- **Infura:** https://www.infura.io/faucet/sepolia
- **QuickNode:** https://faucet.quicknode.com/ethereum/sepolia
- **Coinbase:** https://www.coinbase.com/faucets/ethereum-sepolia-faucet

### Step B: Bridge to Mantle Sepolia
1. Visit: https://bridge.sepolia.mantle.xyz
2. Connect MetaMask (make sure you're on Sepolia network)
3. Bridge ETH to Mantle Sepolia
4. Wait ~5-10 minutes for confirmation

---

## Option 3: Community Discord

If both above fail:

1. Join Mantle Discord: https://discord.gg/mantle
2. Go to #faucet channel
3. Request tokens with your address
4. Community moderators can help

---

## Option 4: Use Local Testing (No Tokens Needed!)

If you can't get testnet tokens, you can still test everything locally:

### Update .env:
```bash
# Comment out Mantle Sepolia
# RPC_URL=https://rpc.sepolia.mantle.xyz
# PRIVATE_KEY=0x...

# Use local Anvil (free, instant)
RPC_URL=http://127.0.0.1:8545
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Run local node:
```bash
# Terminal 1: Start local blockchain
anvil

# Terminal 2: Deploy and test
./test-local.sh
```

**Everything works the same, just not on public testnet!**

---

## Check Your Balance

After getting tokens, verify:
```bash
cast balance YOUR_ADDRESS --rpc-url https://rpc.sepolia.mantle.xyz --ether
```

Should show: `1.000000000000000000` (1 MNT)

---

## Need Help?

- **Mantle Docs:** https://docs.mantle.xyz
- **Discord:** https://discord.gg/mantle
- **Telegram:** https://t.me/mantlenetwork
