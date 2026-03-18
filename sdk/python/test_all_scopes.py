"""
YoorQuezt API Key — Full Scope Test (Python)

Tests all scopes: ofa, bundles, intents

Usage:
    export YQ_API_KEY="yq_live_..."
    python test_all_scopes.py
"""

import os
import sys
import json
import requests

API_KEY = os.getenv("YQ_API_KEY")
if not API_KEY:
    print("Set YQ_API_KEY environment variable")
    sys.exit(1)

GATEWAY = os.getenv("GATEWAY_URL", "https://gateway-testnet.yoorquezt.io")
MESH = os.getenv("MESH_URL", "https://mesh-testnet.yoorquezt.io")

HEADERS = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}",
}

passed = 0
failed = 0


def rpc(method: str, params: dict = None):
    resp = requests.post(
        f"{GATEWAY}/rpc",
        headers=HEADERS,
        json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params or {}},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def mesh_get(path: str, timeout: int = 10):
    resp = requests.get(f"{MESH}{path}", timeout=timeout)
    resp.raise_for_status()
    try:
        return resp.json()
    except requests.exceptions.JSONDecodeError:
        return resp.text


def test(name: str, scope: str, fn):
    global passed, failed
    try:
        result = fn()
        print(f"  PASS  {name} [{scope}]")
        print(f"        {json.dumps(result)[:200]}")
        passed += 1
    except Exception as e:
        print(f"  FAIL  {name} [{scope}]")
        print(f"        {e}")
        failed += 1


def main():
    print("=" * 50)
    print("  YoorQuezt Python API Key Test")
    print(f"  Gateway: {GATEWAY}")
    print(f"  Mesh:    {MESH}")
    print(f"  Key:     {API_KEY[:20]}...")
    print("=" * 50)

    # Public mesh endpoints
    print("\n-- Mesh (public, no key) --")
    test("Health", "public", lambda: mesh_get("/health"))
    test("Peers", "public", lambda: mesh_get("/peers"))
    test("Chains", "public", lambda: mesh_get("/chain"))
    test("Blocks", "public", lambda: mesh_get("/blocks", timeout=30))

    # OFA
    print("\n-- OFA (ofa:read, ofa:write) --")
    test("Gateway health", "public", lambda: rpc("mev_health"))
    test(
        "Protect transaction",
        "ofa:write",
        lambda: rpc(
            "mev_protectTx",
            {
                "raw_tx": "0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080",
                "chain": "ethereum",
            },
        ),
    )
    test(
        "Get protection status",
        "ofa:read",
        lambda: rpc("mev_getProtectStatus", {"tx_id": "ptx-test-123"}),
    )

    # Bundles
    print("\n-- Bundles (bundles:submit) --")
    test(
        "Simulate bundle",
        "bundles:submit",
        lambda: rpc(
            "mev_simulateBundle",
            {
                "txs": ["0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080"],
                "blockNumber": "latest",
                "chain": "ethereum",
            },
        ),
    )
    test(
        "Submit bundle",
        "bundles:submit",
        lambda: rpc(
            "mev_sendBundle",
            {
                "bid_wei": "1000",
                "bundle_id": "py-test-bundle",
                "transactions": [{"chain": "ethereum", "payload": "0xaa", "tx_id": "tx1"}],
            },
        ),
    )

    # Intents
    print("\n-- Intents (intents:submit) --")
    test(
        "Submit intent",
        "intents:submit",
        lambda: rpc(
            "mev_submitIntent",
            {
                "type": "swap",
                "tokenIn": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
                "tokenOut": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                "amountIn": "1000000000000000000",
                "minAmountOut": "1800000000",
                "chain": "ethereum",
                "deadline": 9999999999,
            },
        ),
    )
    test("List solvers", "intents:submit", lambda: rpc("mev_listSolvers"))

    # Summary
    print("\n" + "=" * 50)
    print(f"  Results: {passed} passed, {failed} failed")
    print("=" * 50)

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
