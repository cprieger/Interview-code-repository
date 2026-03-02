#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../../apps/weather-service" && pwd)"
cd "$APP_ROOT"
docker compose down --volumes --remove-orphans
