# character/

Character data model, random generator, and SQLite persistence.

| File | What it does |
|---|---|
| `model.go` | `Character` struct, stats, inventory, XP/level logic |
| `generator.go` | `Generate(req)` — creates a new character with class bonuses applied |
| `store.go` | `Store` — SQLite CRUD via `modernc.org/sqlite` (pure Go, no CGO) |

## Character sheet fields

```
ID, Name, Class, Level, XP, HP, MaxHP
Stats: Strength, Stamina, Marksmanship, Scouting, Scavenging, Crafting, Salvaging
Inventory: []string (5 slots; Hoarder gets 8)
Location: current tile ID
CreatedAt, UpdatedAt
```

## Persistence

- Local dev: SQLite at `DB_PATH` (default `./data/m20.db`)
- Production: swap `Store` for a PostgreSQL implementation — same interface
- WAL mode enabled for concurrent reads
- Schema migrated on startup via `migrate()`

## Level up

`XPForNextLevel(level) = level * 100` — 100 XP for level 2, 200 for level 3, etc.
