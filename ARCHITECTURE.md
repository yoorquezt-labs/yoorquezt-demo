# YoorQuezt — Architecture

## System Overview

```mermaid
graph TB
    subgraph Chains["Blockchain Networks"]
        ETH["Ethereum Sepolia"]
        BASE["Base Sepolia"]
        ARB["Arbitrum Sepolia"]
        SOL["Solana Devnet"]
        FB["Flashbots Relay"]
    end

    subgraph Mesh["P2P Mesh Network (QUIC)"]
        BS["Bootstrap Server<br/>:9000"]
        N1["Node 1<br/>:4433/udp :8080"]
        N2["Node 2<br/>:4434/udp :8081"]
        N3["Node 3<br/>:4435/udp :8082"]
        N4["Node 4<br/>:4436/udp :8083"]
        N5["Node 5<br/>:4437/udp :8084"]
        N6["Node 6<br/>:4438/udp :8085"]
        N7["Node 7<br/>:4439/udp :8086"]

        BS --> N1 & N2 & N3 & N4 & N5 & N6 & N7
        N1 <-->|gossip| N2
        N2 <-->|gossip| N3
        N3 <-->|gossip| N4
        N4 <-->|gossip| N5
        N5 <-->|gossip| N6
        N6 <-->|gossip| N7
        N7 <-->|gossip| N1
    end

    subgraph MEV["MEV Auction Engine"]
        ENGINE["MEV Engine<br/>:9090"]
        OFA["OFA Proxy<br/>:9100"]
        GW["WebSocket Gateway<br/>:9099"]

        ENGINE --> OFA
        ENGINE --> GW
    end

    subgraph Infra["Infrastructure"]
        PG["PostgreSQL<br/>:5432"]
        RD["Redis<br/>:6379"]
    end

    subgraph Traffic["Traffic Generation"]
        TG["Traffic Generator<br/>:9190"]
        SL["Status Logger"]
    end

    subgraph Observability["Observability Stack"]
        PROM["Prometheus<br/>:9091"]
        GRAF["Grafana<br/>:3001"]
        TEMPO["Tempo<br/>:3200"]
        LOKI["Loki<br/>:3100"]
        PT["Promtail"]
    end

    %% Chain connections
    ENGINE -->|eth_callBundle| ETH
    ENGINE -->|eth_callBundle| BASE
    ENGINE -->|eth_callBundle| ARB
    ENGINE -->|getSlot| SOL
    ENGINE -->|mev_sendBundle| FB

    %% Mesh to MEV
    N1 -->|bundles/txs| ENGINE

    %% MEV to Infra
    ENGINE --> PG
    ENGINE --> RD

    %% Traffic
    TG -->|txs/bundles| N1 & N2 & N3 & N4 & N5 & N6 & N7
    TG -->|bundles/intents| ENGINE

    %% Observability
    N1 & N2 & N3 & N4 & N5 & N6 & N7 -.->|metrics| PROM
    ENGINE -.->|metrics| PROM
    PROM -.-> GRAF
    LOKI -.-> GRAF
    TEMPO -.-> GRAF
    PT -.->|logs| LOKI

    classDef chain fill:#f9a825,stroke:#f57f17,color:#000
    classDef mesh fill:#42a5f5,stroke:#1565c0,color:#fff
    classDef mev fill:#ab47bc,stroke:#6a1b9a,color:#fff
    classDef infra fill:#66bb6a,stroke:#2e7d32,color:#fff
    classDef obs fill:#78909c,stroke:#37474f,color:#fff
    classDef traffic fill:#ef5350,stroke:#c62828,color:#fff

    class ETH,BASE,ARB,SOL,FB chain
    class BS,N1,N2,N3,N4,N5,N6,N7 mesh
    class ENGINE,OFA,GW mev
    class PG,RD infra
    class PROM,GRAF,TEMPO,LOKI,PT obs
    class TG,SL traffic
```

## Data Flow

