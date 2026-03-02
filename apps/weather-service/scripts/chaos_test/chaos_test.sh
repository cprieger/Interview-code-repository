#!/bin/bash
# SRE Chaos Validation Suite: Redis Queue + KEDA-Driven Scaling
#
# Loads the Redis queue with jobs to simulate backlog. KEDA (on K8s) sees
# queue depth and scales workers aggressively BEFORE the 15s default poll
# realizes we're behind. Also generates HTTP traffic for 4xx/5xx observability.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 REDIS QUEUE CHAOS TEST - KEDA Scaling Simulation${NC}"
echo -e "   Goal: Load queue so KEDA sees backlog and scales preemptively."
echo ""

# --- Phase 1: BURST-LOAD REDIS QUEUE (primary chaos for KEDA) ---
# Dump hundreds of jobs into Redis. Workers digest; KEDA sees list length.
echo -e "${CYAN}📦 Phase 1: Loading Redis queue (500 chaos + 300 normal jobs)...${NC}"
curl -s -X POST "http://localhost:8080/queue/load?count=500&chaos=true" | head -c 200
echo ""
curl -s -X POST "http://localhost:8080/queue/load?count=300&chaos=false" | head -c 200
echo ""
echo -e "${GREEN}   ✔ 800 jobs queued. Workers digesting. Check weather_queue_length in Grafana.${NC}"
echo ""

# --- Phase 2: HTTP traffic for Golden Signal observability (4xx, 5xx) ---
echo -e "${CYAN}🌐 Phase 2: HTTP traffic (4xx/5xx + valid)...${NC}"
echo "   Generating 500s (server faults)..."
for i in {1..20}; do
   curl -s "http://localhost:8080/weather/lubbock?chaos=true" > /dev/null &
done

echo "   Generating 404s (client faults)..."
for i in {1..20}; do
   curl -s "http://localhost:8080/weather/invalid-location-forcing-404" > /dev/null &
done

echo "   Generating valid traffic..."
for i in {1..20}; do
   curl -s "http://localhost:8080/weather/lubbock" > /dev/null &
done

wait

# --- Phase 3: Show current queue state ---
echo ""
echo -e "${CYAN}📊 Phase 3: Queue stats${NC}"
curl -s "http://localhost:8080/queue/stats" 2>/dev/null || echo '{"error":"queue unreachable"}'
echo ""

echo -e "\n${GREEN}✅ Chaos test complete.${NC}"
echo -e "   ► Grafana: weather_queue_length, weather_jobs_processed_total"
echo -e "   ► Prometheus: weather_queue_length"
echo -e "   ► On K8s: KEDA scales on Redis list length when backlog grows.${NC}"
