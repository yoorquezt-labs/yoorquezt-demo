/**
 * YoorQuezt WebSocket Subscription Test
 *
 * Tests ws:subscribe scope — connects to gateway and subscribes to live streams.
 *
 * Usage:
 *   export YQ_API_KEY="yq_live_..."
 *   npx tsc && node dist/test-websocket.js
 */

import WebSocket from "ws";

const API_KEY = process.env.YQ_API_KEY;
if (!API_KEY) {
  console.error("Set YQ_API_KEY environment variable");
  process.exit(1);
}

const GATEWAY_WS = process.env.GATEWAY_WS || "wss://gateway-testnet.yoorquezt.io/ws";

const topics = ["auction", "mempool", "blocks", "protect", "intents"];

async function main() {
  console.log("==================================================");
  console.log("  YoorQuezt WebSocket Subscription Test");
  console.log(`  Gateway: ${GATEWAY_WS}`);
  console.log(`  Key:     ${API_KEY!.slice(0, 20)}...`);
  console.log("==================================================\n");

  const ws = new WebSocket(GATEWAY_WS);

  ws.on("open", () => {
    console.log("Connected to gateway\n");

    // Subscribe to all topics
    for (const topic of topics) {
      const msg = JSON.stringify({
        jsonrpc: "2.0",
        id: Date.now(),
        method: "mev_subscribe",
        params: { topic },
      });
      ws.send(msg);
      console.log(`  Subscribed to: ${topic}`);
    }

    console.log("\nListening for events (30s)...\n");
  });

  ws.on("message", (data) => {
    const msg = JSON.parse(data.toString());
    if (msg.method === "mev_subscription") {
      const topic = msg.params?.topic || "unknown";
      console.log(`  [${topic}] ${JSON.stringify(msg.params?.data || msg.params).slice(0, 200)}`);
    } else {
      console.log(`  [response] ${JSON.stringify(msg).slice(0, 200)}`);
    }
  });

  ws.on("error", (err) => {
    console.error(`  WebSocket error: ${err.message}`);
  });

  ws.on("close", (code, reason) => {
    console.log(`\nConnection closed (${code}): ${reason}`);
  });

  // Listen for 30 seconds
  await new Promise((resolve) => setTimeout(resolve, 30000));
  ws.close();
  console.log("\nDone.");
}

main().catch(console.error);
