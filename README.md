# 🛡️ Insurance DAO

A decentralized insurance protocol built on Stacks that enables communities to pool tokens and collectively insure against niche risks like crop failures, freelance gig cancellations, and other specialized coverage needs.

## 🌟 Features

- **🏦 Pool Creation**: Create custom insurance pools for specific risks
- **💰 Token Staking**: Stake STX tokens to participate in risk pools
- **📋 Claims Management**: Submit and vote on insurance claims
- **🗳️ Decentralized Voting**: Community-driven claim approval process
- **📊 Transparent Stats**: Track pool performance and payouts
- **⏰ Time-Based Governance**: Built-in expiry and voting periods

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- STX tokens for staking and gas fees

### Pool Creation

Create a new insurance pool for a specific risk:

```clarity
(contract-call? .Insurance-DAO create-pool 
  "Crop Insurance" 
  "Insurance for crop failure due to weather"
  u500    ;; 5% premium rate (500/10000)
  u100000 ;; Max coverage of 1000 STX
  u52560  ;; Active for ~1 year (blocks)
  u1000   ;; Minimum stake of 10 STX
)
```

### Joining a Pool

Stake tokens to join an insurance pool:

```clarity
(contract-call? .Insurance-DAO stake-tokens 
  u1     ;; Pool ID
  u5000  ;; Stake 50 STX
)
```

### Submitting Claims

File a claim when experiencing a covered loss:

```clarity
(contract-call? .Insurance-DAO submit-claim
  u1 ;; Pool ID
  u50000 ;; Claim amount (500 STX)
  "Crop destroyed by hail storm on 2024-01-15. Attached weather reports and damage photos."
)
```

### Voting on Claims

Pool members vote to approve or reject claims:

```clarity
(contract-call? .Insurance-DAO vote-on-claim
  u1   ;; Claim ID
  true ;; Vote to approve (false to reject)
)
```

### Processing Claims

After voting period, anyone can process the claim:

```clarity
(contract-call? .Insurance-DAO process-claim u1)
```

## 📋 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `create-pool` | Create a new insurance pool |
| `stake-tokens` | Join a pool by staking STX |
| `submit-claim` | File an insurance claim |
| `vote-on-claim` | Vote on pending claims |
| `process-claim` | Execute claim after voting |
| `withdraw-stake` | Withdraw staked tokens |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-pool` | Get pool information |
| `get-pool-member` | Get member stake details |
| `get-claim` | Get claim information |
| `get-pool-stats` | Get pool statistics |
| `calculate-premium` | Calculate premium for coverage |

## 🔧 Parameters

### Pool Parameters
- **Premium Rate**: Percentage rate (basis points, e.g., 500 = 5%)
- **Max Coverage**: Maximum payout per claim
- **Duration**: Pool active period in blocks
- **Min Stake**: Minimum required stake to join

### Voting Parameters
- **Voting Period**: 1008 blocks (~1 week)
- **Minimum Voters**: 3 votes required for processing
- **Approval Threshold**: Simple majority (>50%)

## 💡 Use Cases

### 🌾 Agricultural Insurance
Farmers pool funds to cover crop losses from weather, pests, or market volatility.

### 💼 Freelancer Protection
Freelancers insure against client payment defaults or project cancellations.

### 🏠 Property Damage
Communities cover specific risks like flooding in particular neighborhoods.

### 📱 Equipment Coverage
Groups insure valuable equipment or tools used in their profession.

## 🔒 Security Features

- Time-locked withdrawals prevent exit scams
- Multi-signature voting ensures fair claim assessment  
- Transparent on-chain voting and fund management
- Built-in expiry mechanisms prevent stale claims

## 📈 Economics

Pool members earn from:
- **Unused premiums** when claims are lower than expected
- **Staking rewards** from successful risk assessment
- **Governance participation** in pool management decisions

## 🛠️ Development

### Testing
```bash
clarinet test
```

### Local Development
```bash
clarinet console
```

### Deployment
```bash
clarinet deploy
```

## 📜 License

MIT License - See LICENSE file for details.

---

Built with ❤️ on Stacks blockchain
