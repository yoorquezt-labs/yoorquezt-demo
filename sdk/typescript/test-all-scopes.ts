/**
 * YoorQuezt API Key — Full Scope Test (TypeScript)
 *
 * Tests all scopes: ofa, bundles, intents
 *
 * Usage:
 *   export YQ_API_KEY="yq_live_..."
 *   npx tsc && node dist/test-all-scopes.js
 */

import * as http from "http";
import * as https from "https";

const API_KEY = process.env.YQ_API_KEY;
if (!API_KEY) {
  console.error("Set YQ_API_KEY environment variable");
  process.exit(1);
}

const GATEWAY = process.env.GATEWAY_URL || "https://gateway-testnet.yoorquezt.io";
const MESH = process.env.MESH_URL || "https://mesh-testnet.yoorquezt.io";

function httpRequest(url: string, options: http.RequestOptions = {}, body?: string): Promise<any> {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith("https") ? https : http;
    options.timeout = 10000;
    const req = mod.request(url, options, (res) => {
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
    if (body) req.write(body);
    req.end();
  });
}

async function rpc(method: string, params: Record<string, unknown> = {}) {
  const body = JSON.stringify({ jsonrpc: "2.0", id: Date.now(), method, params });
  return httpRequest(`${GATEWAY}/rpc`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
      Authorization: `Bearer ${API_KEY}`,
    },
  }, body);
}

async function meshGet(path: string) {
  return httpRequest(`${MESH}${path}`);
}

let pass = 0;
let fail = 0;

async function test(name: string, scope: string, fn: () => Promise<unknown>) {
  try {
    const result = await fn() as any;
    const str = JSON.stringify(result);
    // Detect error responses: JSON-RPC error, plain 404, or non-object
    const isError =
      (result && typeof result === "object" && result.error) ||
      (typeof result === "string" && result.includes("404"));
    if (isError) {
      console.log(`  FAIL  ${name} [${scope}]`);
      console.log(`        ${str.slice(0, 200)}`);
      fail++;
    } else {
      console.log(`  PASS  ${name} [${scope}]`);
      console.log(`        ${str.slice(0, 200)}`);
      pass++;
    }
  } catch (err) {
    console.log(`  FAIL  ${name} [${scope}]`);
    console.log(`        ${err}`);
    fail++;
  }
}

async function main() {
  console.log("==================================================");
  console.log("  YoorQuezt TypeScript API Key Test");
  console.log(`  Gateway: ${GATEWAY}`);
  console.log(`  Mesh:    ${MESH}`);
  console.log(`  Key:     ${API_KEY!.slice(0, 20)}...`);
  console.log("==================================================\n");

  // Public mesh endpoints (only work with a real mesh node)
  console.log("-- Mesh (public, no key) --");
  await test("Health", "public", () => meshGet("/health"));
  await test("Peers", "public", () => meshGet("/peers"));
  await test("Chains", "public", () => meshGet("/chain"));
  await test("Blocks", "public", () => meshGet("/blocks"));

  // Gateway RPC — OFA
  console.log("\n-- OFA (ofa:read, ofa:write) --");
  await test("Gateway health", "public", () => rpc("mev_health"));
  let protectTxId = "";
  await test("Protect transaction", "ofa:write", async () => {
    const res = await rpc("mev_protectTx", {
      raw_tx: "0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080",
      chain: "ethereum",
    });
    if (res?.result?.tx_id) protectTxId = res.result.tx_id;
    return res;
  });
  await test("Get protection status", "ofa:read", () =>
    rpc("mev_getProtectStatus", { tx_id: protectTxId || "ptx-test-123" })
  );

  // Gateway RPC — Bundles
  console.log("\n-- Bundles (bundles:submit) --");
  await test("Simulate bundle", "bundles:submit", () =>
    rpc("mev_simulateBundle", {
      txs: ["0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080"],
      blockNumber: "latest",
      chain: "ethereum",
    })
  );
  await test("Submit bundle", "bundles:submit", () =>
    rpc("mev_sendBundle", {
      bid_wei: "1000",
      bundle_id: "ts-test-bundle",
      transactions: [{ chain: "ethereum", payload: "0xaa", tx_id: "tx1" }],
    })
  );

  // Gateway RPC — Intents
  console.log("\n-- Intents (intents:submit) --");
  await test("Submit intent", "intents:submit", () =>
    rpc("mev_submitIntent", {
      type: "swap",
      tokenIn: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      tokenOut: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      amountIn: "1000000000000000000",
      minAmountOut: "1800000000",
      chain: "ethereum",
      deadline: 9999999999,
    })
  );
  await test("List solvers", "intents:submit", () => rpc("mev_listSolvers"));

  // Summary
  console.log("\n==================================================");
  console.log(`  Results: ${pass} passed, ${fail} failed`);
  console.log("==================================================");

  if (fail > 0) process.exit(1);
}

main().catch(console.error);
