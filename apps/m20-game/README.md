# M20 Game

Post-apocalyptic dungeon RPG. Go backend, jQuery UI, Ollama AI, SQLite persistence.

## Quickstart

```bash
./scripts/bootstrap/bootstrap.sh   # build + start all services
```

| URL | What |
|---|---|
| http://localhost:8082 | Game UI |
| http://localhost:8082/admin | Admin / API tester |
| http://localhost:8082/health | Health check |
| http://localhost:8082/metrics | Prometheus scrape |
| http://localhost:9090 | Prometheus |
| http://localhost:3000 | Grafana (anonymous admin) |

## Commands

```bash
make build           # compile Go binary
make test            # run all tests
make test-coverage   # tests + coverage report
make docker-up       # bootstrap.sh shorthand
make docker-down     # tear down
```

## API

| Method | Path | Description |
|---|---|---|
| GET | `/health` | `{"status":"up"}` |
| GET | `/metrics` | Prometheus |
| GET | `/api/tile` | Random map tile |
| POST | `/api/land` | Map `{"tileCount":9}` |
| GET | `/api/scavenge?level=N` | Scavenge encounter |
| GET | `/api/items` | All supplies + craftable items |
| POST | `/api/craft` | What can I build? `{"materials":[...],"crafting_level":N}` |
| POST | `/api/combat/roll` | D20 roll `{"stat":N,"bonus":N}` |
| GET | `/api/ai/riddle` | Sphinx riddle (Ollama) |
| POST | `/api/character` | Create `{"name":"...","class":"..."}` |
| GET | `/api/character/:id` | Load character |
| GET | `/api/character/:id/sheet` | Full sheet with class details |

## Stack

| Layer | Technology |
|---|---|
| Backend | Go 1.23, standard library HTTP |
| Persistence | SQLite (modernc.org/sqlite — no CGO) |
| AI | Ollama llama3.2:1b (fallback riddles if unavailable) |
| Frontend | jQuery 3.7.1 (served locally) |
| Observability | Prometheus + Grafana |
| Container | Multi-stage Alpine, non-root user |

## Structure

```
cmd/server/         HTTP server, all route handlers, SRE middleware
internal/config/    Env-var config with defaults
internal/game/      D20 combat, tile/land generation, scavenging
internal/character/ Model, random generator, SQLite store
internal/resources/ Static data: classes, monsters, tiles, items, vehicles
internal/ai/        Ollama client (riddles + monster dialogue)
internal/obs/       Prometheus metrics, alert rules, scrape config
web/static/         jQuery game UI, admin dashboard, CSS
scripts/            bootstrap, unit_test, chaos_test
```
