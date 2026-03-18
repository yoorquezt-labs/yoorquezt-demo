"""
YoorQuezt WebSocket Subscription Test (Python)

Tests ws:subscribe scope — connects to gateway and subscribes to live streams.

Usage:
    export YQ_API_KEY="yq_live_..."
    python test_websocket.py

Prerequisites:
    pip install websockets
"""

import os
import sys
import json
import asyncio
import ssl

try:
    import websockets
except ImportError:
    print("Install websockets: pip install websockets")
    sys.exit(1)

API_KEY = os.getenv("YQ_API_KEY")
if not API_KEY:
    print("Set YQ_API_KEY environment variable")
    sys.exit(1)

GATEWAY_WS = os.getenv("GATEWAY_WS", "wss://gateway-testnet.yoorquezt.io/ws")
TOPICS = ["auction", "mempool", "blocks", "protect", "intents"]


async def main():
    print("=" * 50)
    print("  YoorQuezt WebSocket Subscription Test")
    print(f"  Gateway: {GATEWAY_WS}")
    print(f"  Key:     {API_KEY[:20]}...")
    print("=" * 50)

    # Use default SSL context with certifi certs if available
    ssl_ctx = ssl.create_default_context()
    try:
        import certifi
        ssl_ctx.load_verify_locations(certifi.where())
    except ImportError:
        # Fall back to unverified if certifi not installed
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE

    extra_headers = {"Authorization": f"Bearer {API_KEY}"}

    async with websockets.connect(
        GATEWAY_WS, ssl=ssl_ctx, additional_headers=extra_headers
    ) as ws:
        print("\nConnected to gateway\n")

        # Subscribe to all topics
        for i, topic in enumerate(TOPICS):
            msg = json.dumps({
                "jsonrpc": "2.0",
                "id": 100 + i,
                "method": "mev_subscribe",
                "params": {"topic": topic},
            })
            await ws.send(msg)
            print(f"  Subscribed to: {topic}")

        print("\nListening for events (30s)...\n")

        received = 0
        try:
            async with asyncio.timeout(30):
                async for message in ws:
                    data = json.loads(message)
                    if data.get("method") == "mev_subscription":
                        topic = data.get("params", {}).get("topic", "unknown")
                        payload = json.dumps(data.get("params", {}).get("data", data.get("params")))[:200]
                        print(f"  [{topic}] {payload}")
                        received += 1
                    else:
                        print(f"  [response] {json.dumps(data)[:200]}")
        except asyncio.TimeoutError:
            pass

    print(f"\nDone. Received {received} events.")


if __name__ == "__main__":
    asyncio.run(main())
