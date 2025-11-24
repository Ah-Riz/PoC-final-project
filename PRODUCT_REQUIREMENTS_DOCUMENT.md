# 📋 Aegis Protocol - Product Requirement Document (PRD)

**Version:** 1.0  
**Date:** November 24, 2025  
**Status:** From PoC to Production

---

## 📑 Executive Summary

### Product Overview

**Aegis Protocol** is a production-grade privacy-preserving DeFi lending platform leveraging Zero-Knowledge proofs for complete financial privacy with regulatory compliance.

**Current State (PoC):**
- ✅ Functional ZK proof system (SP1 zkVM)
- ✅ Deployed on Mantle Sepolia testnet
- ✅ Privacy score: 100/100
- ✅ Basic deposit/borrow functionality
- ✅ Wrapped MNT (WMNT) support

**Production Goals:**
- 🎯 Mainnet deployment (Mantle & multi-chain)
- 🎯 Professional UI/UX with mobile support
- 🎯 Multi-collateral & multi-debt tokens
- 🎯 Advanced features (liquidations, governance, yield)
- 🎯 Security audits & formal verification
- 🎯 Institutional-grade compliance tools
- 🎯 Cross-chain interoperability

---

## 🎯 Product Vision

**Mission:** *"Empower users with institutional-grade financial privacy while maintaining transparency for regulatory compliance."*

**Principles:**
1. Privacy First - Default privacy, optional transparency
2. Security Always - Battle-tested cryptography
3. User Empowerment - Self-custody with full control
4. Regulatory Compliance - Built for regulated future
5. Open Innovation - Open-source with community governance

---

## 📈 Market Analysis

### Target Market
- **DeFi Lending:** $20B+ TVL
- **Privacy DeFi:** $2B+ potential (10% adoption)
- **Institutional DeFi:** $50B+ opportunity

### User Segments
1. **High-Net-Worth Individuals:** Privacy-conscious holders ($5B+)
2. **Institutional Investors:** Hedge funds, DAOs ($20B+)
3. **Privacy Advocates:** Financial privacy seekers ($1B+)
4. **Corporate Treasury:** Crypto-native companies ($10B+)

### Competitive Advantage
- ✅ Complete privacy (100/100 vs 0/100 traditional)
- ✅ Regulatory compliance built-in
- ✅ Production-ready ZK (SP1 zkVM)
- ✅ Multi-chain support (planned)
- ✅ Institutional features

---

## 👥 User Personas

### 1. Institutional Ian (Hedge Fund Manager)
**Needs:** Borrow without revealing strategies, prevent front-running, compliance docs
**Pain:** Current DeFi exposes positions to competitors

### 2. Privacy Paula (High-Net-Worth Individual)
**Needs:** Protect financial privacy, simple interface, self-custody
**Pain:** Public blockchain exposes wealth

### 3. Enterprise Eric (CFO)
**Needs:** Corporate treasury management, compliance, audit trails
**Pain:** Competitors track business operations

### 4. Developer Dave (DeFi Developer)
**Needs:** APIs, documentation, composability
**Pain:** Hard to integrate privacy protocols

---

## 🎨 Core Features

### Phase 1: MVP (Months 1-4)

#### 1.1 Private Deposits
- Support 5+ collateral types (ETH, WBTC, stablecoins)
- ZK commitment generation (<10s)
- Merkle tree storage
- Batch deposits for gas optimization
- **Acceptance:** Gas < 300k, amount hidden on-chain

#### 1.2 Private Borrowing
- Borrow against hidden collateral
- ZK proof of LTV (<75%)
- Support 3+ debt tokens (USDC, USDT, DAI)
- Relayer for address privacy
- Interest rate calculation
- **Acceptance:** Proof generation <30s, gas <500k

#### 1.3 Private Repayment
- Partial & full repayment
- Interest calculation
- Commitment updates
- **Acceptance:** Gas <400k

#### 1.4 Wrapped Token Support
- WMNT (already implemented)
- Generic wrapper for native tokens
- 1:1 peg guarantee
- Instant wrap/unwrap

