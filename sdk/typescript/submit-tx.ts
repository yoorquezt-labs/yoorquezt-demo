/**
 * YoorQuezt SDK Example — TypeScript
 *
 * Submit a protected transaction and subscribe to auction results.
 *
 * Usage:
 *   npx tsc && node dist/submit-tx.js
 *
 * Requires local gateway running on ws://localhost:9099
 */

import * as http from "http";
import * as https from "https";
import WebSocket from "ws";

const GATEWAY_URL = process.env.GATEWAY_URL || "https://gateway-testnet.yoorquezt.io";
const GATEWAY_WS = process.env.GATEWAY_WS || "wss://gateway-testnet.yoorquezt.io/ws";

function rpc(method: string, params: Record<string, unknown> = {}): Promise<any> {
  return new Promise((resolve, reject) => {
    const url = `${GATEWAY_URL}/rpc`;
    const mod = url.startsWith("https") ? https : http;
    const body = JSON.stringify({ jsonrpc: "2.0", id: Date.now(), method, params });
    const req = mod.request(url, {
      method: "POST",
      timeout: 10000,
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    }, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          resolve(data);
        }
      });
    });
    req.on("timeout", () => { req.destroy(); reject(new Error("request timeout (10s)")); });
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  console.log("Connecting to YoorQuezt Gateway...");
  console.log(`  HTTP: ${GATEWAY_URL}/rpc`);
  console.log(`  WS:   ${GATEWAY_WS}\n`);

  // 1. Submit a protected transaction
  console.log("1. Submitting protected transaction...");
  const protectResult = await rpc("mev_protectTx", {
    raw_tx: "0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080",
    chain: "ethereum",
  });
  console.log("   Protected:", JSON.stringify(protectResult, null, 2));

  // 2. Submit a bundle
  console.log("\n2. Submitting MEV bundle...");
  const bundleResult = await rpc("mev_sendBundle", {
    bid_wei: "1000",
    bundle_id: "demo-bundle",
    transactions: [
      { chain: "ethereum", payload: "0xf86c0a850254...", tx_id: "tx1" },
    ],
  });
  console.log("   Bundle:", JSON.stringify(bundleResult, null, 2));

  // 3. Subscribe to auction results via WebSocket
  console.log("\n3. Subscribing to auction results...");
  const ws = new WebSocket(GATEWAY_WS);

  ws.on("open", () => {
    ws.send(JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "mev_subscribe",
      params: { topic: "auction" },
    }));
  });

  ws.on("message", (data) => {
    const msg = JSON.parse(data.toString());
    if (msg.method === "mev_subscription") {
      console.log("   Auction result:", JSON.stringify(msg.params, null, 2));
    } else {
      console.log("   Response:", JSON.stringify(msg));
    }
  });

  // 4. Check platform health
  console.log("\n4. Platform health...");
  const health = await rpc("mev_health");
  console.log("   Health:", JSON.stringify(health, null, 2));

  // Keep alive for 10 seconds to receive auction results
  console.log("\nListening for 10 seconds...");
  await new Promise((resolve) => setTimeout(resolve, 10000));

  ws.close();
  console.log("Done.");
}

main().catch(console.error);
