#!/usr/bin/env bash
# bootstrap.sh — Build and start the full m20-game stack.
# Usage: ./scripts/bootstrap/bootstrap.sh
#
# Services started:
#   m20-game   :8082   Game server + REST API + static UI
#   ollama     :11434  Local LLM (Sphinx riddles, monster dialogue)
#   prometheus :9090   Metrics scrape
#   grafana    :3000   Dashboards (anonymous admin — no login)
#
# Note: First run pulls the llama3.2:1b model (~800MB). Subsequent runs are fast.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[m20]${NC} $*"; }
warn()    { echo -e "${YELLOW}[m20]${NC} $*"; }
error()   { echo -e "${RED}[m20]${NC} $*" >&2; exit 1; }

cd "$APP_DIR"

info "=== M20 Game — Bootstrap ==="

# ── 1. Build ──────────────────────────────────────────────────────────────────
info "Building Docker image…"
docker compose build --no-cache

# ── 2. Start services ─────────────────────────────────────────────────────────
info "Starting services…"
docker compose up -d

# ── 3. Health check — m20-game ────────────────────────────────────────────────
info "Waiting for m20-game to be healthy…"
for i in $(seq 1 20); do
  if curl -sf http://localhost:8082/health > /dev/null 2>&1; then
    info "m20-game is up ✓"
    break
  fi
  if [ "$i" -eq 20 ]; then
    error "m20-game did not become healthy after 20 attempts."
  fi
  sleep 2
done

# ── 4. Pull Ollama model (first run only) ─────────────────────────────────────
info "Checking Ollama model (llama3.2:1b)…"
if docker exec m20-ollama ollama list 2>/dev/null | grep -q "llama3.2:1b"; then
  info "llama3.2:1b already present ✓"
else
  warn "Pulling llama3.2:1b (~800MB — first run only)…"
  docker exec m20-ollama ollama pull llama3.2:1b || warn "Ollama pull failed — riddles will use fallback mode"
fi

# ── 5. Summary ────────────────────────────────────────────────────────────────
echo ""
info "=== Stack is running ==="
echo ""
echo "  Game UI     → http://localhost:8082"
echo "  Admin       → http://localhost:8082/admin"
echo "  API health  → http://localhost:8082/health"
echo "  Metrics     → http://localhost:8082/metrics"
echo "  Prometheus  → http://localhost:9090"
echo "  Grafana     → http://localhost:3000  (anonymous admin)"
echo ""
info "To stop: docker compose down"
