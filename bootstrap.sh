#!/bin/bash

# Principal SRE Bootstrap Script (Microservices Edition)
# Purpose: Orchestrates the API, Frontend, and Observability stack.

set -e # Exit on any error

echo "🚀 Starting Weather Microservices Bootstrap..."

# 1. Environment Validation
echo "🔍 Checking prerequisites..."
command -v go >/dev/null 2>&1 || { echo >&2 "❌ Go is not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "❌ Docker is not installed."; exit 1; }

# 2. Dependency Management
echo "📦 Tidying Go modules (Target: Go 1.23)..."
go mod tidy

# 3. Clean State Enforcement
echo "🧹 Cleaning up existing containers and networks..."
docker-compose down --remove-orphans

# 4. Multi-Service Build and Launch
echo "🏗️ Building and launching distributed stack..."
# We use --build to ensure the Go binary is recompiled with any recent changes
docker-compose up --build -d

# 5. Health Verification
echo "⏳ Waiting for API to become healthy..."
MAX_RETRIES=10
COUNT=0
until $(curl -sf http://localhost:8080/health > /dev/null); do
    if [ $COUNT -eq $MAX_RETRIES ]; then
      echo "❌ API failed to start in time."
      exit 1
    fi
    printf '.'
    sleep 2
    COUNT=$((COUNT+1))
done

echo -e "\n--------------------------------------------------------"
echo "✅ BOOTSTRAP SUCCESSFUL"
echo "--------------------------------------------------------"
echo "🌐 FRONTEND DASHBOARD: http://localhost:8081"
echo "📡 WEATHER API:        http://localhost:8080/weather/lubbock"
echo "📊 METRICS (RAW):      http://localhost:8080/metrics"
echo "🔥 PROMETHEUS ALERTS:  http://localhost:9090/alerts"
echo "📈 GRAFANA SIGNALS:    http://localhost:3000"
echo "--------------------------------------------------------"
echo "📝 To view logs: 'docker-compose logs -f weather-service'"
echo "🧪 To run chaos: './chaos_test.sh'"