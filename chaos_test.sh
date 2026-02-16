#!/bin/bash
# SRE Validation Suite: Maximum Observability

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 STARTING FULL-SPECTRUM CHAOS TEST...${NC}"

# 1. Generate 500s (Server Faults)
echo "💥 Phase 1: Generating 500 Errors (Server Faults)..."
for i in {1..20}; do
   curl -s "http://localhost:8080/weather/lubbock?chaos=true" > /dev/null &
done

# 2. Generate 404s (Client Faults)
# We hit a non-existent endpoint to trigger the 4xx alert
echo "⚠️  Phase 2: Generating 404 Errors (Client Faults)..."
for i in {1..20}; do
   curl -s "http://localhost:8080/weather/invalid-location-forcing-404" > /dev/null &
done

# 3. Generate Valid Traffic (To allow Prometheus to calculate rates)
echo "✅ Phase 3: Generating Valid Traffic..."
for i in {1..20}; do
   curl -s "http://localhost:8080/weather/lubbock" > /dev/null &
done

echo -e "\n${GREEN}Tests Dispatched. Check Grafana for 4xx vs 5xx spikes.${NC}"