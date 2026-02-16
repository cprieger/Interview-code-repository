#!/bin/bash
# Principal SRE Chaos Verification

URL="http://localhost:8080/weather/lubbock"

echo "🔍 VERIFYING END-TO-END PROPAGATION..."

# We use -H "X-Chaos-Mode: true" and check the status
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Chaos-Mode: true" "$URL")

if [ "$STATUS" -eq 500 ]; then
    echo "✅ SUCCESS: Chaos Mode verified (Received 500)"
else
    echo "❌ FAILURE: Received $STATUS. Checking logs..."
    docker-compose logs weather-service | grep "Chaos"
    exit 1
fi