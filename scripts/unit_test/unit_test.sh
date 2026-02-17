#!/bin/bash
# Run from repo root so go test finds ./internal/weather/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

echo "🧪 Running SRE Reliability Suite..."

# Run only the Priority test with verbose logging
go test -v ./internal/weather/ -run TestGetWeather_ChaosPriority

if [ $? -eq 0 ]; then
    echo "------------------------------------------------"
    echo "✅ RELIABILITY CHECK PASSED"
    echo "Logic verified: Chaos Injection > Cache-Aside"
    echo "------------------------------------------------"
else
    echo "------------------------------------------------"
    echo "❌ RELIABILITY CHECK FAILED"
    echo "Logic Error: Cache is masking synthetic faults."
    echo "------------------------------------------------"
    exit 1
fi