#### 1.5 Web Interface
- **Frontend:** Next.js 15, React, TailwindCSS, shadcn/ui
- **Web3:** Wagmi v2, Viem, RainbowKit
- **Features:** Wallet connection, deposit/borrow/repay UI, position dashboard
- **Performance:** <3s load time, mobile responsive

---

### Phase 2: Advanced Features (Months 5-8)

#### 2.1 Automated Liquidations
- Keeper network monitors health
- ZK proof of under-collateralization
- Dutch auction mechanism
- 5-10% liquidation bonus
- Privacy-preserving for liquidatees

#### 2.2 Governance & DAO
- $AEGIS token
- Snapshot voting + on-chain execution
- Parameter control (LTV, rates, fees)
- Emergency multisig (3/5)
- **Distribution:** 40% community, 25% team, 15% investors, 10% treasury, 10% liquidity

#### 2.3 Interest Rate Models
```
Utilization-based rates:
- Base rate: 2%
- Slope 1: 4% (0-80% util)
- Slope 2: 60% (80-100% util)
- Optimal: 80%
```

#### 2.4 Oracle Integration
- **Primary:** Chainlink
- **Secondary:** Pyth Network
- **Fallback:** Uniswap V3 TWAP
- Staleness checks, circuit breakers

#### 2.5 Yield Generation
- Deploy idle liquidity to Aave/Compound
- Stake wrapped tokens (stETH, rETH)
- Auto-compound yields
- Target: 80%+ funds deployed

---

### Phase 3: Scale & Optimize (Months 9-12)

#### 3.1 Cross-Chain Support
**Target Chains:** Mantle, Ethereum, Arbitrum, Optimism, Polygon zkEVM, Base
**Bridge:** LayerZero (primary), Axelar (secondary)
**Architecture:** Unified commitment registry, cross-chain nullifiers

#### 3.2 Mobile App
- React Native/Flutter
- WalletConnect integration
- Biometric auth, push notifications
- QR deposits, portfolio tracking

#### 3.3 Advanced Privacy
- Decentralized relayer network (staking/slashing)
- Mixer integration (Tornado-style pools)
- Stealth addresses for withdrawals

#### 3.4 Compliance Suite
- **Selective Disclosure:** Export proofs for auditors
- **KYC Integration:** Optional for institutions
- **Tax Reporting:** Transaction reports
- **Modes:** Full Privacy | Selective Disclosure | Institutional

#### 3.5 Institutional Features
- Multi-sig support (Gnosis Safe)
- Sub-accounts & delegation
- REST API & WebSocket
- JavaScript/Python SDKs
- White-label solution

---

## 🔧 Technical Architecture

### Smart Contract Stack

```
Governance (Governor)
    ↓
Privacy Vault (Core) ←→ Verifier Hub (ZK)
    ↓                        ↓
Commitment Tree      Oracle Registry
    ↓                        ↓
    └────→ Token Registry ←──┘
```

**Core Contracts:**
1. **AegisVault.sol** - Main protocol logic
2. **CommitmentTree.sol** - Merkle tree storage
3. **VerifierHub.sol** - ZK proof verification
4. **OracleRegistry.sol** - Price feeds
5. **InterestRateModel.sol** - Dynamic rates
6. **Liquidator.sol** - Liquidation mechanism

---

### ZK Circuit Design

#### Deposit Circuit
**Private Inputs:** secret_key, amount, token, salt
**Public Outputs:** commitment = hash(secret, amount, token, salt)
**Constraints:** ~50K, Proving: <5s

#### Borrow Circuit
**Private Inputs:** secret, collateral, debt, old_salt, new_salt, merkle_path
**Public Outputs:** nullifier, new_commitment, borrow_amount
**Constraints:**
1. Verify old commitment in Merkle tree
2. Calculate LTV ≤ 75%
3. Generate nullifier = hash(secret, "NULLIFIER", old_salt)
4. Create new commitment with updated debt
**Performance:** ~100K constraints, <15s proving

#### Liquidation Circuit
**Proves:** Position unhealthy (LTV > 80%)
**Outputs:** nullifier, collateral_to_liquidate, is_unhealthy

