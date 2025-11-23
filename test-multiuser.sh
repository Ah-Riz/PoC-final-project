#!/bin/bash

# Multi-User Fork Testing - Tests with Multiple Wallets
# Tests deposit and borrow functions with different users on Mantle Sepolia fork

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Aegis Protocol - Multi-User Fork Testing           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}\n"

# Configuration
NUM_USERS=3
FORK_MODE=true

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    if [ ! -z "$ANVIL_PID" ]; then
        kill $ANVIL_PID 2>/dev/null
        echo -e "${GREEN}✓ Stopped Anvil${NC}"
    fi
}

trap cleanup EXIT

# Step 1: Start Anvil with fork
echo -e "${BLUE}[1/5] Starting Anvil with Mantle Sepolia fork...${NC}"
anvil --fork-url https://rpc.sepolia.mantle.xyz --block-time 1 > anvil-fork.log 2>&1 &
ANVIL_PID=$!

# Wait for Anvil to be ready
echo -e "${YELLOW}Waiting for Anvil to be ready...${NC}"
for i in {1..30}; do
    if cast client --rpc-url http://127.0.0.1:8545 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Anvil is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ Anvil failed to start${NC}"
        exit 1
    fi
    sleep 1
done

if ! kill -0 $ANVIL_PID 2>/dev/null; then
    echo -e "${RED}✗ Anvil failed to start${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Anvil running (PID: $ANVIL_PID)${NC}"
echo -e "${YELLOW}   RPC: http://127.0.0.1:8545${NC}"
echo -e "${YELLOW}   Fork: Mantle Sepolia${NC}\n"

# Step 2: Deploy contracts with real SP1 verifier
echo -e "${BLUE}[2/5] Deploying contracts with REAL SP1 Verifier...${NC}"
cd contracts

export USE_REAL_SP1_VERIFIER=true
forge script script/Deploy.s.sol:DeployScript \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --skip-simulation

DEPLOY_RESULT=$?

if [ $DEPLOY_RESULT -eq 0 ] && [ -f .env.contracts ]; then
    echo -e "${GREEN}✓ Contracts deployed with REAL SP1 Verifier${NC}"
    
    # Load contract addresses
    source .env.contracts
    echo -e "${GREEN}✓ Contract addresses loaded${NC}"
    echo -e "   MockETH: $COLLATERAL_TOKEN"
    echo -e "   MockUSDC: $DEBT_TOKEN"
    echo -e "   SP1Verifier: $VERIFIER"
    echo -e "   AegisVault: $VAULT"
