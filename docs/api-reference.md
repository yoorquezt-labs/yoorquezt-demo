# YoorQuezt API Reference

## Mesh Network API (Port 8080)

### Public Endpoints

#### GET /health
Health check.
```json
{"status": "ok", "uptime": "2h15m", "peers": 3, "chain": "ethereum"}
```

#### GET /peers
List connected peers.
```json
{
  "peers": [
    {"id": "node-2", "addr": "10.0.0.2:4433", "score": 95.5, "latency_ms": 12}
  ]
}
```

#### GET /blocks
List recent blocks.
```json
[
  {"block_id": "abc123...", "tx_count": 15, "timestamp": 1710000000}
]
```

#### GET /block/{id}
Get block by ID.

#### POST /sendTransaction
Submit a transaction to the mesh.
```json
{
  "id": "tx-001",
  "chain": "ethereum",
  "from": "0x...",
  "to": "0x...",
  "value": "1000000000000000000",
  "data": "0x...",
  "gas_price": "50000000000",
  "nonce": 42
}
```

#### POST /sendBundle
Submit a bundle of transactions.

### Authenticated Endpoints (Bearer Token)

#### GET /status
Node status and configuration.

#### GET /metrics
Prometheus metrics.

#### GET /mempool
Pending transaction pool.

---

## MEV Engine API (Port 9090)

### POST /api/v1/bundle
Submit an MEV bundle.
```json
{
  "txs": ["0x..."],
  "block_number": "latest",
  "chain": "ethereum",
  "strategy": "arbitrage",
  "min_profit": "0.01"
}
```

### POST /api/v1/simulate
Simulate a bundle without submitting.
```json
{
  "txs": ["0x..."],
  "block_number": "latest",
  "state_block": "latest"
}
```

### POST /api/v1/protect
Submit a MEV-protected transaction.
```json
{
  "tx": "0x...",
  "chain": "ethereum",
  "max_slippage": 0.5
}
```

### POST /api/v1/intent
Submit an intent for competitive solving.
```json
{
  "type": "swap",
  "chain": "ethereum",
  "token_in": "0x...",
  "token_out": "0x...",
  "amount_in": "1000000000000000000",
  "max_slippage": 0.3,
  "deadline": 300
}
```

### GET /api/v1/auction/results
Query sealed-bid auction results.

### GET /api/v1/relay/list
List active relay connections.

### GET /api/v1/ofa/stats
Order Flow Auction statistics.

---

## WebSocket Gateway (Port 9099)

JSON-RPC 2.0 over WebSocket.

### Methods (27 total)

| Method | Description |
|--------|-------------|
| `mev_submitBundle` | Submit MEV bundle |
| `mev_simulateBundle` | Simulate bundle |
| `mev_protectTransaction` | MEV-protected submission |
| `mev_submitIntent` | Submit intent |
| `mev_getAuctionResults` | Query auctions |
| `mev_health` | Platform health |
| `mev_getRelays` | List relays |
| `mev_getOFAStats` | OFA statistics |
| ... | See full spec in OpenAPI |

### Subscriptions (5 topics)

| Topic | Description |
|-------|-------------|
| `auction_results` | Live auction outcomes |
| `bundle_status` | Bundle lifecycle updates |
| `mev_opportunities` | Detected MEV opportunities |
| `mesh_blocks` | New blocks built |
| `mesh_peers` | Peer connection changes |

### Example

```json
// Subscribe
{"jsonrpc":"2.0","method":"subscribe","params":["auction_results"],"id":1}

// Notification
{"jsonrpc":"2.0","method":"subscription","params":{"topic":"auction_results","data":{...}}}
```

---

## OFA Proxy (Port 9100)

Drop-in Ethereum RPC proxy. Replace your RPC URL with the OFA endpoint.

### Intercepted Methods

| Method | Behavior |
|--------|----------|
| `eth_sendRawTransaction` | Intercept, detect MEV, backrun, rebate 80% |
| All others | Pass through to upstream RPC |

### GET /healthz
Health check.

### GET /metrics
Prometheus metrics (protected transactions, rebates, latency).