```mermaid
sequenceDiagram
    participant User as User / DApp
    participant OFA as OFA Proxy
    participant Engine as MEV Engine
    participant Mesh as P2P Mesh
    participant Chain as Blockchain

    Note over User,Chain: Transaction Protection Flow (OFA)
    User->>OFA: eth_sendRawTransaction
    OFA->>OFA: Detect swap intent
    OFA->>Engine: Submit protected tx
    Engine->>Engine: Find backrun opportunity
    Engine->>Engine: Build bundle (user tx + backrun)
    Engine->>Chain: Submit bundle via relay
    Chain-->>Engine: Bundle landed
    Engine-->>OFA: 80% MEV rebate to user
    OFA-->>User: Tx confirmed + rebate

    Note over User,Chain: MEV Auction Flow
    Mesh->>Engine: Gossip bundles from searchers
    Engine->>Engine: Sealed-bid auction (rank by fee)
    Engine->>Engine: Simulate via eth_callBundle
    Engine->>Engine: Build block (fee-priority order)
    Engine->>Chain: Submit to multi-relay marketplace
    Chain-->>Engine: Block included
```

## MEV Pipeline

```mermaid
flowchart LR
    subgraph Receive
        A[Mesh Gossip] --> D[Bundle Pool]
        B[OFA Proxy] --> D
        C[Intent Solver] --> D
    end

    subgraph Auction["Sealed-Bid Auction"]
        D --> E[Rank by Fee]
        E --> F[Simulate<br/>eth_callBundle]
        F --> G{Valid?}
        G -->|Yes| H[Block Builder]
        G -->|No| I[Reject]
    end

    subgraph Submit
        H --> J[Multi-Relay<br/>Marketplace]
        J --> K[Flashbots]
        J --> L[BloXroute]
        J --> M[Eden]
        J --> N[Ultra Sound]
    end

    subgraph Strategy
        O[Arb Detection] --> D
        P[Sandwich Guard] --> D
        Q[Liquidation] --> D
        R[Cross-Chain] --> D
    end

    style Receive fill:#e3f2fd
    style Auction fill:#f3e5f5
    style Submit fill:#e8f5e9
    style Strategy fill:#fff3e0
```

## Gossip Protocol

```mermaid
flowchart LR
    subgraph Node["Mesh Node"]
        RX[Receive] --> VERIFY[Verify Signature<br/>ECDSA P-256]
        VERIFY --> DECOMP[Decompress<br/>zstd]
        DECOMP --> DECRYPT[Decrypt<br/>AES-256-GCM]
        DECRYPT --> DEDUP[Dedup<br/>Bloom Filter]
        DEDUP --> MEMPOOL[Mempool]
        MEMPOOL --> BATCH[Batch]
        BATCH --> ENCRYPT[Encrypt]
        ENCRYPT --> COMP[Compress]
        COMP --> SIGN[Sign]
        SIGN --> TX[Gossip to Peers]
    end

    style Node fill:#e3f2fd
```

## Network Topology

```mermaid
graph LR
    subgraph Ports["Service Ports"]
        direction TB
        P1["Mesh Nodes: 4433-4439/udp + 8080-8086/http"]
        P2["MEV Engine: 9090"]
        P3["OFA Proxy: 9100"]
        P4["WS Gateway: 9099"]
        P5["Traffic Gen: 9190"]
        P6["PostgreSQL: 5432"]
        P7["Redis: 6379"]
        P8["Prometheus: 9091"]
        P9["Grafana: 3001"]
        P10["Tempo: 3200, 4318"]
        P11["Loki: 3100"]
    end
```

## Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| P2P Transport | QUIC + TLS 1.3 | Multiplexed, encrypted peer communication |
| Gossip | Custom batched protocol | Tx/bundle/block propagation |
| Compression | zstd | Reduce bandwidth |
| Encryption | AES-256-GCM | Message confidentiality |
| Signing | ECDSA P-256 | Message authenticity |
| Dedup | Bloom filter | Prevent re-gossip |
| Block Building | Bundle-first, fee-priority | MEV-optimized block construction |
| Simulation | eth_callBundle | Bundle validation |
| Database | PostgreSQL 16 | Relay reputation, auction history |
| Cache | Redis 7 | Hot state, rate limiting |
| Metrics | Prometheus | Time-series metrics |
| Dashboards | Grafana 10.4 | Visualization |
| Tracing | Tempo + OpenTelemetry | Distributed tracing |
| Logs | Loki + Promtail | Centralized log aggregation |
| Contracts | Solidity (Foundry) | Settlement, rebates, intents |
| Language | Go | All backend services |
