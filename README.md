# YoorQuezt — Decentralized MEV Infrastructure

> High-performance P2P transaction relay network with integrated MEV extraction, protection, and order flow auctions.

## What is YoorQuezt?

YoorQuezt is a **full-stack MEV infrastructure platform** that combines:

- **Mesh Network** — Decentralized P2P relay for sub-millisecond transaction propagation across 15+ chains
- **MEV Engine** — Intelligent MEV detection, arbitrage, liquidation, sandwich protection, and intent solving
- **Order Flow Auction (OFA)** — Fair auction system that returns MEV value to users via rebates
- **Settlement Contracts** — On-chain auction settlement, rebate distribution, and intent registry

```
┌─────────────────────────────────────────────────────────────────────┐
│                        YoorQuezt Platform                          │
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────┐  │
│  │  Mesh    │    │   MEV    │    │   OFA    │    │  Settlement  │  │
│  │ Network  │───▶│  Engine  │───▶│  Proxy   │───▶│  Contracts   │  │
│  │ (P2P)   │    │          │    │          │    │  (Solidity)  │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────────┘  │
│       │               │               │                             │
│  ┌────┴────┐    ┌─────┴─────┐   ┌─────┴─────┐                     │
│  │ 15+     │    │ Arb,Liq,  │   │ Rebates,  │                     │
│  │ Chains  │    │ Sandwich, │   │ Fair      │                     │
│  │ QUIC    │    │ Intent    │   │ Ordering  │                     │
│  └─────────┘    └───────────┘   └───────────┘                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Option 1: Local Mock (quickest, no API keys needed)

```bash
make up          # Start full stack with mock RPC
make demo        # Run 60-second automated demo
make demo-full   # Run 5-minute comprehensive demo
```

### Option 2: Live Testnet (real chains + relays, for demos/investors)

```bash
# 1. Configure .env.testnet (Alchemy free tier + test wallet)
cp .env.example .env.testnet
# Edit .env.testnet with your SEPOLIA_RPC_URL and SIGNER_PRIVATE_KEY

# 2. Start the live stack
make live-up       # Sepolia + Base + Arb + Optimism + Solana devnet
make live-status   # Check all services
make live-logs     # Tail logs
make live-down     # Stop

# What's included:
#   - 3-node mesh cluster (real P2P gossip, QUIC transport)
#   - MEV engine scanning real Sepolia + L2 testnets
#   - Flashbots Sepolia relay + MEV-Share SSE hints
#   - Binance + Coinbase real price feeds
#   - Cross-chain arb detection (Ethereum ↔ Base)
#   - Traffic generator (continuous txs, bundles, intents, protected txs)
#   - Full Grafana dashboard (http://localhost:3000)
```

### Option 3: Minikube (production-like)

```bash
make minikube-start   # Start minikube cluster
make minikube-deploy  # Deploy all services
make minikube-demo    # Run demo against cluster
make minikube-dash    # Open Grafana dashboard
```

## Architecture

### Mesh Network — P2P Transaction Relay

| Feature | Detail |
|---------|--------|
| **Transport** | QUIC (0-RTT, multiplexed streams) |
| **Encryption** | TLS 1.3 + AES-256-GCM payload encryption |
| **Signing** | ECDSA P-256 per-message signatures |
| **Gossip** | Batched gossip with bloom filter dedup |
| **Compression** | zstd compression (70-80% reduction) |
| **Peers** | Reputation-scored peer management |
| **Storage** | 3-tier: memory → Redis → PostgreSQL |

### MEV Engine — Intelligent Extraction

| Strategy | Description |
|----------|-------------|
| **Arbitrage** | Binary + triangular cross-DEX arbitrage |
| **Liquidation** | Under-collateralized position liquidation |
| **Sandwich** | Detection and protection (not exploitation) |
| **Intent Solving** | Competitive solver marketplace |
| **Backrun** | MEV-Share compatible backrun bundling |
| **Flash Loans** | Atomic flash loan arbitrage execution |

### Supported Chains

| Chain | Type | Connection |
|-------|------|------------|
| Ethereum | EVM | WebSocket |
| BSC | EVM | WebSocket |
| Arbitrum | EVM | WebSocket |
| Base | EVM | WebSocket |
| Optimism | EVM | WebSocket |
| Polygon | EVM | WebSocket |
| Avalanche | EVM | WebSocket |
| zkSync | EVM | WebSocket |
| Hyperliquid | EVM | WebSocket |
| Monad | EVM | WebSocket |
| Berachain | EVM | WebSocket |
| Sei | EVM | WebSocket |
| MegaETH | EVM | WebSocket |
| Solana | SVM | Polling |
| Sui | Move | Polling |

### Security

- **Transport**: TLS 1.3 mutual authentication
- **Payload**: AES-256-GCM encryption with rotating keys
- **Signing**: ECDSA P-256 per-message signatures
- **Rate Limiting**: Per-peer adaptive rate limiting
- **Reputation**: Score-based peer trust management
- **Contracts**: Audited internally, RFP ready for external audit
- **No hardcoded secrets**: All credentials via env vars

### Observability

The demo includes a full observability stack:
- **Prometheus** — Metrics collection (20+ custom metrics)
- **Grafana** — Pre-built dashboards for mesh, MEV, and OFA
- **OpenTelemetry** — Distributed tracing with Tempo
- **Loki** — Centralized log aggregation

## API

### Mesh Network API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/peers` | GET | Connected peers |
| `/blocks` | GET | Recent blocks |
| `/block/{id}` | GET | Block by ID |
| `/sendTransaction` | POST | Submit transaction |
| `/sendBundle` | POST | Submit bundle |
| `/mempool` | GET | Pending transactions (auth) |
| `/metrics` | GET | Prometheus metrics (auth) |