---

### Backend Infrastructure

#### 1. Proof Generation Service
- **Tech:** Rust, SP1 SDK, gRPC
- **Capacity:** 1000 proofs/min
- **Deployment:** Kubernetes (multi-region)

#### 2. Relayer Network
- **Tech:** Node.js, Ethers.js, Redis
- **Fee:** Gas + 0.1% protocol fee
- **Capacity:** 500 tx/min

#### 3. Indexer Service
- **Tech:** Go, PostgreSQL, GraphQL
- **Data:** Commitments, nullifiers, events, interest history

#### 4. Oracle Aggregator
- **Tech:** Python, Redis, WebSocket
- **Sources:** Chainlink, Pyth, DEX TWAPs
- **Frequency:** Every block

#### 5. Keeper Network
- **Purpose:** Monitor health, trigger liquidations
- **Reward:** Protocol fees

---

## 🔐 Security Requirements

### Phase 1: Pre-Launch
1. **Smart Contract Audits**
   - Trail of Bits (Tier 1)
   - OpenZeppelin or Consensys Diligence
   - Independent review: Cyfrin or Spearbit

2. **ZK Circuit Audit**
   - Audit circuits for soundness
   - Constraint verification
   - Vulnerability assessment

3. **Formal Verification**
   - Certora prover for critical functions
   - Mathematical proofs of correctness

4. **Bug Bounty**
   - Immunefi platform
   - Rewards: $10K-$500K based on severity

### Phase 2: Post-Launch
- Real-time monitoring (Forta/Tenderly)
- Emergency pause mechanisms
- Upgrade timelock (48-72 hours)
- Insurance coverage (Nexus Mutual)

---

## 📊 Performance Targets

### Smart Contracts
- Deposit gas: <300K
- Borrow gas: <500K
- Repayment gas: <400K
- Liquidation gas: <600K

### ZK Proofs
- Deposit proof: <5s
- Borrow proof: <15s
- Verification: <100ms on-chain

### Frontend
- Page load: <3s
- Time to interactive: <5s
- Lighthouse score: >90

### Backend
- API response: <200ms (p95)
- Uptime: 99.9%
- Proof generation queue: <30s wait

---

## 🚀 Deployment Strategy

### Testnet Phase (Month 1-2)
1. Deploy on Mantle Sepolia ✅ (Done)
2. Deploy on Ethereum Sepolia
3. Deploy on Arbitrum Sepolia
4. Beta testing with 50-100 users
5. Bug fixes & optimizations

### Mainnet Phase 1 (Month 3-4)
1. **Soft Launch:** Mantle Mainnet
   - TVL cap: $1M (first month)
   - Whitelisted users only
   - Gradual TVL increase

2. **Public Launch:** Month 4
   - Remove TVL caps (or $50M cap)
   - Open to all users
   - Liquidity mining incentives

### Mainnet Phase 2 (Month 5-8)
1. Ethereum Mainnet deployment
2. L2 deployments (Arbitrum, Optimism, Base)
3. Cross-chain bridges activated

---

## 📈 Success Metrics

### Phase 1 (Months 1-4)
- TVL: $10M+
- Users: 1,000+
- Transactions: 5,000+
- Uptime: 99.9%+

### Phase 2 (Months 5-8)
- TVL: $50M+
- Users: 5,000+
- Chains: 3+
- Integrations: 5+ protocols

### Phase 3 (Months 9-12)
- TVL: $200M+
- Users: 20,000+
- Chains: 6+
- Revenue: $1M+ (fees)

---

## 💰 Tokenomics & Revenue

### Revenue Streams
1. **Protocol Fees:** 0.1% on borrows
2. **Interest Spread:** 10% of interest
3. **Liquidation Fees:** 2% of liquidation bonus
4. **Relayer Fees:** 0.05% transaction fee

### Token Utility ($AEGIS)
- Governance voting
- Fee discounts (stakers)
- Collateral (future)
- Liquidity mining rewards

