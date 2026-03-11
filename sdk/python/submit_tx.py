"""
YoorQuezt SDK Example — Python

Submit a protected transaction and query MEV opportunities.

Usage:
    python submit_tx.py

Prerequisites:
    pip install yoorquezt-sdk
"""

import os
import json
import requests

MEV_URL = os.getenv("MEV_URL", "http://localhost:9090")
MESH_URL = os.getenv("MESH_URL", "http://localhost:8080")
TOKEN = os.getenv("MEV_API_TOKEN", "demo-token")

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {TOKEN}",
}


def main():
    print("YoorQuezt SDK Example\n")

    # 1. Check health
    print("1. Checking platform health...")
    mesh_health = requests.get(f"{MESH_URL}/health").json()
    mev_health = requests.get(f"{MEV_URL}/health").json()
    print(f"   Mesh:  {json.dumps(mesh_health)}")
    print(f"   MEV:   {json.dumps(mev_health)}")

    # 2. Submit transaction to mesh
    print("\n2. Submitting transaction to mesh...")
    tx_result = requests.post(
        f"{MESH_URL}/sendTransaction",
        json={
            "id": "sdk-demo-tx-001",
            "chain": "ethereum",
            "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
            "to": "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
            "value": "1000000000000000000",
            "data": "0x38ed1739",
            "gas_price": "50000000000",
            "nonce": 1,
        },
    ).json()
    print(f"   Result: {json.dumps(tx_result, indent=2)}")

    # 3. Submit MEV bundle
    print("\n3. Submitting MEV bundle...")
    bundle_result = requests.post(
        f"{MEV_URL}/api/v1/bundle",
        headers=HEADERS,
        json={
            "txs": ["0xf86c0a85..."],
            "block_number": "latest",
            "chain": "ethereum",
            "min_profit": "0.01",
        },
    ).json()
    print(f"   Bundle: {json.dumps(bundle_result, indent=2)}")

    # 4. Protect transaction
    print("\n4. MEV protection...")
    protect_result = requests.post(
        f"{MEV_URL}/api/v1/protect",
        headers=HEADERS,
        json={
            "tx": "0xf86c0a85...",
            "chain": "ethereum",
            "max_slippage": 0.5,
        },
    ).json()
    print(f"   Protected: {json.dumps(protect_result, indent=2)}")

    # 5. Query peers
    print("\n5. Mesh network peers...")
    peers = requests.get(f"{MESH_URL}/peers").json()
    print(f"   Peers: {json.dumps(peers, indent=2)}")

    # 6. Query blocks
    print("\n6. Recent blocks...")
    blocks = requests.get(f"{MESH_URL}/blocks").json()
    if isinstance(blocks, list):
        print(f"   Built {len(blocks)} blocks")
    else:
        print(f"   Blocks: {json.dumps(blocks, indent=2)}")

    print("\nDone.")


if __name__ == "__main__":
    main()
