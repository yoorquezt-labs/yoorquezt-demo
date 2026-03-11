# YoorQuezt — Technical Due Diligence Supplement

## Engineering Metrics

| Metric | Value |
|--------|-------|
| **Codebase** | ~40K lines Go, ~2K lines Solidity |
| **Test Suite** | 2,934 tests, 100% pass rate |
| **Test Types** | Unit, smoke, integration (Docker), E2E (live chains) |
| **Race Detector** | All tests pass with `-race` flag |
| **CI/CD** | GitHub Actions: lint, test, build, Docker, contracts |
| **Coverage** | Core logic 70-100%, overall ~55% |
| **Smart Contracts** | 4 contracts, 96 Foundry tests, internal audit complete |
| **Documentation** | 28 docs, OpenAPI 3.0 spec, architecture diagrams |
| **Docker Images** | Multi-arch (amd64/arm64), GHCR |

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Go 1.24 |
| P2P Transport | QUIC (quic-go) |
| Encryption | AES-256-GCM, ECDSA P-256 |
| Compression | zstd |
| Storage | Memory / Redis / PostgreSQL |
| Contracts | Solidity 0.8.24, Foundry |
| Monitoring | Prometheus, Grafana, OpenTelemetry, Loki |
| Deployment | Docker, Kubernetes, Minikube |

## Competitive Advantages

### vs. bloXroute
- **Open protocol** — Not a single-operator relay
- **Multi-chain native** — 15 chains vs EVM-only focus
- **MEV protection** — Users get 80% rebate vs. 0%
- **Intent solving** — Competitive solver marketplace

### vs. Flashbots
- **Full stack** — Relay + MEV + OFA + Settlement in one platform
- **Multi-chain** — Solana, Sui, BSC, not just Ethereum
- **User rebates** — OFA returns value to users
- **P2P gossip** — Decentralized vs. centralized relay

### vs. MEV-Share
- **Compatible** — Supports MEV-Share protocol (SSE hints, backrun)
- **Extended** — Adds intent solving, liquidation, cross-chain arb
- **On-chain settlement** — Trustless auction via smart contracts

## Revenue Model

1. **Protocol Fees** — 20% of MEV extracted (80% to users)
2. **Relay Fees** — Per-bundle relay marketplace fees
3. **Intent Fees** — Solver marketplace commission
4. **SaaS** — Enterprise API access

## Security Posture

- No hardcoded secrets (env var injection only)
- TLS 1.3 mandatory for all P2P connections
- AES-256-GCM payload encryption
- ECDSA P-256 message signing with low-S normalization
- 10MB message size limits
- 100 connection cap per node
- Rate limiting per peer
- Reputation-based peer management
- Smart contract: Ownable2Step, ReentrancyGuard, Pausable
- Internal audit: 8 HIGH findings resolved
- External audit: RFP ready, deferred pending funding

## Roadmap

### Completed
- Multi-chain mesh network (15 chains)
- MEV engine (5 strategies)
- OFA proxy with user rebates
- WebSocket gateway + CLI + TUI
- Settlement contracts (4 Solidity)
- TypeScript + Python SDKs
- Full observability stack
- Kubernetes deployment

### In Progress
- Cross-chain MEV (atomic bridge arb)
- Solver marketplace launch
- Mainnet deployment

### Planned
- External smart contract audit
- Token launch for governance
- Decentralized relay operator program
- L2 sequencer integration
