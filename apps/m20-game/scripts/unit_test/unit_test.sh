#!/usr/bin/env bash
# unit_test.sh — Run the m20-game test suite with coverage.
# Uses Docker to avoid requiring Go on the host.
#
# Usage: ./scripts/unit_test/unit_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[m20] Running tests via Docker…"

MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$APP_DIR:/app" \
  -w /app \
  golang:1.23-alpine \
  go test -v -coverprofile=coverage.out ./...

echo ""
echo "[m20] Coverage summary:"
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$APP_DIR:/app" \
  -w /app \
  golang:1.23-alpine \
  go tool cover -func=coverage.out | tail -5

echo "[m20] Done."
