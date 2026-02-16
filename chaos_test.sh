#!/bin/bash
echo "🔍 VERIFYING END-TO-END PROPAGATION..."

# We use Lubbock-Chaos to ensure we aren't hitting a previous 'Lubbock' cache entry
URL="http://localhost:8080/weather/lubbock-chaos"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Chaos-Mode: true" "$URL")

if [ "$STATUS" -eq 500 ]; then
    echo "✅ SUCCESS: Received 500"
else
    echo "❌ FAILURE: Received $STATUS"
    docker-compose logs weather-service | tail -n 5
fi