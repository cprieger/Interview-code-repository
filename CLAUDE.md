# CLAUDE.md — Weather Service SRE Edition

Context file for Claude Code. Loaded automatically at session start to reduce exploration overhead.

---

## Project Overview

A Go 1.23 microservice demonstrating **SRE best practices**: observability, chaos engineering, and infrastructure-as-code. Built as an interview demo. The service returns mock weather data (always 72°F, Sunny) — the real point is the surrounding SRE instrumentation.

**Module:** `weather-service`
**Binary entrypoint:** `cmd/server/main.go`
**Direct deps:** `github.com/google/uuid`, `github.com/prometheus/client_golang`

---

## Key Commands

```bash
# Build & Run locally
make build                      # compiles → bin/weather-api
make run                        # build + run (sets dummy WEATHER_API_KEY)
go build -o bin/weather-api cmd/server/main.go  # manual

# Test
make test                       # go test -v ./...
make test-coverage              # + generates coverage.out + prints summary
make test-html                  # + generates coverage.html
./scripts/unit_test/unit_test.sh  # shell wrapper for the above

# Docker (full stack)
./scripts/bootstrap/bootstrap.sh  # clean build + compose up + health check
docker compose up --build         # manual equivalent
docker compose down               # tear down

# Chaos (requires stack running)
./scripts/chaos_test/chaos_test.sh  # fires 60 concurrent requests (20 500s, 20 404s, 20 ok)
curl "http://localhost:8080/weather/lubbock?chaos=true"            # single 500
curl -H "X-Chaos-Mode: true" http://localhost:8080/weather/lubbock # single 500
```

---

## Architecture

### Go Source Files

| File | Purpose |
|---|---|
| `cmd/server/main.go` | HTTP server, routing, `sreMiddleware`, `statusRecorder` |
| `internal/weather/client.go` | Mock weather data, `sync.Map` cache, chaos priority check |
| `internal/obs/metrics.go` | Prometheus counters/histograms — single source of truth for metric names |
| `internal/config/config.go` | Env-var config loading with defaults |

### Test Files

| File | What it covers |
|---|---|
| `internal/weather/client_test.go` | Cache hit, cache miss, chaos priority, chaos+cache miss, chaos=false |
| `cmd/server/handler_test.go` | Health check, weather success, chaos→500, 404 |
| `cmd/server/middleware_test.go` | Chaos via query param, chaos via header, no-chaos, path normalization, statusRecorder |
| `cmd/server/integration_test.go` | Full chain: middleware → handler → client, for all scenarios |

### Docker Services

| Service | Port | Image |
|---|---|---|
| `weather-service` | 8080 | Built from `dockerfile` (multi-stage, alpine) |
| `prometheus` | 9090 | `prom/prometheus:latest` |
| `grafana` | 3000 | `grafana/grafana:latest` (anonymous admin enabled) |
| `dashboard-ui` | 8081 | `nginx:alpine` (serves `dashboard/index.html`) |

All services share a `monitoring` bridge network. Prometheus config and alert rules are mounted from `internal/obs/`.

---

## Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Returns `{"status":"up"}` with 200 |
| GET | `/weather/:location` | Returns `{"temperature":72,"conditions":"Sunny"}` (or 500 in chaos) |
| GET | `/metrics` | Prometheus scrape endpoint (bypasses SRE middleware) |

---

## Chaos Engineering

**How it works (full chain):**

1. `sreMiddleware` checks `?chaos=true` query param OR `X-Chaos-Mode: true` header
2. Sets `context.Value("chaos_trigger") = "true"` on the request context
3. `weather.Client.GetWeather()` checks the context key **before** checking the cache
4. If chaos: returns `fmt.Errorf("simulated_upstream_failure_500")` (bypasses cache entirely)
5. Handler sees the error → `http.Error(w, err.Error(), 500)`

**Key insight:** Chaos takes priority over cached data. A cached location still returns 500 under chaos.