### Distribution
- 40% Community incentives (4-year vesting)
- 25% Team (4-year vesting, 1-year cliff)
- 15% Investors (2-year vesting, 6-month cliff)
- 10% Treasury (governance-controlled)
- 10% Liquidity mining (3-year distribution)

---

## 🗓️ Timeline & Milestones

### Q1 2026: Foundation
- [x] PoC complete (Done)
- [ ] Smart contract audits
- [ ] ZK circuit optimization
- [ ] Frontend MVP
- [ ] Testnet deployment (all chains)

### Q2 2026: Launch
- [ ] Mainnet soft launch (Mantle)
- [ ] Public launch
- [ ] Liquidity mining
- [ ] $AEGIS token launch

### Q3 2026: Scale
- [ ] Multi-chain expansion
- [ ] Mobile app release
- [ ] Liquidations live
- [ ] Governance activation

### Q4 2026: Optimize
- [ ] Cross-chain bridges
- [ ] Institutional features
- [ ] Compliance suite
- [ ] V2 planning

---

## ⚠️ Risk Management

### Technical Risks
- **ZK Proof Bugs:** Mitigate with audits, testing
- **Smart Contract Vulnerabilities:** Audits, formal verification, bug bounties
- **Oracle Failures:** Multi-source oracles, circuit breakers

### Market Risks
- **Low Adoption:** Liquidity mining, partnerships
- **Competitor Launch:** First-mover advantage, superior UX
- **Regulatory Changes:** Compliance-first design, legal counsel

### Operational Risks
- **Key Personnel Loss:** Distributed team, documentation
- **Infrastructure Outages:** Multi-region deployment, redundancy
- **Security Incidents:** Insurance, emergency procedures

---

## 📞 Stakeholders & Roles

### Core Team
- **CEO/Founder:** Vision, fundraising, partnerships
- **CTO:** Technical architecture, team leadership
- **Lead Smart Contract Engineer:** Solidity development
- **ZK Engineer:** Circuit design, SP1 integration
- **Frontend Engineer:** React/Next.js development
- **Backend Engineer:** APIs, infrastructure
- **Security Engineer:** Audits, monitoring
- **Product Manager:** Requirements, roadmap
- **Designer:** UI/UX
- **Marketing Lead:** Community, growth

### Advisors
- **DeFi Expert:** Protocol design, tokenomics
- **Security Advisor:** Audit oversight, best practices
- **Legal Counsel:** Regulatory compliance
- **ZK Researcher:** Advanced cryptography

---

## 💵 Budget Estimate

### Development (12 months)
- Team (10 people): $2M
- Audits: $300K
- Infrastructure: $100K
- Tools & licenses: $50K
**Subtotal:** $2.45M

### Marketing & Growth
- Liquidity mining: $2M
- Marketing campaigns: $500K
- Community incentives: $300K
- Events & conferences: $100K
**Subtotal:** $2.9M

### Operations
- Legal & compliance: $200K
- Admin & misc: $100K
**Subtotal:** $300K

### Contingency (15%)
- Buffer: $870K

**Total Budget:** $6.52M

---

## 📋 Appendix

### Technical Specifications

**Commitment Formula:**
```
commitment = Poseidon(
    user_secret_key,
    collateral_amount,
    collateral_token_id,
    debt_amount,
    debt_token_id,
    note_salt
)
```

**Nullifier Formula:**
```
nullifier = Poseidon(
    user_secret_key,
    "NULLIFIER",
    note_salt
)
```

**LTV Calculation:**
```
LTV = (debt_value_usd * 10000) / collateral_value_usd  // basis points
Max LTV = 7500  // 75%
Liquidation threshold = 8000  // 80%
```

**Interest Rate Formula:**
```
if utilization < 80%:
    rate = base_rate + (utilization * slope1)
else:
    rate = base_rate + (80% * slope1) + ((utilization - 80%) * slope2)
```

---

## ✅ Approval & Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Product Manager | | | |
| CTO | | | |
| CEO | | | |
| Lead Investor | | | |

---

**Document Status:** Draft v1.0  
**Next Review:** TBD  
**Contact:** product@aegisprotocol.xyz

