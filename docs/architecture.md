# YoorQuezt Architecture

## System Overview

```
                                    ┌─────────────────┐
                                    │   Investors /    │
                                    │   DeFi Users     │
                                    └────────┬────────┘
                                             │
                              ┌──────────────┼──────────────┐
                              │              │              │
                         ┌────┴────┐   ┌─────┴─────┐  ┌────┴────┐
                         │ SDK     │   │ CLI       │  │ TUI     │
                         │ (TS/Py) │   │ (yqctl)   │  │ (yqtui) │
                         └────┬────┘   └─────┬─────┘  └────┬────┘
                              │              │              │
                              └──────────────┼──────────────┘
                                             │
                                    ┌────────┴────────┐
                                    │  WS Gateway     │
                                    │  (JSON-RPC 2.0) │
                                    │  Port 9099      │
                                    └────────┬────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
           ┌────────┴────────┐     ┌─────────┴─────────┐   ┌────────┴────────┐
           │  OFA Proxy      │     │   MEV Engine       │   │  Mesh Network   │
           │  Port 9100      │     │   Port 9090        │   │  Port 8080/4433 │
           │                 │     │                     │   │                 │
           │  - Intercept TX │     │  - Arbitrage        │   │  - QUIC P2P     │
           │  - Detect MEV   │     │  - Liquidation      │   │  - Gossip       │
           │  - Backrun      │     │  - Sandwich Guard   │   │  - Block Build  │
           │  - 80% Rebate   │     │  - Intent Solving   │   │  - Reputation   │
           └─────────────────┘     │  - Flash Loans      │   │  - 15+ Chains   │
                                   │  - Sealed Auction   │   └────────┬────────┘
                                   └─────────┬─────────┘             │
                                             │                        │
                                   ┌─────────┴─────────┐   ┌────────┴────────┐
                                   │  Settlement        │   │  Bootstrap      │
                                   │  Contracts          │   │  Server         │
                                   │                     │   │  Port 9000      │
                                   │  - AuctionSettlement│   │                 │
                                   │  - RebateDistributor│   │  - Peer Disc.   │
                                   │  - IntentRegistry   │   │  - Health       │
                                   │  - ArbExecutor      │   │  - Cleanup      │
                                   └─────────────────────┘   └─────────────────┘
```

## Data Flow

### Transaction Lifecycle

```
User submits TX
    │
    ├──▶ Direct to Mesh ──▶ Gossip to all peers ──▶ Block building
    │                                                     │
    └──▶ Via OFA Proxy                                    │
              │                                           │
              ├── Detect swap? ──▶ Calculate backrun      │
              │                         │                 │
              │                    Bundle (user TX + backrun)
              │                         │                 │
              │                    Sealed-bid auction      │
              │                         │                 │
              │                    80% profit ──▶ User rebate
              │                    20% profit ──▶ Protocol
              │                         │
              └── No MEV? ──▶ Forward to MEV engine ──▶ Submit to chain
```

### Gossip Protocol

```
Node A receives TX
    │
    ├── Validate signature (ECDSA P-256)
    ├── Check bloom filter (dedup)
    ├── Compress payload (zstd, ~75% reduction)
    ├── Encrypt (AES-256-GCM)
    ├── Batch with pending messages
    │
    └── Send to all peers via QUIC streams
              │
              ├── Peer B receives ──▶ ACK ──▶ Reputation reward
              ├── Peer C receives ──▶ ACK ──▶ Reputation reward
              └── Peer D timeout   ──▶ NACK ──▶ Reputation penalty
```

## Security Layers

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Transport | TLS 1.3 | Mutual authentication, forward secrecy |
| Payload | AES-256-GCM | Symmetric encryption of all messages |
| Signing | ECDSA P-256 | Per-message authentication |
| Dedup | Bloom filter | Prevent message replay |
| Rate Limit | Adaptive | Per-peer rate limiting |
| Reputation | Score-based | Peer trust management |

## Deployment Options

### Docker Compose (Development / Demo)
- Single command: `make up`
- Full stack with observability
- Mock blockchain RPCs

### Minikube (Staging / Investor Demo)
- Production-like Kubernetes environment
- StatefulSet for mesh nodes (3 replicas)
- HPA, PDB, monitoring
- NodePort services for external access

### Production (Cloud)
- Kubernetes with Helm charts
- Multi-AZ deployment
- Real chain RPCs via env vars
- Cert-manager for TLS
- Ingress with rate limiting
