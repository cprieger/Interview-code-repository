#!/bin/bash
set -e

echo "🧪 Running Production Health Suite..."

# 1. Run Internal Go Tests
echo "--- [1/3] Running Unit Tests ---"
docker-compose exec -T weather-service go test ./... -v

# 2. Check Container Liveness
echo "--- [2/3] Checking Container States ---"
services=("weather-service" "dashboard-ui" "prometheus" "grafana")
for service in "${services[@]}"; do
    STATUS=$(docker inspect -f '{{.State.Running}}' sezzleinterview-${service}-1)
    if [ "$STATUS" = "true" ]; then
        echo "✅ $service is running."
    else
        echo "❌ $service is DOWN."
        exit 1
    fi
done

# 3. Verify Prometheus Targets
echo "--- [3/3] Verifying Prometheus Scraping ---"
TARGET_STATUS=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[0].health')
if [ "$TARGET_STATUS" = "up" ]; then
    echo "✅ Prometheus is successfully scraping the weather-service."
else
    echo "❌ Prometheus target is unhealthy or not found."
    exit 1
fi

echo "✨ ALL SYSTEMS NOMINAL"