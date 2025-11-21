#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Aegis Protocol - Mantle Sepolia Deployment     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}\n"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}✗ .env file not found!${NC}"
    echo -e "${YELLOW}Please create .env file with:${NC}"
    echo "  RPC_URL=https://rpc.sepolia.mantle.xyz"
    echo "  PRIVATE_KEY=<your-private-key>"
    exit 1
fi

# Load environment
source .env

# Check if PRIVATE_KEY is set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}✗ PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

# Check if RPC_URL is set
if [ -z "$RPC_URL" ]; then
    RPC_URL="https://rpc.sepolia.mantle.xyz"
    echo -e "${YELLOW}Using default RPC: $RPC_URL${NC}"
fi

echo -e "${BLUE}Configuration:${NC}"
echo "  RPC: $RPC_URL"
echo "  Deployer: $(cast wallet address $PRIVATE_KEY 2>/dev/null || echo 'Unable to derive')"
echo ""

# Check balance
BALANCE=$(cast balance $(cast wallet address $PRIVATE_KEY) --rpc-url $RPC_URL 2>/dev/null || echo "0")
echo -e "${BLUE}Checking balance...${NC}"
echo "  Balance: $(cast --to-unit $BALANCE ether) MNT"

if [ "$BALANCE" == "0" ] || [ -z "$BALANCE" ]; then
    echo -e "${RED}✗ Insufficient balance!${NC}"
    echo -e "${YELLOW}Get testnet MNT from: https://faucet.sepolia.mantle.xyz${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Sufficient balance${NC}\n"

# Deploy contracts
echo -e "${BLUE}[1/2] Deploying contracts to Mantle Sepolia...${NC}"
cd contracts

forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --slow

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Deployment successful!${NC}"
    
    # Copy addresses to parent .env
    if [ -f .env.contracts ]; then
        echo -e "${BLUE}[2/2] Saving deployment addresses...${NC}"
        
        # Remove old addresses from .env if they exist
        sed -i.bak '/^VAULT=/d; /^COLLATERAL_TOKEN=/d; /^DEBT_TOKEN=/d; /^VERIFIER=/d' ../.env
        
        # Append new addresses
        cat .env.contracts >> ../.env
        echo -e "${GREEN}✓ Addresses saved to .env${NC}\n"
        
        # Display addresses
        echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           Deployment Complete!                    ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${BLUE}Deployed Contracts:${NC}"
        cat .env.contracts
        
        echo -e "\n${BLUE}View on Explorer:${NC}"
        VAULT=$(grep "^VAULT=" .env.contracts | cut -d'=' -f2)
        echo "  https://explorer.sepolia.mantle.xyz/address/$VAULT"
        
    fi
else
    echo -e "\n${RED}✗ Deployment failed!${NC}"
    echo -e "${YELLOW}Check the error messages above${NC}"
    exit 1
fi

cd ..

echo -e "\n${GREEN}Next steps:${NC}"
echo "  1. View contracts on explorer (link above)"
echo "  2. Run integration test: cd script && cargo run --release --bin e2e"
echo "  3. Read DEPLOY_TESTNET.md for testing guide"

