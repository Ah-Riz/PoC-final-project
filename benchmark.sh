#!/bin/bash

# Aegis Protocol - Comprehensive ZK Proof Benchmark Suite

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Aegis Protocol - ZK Proof Benchmark & Stress Test   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

echo "Choose test mode:"
echo "  [1] Fast Validation - Quick execution test (~5 seconds) ⚡ RECOMMENDED"
echo "  [2] Basic Tests - With proof generation (~2 minutes)"
echo "  [3] Groth16 Mode - On-chain ready proofs (~15 min first time, then ~5 min)"
echo "  [4] Benchmark Mode - Performance tests (~5 minutes)"
echo "  [5] Stress Test - 10 users, 20 proofs (~15 minutes)"
echo "  [6] Full Suite - All tests (~30 minutes)"
echo ""
read -p "Select [1/2/3/4/5/6]: " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Running Fast Validation (No Proof Generation)...${NC}\n"
        cd script
        cargo run --release fast
        ;;
    2)
        echo -e "\n${YELLOW}Running Basic Tests (With Proofs)...${NC}\n"
        cd script
        cargo run --release
        ;;
    3)
        echo -e "\n${YELLOW}Generating Groth16 Proofs (On-Chain Ready)...${NC}\n"
        echo -e "${BLUE}⚠️  First time setup takes 10-15 minutes${NC}"
        echo -e "${BLUE}    Subsequent runs will be much faster (~5 min)${NC}\n"
        cd script
        cargo run --release groth16
        ;;
    4)
        echo -e "\n${YELLOW}Running Performance Benchmarks...${NC}\n"
        cd script
        cargo run --release benchmark
        ;;
    5)
        echo -e "\n${YELLOW}Running Stress Test (10 users)...${NC}\n"
        cd script
        cargo run --release stress
        ;;
    6)
        echo -e "\n${YELLOW}Running Full Test Suite (this will take a while)...${NC}\n"
        cd script
        echo "Step 1/5: Fast Validation"
        cargo run --release fast
        echo -e "\n${BLUE}Step 2/5: Basic Tests${NC}"
        cargo run --release
        echo -e "\n${BLUE}Step 3/5: Groth16 Proofs${NC}"
        cargo run --release groth16
        echo -e "\n${BLUE}Step 4/5: Benchmarks${NC}"
        cargo run --release benchmark
        echo -e "\n${BLUE}Step 5/5: Stress Test${NC}"
        cargo run --release stress
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            ✅ Benchmark Complete!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}\n"
