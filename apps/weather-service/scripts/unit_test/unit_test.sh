#!/bin/bash
# Run from repo root so go test finds all packages
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

echo "🧪 Running Full Test Suite..."

# Run all tests with coverage
go test -v -coverprofile=coverage.out ./...

if [ $? -eq 0 ]; then
    echo "------------------------------------------------"
    echo "✅ ALL TESTS PASSED"
    echo "------------------------------------------------"
    
    # Show coverage summary
    if command -v go &> /dev/null; then
        echo ""
        echo "📊 Coverage Summary:"
        go tool cover -func=coverage.out | tail -1
        echo ""
        echo "View detailed coverage: go tool cover -html=coverage.out"
    fi
else
    echo "------------------------------------------------"
    echo "❌ TESTS FAILED"
    echo "------------------------------------------------"
    exit 1
fi
