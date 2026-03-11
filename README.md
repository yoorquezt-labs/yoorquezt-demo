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

### Option 1: Docker Compose (quickest)

```bash
make up          # Start full stack (mesh + MEV + monitoring)
make demo        # Run 60-second automated demo
make demo-full   # Run 5-minute comprehensive demo
```

### Option 2: Minikube (production-like)

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
