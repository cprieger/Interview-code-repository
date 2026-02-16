#!/bin/bash
# Principal SRE Chaos Verification

URL="http://localhost:8080/weather/lubbock"

echo "🔍 VERIFYING END-TO-END PROPAGATION..."

# Force no-cache and provide the chaos header
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "X-Chaos-Mode: true" \
  -H "Cache-Control: no-cache" \
  "$URL")

if [ "$STATUS" -eq 500 ]; then
    echo "✅ SUCCESS: Chaos Mode verified (Received 500)"
else
    echo "❌ FAILURE: Received $STATUS. Dumping logs:"
    docker-compose logs weather-service | tail -n 20
    exit 1
fi