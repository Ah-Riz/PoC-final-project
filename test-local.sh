#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Aegis Protocol - Local End-to-End Test Suite   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"

# Check if .env exists, if not copy from example
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    cp .env.example .env
fi

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    if [ ! -z "$ANVIL_PID" ]; then
        kill $ANVIL_PID 2>/dev/null
        echo -e "${GREEN}✓ Stopped Anvil${NC}"
    fi
}
trap cleanup EXIT

# Step 1: Start Anvil (local Ethereum node)
echo -e "${BLUE}[1/4] Starting Anvil...${NC}"
anvil --block-time 1 > /dev/null 2>&1 &
ANVIL_PID=$!
sleep 2

if ps -p $ANVIL_PID > /dev/null; then
   echo -e "${GREEN}✓ Anvil started (PID: $ANVIL_PID)${NC}"
else
   echo -e "${RED}✗ Failed to start Anvil${NC}"
   exit 1
fi

# Step 2: Deploy contracts
echo -e "\n${BLUE}[2/4] Deploying contracts...${NC}"
cd contracts
forge script script/Deploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Contracts deployed${NC}"
    
    # Copy contract addresses to parent .env
    if [ -f .env.contracts ]; then
        cat .env.contracts >> ../.env
        echo -e "${GREEN}✓ Contract addresses saved to .env${NC}"
    fi
else
    echo -e "${RED}✗ Deployment failed${NC}"
    exit 1
fi
cd ..

# Step 3: Build ZK program
echo -e "\n${BLUE}[3/4] Building ZK program...${NC}"
cd zk-program
cargo prove build
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ ZK program built${NC}"
else
    echo -e "${RED}✗ ZK build failed${NC}"
    exit 1
fi
cd ..

# Step 4: Run contract tests
echo -e "\n${BLUE}[4/4] Running smart contract tests...${NC}"
cd contracts
forge test -vv
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Smart contract tests passed${NC}"
else
    echo -e "${RED}✗ Smart contract tests failed${NC}"
    exit 1
fi
cd ..

echo -e "\n${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✓ ALL TESTS PASSED!                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}Test suite complete!${NC}"
echo -e "${YELLOW}Deployed contracts available at:${NC}"
cat contracts/.env.contracts 2>/dev/null || echo "  (addresses in contracts/.env.contracts)"
