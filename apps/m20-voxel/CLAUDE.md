# M20: Voxel — working agreements

A cute co-op voxel survival game set in M20's post-apocalyptic wasteland, where every action resolves with visible, physical d20 dice.

Design docs in `docs/` are the source of truth. Read them before proposing changes:

- `docs/00-vision.md` — pillars, tone, art direction, world
- `docs/01-gameplay-loop.md` — the d20 system, combat math, scaling
- `docs/02-tech-stack.md` — engine, architecture, networking
- `docs/03-roadmap.md` — milestones and their order
- `docs/04-controls.md` — controller-first input and UI rules
- `docs/05-m20-canon.md` — **rules and content authority**, extracted from the existing Go game
- `docs/06-porting-strategy.md` — what carries over from M20 and how
- `docs/07-arsenal.md` — weapons, damage types, mods, crafting
- `docs/08-bestiary.md` — full monster roster, affinities, loot bags, trademark guidance
- `docs/09-doc-maxamillion.md` — **the antagonist/guide who justifies the whole design**
- `docs/10-ai-dev-workflow.md` — agent split, orchestration, Ollama's role
- `docs/11-art-pipeline.md` — voxel assets, where Gemini fits and where it doesn't
- `docs/12-handoff.md` — repo layout, LFS, documentation model
- `docs/REVIEW-CHECKLIST.md` — the post-merge audit

## Agent boundaries

Six Pantheon members are scoped to this app, split by **file ownership** so parallel work can't collide. Defined in the monorepo root `.claude/agents/`:

| Agent | Owns |
|---|---|
| 🌍 **Gaia** | `scenes/world/`, `scripts/world/`, `data/blocks/` |
| 🎲 **Tyche** | `scenes/dice/`, `scripts/d20/`, `scripts/combat/` |
| 🧵 **Ariadne** | `scripts/net/`, `export/` |
| 🏺 **Pandora** | `data/**`, `apps/m20-game/cmd/exportdata/` |
| 🔥 **Hestia** | `scenes/ui/`, `scripts/ui/`, InputMap |
| 🛠️ **Daedalus** | `assets/` |

**Themis** runs `docs/REVIEW-CHECKLIST.md` after every merge. **Agon** owns gameplay feel, **Atlas** the roadmap.

`project.godot`, autoloads, and this file are **human-only** — agents propose, Chris applies.

Don't parallelize M2 (dice feel) or M4 (netcode).

## Canon comes from Go, by export

`apps/m20-game/internal/resources` is the single source of truth. It reaches this project via `cd apps/m20-game && make export-data`, which writes `data/*.json`. **Never hand-edit `data/*.json`** — it gets overwritten, and two hand-maintained copies drift within a week. `make export-check` fails if the export is stale.

## M20 canon is authoritative

The existing game lives at `../Interview-code-repository/apps/m20-game` (Go + SQLite + Ollama). Its data is canon — do not invent stats, classes, monsters, items, or tone. When in doubt, read the Go source.

**Seven stats, not D&D's six:** Strength, Stamina, Marksmanship, Scouting, Scavenging, Crafting, Salvaging. Base 3 + class bonuses.

**Eight classes:** Scavenger, Medic, Gunslinger, Wrench Witch, Brawler, Conspiracy Theorist, Hoarder, Street Pharmacist.

**Ten monsters, all public-domain folkloric** (deliberate IP choice — keep it): Zombie, Mummy, Werewolf, Wraith, Vampire, Basilisk, Frankenstein, Golem, Sphinx, Windego (boss).

**Roll engine:** `total = d20 + stat + bonus`. Four outcomes — nat 1 = crit failure; `roll >= critThreshold` (20, Brawler 18) = crit success; `total >= monster.Defense` = success; else failure. *Use Defense — the Go version hardcodes 10, which is a bug to fix in the port.*

