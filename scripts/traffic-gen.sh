#!/bin/sh
# YoorQuezt Traffic Generator
# Uses wget (available in Alpine) — no curl dependency
#
# Environment:
#   MESH_NODES   — comma-separated mesh node URLs
#   MEV_ENGINE   — MEV engine URL
#   MEV_API_TOKEN — auth token
#   TX_RATE      — transactions per cycle (default 10)
#   BUNDLE_RATE  — bundles per cycle (default 3)

set -e

TX_RATE=${TX_RATE:-10}
BUNDLE_RATE=${BUNDLE_RATE:-3}
TOKEN=${MEV_API_TOKEN:-demo-token}
ENGINE=${MEV_ENGINE:-http://mev-engine:9090}

# Parse mesh nodes
IFS=',' read -r NODE1 NODE2 NODE3 <<EOF
${MESH_NODES:-http://mesh-node-1:8080,http://mesh-node-2:8080,http://mesh-node-3:8080}
EOF

NODES="$NODE1 $NODE2 $NODE3"
CHAINS="ethereum base arbitrum optimism"
CYCLE=0

log() {
  echo "[traffic-gen] $(date +%H:%M:%S) $*"
}

rand_hex() {
  head -c "$1" /dev/urandom | od -A n -t x1 | tr -d ' \n'
}

rand_addr() {
  echo "0x$(rand_hex 20)"
}

rand_int() {
  awk -v min="$1" -v max="$2" 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'
}

# POST helper using wget (Alpine doesn't have curl)
post() {
  local url="$1"
  local data="$2"
  local auth="$3"
  if [ -n "$auth" ]; then
    wget -q -O /dev/null --timeout=5 \
      --header="Content-Type: application/json" \
      --header="Authorization: Bearer $auth" \
      --post-data="$data" \
      "$url" 2>/dev/null || true
  else
    wget -q -O /dev/null --timeout=5 \
      --header="Content-Type: application/json" \
      --post-data="$data" \
      "$url" 2>/dev/null || true
  fi
}

wait_for_services() {
  log "Waiting for services..."
  for i in $(seq 1 60); do
    if wget -q --spider "$ENGINE/health" 2>/dev/null; then
      log "MEV engine ready"
      break
    fi
    sleep 2
  done
  for node in $NODES; do
    for i in $(seq 1 30); do
      if wget -q --spider "$node/health" 2>/dev/null; then
        log "Node $node ready"
        break
      fi
      sleep 2
    done
  done
  sleep 5
  log "All services ready — starting traffic generation"
}

# ── Send transactions to mesh nodes ──────────────
send_transactions() {
  local count=$1
  for node in $NODES; do
    local per_node=$(( count / 3 + 1 ))
    for i in $(seq 1 "$per_node"); do
      chain=$(echo $CHAINS | tr ' ' '\n' | awk -v n="$(rand_int 1 4)" 'NR==n')
      fee=$(rand_int 1 200)
      post "$node/sendTransaction" \
        "{\"chain\":\"$chain\",\"raw_tx\":\"0x$(rand_hex 64)\",\"priority_fee\":\"$fee\",\"from\":\"$(rand_addr)\",\"to\":\"$(rand_addr)\",\"value\":\"$(rand_int 1000 1000000)\"}" &
    done
  done
  wait
}

# ── Send bundles to MEV engine ───────────────────
send_bundles() {
  local count=$1
  for i in $(seq 1 "$count"); do
    local num_txs=$(rand_int 2 5)
    local txs=""
    for t in $(seq 1 "$num_txs"); do
      [ -n "$txs" ] && txs="$txs,"
      txs="$txs{\"tx_id\":\"tx-$(rand_hex 8)\",\"chain\":\"ethereum\",\"payload\":\"0x$(rand_hex 64)\"}"
    done
    post "$ENGINE/searcher/bundle" \
      "{\"transactions\":[$txs],\"bid_wei\":\"$(rand_int 1000000 50000000)\"}" \
      "$TOKEN" &
  done
  wait
}

# ── Send protected transactions ──────────────────
send_protected_txs() {
  local count=$1
  for i in $(seq 1 "$count"); do
    post "$ENGINE/protect/tx" \
      "{\"tx\":\"0x$(rand_hex 64)\",\"chain\":\"ethereum\",\"max_slippage_bps\":$(rand_int 10 100),\"from\":\"$(rand_addr)\"}" \
      "$TOKEN" &
  done
  wait
}

# ── Submit intents ───────────────────────────────
send_intents() {
  local count=$1
  local intent_types="swap limit_order bridge"
  for i in $(seq 1 "$count"); do
    itype=$(echo $intent_types | tr ' ' '\n' | awk -v n="$(rand_int 1 3)" 'NR==n')
    post "$ENGINE/intent" \
      "{\"type\":\"$itype\",\"chain\":\"ethereum\",\"token_in\":\"$(rand_addr)\",\"token_out\":\"$(rand_addr)\",\"amount_in\":\"$(rand_int 100000 10000000)\",\"min_amount_out\":\"$(rand_int 50000 5000000)\",\"deadline\":$(($(date +%s) + 300)),\"sender\":\"$(rand_addr)\"}" \
      "$TOKEN" &
  done
  wait
}

# ── Simulate bundles ─────────────────────────────
send_simulations() {
  local count=$1
  for i in $(seq 1 "$count"); do
    post "$ENGINE/simulateBundle" \
      "{\"transactions\":[{\"tx_id\":\"sim-$(rand_hex 4)\",\"chain\":\"ethereum\",\"payload\":\"0x$(rand_hex 64)\"},{\"tx_id\":\"sim-$(rand_hex 4)\",\"chain\":\"ethereum\",\"payload\":\"0x$(rand_hex 64)\"}],\"bid_wei\":\"$(rand_int 100000 5000000)\"}" \
      "$TOKEN" &
  done
  wait
}

# ── Main loop ────────────────────────────────────
wait_for_services

log "Traffic config: TX_RATE=$TX_RATE BUNDLE_RATE=$BUNDLE_RATE"

while true; do
  CYCLE=$((CYCLE + 1))

  # Every cycle: transactions + bundles
  send_transactions "$TX_RATE"
  send_bundles "$BUNDLE_RATE"

  # Every 2nd cycle: protected txs
  if [ $((CYCLE % 2)) -eq 0 ]; then
    send_protected_txs 3
  fi

  # Every 3rd cycle: intents
  if [ $((CYCLE % 3)) -eq 0 ]; then
    send_intents 3
  fi

  # Every 5th cycle: simulations
  if [ $((CYCLE % 5)) -eq 0 ]; then
    send_simulations 2
  fi

  # Log stats every 10 cycles
  if [ $((CYCLE % 10)) -eq 0 ]; then
    total_txs=$((CYCLE * TX_RATE))
    total_bundles=$((CYCLE * BUNDLE_RATE))
    log "Cycle $CYCLE | ~${total_txs} txs, ~${total_bundles} bundles sent"

    for node in $NODES; do
      if ! wget -q --spider "$node/health" 2>/dev/null; then
        log "WARNING: $node unhealthy"
      fi
    done
  fi

  # Pace: ~3 seconds per cycle (faster for demo)
  sleep 3
done
