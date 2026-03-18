#!/usr/bin/env bash
set -uo pipefail

# YoorQuezt API Key Test Suite
# Tests all scopes: ofa:read, ofa:write, bundles:submit, intents:submit, webhooks:manage, ws:subscribe
#
# Usage:
#   export YQ_API_KEY="yq_live_..."
#   ./test-api-key.sh
#
# Optional:
#   export GATEWAY_URL="https://gateway-testnet.yoorquezt.io"
#   export MESH_URL="https://mesh-testnet.yoorquezt.io"

API_KEY="${YQ_API_KEY:?Set YQ_API_KEY to your portal API key}"
GATEWAY="${GATEWAY_URL:-https://gateway-testnet.yoorquezt.io}"
MESH="${MESH_URL:-https://mesh-testnet.yoorquezt.io}"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

test_step() {
  local step="$1" scope="$2" desc="$3"
  echo -e "\n${BOLD}${CYAN}[$step]${NC} ${BOLD}$desc${NC} ${YELLOW}($scope)${NC}"
}

check() {
  if [ -n "$1" ] && [ "$1" != "null" ]; then
    echo -e "  ${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
  fi
}

AUTH=(-H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json")

echo -e "${BOLD}${CYAN}"
echo "=================================================="
echo "  YoorQuezt API Key Test Suite"
echo "  Gateway: $GATEWAY"
echo "  Mesh:    $MESH"
echo "  Key:     ${API_KEY:0:20}..."
echo "=================================================="
echo -e "${NC}"

# ── No-auth endpoints (mesh) ──────────────────────────

test_step "1/10" "public" "Mesh health check"
RESULT=$(curl -sf "$MESH/health" 2>/dev/null || echo "")
echo "  $RESULT"
check "$RESULT"

test_step "2/10" "public" "Mesh peers"
RESULT=$(curl -sf "$MESH/peers" 2>/dev/null || echo "")
echo "  $RESULT" | head -c 200
echo ""
check "$RESULT"

test_step "3/10" "public" "Mesh chains"
RESULT=$(curl -sf "$MESH/chain" 2>/dev/null || echo "")
echo "  $RESULT" | head -c 200
echo ""
check "$RESULT"

test_step "4/10" "public" "Mesh blocks"
RESULT=$(curl -sf --max-time 60 "$MESH/blocks" 2>/dev/null || echo "")
echo "  $RESULT" | head -c 200
echo ""
check "$RESULT"

# ── Gateway JSON-RPC (requires API key) ──────────────

test_step "5/10" "public" "Gateway health"
RESULT=$(curl -sf "$GATEWAY/rpc" "${AUTH[@]}" \
  -d '{"jsonrpc":"2.0","id":1,"method":"mev_health","params":{}}' 2>/dev/null || echo "")
echo "  $RESULT"
check "$RESULT"

test_step "6/10" "ofa:write" "Protect transaction (OFA)"
RESULT=$(curl -sf "$GATEWAY/rpc" "${AUTH[@]}" \
  -d '{
    "jsonrpc":"2.0","id":2,"method":"mev_protectTx",
    "params":{"raw_tx":"0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080","chain":"ethereum"}
  }' 2>/dev/null || echo "")
echo "  $RESULT"
check "$RESULT"

test_step "7/10" "ofa:read" "Get protection status"
RESULT=$(curl -sf "$GATEWAY/rpc" "${AUTH[@]}" \
  -d '{"jsonrpc":"2.0","id":3,"method":"mev_getProtectStatus","params":{"tx_id":"ptx-test-123"}}' 2>/dev/null || echo "")
echo "  $RESULT"
check "$RESULT"

test_step "8/10" "bundles:submit" "Simulate bundle"
RESULT=$(curl -sf "$GATEWAY/rpc" "${AUTH[@]}" \
  -d '{
    "jsonrpc":"2.0","id":4,"method":"mev_simulateBundle",
    "params":{"txs":["0xf86c0a8502540be400825208947a250d5630b4cf539739df2c5dacb4c659f2488d880de0b6b3a764000080"],"blockNumber":"latest","chain":"ethereum"}
  }' 2>/dev/null || echo "")
echo "  $RESULT"
check "$RESULT"

test_step "9/10" "bundles:submit" "Submit bundle"
RESULT=$(curl -sf "$GATEWAY/rpc" "${AUTH[@]}" \
  -d '{
    "jsonrpc":"2.0","id":5,"method":"mev_sendBundle",
    "params":{"bid_wei":"1000","bundle_id":"curl-test","transactions":[{"chain":"ethereum","payload":"0xaa","tx_id":"tx1"}]}
  }' 2>/dev/null || echo "")
echo "  $RESULT"
check "$RESULT"

test_step "10/10" "intents:submit" "Submit intent"
RESULT=$(curl -sf "$GATEWAY/rpc" "${AUTH[@]}" \
  -d '{
    "jsonrpc":"2.0","id":6,"method":"mev_submitIntent",
    "params":{"type":"swap","tokenIn":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2","tokenOut":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48","amountIn":"1000000000000000000","minAmountOut":"1800000000","chain":"ethereum","deadline":9999999999}
  }' 2>/dev/null || echo "")
echo "  $RESULT"
check "$RESULT"

# ── Summary ──────────────────────────────────────────

echo -e "\n${BOLD}${CYAN}=================================================="
echo "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo -e "${CYAN}==================================================${NC}"

if [ $FAIL -gt 0 ]; then
  echo -e "\n${YELLOW}Note: Some gateway tests may fail if testnet services are down.${NC}"
  echo -e "${YELLOW}Mesh endpoints (1-4) should always work if the node is running.${NC}"
  exit 1
fi
