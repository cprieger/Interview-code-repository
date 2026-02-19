#!/bin/bash
# Start the full stack via Docker Compose (Redis + Weather + Prometheus + Grafana + Dashboard)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../../apps/weather-service" && pwd)"
cd "$APP_ROOT"
docker compose up -d
echo ""
echo "Stack up. Dashboard: http://localhost:8081"
echo "Run chaos: ./scripts/chaos_test/chaos_test.sh"
