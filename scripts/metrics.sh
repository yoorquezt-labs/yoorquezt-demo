#!/usr/bin/env bash
set -euo pipefail

# YoorQuezt Platform Metrics Report
# Queries Prometheus + service APIs to produce investor-ready numbers.
#
# Usage:
#   ./scripts/metrics.sh                  # default: Prometheus on :9091, Mesh on :8080, MEV on :9090
#   PROM=http://host:9091 ./scripts/metrics.sh

PROM="${PROM:-http://localhost:9091}"
MESH="${MESH:-http://localhost:8080}"
MEV="${MEV:-http://localhost:9090}"
TOKEN="${MEV_API_TOKEN:-demo-token}"

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── helpers ───────────────────────────────────────────────
prom_val() {
  local query="$1"
  curl -sf "$PROM/api/v1/query" --data-urlencode "query=$query" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data',{}).get('result',[])
if results:
    for r in results:
        job = r.get('metric',{}).get('job','')
        val = r['value'][1]
        if job: print(f'{job}={val}')
        else:   print(val)
else:
    print('N/A')
" 2>/dev/null || echo "N/A"
}

prom_single() {
  local query="$1"
  curl -sf "$PROM/api/v1/query" --data-urlencode "query=$query" 2>/dev/null \
    | python3 -c "
import sys, json, math
data = json.load(sys.stdin)
results = data.get('data',{}).get('result',[])
if results:
    v = float(results[0]['value'][1])
    if math.isnan(v): print('N/A')
    else: print(f'{v}')
else: print('N/A')
" 2>/dev/null || echo "N/A"
}

section() {
  echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"
}

row() {
  printf "  %-32s %s\n" "$1" "$2"
}

# ── header ────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║        YoorQuezt Platform — Metrics Report          ║"
echo "║        $(date '+%Y-%m-%d %H:%M:%S %Z')              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Service Health ─────────────────────────────────────
section "Service Health"
for svc in mesh mev-engine ofa-proxy gateway; do
  case "$svc" in
    mesh)       url="$MESH/health" ;;
    mev-engine) url="$MEV/health" ;;
    ofa-proxy)  url="http://localhost:9100/health" ;;
    gateway)    url="http://localhost:9099/health" ;;
  esac
  if curl -sf --max-time 2 "$url" >/dev/null 2>&1; then
    row "$svc" "$(echo -e "${GREEN}UP${NC}")"
  else
    row "$svc" "$(echo -e "${RED}DOWN${NC}")"
  fi
done

# ── 2. Mesh Network ──────────────────────────────────────
section "Mesh Network"

peers=$(prom_val "mesh_peers_connected")
row "Connected Peers" "$peers"

mempool=$(prom_val "mesh_mempool_size")
row "Mempool Size" "$mempool"

block_height=$(prom_val "mesh_block_height")
row "Block Height" "$block_height"

uptime_raw=$(prom_single "max(mesh_uptime_seconds)")
if [ "$uptime_raw" != "N/A" ]; then
  uptime_min=$(python3 -c "print(f'{float(\"$uptime_raw\")/60:.1f} min')")
  row "Uptime" "$uptime_min"
else
  row "Uptime" "N/A"
fi

# ── 3. MEV Engine ─────────────────────────────────────────
section "MEV Engine"

auction_ticks=$(prom_single "sum(mev_auction_ticks_total)")
row "Auction Ticks" "$auction_ticks"

bundles_processed=$(prom_single "sum(mev_bundles_processed_total)")
row "Bundles Processed" "$bundles_processed"

bundles_ranked=$(prom_single "sum(mev_bundles_ranked_total)")
row "Bundles Ranked" "$bundles_ranked"

bundles_submitted=$(prom_single "sum(mev_bundles_submitted_total)")
row "Bundles Submitted" "$bundles_submitted"

blocks_built=$(prom_single "sum(mev_blocks_built_total)")
row "Blocks Built" "$blocks_built"

# ── 4. Latency ────────────────────────────────────────────
section "Latency"

