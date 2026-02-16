#!/bin/bash

BASE_URL="http://localhost:8080"
echo "🔥 [SRE] INITIALIZING VERIFIED CHAOS TEST..."

# Step 1: Verification
echo "🔍 Testing Header Propagation..."
RESP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Chaos-Mode: true" $BASE_URL/weather/lubbock)

if [ "$RESP_CODE" -eq 500 ]; then
    echo "✅ Header Verified: Server correctly injecting 500 errors."
else
    echo "❌ Header Failed: Expected 500, got $RESP_CODE. Check logs."
    exit 1
fi

# Step 2: Anomaly Generation (Mixed Traffic)
echo "🚀 Generating Anomaly Traffic..."
for i in {1..40}
do
    # 50% Chaos, 50% Normal
    if (( $i % 2 == 0 )); then
        curl -s -H "X-Chaos-Mode: true" "$BASE_URL/weather/lubbock" > /dev/null &
    else
        curl -s "$BASE_URL/weather/lubbock" > /dev/null &
    fi
    sleep 0.2
done

echo ""
echo "✅ Test Sequence Complete."
echo "View Anomaly Z-Scores in Grafana: http://localhost:3000"
echo "Check Firing Alerts in Prometheus: http://localhost:9090/alerts"