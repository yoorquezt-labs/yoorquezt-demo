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

    async with websockets.connect(GATEWAY_WS) as ws:
        print("\nConnected to gateway\n")

        # Subscribe to all topics
        for topic in TOPICS:
            msg = json.dumps({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "yq_subscribe",
                "params": {"topic": topic},
            })
            await ws.send(msg)
            print(f"  Subscribed to: {topic}")

        print("\nListening for events (30s)...\n")

        try:
            async with asyncio.timeout(30):
                async for message in ws:
                    data = json.loads(message)
                    if data.get("method") == "mev_subscription":
                        topic = data.get("params", {}).get("topic", "unknown")
                        payload = json.dumps(data.get("params", {}).get("data", data.get("params")))[:200]
                        print(f"  [{topic}] {payload}")
                    else:
                        print(f"  [response] {json.dumps(data)[:200]}")
        except asyncio.TimeoutError:
            pass

    print("\nDone.")


if __name__ == "__main__":
    asyncio.run(main())
