# bootstrap.sh

**Purpose:** One-click SRE bootstrap for the Weather Service. Cleans the environment, rebuilds images from source, starts the full Docker stack, and waits until the API is healthy.

## What it does

1. **Sanitize environment** — Runs `docker-compose down --volumes --remove-orphans` and removes the `weather-service` image so the next build is from scratch.
2. **Build** — Builds the Weather Service image with `docker-compose build --no-cache weather-service`.
3. **Deploy** — Starts all services with `docker-compose up -d` (Weather API, Prometheus, Grafana, Dashboard UI).
4. **Health check** — Polls `http://localhost:8080/health` until the API reports healthy (or times out after 30 attempts).
5. **Command center** — Prints URLs for the dashboard hub, Grafana, Prometheus, and the Weather API, plus how to run the chaos test.

## Usage

Run from the **project root** (the script changes into the repo root automatically):

```bash
chmod +x scripts/bootstrap/bootstrap.sh
./scripts/bootstrap/bootstrap.sh
```

## Requirements

- Docker and Docker Compose
- Ports 3000, 8080, 8081, 9090 available

## When to use

- First-time setup
- After pulling changes to rebuild from source
- When you want a clean state (no old volumes or cached images)