**Tone (verbatim from `internal/ai/ollama.go`):** "a campy B-movie zombie apocalypse comedy — think Zombies Ate My Neighbors crossed with Army of Darkness."

**Setting is suburban post-apocalypse**, not fantasy. Ruined city blocks, overgrown highways, gas stations, hospitals, malls. You scavenge containers for supplies and mine terrain for building materials — two separate economies.

Game data comes from exporting the Go `resources` tables to JSON, not from transcription. Keep Go as the single source of truth for content.

## Non-negotiables

**Server-authoritative, always.** Single-player is a local server with one client. There is one code path. Never write `if singleplayer`. Gate logic on `multiplayer.is_server()`.

**The server rolls the dice.** Every d20, damage die, and saving throw is resolved server-side and replicated. The client plays a tumble animation that lands on the given result. Client physics must never determine a number — it desyncs and it's cheatable.

**GDScript, not C#.** Voxel Tools is a GDExtension; reaching its classes from C# requires untyped reflection (`ClassDB.Instantiate`, `.Call`, `.Set`). Don't.

**Voxel Tools = GDExtension edition, pinned.** Works with stock Godot, exports with normal templates. Don't switch to the module edition without a reason. Multiplayer support in Voxel Tools is experimental and has changed between versions — keep terrain-sync isolated in `scripts/net/` and read the changelog before upgrading.

**`VoxelTerrain` + `VoxelMesherBlocky` only.** `VoxelLodTerrain` has no multiplayer support.

**Controller-first. No drag-and-drop, anywhere.** The game must be fully playable on an Xbox pad. Inventory is focus-navigation plus verbs on a selected slot ("Move to…", "Split", "Drop") — never dragging. All input goes through Godot's `InputMap` actions; never check a hardcoded key or joypad button in gameplay code. Set `focus_neighbor_*` on every `Control`. Test each UI screen with the mouse unplugged.

**Game data lives in JSON under `data/`.** Blocks, items, recipes, monster stat blocks. Not Godot resources — JSON is diffable and safely bulk-editable.

## Doc Maxamillion frames everything

**M20 = Model 20** — the twentieth training world built by **Doc Maxamillion**, called **Doc M** by everyone including himself. Mad, not evil.

> Spelling is deliberate — *Maxamillion*, not Maximilian. It's the joke. Never "correct" it. He pulled the players in to make them better at things and he's insufferably proud of it. He is the reason for every soft mechanic, so keep them consistent with him:

- Respawn in bed = he rebuilds you
- Keep inventory = he's testing, not punishing
- Monsters pop into **loot bags** = they're constructs, he recycles them
- **Water gun as the primary weapon** = he doesn't issue lethal weapons in a training world
- Visible dice = he made the rules legible on purpose
- Folkloric and B-movie monsters side by side = he's a film buff, it's his collection

He's voiced by the Ollama sidecar. **Never block gameplay on inference** — fire the request, fall back to a canned line after ~800ms.

## Tone

Cute, goofy, B-movie. **No corpses, ever** — monsters pop into confetti and leave loot bags. Death is embarrassing, not punishing. Failure states are funny, never destructive: a crafting fumble makes a Suspicious Medkit, it never eats your materials.

## Monsters and trademarks

Generic creature *types* only — never film characters. An aggressive tomato is fine; the franchise name is a live trademark. Frankenstein's monster is public domain but Universal's flat-head/neck-bolt design is not — give him a different silhouette. Full safe/unsafe list in `08-bestiary.md`.

## The pillars (cut anything that doesn't serve one)

1. Dice are the toy — physical, visible, tactile.
2. Campy, not grim.
3. Cozy day → chaotic night → cozy day.
4. Nothing here is real, which is why it's safe to be silly.

## Stack

Godot 4.7.x · Zylann `godot_voxel` GDExtension · GDScript · ENet high-level multiplayer · `VoxelStreamSQLite` persistence · MagicaVoxel `.vox` for characters and props.
