## 2026-03-02 (3)

- Added `apps/m20-game/` — full M20 RPG game engine, Phase 2 of the platform roadmap:
  - `cmd/server/main.go` — HTTP server with all 12 REST endpoints, SRE middleware, structured JSON errors, Prometheus metrics.
  - `internal/game/` — D20 combat engine, tile/land generation, scavenging, building explore, vehicle find.
  - `internal/character/` — Character model, random generator (8 classes), SQLite persistence via `modernc.org/sqlite` (no CGO).
  - `internal/resources/` — Static game data: 8 classes, 10 monsters, 10 tile types, 14 supplies, 6 craftable items, 6 vehicles.
  - `internal/ai/ollama.go` — Ollama HTTP client for Sphinx riddles and monster dialogue; graceful fallback if Ollama unavailable.
  - `internal/obs/` — Prometheus metrics (promauto), alert rules (4 rules), Prometheus scrape config.
  - `web/static/` — jQuery 3.7.1 game UI, admin dashboard, post-apocalyptic dark CSS, PWA manifest.
  - `dockerfile` — Multi-stage Alpine build, non-root user (`m20:m20`), exposes 8082.
  - `docker-compose.yml` — m20-game + Ollama + Prometheus + Grafana.
  - `Makefile`, `scripts/` — bootstrap, unit_test, chaos_test (real 404 validation fixed from weather-service).
  - README.md in every directory.

## 2026-03-02

- Fixed `apps/weather-service/scripts/bootstrap/bootstrap.sh`:
  - Replaced deprecated `docker-compose` (hyphen CLI) with `docker compose` on all 4 invocations.
  - Corrected Grafana credentials hint — anonymous admin is enabled, no login required.

## 2026-03-02 (initial)

- Added `.gitignore` to exclude build artifacts and sensitive files:
  - Covers `bin/`, root `weather-api` binary, `coverage.out`, `coverage.html`, `vendor/`, `.env`, editor configs, and OS files.
  - Removed `bin/weather-api` and root `weather-api` binaries that were previously committed to the repo.
- Added `CLAUDE.md` for Claude Code session context:
  - Documents architecture, key commands, endpoints, chaos engineering chain, Prometheus metrics/alerts, and important code patterns.
  - Reduces per-session AI exploration token cost by ~20k–35k tokens.
## 2026-02-20

- **Lint hardening (weather-service)**:
  - Fixed `errcheck` findings by handling return values from `w.Write`, `json.NewEncoder(...).Encode`, deferred Redis `Close`, and `http.ListenAndServe`.
  - Fixed `staticcheck SA1029` by replacing string context keys with typed helpers in `internal/weather/client.go` (`WithChaosTrigger`, `ChaosTrigger`) and updating call sites.
  - Applied `gofmt` to all touched files.
- **Tests & validation**:
  - Ran full package tests in `apps/weather-service` via `go test -v ./...` (pass).
  - Ran script-based full test suite via `bash ./scripts/unit_test/unit_test.sh` (pass, coverage produced).
  - Ran chaos validation via `./scripts/chaos_test/chaos_test.sh` (pass).
- **Repo hygiene**:
  - Added root `.gitignore` for Go build artifacts, coverage files, local env/log/temp files, binaries, and macOS/editor noise.
- **Docs**:
  - Updated `GEMINI.md` to reflect typed context key strategy and lint reliability hardening.
  - Updated `apps/weather-service/README.md` with a concise quality/testing command section.

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