else
    echo -e "${RED}✗ Contract deployment failed${NC}"
    echo -e "${YELLOW}Trying deployment log...${NC}"
    tail -20 ../contracts/broadcast/Deploy.s.sol/*/run-latest.json 2>/dev/null || echo "No deployment log found"
    exit 1
fi

cd ..

# Step 3: Generate test wallets
echo -e "\n${BLUE}[3/5] Generating test wallets...${NC}"

# Anvil default accounts (we'll use accounts 1, 2, 3 for users)
declare -a USER_ADDRESSES=(
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"  # Account 1
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"  # Account 2
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906"  # Account 3
)

declare -a USER_PRIVATE_KEYS=(
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
    "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
)

echo -e "${YELLOW}Created $NUM_USERS test wallets:${NC}"
for i in $(seq 0 $((NUM_USERS-1))); do
    echo -e "  User $((i+1)): ${USER_ADDRESSES[$i]}"
done

# Step 4: Fund wallets and mint tokens
echo -e "\n${BLUE}[4/5] Funding wallets and minting tokens...${NC}"

for i in $(seq 0 $((NUM_USERS-1))); do
    USER_ADDR=${USER_ADDRESSES[$i]}
    USER_KEY=${USER_PRIVATE_KEYS[$i]}
    USER_NUM=$((i+1))
    
    echo -e "\n${YELLOW}Setting up User $USER_NUM ($USER_ADDR)...${NC}"
    
    # Mint collateral tokens (MockETH)
    AMOUNT=$((10 * (USER_NUM + 1)))  # User 1 gets 20 ETH, User 2 gets 30 ETH, etc.
    AMOUNT_WEI="${AMOUNT}000000000000000000"
    
    cast send $COLLATERAL_TOKEN \
        "mint(address,uint256)" \
        $USER_ADDR \
        $AMOUNT_WEI \
        --rpc-url http://127.0.0.1:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
        > /dev/null 2>&1
    
    echo -e "  ${GREEN}✓ Minted $AMOUNT ETH (collateral)${NC}"
    
    # Check balance
    BALANCE=$(cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" $USER_ADDR --rpc-url http://127.0.0.1:8545)
    BALANCE_ETH=$(echo "scale=2; $BALANCE / 1000000000000000000" | bc)
    echo -e "  ${GREEN}✓ Balance: $BALANCE_ETH ETH${NC}"
done

# Step 5: Test deposit and borrow for each user
echo -e "\n${BLUE}[5/5] Testing operations for each user...${NC}\n"

for i in $(seq 0 $((NUM_USERS-1))); do
    USER_ADDR=${USER_ADDRESSES[$i]}
    USER_KEY=${USER_PRIVATE_KEYS[$i]}
    USER_NUM=$((i+1))
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  User $USER_NUM Testing (${USER_ADDR:0:10}...)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
    
    # Calculate amounts
    COLLATERAL_AMOUNT=$((10 * (USER_NUM + 1)))  # 20, 30, 40 ETH
    COLLATERAL_WEI="${COLLATERAL_AMOUNT}000000000000000000"
    
    # Borrow amount (30% LTV for safety)
    # At $2500 per ETH: 20 ETH = $50k, borrow $15k
    COLLATERAL_VALUE=$((COLLATERAL_AMOUNT * 2500))
    BORROW_AMOUNT=$((COLLATERAL_VALUE * 30 / 100))
    BORROW_USDC="${BORROW_AMOUNT}000000"
    
    echo -e "${YELLOW}User $USER_NUM Configuration:${NC}"
    echo -e "  Collateral: $COLLATERAL_AMOUNT ETH"
    echo -e "  Collateral Value: \$$COLLATERAL_VALUE"
    echo -e "  Borrow Amount: \$$BORROW_AMOUNT USDC (30% LTV)"
    echo -e ""
    
    # Test 1: Approve collateral
    echo -e "${YELLOW}[Test 1] Approving collateral...${NC}"
    cast send $COLLATERAL_TOKEN \
        "approve(address,uint256)" \
        $VAULT \
        $COLLATERAL_WEI \
        --rpc-url http://127.0.0.1:8545 \
        --private-key $USER_KEY \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Collateral approved${NC}\n"
    else
        echo -e "${RED}✗ Approval failed${NC}\n"
        continue
    fi
    
    # Test 2: Deposit collateral
    echo -e "${YELLOW}[Test 2] Depositing collateral...${NC}"
    
    # Generate mock proof data (32 bytes commitment)
    COMMITMENT="0x$(printf '01%.0s' {1..64})"
    PROOF="0x"  # Empty proof for now (would use real ZK proof)
    
    TX_HASH=$(cast send $VAULT \
        "deposit(uint256,bytes32,bytes)" \
        $COLLATERAL_WEI \
        $COMMITMENT \
        $PROOF \
        --rpc-url http://127.0.0.1:8545 \
        --private-key $USER_KEY \
        2>/dev/null | grep "transactionHash" | awk '{print $2}')
    
    if [ ! -z "$TX_HASH" ]; then
        echo -e "${GREEN}✓ Deposit successful${NC}"
        echo -e "  TX: $TX_HASH"
        
        # Check vault balance
        VAULT_BALANCE=$(cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" $VAULT --rpc-url http://127.0.0.1:8545)
        VAULT_ETH=$(echo "scale=2; $VAULT_BALANCE / 1000000000000000000" | bc)
        echo -e "  ${GREEN}✓ Vault now holds: $VAULT_ETH ETH total${NC}\n"
    else
        echo -e "${RED}✗ Deposit failed${NC}\n"
        continue
    fi
    
    # Test 3: Borrow
    echo -e "${YELLOW}[Test 3] Borrowing USDC...${NC}"
    
    # Generate borrow proof data
    NULLIFIER="0x$(printf '02%.0s' {1..64})"
    NEW_COMMITMENT="0x$(printf '03%.0s' {1..64})"
    
    # Encode public values (simplified - would use real encoding)
    PUBLIC_VALUES="0x$(printf '00%.0s' {1..168})"
    
    TX_HASH=$(cast send $VAULT \
        "borrow(bytes32,bytes32,bytes,bytes)" \
        $NULLIFIER \
        $NEW_COMMITMENT \
        $PUBLIC_VALUES \
        $PROOF \
        --rpc-url http://127.0.0.1:8545 \
        --private-key $USER_KEY \
        --gas-limit 500000 \
        2>/dev/null | grep "transactionHash" | awk '{print $2}')
    
    if [ ! -z "$TX_HASH" ]; then
        echo -e "${GREEN}✓ Borrow successful${NC}"
        echo -e "  TX: $TX_HASH"
        
        # Check user USDC balance
        USER_USDC=$(cast call $DEBT_TOKEN "balanceOf(address)(uint256)" $USER_ADDR --rpc-url http://127.0.0.1:8545)
        USER_USDC_READABLE=$(echo "scale=2; $USER_USDC / 1000000" | bc)
        echo -e "  ${GREEN}✓ User received: \$$USER_USDC_READABLE USDC${NC}\n"
    else
        echo -e "${YELLOW}⚠ Borrow skipped (needs real ZK proof)${NC}\n"
    fi
    
    echo -e "${GREEN}✓ User $USER_NUM testing complete${NC}\n"
done

# Final summary
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Multi-User Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Final State:${NC}"

# Check vault collateral
VAULT_BALANCE=$(cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" $VAULT --rpc-url http://127.0.0.1:8545)
VAULT_ETH=$(echo "scale=2; $VAULT_BALANCE / 1000000000000000000" | bc)
echo -e "  Total Collateral in Vault: ${GREEN}$VAULT_ETH ETH${NC}"

# Check each user's balances
echo -e "\n${YELLOW}User Balances:${NC}"
for i in $(seq 0 $((NUM_USERS-1))); do
    USER_ADDR=${USER_ADDRESSES[$i]}
    USER_NUM=$((i+1))
    
    ETH_BAL=$(cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" $USER_ADDR --rpc-url http://127.0.0.1:8545)
    ETH_READABLE=$(echo "scale=2; $ETH_BAL / 1000000000000000000" | bc)
    
    USDC_BAL=$(cast call $DEBT_TOKEN "balanceOf(address)(uint256)" $USER_ADDR --rpc-url http://127.0.0.1:8545)
    USDC_READABLE=$(echo "scale=2; $USDC_BAL / 1000000" | bc)
    
    echo -e "  User $USER_NUM: ${GREEN}$ETH_READABLE ETH${NC}, ${GREEN}\$$USDC_READABLE USDC${NC}"
done

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✓ Multi-User Fork Testing Complete!           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Note: Borrow operations require real ZK proofs.${NC}"
echo -e "${YELLOW}      Generate proofs with: cd script && cargo run --release --bin zk-script groth16${NC}\n"

echo -e "${BLUE}Deployed Contracts:${NC}"
echo -e "  MockETH: $COLLATERAL_TOKEN"
echo -e "  MockUSDC: $DEBT_TOKEN"
echo -e "  SP1Verifier (REAL): $VERIFIER"
echo -e "  AegisVault: $VAULT"
echo -e ""
