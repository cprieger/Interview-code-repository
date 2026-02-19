# SRE Lab — Overview

This repo is an **SRE skills showcase** built around a Go weather microservice. It demonstrates:

- **Observability** — Prometheus, Grafana, Golden Signals
- **Chaos engineering** — Fault injection, Redis queue loading
- **Autoscaling** — HPA, VPA, KEDA, Cluster Autoscaler / Karpenter
- **Infrastructure** — Docker Compose, local K8s (kind), OpenTofu (AWS)

## Layout

```
├── apps/weather-service/    # Go app, Redis queue, Compose stack
├── platform/
│   ├── local/               # kind config, K8s manifests
│   └── aws/                 # OpenTofu (EKS, Karpenter)
├── docs/                    # Detailed guides
├── scripts/
│   ├── bootstrap/           # Full stack bootstrap
│   ├── chaos_test/          # Queue + HTTP chaos
│   ├── unit_test/           # Go tests
│   └── local/               # kind, compose helpers
└── .github/workflows/       # CI
```

## Quick Start

**Docker Compose (easiest):**

```bash
cd apps/weather-service
./scripts/bootstrap/bootstrap.sh
```

Then open http://localhost:8081 and run `./scripts/chaos_test/chaos_test.sh`.

## Scaling and KEDA

The weather service uses a **Redis queue** for jobs. Chaos tests load the queue; **KEDA** scales workers based on Redis list length. See:

- `docs/scaling-hpa-vpa.md`
- `docs/keda.md`
- `platform/local/k8s/weather-service/README.md`
