#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Aegis Protocol - Local End-to-End Test Suite   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"

# Check for fork mode
FORK_MODE=false
if [ "$1" = "--fork" ] || [ "$1" = "-f" ]; then
    FORK_MODE=true
    echo -e "${YELLOW}🌐 Fork mode: Will fork Mantle Sepolia testnet${NC}"
    echo ""
fi

# Check if .env exists, if not copy from example
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    cp .env.example .env
fi

# Check if Anvil is already running
if lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Anvil already running on port 8545"
    echo "   Kill it first: pkill -f anvil"
    exit 1
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

# Start Anvil
if [ "$FORK_MODE" = true ]; then
    echo "🔧 Starting Anvil with Mantle Sepolia fork..."
    echo "   RPC: https://rpc.sepolia.mantle.xyz"
    anvil --fork-url https://rpc.sepolia.mantle.xyz --block-time 1 > anvil-fork.log 2>&1 &
    ANVIL_PID=$!
    sleep 5  # Fork needs more time to start
else
    echo "🔧 Starting Anvil (local mode)..."
    anvil --block-time 1 > /dev/null 2>&1 &
    ANVIL_PID=$!
    sleep 2
fi

# Check if Anvil started
if ! ps -p $ANVIL_PID > /dev/null; then
   echo "❌ Failed to start Anvil"
   if [ "$FORK_MODE" = true ]; then
       echo "   Check anvil-fork.log for details"
       tail -n 20 anvil-fork.log
   fi
   exit 1
fi

echo "✅ Anvil running (PID: $ANVIL_PID)"

# Check for SP1 verifier in fork mode
if [ "$FORK_MODE" = true ]; then
    echo ""
    echo -e "${BLUE}🔍 Checking for SP1 verifier on Mantle Sepolia...${NC}"
    
    SP1_GROTH16="0x397A5f7f3dBd538f23DE225B51f532c34448dA9B"
    SP1_PLONK="0x3B6041173B80E77f038f3F2C0f9744f04837185e"
    
    # Check Groth16 verifier
    CODE=$(cast code $SP1_GROTH16 --rpc-url http://127.0.0.1:8545 2>/dev/null || echo "0x")
    
    if [ "$CODE" != "0x" ] && [ ${#CODE} -gt 10 ]; then
        echo -e "${GREEN}✓ Found SP1 Groth16 Verifier at $SP1_GROTH16${NC}"
        echo -e "${GREEN}  This means you can deploy with REAL ZK verification!${NC}"
    else
        echo -e "${YELLOW}⚠ SP1 verifier not deployed on Mantle Sepolia yet${NC}"
        echo -e "${YELLOW}  Will use MockVerifier for testing${NC}"
    fi
    
    # Check PLONK verifier
    CODE=$(cast code $SP1_PLONK --rpc-url http://127.0.0.1:8545 2>/dev/null || echo "0x")
    
    if [ "$CODE" != "0x" ] && [ ${#CODE} -gt 10 ]; then
        echo -e "${GREEN}✓ Found SP1 PLONK Verifier at $SP1_PLONK${NC}"
    fi
    
    echo ""
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

if [ "$FORK_MODE" = true ]; then
    echo -e "${YELLOW}🌐 Fork mode: Tested against Mantle Sepolia state${NC}"
    echo -e "${YELLOW}   Fork log: anvil-fork.log${NC}"
fi

echo -e "${YELLOW}Deployed contracts available at:${NC}"
cat contracts/.env.contracts 2>/dev/null || echo "  (addresses in contracts/.env.contracts)"
