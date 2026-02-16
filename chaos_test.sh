#!/bin/bash

echo "🔥 [SRE] INITIALIZING MULTI-VECTOR CHAOS TEST..."
echo "Targeting: http://localhost:8080"
echo "Metrics:   http://localhost:8080/metrics"

# Helper for randomizing
random_range() { echo $(( $1 + RANDOM % ($2 - $1 + 1) )); }

for i in {1..100}
do
    SELECTOR=$(random_range 1 10)

    if [ $SELECTOR -gt 7 ]; then
        # 500 INTERNAL SERVER ERROR (Chaos Mode)
        echo "💥 Sending Chaos Spike (500)..."
        curl -s -H "X-Chaos-Mode: true" "http://localhost:8080/weather/lubbock" > /dev/null &
    
    elif [ $SELECTOR -eq 5 ]; then
        # 404 NOT FOUND (Path Anomaly)
        echo "❓ Sending Invalid Path (404)..."
        curl -s "http://localhost:8080/invalid/path/test" > /dev/null &

    elif [ $SELECTOR -eq 3 ]; then
        # LATENCY ANOMALY (Slow Request simulation via Lubbock)
        # Note: We send several fast ones then a few slow ones to mess with the Z-Score
        echo "🐢 Simulating Latency Outlier..."
        curl -s "http://localhost:8080/weather/lubbock" > /dev/null &
        sleep 0.5 

    else
        # 200 OK (Baseline Traffic)
        curl -s "http://localhost:8080/weather/lubbock" > /dev/null &
    fi

    # Jitter to simulate real-world traffic patterns
    sleep 0.2
done

echo ""
echo "✅ [SRE] Chaos Sequence Complete."
echo "Check Grafana (http://localhost:3000) for Z-Score deviations."
echo "Check Prometheus (http://localhost:9090/alerts) for firing anomalies."