**Context keys used in middleware:**
- `"chaos_trigger"` — `"true"` or `"false"` (string)
- `"trace_id"` — UUID string for request tracing

---

## Observability

### Prometheus Metric Names

| Metric | Type | Labels |
|---|---|---|
| `weather_service_http_requests_total` | Counter | `path`, `method`, `code`, `status_text` |
| `weather_service_http_request_duration_seconds` | Histogram | `path`, `method` |
| `weather_service_cache_hits_total` | Counter | — |
| `weather_service_cache_misses_total` | Counter | — |

Metrics are registered via `promauto` (auto-registered at package init). Defined in `internal/obs/metrics.go`.

### Alert Rules (`internal/obs/alert_rules.yml`)

| Alert | Condition |
|---|---|
| `API_Server_Errors_High` | >10% 5xx rate over 1m, fires after 10s |
| `API_Client_Errors_High` | >10% 4xx rate over 1m, fires after 1m |
| `API_Latency_High` | P99 latency >500ms over 1m, fires after 30s |
| `System_Memory_High` | Heap >50MB, fires after 1m |
| `System_CPU_High` | CPU rate >0.5, fires after 1m |
| `System_Goroutines_High` | >100 goroutines, fires after 1m |
| `API_Traffic_Zero` | Zero traffic for 2m, severity critical |

### Grafana Dashboards

Pre-provisioned at startup from `grafana/provisioning/`. Panels:
- Requests per Second (Throughput)
- Error Rate by Type (4xx vs 5xx)
- P99 Latency
- Memory Usage (Heap In-Use)
- Goroutines (Concurrency)
- HTTP Status Breakdown (table)

---

## Important Patterns

**Path normalization** (cardinality control): In `sreMiddleware`, any path starting with `/weather/` is normalized to `/weather/:location` before recording metrics. Prevents high-cardinality label explosion.

**`statusRecorder`**: A thin `http.ResponseWriter` wrapper in `main.go` that captures the response status code written by downstream handlers, so `sreMiddleware` can record it in Prometheus after the fact.

**`sync.Map` cache**: `weather.Client` uses `sync.Map` for lock-free concurrent caching. Cache key is the location string. No TTL — data lives for the process lifetime. Config TTL (`5 * time.Minute`) in `internal/config/config.go` is defined but not yet wired to the cache.

**`promauto` auto-registration**: Metrics in `internal/obs/metrics.go` are registered automatically when the package is imported. No manual `prometheus.MustRegister()` calls needed.

---

## Environment Variables

| Var | Default | Description |
|---|---|---|
| `PORT` | `8080` | Listen port |
| `WEATHER_API_KEY` | `"mock-key"` | Placeholder — no real API called |
| `LOG_LEVEL` | `"info"` | Log level (not yet wired to slog) |

Config is loaded via `internal/config/config.go:Load()` but `main.go` does not currently call it — the server hardcodes `:8080`. Config is available for future use.

---

## Scripts

| Script | Location | Purpose |
|---|---|---|
| `bootstrap.sh` | `scripts/bootstrap/` | One-shot: clean, build image, compose up, health check |
| `chaos_test.sh` | `scripts/chaos_test/` | SRE validation: 60 concurrent requests (3 phases) |
| `unit_test.sh` | `scripts/unit_test/` | Shell wrapper that runs `go test -v ./...` |

Each script directory has its own `README.md`.

---

## Changelog

See `CHANGELOG.md` for full history.

**Workflow: always update `CHANGELOG.md` when making changes.**

Add a new dated section at the top (`## YYYY-MM-DD`) before opening a PR. Each entry should describe:
- What changed and which files were affected
- Why (the problem it solves or improvement made)

Group related changes under the same date. Keep entries concise — one line per logical change is ideal.

```markdown
## YYYY-MM-DD

- Brief description of change:
  - Detail about affected file or behavior.
```
