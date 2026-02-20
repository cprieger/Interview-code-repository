# Weather Service SRE Edition 🌩️

Production-grade Go microservice with **Redis queue**, SRE middleware, and observability. Used as the core application for the SRE lab.

## Quick Start

```bash
chmod +x scripts/bootstrap/bootstrap.sh scripts/chaos_test/chaos_test.sh scripts/unit_test/unit_test.sh
./scripts/bootstrap/bootstrap.sh
```

Control Plane: **http://localhost:8081**

## Architecture

| Service         | Port  | Description                                    |
|-----------------|-------|------------------------------------------------|
| Weather API     | 8080  | Go service: HTTP API + Redis queue worker      |
| Redis           | 6379  | Message queue for jobs (`weather:jobs`)         |
| Redis Exporter  | 9121  | Prometheus metrics for Redis                   |
| Prometheus      | 9090  | Metrics, alert rules                           |
| Grafana         | 3000  | Dashboards (Golden Signals, Queue, Redis)      |
| Dashboard UI    | 8081  | Central navigation hub                          |

## Redis Queue & KEDA

- **Queue**: Jobs are pushed to `weather:jobs`. Workers consume via BRPOP.
- **KEDA**: On Kubernetes, KEDA scales the deployment based on Redis list length.
- **Chaos**: `./scripts/chaos_test/chaos_test.sh` loads 800 jobs to simulate backlog.

### Endpoints

- `GET /health` — Health check
- `GET /weather/:location` — HTTP weather (direct)
- `POST /queue/load?count=N&chaos=true|false` — Bulk-load jobs
- `GET /queue/stats` — Current queue length
- `GET /metrics` — Prometheus metrics

## Chaos Engineering

- **HTTP chaos**: `GET /weather/lubbock?chaos=true`
- **Queue chaos**: `curl -X POST 'http://localhost:8080/queue/load?count=500&chaos=true'`
- **Full suite**: `./scripts/chaos_test/chaos_test.sh`

## Quality & Testing

- **All package tests**: `go test -v ./...`
- **Scripted suite + coverage**: `bash ./scripts/unit_test/unit_test.sh`
- **Chaos validation**: `./scripts/chaos_test/chaos_test.sh`
- **Formatting**: `gofmt -w ./...` (or run against changed files)

## Project Structure

```
├── cmd/server/         # Entrypoint, middleware, queue worker
├── internal/
│   ├── weather/        # Business logic
│   ├── obs/            # Prometheus config, metrics
│   └── queue/          # Redis client, job types
├── grafana/            # Dashboards, datasources
├── dashboard/          # Control Plane HTML
└── scripts/
    ├── bootstrap/      # Full stack bootstrap
    ├── chaos_test/     # Queue + HTTP chaos
    └── unit_test/      # Go tests
```
