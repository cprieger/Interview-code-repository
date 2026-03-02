# internal/

Go packages that implement the game engine. Nothing here is exposed externally.

| Package | Responsibility |
|---|---|
| `config/` | Load env vars with defaults (PORT, DB_PATH, OLLAMA_URL) |
| `game/` | D20 rolls, tile generation, land maps, scavenging, building/vehicle encounters |
| `character/` | Character data model, random generator, SQLite persistence |
| `resources/` | Static game data: 8 classes, 10 monsters, 10 tiles, 14 supplies, 6 crafts, 6 vehicles |
| `ai/` | Ollama HTTP client — riddles and monster dialogue, with graceful fallback |
| `obs/` | Prometheus metric definitions (promauto pattern), scrape config, alert rules |

## Pattern

All packages follow the `weather-service` conventions:
- Metrics registered via `promauto` — no manual `Register()` calls
- Structured errors: `{"error": {"code": "...", "message": "...", "hint": "..."}}`
- `config.Load()` reads env vars, never panics — all have defaults
