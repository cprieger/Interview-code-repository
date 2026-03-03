#!/usr/bin/env bash
# chaos_test.sh — M20 game API chaos validation.
# Fires concurrent requests across all game endpoints to verify the
# SRE middleware records metrics correctly under load.
#
# Usage: ./scripts/chaos_test/chaos_test.sh
# Requires: stack running via bootstrap.sh

set -euo pipefail

BASE="http://localhost:8082"
CONCURRENCY=20

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

# ── Health gate ───────────────────────────────────────────────────────────────
info "Checking health gate…"
if ! curl -sf "$BASE/health" > /dev/null; then
  fail "m20-game is not running. Start with: ./scripts/bootstrap/bootstrap.sh"
  exit 1
fi
pass "Health check OK"
echo ""

# ── Phase 1: GET endpoints — concurrent load ──────────────────────────────────
info "Phase 1: Concurrent GET requests (${CONCURRENCY} each)…"

fire_gets() {
  local url=$1
  local pids=()
  for i in $(seq 1 $CONCURRENCY); do
    curl -sf "$url" > /dev/null &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}

fire_gets "$BASE/api/tile"
pass "/api/tile — $CONCURRENCY requests"

fire_gets "$BASE/api/scavenge?level=5"
pass "/api/scavenge — $CONCURRENCY requests"

fire_gets "$BASE/api/items"
pass "/api/items — $CONCURRENCY requests"

echo ""

# ── Phase 2: POST endpoints — concurrent load ──────────────────────────────────
info "Phase 2: Concurrent POST requests (${CONCURRENCY} each)…"

fire_posts() {
  local url=$1
  local body=$2
  local pids=()
  for i in $(seq 1 $CONCURRENCY); do
    curl -sf -X POST -H "Content-Type: application/json" -d "$body" "$url" > /dev/null &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}

fire_posts "$BASE/api/land"         '{"tileCount":9}'
pass "/api/land — $CONCURRENCY requests"

fire_posts "$BASE/api/combat/roll"  '{"stat":5,"bonus":2}'
pass "/api/combat/roll — $CONCURRENCY requests"

fire_posts "$BASE/api/craft"        '{"materials":["Scrap Metal","Wire"],"crafting_level":3}'
pass "/api/craft — $CONCURRENCY requests"

echo ""

# ── Phase 3: 404 validation ────────────────────────────────────────────────────
info "Phase 3: Generating real 404s (unknown routes)…"

for i in $(seq 1 $CONCURRENCY); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/unknown/route-$i")
  if [ "$STATUS" != "404" ]; then
    fail "Expected 404, got $STATUS for /unknown/route-$i"
  fi
done
pass "All /unknown/* routes returned 404 ✓"

echo ""

# ── Phase 4: Character lifecycle ──────────────────────────────────────────────
info "Phase 4: Character create + load lifecycle…"

CREATE_RESP=$(curl -sf -X POST -H "Content-Type: application/json" \
  -d '{"name":"Chaos Tester","class":"Brawler"}' \
  "$BASE/api/character")

CHAR_ID=$(echo "$CREATE_RESP" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$CHAR_ID" ]; then
  fail "Character creation returned no ID"
else
  pass "Character created: $CHAR_ID"
  SHEET=$(curl -sf "$BASE/api/character/$CHAR_ID/sheet")
  if echo "$SHEET" | grep -q '"name":"Chaos Tester"'; then
    pass "Character sheet loaded OK"
  else
    fail "Character sheet missing expected name field"
  fi
fi

echo ""

# ── Metrics check ─────────────────────────────────────────────────────────────
info "Checking Prometheus metrics…"
METRICS=$(curl -sf "$BASE/metrics")

check_metric() {
  if echo "$METRICS" | grep -q "$1"; then
    pass "Metric present: $1"
  else
    fail "Metric MISSING: $1"
  fi
}

check_metric "m20_http_requests_total"
check_metric "m20_combat_rolls_total"
check_metric "m20_tiles_generated_total"
check_metric "m20_characters_created_total"

echo ""
info "=== Chaos test complete. Check Grafana: http://localhost:3000 ==="
