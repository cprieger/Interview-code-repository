# M20: Voxel

A cute co-op voxel survival game set inside Doc Maxamillion's training world. Scavenge, build, and fight B-movie monsters with a water gun — and every shot throws real dice onto the ground.

Shares a universe, a rules system, and a content library with [`apps/m20-game`](../m20-game/).

> **Status: design complete, implementation not started.** Ten design docs, seven scoped agents, and the data-export bridge are in place. M0 is the next step.

## Quick orientation

| If you want to… | Read |
|---|---|
| Understand the game in 5 minutes | [`docs/00-vision.md`](docs/00-vision.md) |
| Know the rules and the math | [`docs/01-gameplay-loop.md`](docs/01-gameplay-loop.md) |
| Set up the engine | [`docs/02-tech-stack.md`](docs/02-tech-stack.md) |
| Know what to build next | [`docs/03-roadmap.md`](docs/03-roadmap.md) |
| Check a stat or item | [`docs/05-m20-canon.md`](docs/05-m20-canon.md) |
| Work with agents | [`docs/10-ai-dev-workflow.md`](docs/10-ai-dev-workflow.md) |

Full index in [`CLAUDE.md`](CLAUDE.md), which is also the working agreement every agent loads.

## Stack

| Layer | Choice |
|---|---|
| Engine | Godot 4.7.x (stock, official) |
| Voxel | Zylann `godot_voxel` — **GDExtension edition**, pinned |
| Language | GDScript (never C# — GDExtension classes need reflection from C#) |
| Networking | Godot high-level multiplayer (ENet) |
| Persistence | `VoxelStreamSQLite` |
| Art | MagicaVoxel `.vox` + scripted generation |
| Narration | Ollama, via the existing `apps/m20-game` service |

Godot and Voxel Tools are both MIT — a closed commercial build needs only an attribution line.

## Getting started

```bash
# 1. Export canon data from the Go game (required before anything else)
cd apps/m20-game
make export-data          # writes ../m20-voxel/data/*.json

# 2. Install Godot 4.7.x (stock) and drop in Voxel Tools GDExtension
#    → addons/zylann.voxel/   (pin the version, vendor it into the repo)

# 3. Open apps/m20-voxel/project.godot
```

Then work M0 in [`docs/03-roadmap.md`](docs/03-roadmap.md).

## The data bridge

**`apps/m20-game` is the single source of truth for canon** — stats, classes, monsters, items, tone. It reaches Godot by export, not transcription:

```
internal/resources/*.go  →  cmd/exportdata  →  apps/m20-voxel/data/*.json
```

Change canon in Go, re-run `make export-data`. Never hand-edit `data/*.json`; it will be overwritten and the two games will drift.

`make export-check` fails if the checked-in export is stale — wire it into CI.

## The agents

Seven Pantheon members are scoped to this app, split by **file ownership** so parallel work can't collide. Defined in [`../../.claude/agents/`](../../.claude/agents/).

| Agent | Owns |
|---|---|
| 🌍 **Gaia** | `scenes/world/`, `scripts/world/`, `data/blocks/` |
| 🎲 **Tyche** | `scenes/dice/`, `scripts/d20/`, `scripts/combat/` |
| 🧵 **Ariadne** | `scripts/net/`, `export/` |
| 🏺 **Pandora** | `data/**`, the export tool |
| 🔥 **Hestia** | `scenes/ui/`, `scripts/ui/`, InputMap |
| 🛠️ **Daedalus** | `assets/` |
| ⚖️ **Themis** | Review — runs [`docs/REVIEW-CHECKLIST.md`](docs/REVIEW-CHECKLIST.md) after merges |

Plus the existing pantheon: **Agon** (gameplay feel), **Atlas** (roadmap), **Prometheus** (CI/deploy), **Hades** (security).

`project.godot`, autoloads, and `CLAUDE.md` are **human-only**. Agents propose; Chris applies.

**Don't parallelize M2** (dice feel — needs hands on a controller) **or M4** (netcode — concurrent edits produce ghost bugs).

## Non-negotiables

These are in `CLAUDE.md` and audited after every merge:

- **Server-authoritative, always.** Single-player is a local server with one client. Never `if singleplayer`.
- **The server rolls the dice.** Clients animate a predetermined result. Client-side rolls desync and are trivially cheatable.
- **No drag-and-drop, anywhere.** Full Xbox controller play is a requirement, not a port.
- **`VoxelTerrain` + `VoxelMesherBlocky` only.** `VoxelLodTerrain` has no multiplayer support.
- **No corpses.** Monsters pop into loot bags. They were constructs; Doc M recycles.

## Repo location

This lives in the monorepo because M0–M3 lean hard on the canon data next to `apps/m20-game`. Once the game is real and shipping, it should move to its own public repo — see [`docs/12-handoff.md`](docs/12-handoff.md) for the split path and why the timing matters.
