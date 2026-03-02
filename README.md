# SRE Lab — Scaling & Observability Showcase 🚀

A **Kubernetes scaling & SRE skills lab** built around a Go weather microservice. Demonstrates HPA, VPA, KEDA, Redis queue-based scaling, chaos engineering, and full observability.

## Quick Start

**Docker Compose (easiest):**

```bash
cd apps/weather-service
chmod +x scripts/bootstrap/bootstrap.sh scripts/chaos_test/chaos_test.sh scripts/unit_test/unit_test.sh
./scripts/bootstrap/bootstrap.sh
```

Then open **http://localhost:8081** (Control Plane) and run:

```bash
./scripts/chaos_test/chaos_test.sh
```

## Architecture

| Component        | Purpose                                                    |
|------------------|------------------------------------------------------------|
| **Weather Service** | Go microservice with Redis queue worker, HTTP API, chaos injection |
| **Redis**        | Message queue (`weather:jobs`). KEDA scales on list length. |
| **Prometheus**   | Metrics, alerts, scrapes weather + redis-exporter          |
| **Grafana**      | Dashboards: Golden Signals, Redis Queue, KEDA visibility    |
| **Dashboard UI** | Central hub with links to all tools                         |

## Scaling Stack

- **KEDA** — Scale workers based on Redis queue backlog (event-driven)
- **HPA** — CPU-based scaling (1–3 replicas)
- **VPA** — Resource recommendations and auto-sizing
- **Cluster Autoscaler / Karpenter** — Node-level scaling (AWS / OpenTofu)

## Project Layout

```
├── apps/weather-service/     # Go app + Redis queue + Compose
├── platform/local/           # kind config, K8s manifests
├── docs/                     # Guides (overview, scaling, KEDA, chaos)
├── scripts/local/            # kind_up, compose_up, etc.
└── .github/workflows/        # CI (test, lint, Docker build, vuln scan)
```

## Docs

- [Overview](docs/overview.md)
- [K8s Manifests](platform/local/k8s/weather-service/README.md)

## Run Locally

- **Compose**: `./scripts/local/compose_up.sh` (from repo root)
- **Kind + K8s**: See `scripts/local/kind_up.sh` and [K8s README](platform/local/k8s/weather-service/README.md)