### MEV Engine API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/v1/bundle` | POST | Submit MEV bundle |
| `/api/v1/simulate` | POST | Simulate bundle |
| `/api/v1/protect` | POST | MEV-protected transaction |
| `/api/v1/intent` | POST | Submit intent |
| `/api/v1/auction/results` | GET | Auction results |
| `/api/v1/relay/list` | GET | Active relays |
| `/api/v1/ofa/stats` | GET | OFA statistics |

### WebSocket Gateway (JSON-RPC 2.0)

```json
{"jsonrpc":"2.0","method":"mev_submitBundle","params":[{"txs":["0x..."],"blockNumber":"0x..."}],"id":1}
```

27 RPC methods + 5 subscription topics available.

## SDK Examples

### TypeScript

```typescript
import { YoorQueztClient } from '@yoorquezt/sdk-mev';

const client = new YoorQueztClient('ws://localhost:9099');
await client.connect();

// Submit protected transaction
const result = await client.protectTransaction({
  tx: '0x...',
  chain: 'ethereum',
  maxSlippage: 0.5,
});

// Subscribe to auction results
client.subscribe('auction_results', (result) => {
  console.log('Auction:', result.bundleHash, result.profit);
});
```

### Python

```python
from yoorquezt import YoorQueztClient

client = YoorQueztClient("ws://localhost:9099")
client.connect()

# Submit bundle
result = client.submit_bundle(
    txs=["0x..."],
    block_number="latest",
    chain="ethereum",
)

# Stream MEV opportunities
for opportunity in client.stream_opportunities():
    print(f"Found: {opportunity.type} - {opportunity.profit_eth} ETH")
```

## CLI Tools

| Tool | Description |
|------|-------------|
| `yqctl` | CLI for bundles, auctions, intents, relays, health |
| `yqtui` | 5-tab TUI dashboard (live WebSocket) |
| `yqmev` | WebSocket JSON-RPC gateway |
| `yqofa` | Order Flow Auction proxy |

## Performance Benchmarks

Tested on a 3-node mesh cluster with gossip, peer discovery, and MEV engine active.

### Relay Throughput

| Test | Transactions | Duration | Throughput | Metrics Failures |
|------|-------------|----------|------------|-----------------|
| Baseline | 500 | 2s | 250 tx/s | 0 |
| Medium load | 2,000 | 7s | 285 tx/s | 0 |
| Heavy load | 5,000 | 15s | 333 tx/s | 0 |
| Stress test | 10,000 | 38s | 263 tx/s | 0 |
| Max stress | 25,000 | 114s | 219 tx/s | 0 |

### Cluster Stability

| Metric | Result |
|--------|--------|
| **Nodes UP** | 3/3 throughout all tests |
| **Peers connected** | 4 per node (full mesh) |
| **Metrics response** | <2s under 10K tx load |
| **Block building** | Continuous under load |
| **Gossip propagation** | Lock-free snapshot pattern, no starvation |
| **Race detector** | All concurrency tests pass with `-race` |

### Key Latencies

| Operation | p50 | p99 |
|-----------|-----|-----|
| Transaction relay (ingest) | <1ms | <5ms |
| Metrics endpoint | <10ms | <100ms |
| Peer gossip round | <500ms | <2s |
| Block build cycle | <50ms | <200ms |

> All benchmarks run on Docker Desktop (Apple Silicon). Production hardware will yield higher throughput.

## Project Stats

| Metric | Value |
|--------|-------|
| **Test Suite** | 2,934 tests (100% pass rate) |
| **Race Detector** | All tests pass with `-race` |
| **CI/CD** | GitHub Actions (lint, test, build, Docker) |
| **Contracts** | 4 Solidity contracts, 96 Foundry tests |
| **Documentation** | 28 docs, OpenAPI spec, architecture diagrams |
| **Languages** | Go, Solidity, TypeScript, Python |

## License

Proprietary. All rights reserved.

---

Built by [YoorQuezt Labs](https://yoorquezt.io)
