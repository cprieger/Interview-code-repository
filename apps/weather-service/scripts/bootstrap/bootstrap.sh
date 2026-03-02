#!/bin/bash
set -e

# Run from repo root so docker-compose finds docker-compose.yml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# --- SRE COLOR PALETTE ---
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}   🚀 WEATHER SERVICE SRE BOOTSTRAP PROTOCOL   ${NC}"
echo -e "${BLUE}=================================================${NC}"

# 1. DESTRUCTIVE CLEANUP
# We remove volumes to reset Prometheus/Grafana state for a clean test run.
echo -e "\n${YELLOW}🧹 [PHASE 1] SANITIZING ENVIRONMENT...${NC}"
docker compose down --volumes --remove-orphans
# Force remove the image to guarantee a rebuild from source
docker rmi weather-service:latest 2>/dev/null || true
echo -e "${GREEN}   ✔ Environment Cleaned${NC}"

# 2. COMPILATION & BUILD
# We use --no-cache to guarantee the latest Go code is compiled.
echo -e "\n${YELLOW}🏗️  [PHASE 2] BUILDING IMAGES (NO-CACHE)...${NC}"
docker compose build --no-cache weather-service
echo -e "${GREEN}   ✔ Build Complete${NC}"

# 3. DEPLOYMENT
echo -e "\n${YELLOW}🚀 [PHASE 3] STARTING STACK...${NC}"
docker compose up -d
echo -e "${GREEN}   ✔ Containers Launched${NC}"

# 4. HEALTH CHECK LOOP
# We poll the API to ensure the binary actually started successfully.
echo -e "\n${YELLOW}⏳ [PHASE 4] WAITING FOR HEALTH CHECKS...${NC}"
attempt=0
max_attempts=30

while [ $attempt -le $max_attempts ]; do
    if curl -s "http://localhost:8080/health" | grep -q "up"; then
        echo -e "${GREEN}   ✔ Weather API is HEALTHY (Port 8080)${NC}"
        break
    fi
    
    attempt=$(( attempt + 1 ))
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}❌ TIMEOUT: Weather API failed to start.${NC}"
        docker compose logs weather-service | tail -n 10
        exit 1
    fi
    
    printf "."
    sleep 1
done

# 5. COMMAND CENTER OUTPUT
echo -e "\n${BLUE}=================================================${NC}"
echo -e "${BLUE}   ✨ SRE COMMAND CENTER - ALL SYSTEMS GO   ${NC}"
echo -e "${BLUE}=================================================${NC}"

echo -e "\n${CYAN}🎯 MAIN DASHBOARD HUB (START HERE)${NC}"
echo -e "   ► URL:            http://localhost:8081"
echo -e "   (Links to all other tools from one central UI)"

echo -e "\n${CYAN}🛠️  INDIVIDUAL SERVICE LINKS${NC}"
echo -e "   ► Grafana:        http://localhost:3000"
echo -e "     (Anonymous admin — no login required)"
echo -e "   ► Prometheus:     http://localhost:9090/alerts"
echo -e "   ► Weather API:    http://localhost:8080/weather/lubbock"

echo -e "\n${CYAN}💥 CHAOS ENGINEERING (Redis Queue + KEDA)${NC}"
echo -e "   ► Load Queue:     curl -X POST 'http://localhost:8080/queue/load?count=500&chaos=true'"
echo -e "   ► Run Test Suite: ${YELLOW}./scripts/chaos_test/chaos_test.sh${NC}"
echo -e "   ► Queue Stats:    http://localhost:8080/queue/stats"

echo -e "\n${CYAN}📦 REDIS & QUEUE${NC}"
echo -e "   ► Redis:          localhost:6379"
echo -e "   ► Redis Exporter: http://localhost:9121/metrics"

echo -e "${BLUE}=================================================${NC}"
