# YoorQuezt Demo Recording Guide (3-5 min)

## What Grant Programs Care About

### Ethereum Foundation / Protocol Guild
- **Public good**: Decentralized relay (not another centralized service)
- **User protection**: MEV protection that returns value to users
- **Working code**: Real transactions on testnet, not slides

### Flashbots Grants
- **MEV-Share compatibility**: You support their protocol
- **Beyond Flashbots**: Intent solving, multi-chain, OFA rebates
- **Research depth**: Show the sealed-bid auction, fair ordering

### Uniswap Foundation
- **DEX user protection**: Sandwich guard for swaps
- **Backrun rebates**: 80% of MEV value back to swappers
- **Multi-DEX awareness**: V2 + V3 arb detection

### Optimism RetroPGF / Base / Arbitrum DAO
- **Multi-chain**: You already support their L2s
- **Cross-chain MEV**: Show connectivity to their testnets
- **User benefit**: Measurable rebates, not just extraction

---

## Pre-Recording Setup

### 1. Get testnet ETH + RPC URLs

```bash
# You need:
# - Alchemy/Infura Sepolia RPC URL (free tier works)
# - Sepolia ETH (faucet: https://sepoliafaucet.com)
# - A test private key with ~0.1 Sepolia ETH

# Create .env.testnet in the demo repo
cat > .env.testnet << 'EOF'
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
SIGNER_PRIVATE_KEY=YOUR_TEST_PRIVATE_KEY
MEV_API_TOKEN=demo-token
MESH_SHARED_KEY=demo-shared-key-32bytes!
EOF
```

### 2. Terminal setup
- Use a clean terminal (iTerm2 or Warp)
- Font size: 16-18pt (readable on video)
- Dark theme, no distracting prompts
- Split into 2-3 panes if needed

### 3. Recording tool
- **asciinema** (terminal only, lightweight): `brew install asciinema`
- **OBS Studio** (screen + voiceover): best for polished video
- **Loom** (quickest, screen + webcam): good for informal demos

---

## Demo Script (3-5 minutes)

### Scene 1: The Problem (30 seconds)
**What to say:**
> "Every day, DeFi users lose millions to MEV — sandwich attacks, frontrunning,
> and unfair ordering. YoorQuezt fixes this with a decentralized relay network
> that protects users and returns extracted value back to them."

**What to show:** Nothing yet — this is your opening hook. Can overlay text/slides.

---

### Scene 2: Boot the Infrastructure (45 seconds)
**What to say:**
> "Let me show you the full stack running. One command brings up a 3-node
> mesh network, MEV engine, OFA proxy, gateway, and full observability."

**What to do:**
```bash
# Show the docker-compose (briefly scroll through services)
cat docker-compose.testnet.yaml | head -40

# Start everything
docker compose -f docker-compose.testnet.yaml up -d

# Show services coming up
docker compose -f docker-compose.testnet.yaml ps
```

**Wait 10-15 seconds, then:**
```bash
# Health check all services
curl -s http://localhost:8080/health | jq .   # Mesh
curl -s http://localhost:9090/health | jq .   # MEV Engine
```

**Key talking point:** "Three mesh nodes connected via QUIC with TLS 1.3, AES-256-GCM encrypted gossip, ECDSA-signed messages."

---

### Scene 3: Mesh Network in Action (60 seconds)
**What to say:**
> "The mesh network is a decentralized P2P relay. Transactions propagate
> to all nodes in milliseconds via our gossip protocol."

**What to do:**
```bash
# Show connected peers
curl -s http://localhost:8080/peers | jq .

# Submit a transaction to Node 1
curl -s -X POST http://localhost:8080/sendTransaction \
  -H "Content-Type: application/json" \
  -d '{
    "id": "demo-tx-001",
    "chain": "ethereum",
    "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
    "to": "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    "value": "1000000000000000000",
    "data": "0x38ed1739",
    "gas_price": "50000000000",
    "nonce": 42
  }' | jq .

# Verify it propagated to Node 2
curl -s http://localhost:8081/peers | jq .

# Show blocks being built
sleep 3
curl -s http://localhost:8080/blocks | jq .
```

**Key talking point:** "The transaction was gossiped to all 3 nodes, deduplicated via bloom filter, compressed with zstd, and encrypted end-to-end. Now watch it get included in a block with fee-priority ordering."

---

### Scene 4: MEV Detection & Protection (60 seconds)

**THIS IS THE MONEY SHOT FOR GRANTS**

**What to say:**
> "Now the powerful part. When a user submits a swap through our OFA proxy,
> we detect the MEV opportunity, create a backrun bundle, and return 80%
> of the extracted value back to the user as a rebate."

