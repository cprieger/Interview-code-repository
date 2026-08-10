# Porting Strategy — from Go/jQuery to Godot voxel

> Status: draft v0.1 — 2026-08-08
> Reads on: `docs/05-m20-canon.md`

## What we're actually doing

M20 today is a **turn-based, tile-card, browser RPG**. The voxel game is **real-time, first/third-person, 3D, co-op**. Those are different games sharing a universe, a rules system, and a content library.

So this isn't a port of the *code*. It's a port of the **rules and content**, with the presentation rebuilt from scratch. Being clear about that upfront prevents a lot of wasted effort trying to preserve things that shouldn't survive.

## The three-bucket split

### Bucket 1 — carries over unchanged (the good news)

This is most of the value, and it's all data:

- 7 stats, 8 classes with bonuses and abilities
- The d20 roll engine and its four outcomes
- 10 monsters with full stat blocks
- Monster groups with their narrative setup text
- 10 tiles → voxel biomes
- 6 buildings with loot tables → authored structures
- 14 supplies, 6 craftables, equipment bonuses
- 6 vehicles
- XP curve and level-up rules
- All flavor text and tone

**Action:** write a tiny Go program in the existing repo that marshals every `resources` table to JSON and dumps it into the Godot project's `data/`. The structs already carry `json:` tags, so this is maybe 40 lines and it's *exact* — no transcription errors, and re-runnable when the source data changes.

```go
// apps/m20-game/cmd/exportdata/main.go  (to write)
// Marshals resources.Classes(), Monsters(), Tiles(), Buildings(),
// Supplies(), CraftableItems(), Vehicles(), EquipBonuses → ./export/*.json
```

Single source of truth stays in Go. Godot consumes JSON. Do this in **M0**, before anything else — it makes every later milestone content-complete from day one.

### Bucket 2 — same intent, new mechanism

| M20 today | Voxel version |
|---|---|
| Tile *cards* drawn 2-pick-1 onto a 5×5 fog grid | Tiles become **biomes** in a continuous procedural world; fog-of-war becomes actual exploration |
| Buildings entered via a menu | Buildings are **structures you walk into**, generated on matching tiles |
| Scavenging = a die roll on a tile | Scavenging = **searching containers** — lockers, cars, shelves — still gated by a Scavenging check |
| Initiative order, turn-based combat | Real-time swings. Initiative mostly dissolves (see below) |
| Party of 4 managed as a roster | Party of 4 becomes **4 human players** (up to 8) |
| Monster group = a combat encounter list | Group = the **actual monsters standing in that building**, spawned weakest-first-nearest |
| HP bars in the DOM | Diegetic — health on the character, dice in the world |

### Bucket 3 — doesn't survive, and that's fine

- jQuery UI, admin dashboard, DOM rendering
- Tile-card draw mechanic (replaced by exploration)
- Turn order / initiative tracker (real-time)
- `localStorage` session restore (replaced by server-side saves)

Delete-with-confidence list. Don't try to preserve these.

## The big architectural question: keep the Go server?

The Go service is not a prototype — it has a rules engine, SQLite persistence, Prometheus metrics, health checks, Docker, and a working Ollama integration. Throwing that away would be wasteful. But making it *the* game server is also wrong: voxel terrain and 60Hz movement have to live in Godot/ENet, and split authority between two processes is a bug factory.

**Recommendation — a narrow, well-chosen split:**

```
┌─────────────────────────┐
│  Godot dedicated server │   authoritative for everything real-time:
│  (GDScript, ENet)       │   terrain, movement, combat, dice results,
│                         │   monster AI, inventory, world persistence
└───────────┬─────────────┘
            │ HTTP (async, non-blocking, always fallback-safe)
            ▼
┌─────────────────────────┐
│  Doc M's voice  │   the existing Go app, trimmed:
│  (Go + Ollama)          │   Sphinx riddles, building entrances,
│                         │   monster dialogue, morning briefings,
│                         │   crit reactions, death commentary
└─────────────────────────┘
```

**Why this split and not another:**

- **Everything latency-sensitive stays in one process.** No cross-service authority, no distributed state, no desync class of bug.
- **Narration is the perfect thing to externalize.** It's asynchronous by nature (you can wait 800ms for a Sphinx riddle), it already works, and it already has hardcoded fallbacks for when Ollama is unavailable — so a dead sidecar degrades to canned text instead of breaking the game.
- **Rebuilding the Ollama layer in GDScript would be pure waste.** Six tuned prompts with a tone prefix and fallbacks — it's done, it works, leave it. Rewrite `tonePrefix` as **Doc M's character prompt** rather than a genre prompt and the whole sidecar becomes him (`09-doc-maxamillion.md`).
- **It ships fine.** Bundle Ollama for the dedicated server; for listen servers, the service is simply absent and every player gets the fallback text. Nobody's game breaks because they didn't install a 1B model.

**Port the roll engine to GDScript.** It's 75 lines. Calling out to HTTP for every d20 would add latency to the single most tactile moment in the game. Rules live where the dice are.

## Corrections to make during the port

Two things found in the existing code (detail in `05-m20-canon.md`):

1. **`Monster.Defense` is never used** — `Roll()` hardcodes `total >= 10`, so a Zombie (DEF 8) is exactly as hard to hit as a Windego (DEF 17). The voxel version must use `total >= monster.Defense`. Worth fixing in the Go app too.
2. **Hoarder inventory bonus is self-contradictory** — class text says 8-vs-5, `model.go` says 25-vs-20. Take the model as truth, fix the text.

## Design decisions this forces

Real-time 3D breaks some assumptions that turn-based tiles allowed. These need answers:

**Initiative and the Gunslinger.** "Always acts first" is meaningless in real-time, and doesn't scale to 8 players anyway. Reroll the ability — suggest **a damage bonus on the first hit against an unaware target**, which preserves "I strike first" in a real-time idiom and stays useful with 8 players.

**Medic's "heal once per fight."** There are no discrete fights in an open voxel world. Convert to a cooldown.

**Party of 4 → 8 players.** Canon is 4. Monster group sizes and the XP curve were tuned for 4. Use the scaling rules in `01-gameplay-loop.md`, and treat 4 as the balance target with 8 as the stretch.

**Stamina vs. HP.** Stamina is a stat *and* conceptually a resource. In real-time with sprinting and swinging, a stamina *bar* is a natural mechanic. Decide whether Stamina stays purely a stat (safer, matches canon) or also drives a bar (better real-time feel, diverges from canon).

**Scavenging vs. mining.** M20 scavenges; Minecraft mines. Lean hard into scavenging — searching a wrecked car is more on-theme than digging a hole, and it makes the game feel less like a clone. But voxel players *will* want to dig and build. Suggested resolution: **you mine terrain for building materials, you scavenge containers for supplies.** Two economies, clearly separated.

**Where does "Escape the Dungeon" go?** The M20 title promises an escape objective, and the Exit Tile + Windego boss is the existing win condition. A survival sandbox has no end. Decide whether the voxel game keeps a **win condition** (find the Dungeon Entrance, beat the Windego, escape) or becomes open-ended. Keeping it is more distinctive and matches the anti-pillar "not a live-service" — a voxel survival game you can actually *finish* is a genuinely good hook.

## Revised M0

`03-roadmap.md`'s M0 gains one item, and it should be first:

> **M0.1 — Export the M20 data tables to JSON.** Write `cmd/exportdata` in the Go repo, dump all `resources` tables, commit the output into the Godot project's `data/`. Everything downstream is then content-complete.
