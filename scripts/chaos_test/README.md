# chaos_test.sh

**Purpose:** SRE validation suite that generates mixed traffic (successes, 4xx, and 5xx) so you can verify observability in Grafana and Prometheus.

## What it does

Runs three phases in parallel (each fires ~20 requests in the background):

1. **Phase 1 — 500 errors** — Calls `GET /weather/lubbock?chaos=true` to trigger server faults (5xx).
2. **Phase 2 — 404 errors** — Calls `GET /weather/invalid-location-forcing-404` to trigger client faults (4xx).
3. **Phase 3 — Valid traffic** — Calls `GET /weather/lubbock` for successful requests so Prometheus can compute error rates.

Afterward you can open Grafana (and Prometheus alerts) to see 4xx vs 5xx spikes and confirm alerting/visibility.

## Usage

Run from anywhere; it only needs the Weather API to be reachable on `localhost:8080`:

```bash
chmod +x scripts/chaos_test/chaos_test.sh
./scripts/chaos_test/chaos_test.sh
```

**Prerequisite:** The stack must be up (e.g. after running `scripts/bootstrap/bootstrap.sh`).

## When to use

- After bringing up the stack, to confirm metrics and alerts work.
- When validating or tuning Prometheus alert rules or Grafana dashboards.