**What to do:**
```bash
# Step 1: Submit a protected transaction
curl -s -X POST http://localhost:9090/api/v1/protect \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer demo-token" \
  -d '{
    "tx": "0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080",
    "chain": "ethereum",
    "max_slippage": 0.5
  }' | jq .

# Step 2: Submit an MEV bundle
curl -s -X POST http://localhost:9090/api/v1/bundle \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer demo-token" \
  -d '{
    "txs": ["0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080"],
    "block_number": "latest",
    "chain": "ethereum",
    "strategy": "arbitrage"
  }' | jq .

# Step 3: Show the OFA proxy intercepting a raw transaction
curl -s -X POST http://localhost:9100 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "eth_sendRawTransaction",
    "params": ["0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080"],
    "id": 1
  }' | jq .
```

**Key talking point:** "The OFA proxy is a drop-in replacement for any Ethereum RPC. Users just change their RPC URL — no code changes. We intercept swaps, detect backrun opportunities, and return 80% of the profit. The user gets a better price than they would on any other relay."

---

### Scene 5: Observability & Dashboards (45 seconds)
**What to say:**
> "Full observability out of the box. Prometheus metrics, Grafana dashboards,
> distributed tracing with OpenTelemetry, and centralized logs."

**What to do:**
- Open browser: `http://localhost:3000` (Grafana)
- Login: admin / yoorquezt
- Show the "YoorQuezt Platform Overview" dashboard
- Point out:
  - Mesh peers connected (gauge)
  - Gossip latency p99 (graph)
  - Bundles submitted (counter)
  - Strategy performance (by type)

**Key talking point:** "Every transaction is traced end-to-end — from submission through gossip, MEV detection, bundling, and settlement. This is production-grade observability."

---

### Scene 6: Developer Experience (45 seconds)
**What to say:**
> "For developers, we provide TypeScript and Python SDKs, a CLI tool,
> a live TUI dashboard, and a WebSocket gateway with 27 JSON-RPC methods."

**What to do:**
```bash
# Show SDK example (just cat the file, don't run it)
cat sdk/typescript/submit-tx.ts

# Show the API is a standard JSON-RPC interface
curl -s -X POST ws://localhost:9099 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"mev_health","params":{},"id":1}' | jq .
```

**Key talking point:** "Any dApp can integrate in 5 lines of code. Just point your RPC URL to our OFA proxy and your users are automatically protected."

---

### Scene 7: Closing (30 seconds)
**What to say:**
> "YoorQuezt is a full-stack MEV infrastructure platform — mesh relay,
> extraction engine, user protection, and on-chain settlement.
> 15 chains, 2,900+ tests, 4 audited smart contracts.
> We're building the fair ordering layer for DeFi."

**What to show:**
```bash
# Final stats
echo "=== YoorQuezt Platform ==="
echo "Chains:     15 (Ethereum, BSC, Solana, Sui, Arbitrum, Base, ...)"
echo "Tests:      2,934 (100% pass rate)"
echo "Contracts:  4 Solidity (settlement, rebate, intent, executor)"
echo "Binaries:   8 (node, bootstrap, mev, gateway, ofa, cli, tui, mockrpc)"
echo "Coverage:   Core logic 70-100%"
```

---

## Grant-Specific Tips

### For Ethereum Foundation
- Emphasize **public good**: decentralized relay, not rent-seeking
- Show MEV-Share compatibility (you extend their standard)
- Mention the 80% rebate — this aligns with "returning value to users"

### For Flashbots
- Show SSE hints integration (you speak their protocol)
- Emphasize what you add: intent solving, multi-chain, OFA
- Position as complementary, not competitive

### For L2 Grants (Optimism, Arbitrum, Base)
- Show multi-chain config with their testnet connected
- Emphasize cross-chain MEV detection
- Show you're already integrated with their chains

### For Uniswap Foundation
- Focus on the swap protection story
- Show a real Uniswap V2 swap going through OFA
- Quantify: "X% of swap MEV returned to users"

---

## Recording Checklist

- [ ] Terminal font 16-18pt, dark theme
- [ ] All services healthy before recording
- [ ] Grafana dashboard pre-loaded in browser tab
- [ ] Script commands pre-typed in a notes file (copy-paste, don't type live)
- [ ] Practice the voiceover 2-3 times
- [ ] Record in 1080p minimum
- [ ] Add intro/outro title cards in post
- [ ] Upload to YouTube (unlisted) + share link in grant application

## Quick Recording Commands

```bash
# Terminal recording (lightweight)
asciinema rec demo.cast --title "YoorQuezt Platform Demo"

# Convert to GIF (for README/docs)
# Install: pip install asciinema-agg
agg demo.cast demo.gif --cols 120 --rows 35

# Screen recording with OBS
# Set up: Display Capture + Audio Input (mic)
# Output: 1080p, 30fps, MP4
```
