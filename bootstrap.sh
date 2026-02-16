#!/bin/bash

# Principal SRE Bootstrap Script
# Purpose: Automated environment setup and service launch

set -e # Exit on error

echo "🚀 Starting Weather Service Bootstrap..."

# 1. Check for Prerequisites
command -v go >/dev/null 2>&1 || { echo >&2 "❌ Go is not installed. Aborting."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "❌ Docker is not installed. Aborting."; exit 1; }

# 2. Initialize Go Modules and Dependencies
echo "📦 Tidying Go modules..."
go mod tidy

# 3. Clean up any old containers
echo "🧹 Cleaning up old Docker artifacts..."
docker-compose down --remove-orphans

# 4. Build and Launch the Stack
echo "🏗️ Building and launching service with Prometheus & Grafana..."
docker-compose up --build -d

echo "--------------------------------------------------------"
echo "✅ Setup Complete!"
echo "📍 API:       http://localhost:8080/weather/lubbock"
echo "📍 Metrics:   http://localhost:8080/metrics"
echo "📍 Dashboard: http://localhost:8080/dashboard"
echo "📍 Prometheus: http://localhost:9090"
echo "📍 Grafana:    http://localhost:3000"
echo "--------------------------------------------------------"
echo "📝 Run 'docker-compose logs -f weather-service' to view logs."