# Compute from raw histogram sum/count for accuracy
tick_sum=$(prom_single "sum(mev_auction_tick_duration_seconds_sum)")
tick_count=$(prom_single "sum(mev_auction_tick_duration_seconds_count)")
if [ "$tick_sum" != "N/A" ] && [ "$tick_count" != "N/A" ] && [ "$tick_count" != "0" ]; then
  tick_avg=$(python3 -c "
s=float('$tick_sum'); c=float('$tick_count')
if c > 0: print(f'{(s/c)*1000:.2f} ms')
else: print('N/A')
")
  row "Auction Tick (avg)" "$tick_avg"
else
  row "Auction Tick (avg)" "N/A"
fi

rank_sum=$(prom_single "sum(mev_engine_tick_rank_duration_seconds_sum)")
rank_count=$(prom_single "sum(mev_engine_tick_rank_duration_seconds_count)")
if [ "$rank_sum" != "N/A" ] && [ "$rank_count" != "N/A" ] && [ "$rank_count" != "0" ]; then
  rank_avg=$(python3 -c "
s=float('$rank_sum'); c=float('$rank_count')
if c > 0: print(f'{(s/c)*1000:.2f} ms')
else: print('N/A')
")
  row "Rank Duration (avg)" "$rank_avg"
else
  row "Rank Duration (avg)" "N/A"
fi

sim_sum=$(prom_single "sum(mev_engine_tick_sim_duration_seconds_sum)")
sim_count=$(prom_single "sum(mev_engine_tick_sim_duration_seconds_count)")
if [ "$sim_sum" != "N/A" ] && [ "$sim_count" != "N/A" ] && [ "$sim_count" != "0" ]; then
  sim_avg=$(python3 -c "
s=float('$sim_sum'); c=float('$sim_count')
if c > 0: print(f'{(s/c)*1000:.3f} ms')
else: print('N/A')
")
  row "Sim Duration (avg)" "$sim_avg"
else
  row "Sim Duration (avg)" "N/A"
fi

# ── 5. Throughput ─────────────────────────────────────────
section "Throughput (1m rate)"

bundle_rate=$(prom_single "sum(rate(mev_bundles_processed_total[1m]))")
if [ "$bundle_rate" != "N/A" ]; then
  bundle_rate_fmt=$(python3 -c "print(f'{float(\"$bundle_rate\"):.1f}/s')")
  row "Bundle Processing" "$bundle_rate_fmt"
else
  row "Bundle Processing" "N/A"
fi

tx_rate=$(prom_single "sum(rate(mev_bundles_submitted_total[1m]))")
if [ "$tx_rate" != "N/A" ]; then
  tx_rate_fmt=$(python3 -c "print(f'{float(\"$tx_rate\"):.1f}/s')")
  row "Bundle Submission" "$tx_rate_fmt"
else
  row "Bundle Submission" "N/A"
fi

# ── 6. Revenue & Risk ────────────────────────────────────
section "Revenue & Risk"

profit=$(prom_single "mev_block_total_profit_wei")
if [ "$profit" != "N/A" ]; then
  profit_eth=$(python3 -c "print(f'{float(\"$profit\")/1e18:.6f} ETH')")
  row "Block Profit" "$profit_eth"
else
  row "Block Profit" "N/A"
fi

mev_extracted=$(prom_single "mev_protect_mev_extracted_total_wei")
if [ "$mev_extracted" != "N/A" ]; then
  extracted_eth=$(python3 -c "print(f'{float(\"$mev_extracted\")/1e18:.6f} ETH')")
  row "MEV Extracted" "$extracted_eth"
else
  row "MEV Extracted" "N/A"
fi

rebates=$(prom_single "mev_protect_tx_rebates_total_wei")
if [ "$rebates" != "N/A" ]; then
  rebates_eth=$(python3 -c "print(f'{float(\"$rebates\")/1e18:.6f} ETH')")
  row "User Rebates" "$rebates_eth"
else
  row "User Rebates" "N/A"
fi

risk_halted=$(prom_single "mev_risk_halted")
if [ "$risk_halted" = "0" ] || [ "$risk_halted" = "0.0" ]; then
  row "Risk Status" "$(echo -e "${GREEN}OK${NC}")"
elif [ "$risk_halted" = "N/A" ]; then
  row "Risk Status" "N/A"
else
  row "Risk Status" "$(echo -e "${RED}HALTED${NC}")"
fi

blocked=$(prom_single "mev_blocked_actors_gauge")
row "Blocked Actors" "${blocked:-0}"

# ── 7. Strategy Counters ─────────────────────────────────
section "Strategy Counters"

arb_opps=$(prom_single "mev_arb_opportunities_found_total")
row "Arb Opportunities" "${arb_opps}"

arb_submitted=$(prom_single "mev_arb_bundles_submitted_total")
row "Arb Bundles Submitted" "${arb_submitted}"

crosschain=$(prom_single "mev_crosschain_opportunities_total")
row "Cross-chain Opps" "${crosschain}"

# ── 8. Traffic Generator ─────────────────────────────────
section "Traffic Generator"
TRAFFICGEN_STATUS=$(curl -sf --max-time 2 http://localhost:9190/status 2>/dev/null || echo "")
if [ -n "$TRAFFICGEN_STATUS" ]; then
  echo "$TRAFFICGEN_STATUS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for k, v in data.items():
        print(f'  {k:32s} {v}')
except: print('  (raw) ' + sys.stdin.read())
" 2>/dev/null
else
  # Fallback: read from docker logs
  latest=$(docker logs trafficgen 2>&1 | grep "STATS" | tail -1)
  if [ -n "$latest" ]; then
    row "Latest" "$latest"
  else
    row "Status" "not running or not reachable"
  fi
fi

# ── footer ────────────────────────────────────────────────
echo -e "\n${BOLD}${CYAN}━━━ Endpoints ━━━${NC}"
row "Grafana" "http://localhost:3001  (admin/yoorquezt)"
row "Prometheus" "http://localhost:9091"
row "Mesh API" "http://localhost:8080"
row "MEV Engine" "http://localhost:9090"
row "OFA Proxy" "http://localhost:9100"
row "Gateway (WS)" "ws://localhost:9099"
echo ""
