## 2026-02-19 (rieger-mastering-hpa branch)

- **Redis queue + KEDA**: Weather service now consumes jobs from Redis (`weather:jobs`). KEDA scales workers based on queue backlog. Chaos test loads 800 jobs to simulate demand.
- **Restructure**: Moved Go app to `apps/weather-service/`. Root README is now SRE lab overview.
- **Observability**: Added `redis-exporter`, Grafana "Redis Queue & KEDA Scaling" dashboard, `weather_queue_length` and `weather_jobs_processed_total` metrics, `Queue_Backlog_High` alert.
- **Dashboard UI**: Links to Grafana, Prometheus, Redis Exporter, Queue Stats, chaos load.
- **K8s**: Manifests in `platform/local/k8s/weather-service/` (Redis, weather-service, KEDA ScaledObject, HPA, VPA).
- **Scripts**: `scripts/local/kind_up.sh`, `compose_up.sh`, `compose_down.sh`, `kind_down.sh`.
- **CI**: `.github/workflows/ci.yml` — test, lint, Docker build, govulncheck.
- **Docs**: `docs/overview.md`, `docs/keda.md`, `docs/scaling-hpa-vpa.md`.

## 2026-02-17

- Aligned HTTP metrics with Prometheus:
  - Centralized metric definitions in `internal/obs/metrics.go` (`HttpRequestsTotal` and `HttpRequestDuration` with `path`, `method`, `code`, `status_text`).
  - Updated `cmd/server/main.go` to use `obs` metrics and keep routing/SRE logic focused.
- Reorganized observability configuration:
  - Moved `prometheus.yml`, `alert_rules.yml`, and `alertmanager.yaml` into `internal/obs/`.
  - Updated `docker-compose.yml` to mount configs from `internal/obs`.
- Standardized scripts and documentation:
  - Created `scripts/` hierarchy with per-script READMEs (`bootstrap`, `chaos_test`, `unit_test`).
  - Updated `README.md`, `GEMINI.md`, and dashboard title to match the new structure and neutral naming.
- Strengthened testing posture:
  - Fixed and expanded `internal/weather/client_test.go` to cover cache hits/misses and chaos priority.
  - Added handler, middleware, and integration tests under `cmd/server/`.
  - Updated `scripts/unit_test/unit_test.sh` and `Makefile` to run the full suite with coverage reporting.

