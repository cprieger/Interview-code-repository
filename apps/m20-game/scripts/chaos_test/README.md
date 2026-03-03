# scripts/chaos_test/

`chaos_test.sh` — Load test and validation script for the running stack.

```bash
./scripts/chaos_test/chaos_test.sh
```

Requires: stack running (`./scripts/bootstrap/bootstrap.sh`).

**Phase 1:** 20 concurrent GETs on `/api/tile`, `/api/scavenge`, `/api/items`
**Phase 2:** 20 concurrent POSTs on `/api/land`, `/api/combat/roll`, `/api/craft`
**Phase 3:** 20 requests to `/unknown/route-N` — verifies all return real 404s (not 200s)
**Phase 4:** Character lifecycle — create, then load by ID via `/sheet` endpoint
**Metrics check:** Verifies key m20 metrics are present in `/metrics`

After running, check Grafana (http://localhost:3000) to see the spike in combat rolls, tile generation, and request rates.
