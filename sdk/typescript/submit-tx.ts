/**
 * YoorQuezt SDK Example — TypeScript
 *
 * Submit a protected transaction and subscribe to auction results.
 *
 * Usage:
 *   npx ts-node submit-tx.ts
 *
 * Prerequisites:
 *   npm install @yoorquezt/sdk-mev
 */

import { YoorQueztClient } from "@yoorquezt/sdk-mev";

const GATEWAY_URL = process.env.GATEWAY_URL || "ws://localhost:9099";

async function main() {
  console.log("Connecting to YoorQuezt Gateway...");
  const client = new YoorQueztClient(GATEWAY_URL);
  await client.connect();
  console.log("Connected!\n");

  // 1. Submit a protected transaction
  console.log("1. Submitting protected transaction...");
  const protectResult = await client.call("mev_protectTransaction", {
    tx: "0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080",
    chain: "ethereum",
    maxSlippage: 0.5,
  });
  console.log("   Protected:", JSON.stringify(protectResult, null, 2));

  // 2. Submit a bundle
  console.log("\n2. Submitting MEV bundle...");
  const bundleResult = await client.call("mev_submitBundle", {
    txs: [
      "0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080",
    ],
    blockNumber: "latest",
    chain: "ethereum",
  });
  console.log("   Bundle:", JSON.stringify(bundleResult, null, 2));

  // 3. Subscribe to auction results
  console.log("\n3. Subscribing to auction results...");
  const sub = await client.subscribe("auction_results");
  sub.on("data", (result: unknown) => {
    console.log("   Auction result:", JSON.stringify(result, null, 2));
  });

  // 4. Check platform health
  console.log("\n4. Platform health...");
  const health = await client.call("mev_health", {});
  console.log("   Health:", JSON.stringify(health, null, 2));

  // Keep alive for 10 seconds to receive auction results
  console.log("\nListening for 10 seconds...");
  await new Promise((resolve) => setTimeout(resolve, 10000));

  await client.disconnect();
  console.log("Done.");
}

main().catch(console.error);
