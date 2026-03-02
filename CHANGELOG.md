## 2026-03-02

- Added `.gitignore` to exclude build artifacts and sensitive files:
  - Covers `bin/`, root `weather-api` binary, `coverage.out`, `coverage.html`, `vendor/`, `.env`, editor configs, and OS files.
  - Removed `bin/weather-api` and root `weather-api` binaries that were previously committed to the repo.
- Added `CLAUDE.md` for Claude Code session context:
  - Documents architecture, key commands, endpoints, chaos engineering chain, Prometheus metrics/alerts, and important code patterns.
  - Reduces per-session AI exploration token cost by ~20k–35k tokens.

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

