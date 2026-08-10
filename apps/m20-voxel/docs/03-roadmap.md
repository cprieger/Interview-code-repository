# Roadmap

> Status: draft v0.1 — 2026-08-08

No deadlines. This is a for-fun project and the stated goal is to take our time. What matters is the **order**, because some things are painful to retrofit and cheap to build in early.

Every milestone ends with something you can actually play. If a milestone doesn't produce a playable build, it's badly scoped.

---

## M0 — Spike: does the stack work?

**Goal:** stand on procedurally generated voxel terrain in a Godot build you made yourself, with M20's content already in the project.

**M0.1 — export the M20 data first.** Write `cmd/exportdata` in the Go repo, marshal every `resources` table (classes, monsters, tiles, buildings, supplies, craftables, equipment, vehicles) to JSON, commit the output into `data/`. ~40 lines, the structs already have `json:` tags. Do this before anything else — every later milestone is then content-complete. See `06-porting-strategy.md`.


- Install Godot 4.7.x (stock, official).
- Drop in Voxel Tools **GDExtension**, pin the version, vendor it into the repo.
- `VoxelTerrain` + `VoxelMesherBlocky` + a noise generator. Walk around.
- Break a block. Place a block.
- Export a Windows `.exe` and run it outside the editor.
- Set up the repo, `CLAUDE.md`, and the Godot MCP integration.

**Done when:** you double-click an exe and walk on a hill you generated.
**Why first:** this is the only milestone that can kill the whole plan. Find out now.

---

## M1 — The cozy half

**Goal:** the daytime loop, solo.

- Chibi player character (MagicaVoxel → `.vox`), third-person camera.
- ~12 block types with a proper block registry in `data/blocks/`.
- Inventory + hotbar.
- Crafting bench and ~15 recipes across wood/stone tiers.
- Bed: craft it, place it, sleep in it, respawn at it.
- Day/night cycle with a visible dusk warning.
- World save/load via `VoxelStreamSQLite`.
- **Controller-first UI from the start** (`docs/04-controls.md`): all input via `InputMap`, focus-based inventory navigation, verb menus instead of drag-and-drop.

**Done when:** you can wake up, gather, craft a pickaxe, build a hut, and sleep — **with the mouse unplugged**. No combat at all.

---

## M2 — The dice ⭐

**Goal:** prove pillar #1. This is the make-or-break milestone.

- `scripts/d20/` — roll resolution, modifiers, advantage/disadvantage, stat blocks.
- Character sheet: six stats, HP, level. Crayon-RPG-sheet UI.
- **The dice rig**: a d20 pops from the weapon, tumbles, lands on a *predetermined* face. Get the snap-blend invisible.
- Damage dice burst, values fly up as the number.
- Nat 20 treatment: gold, glow, slow-mo, shake, confetti.
- Nat 1 treatment: cracked die, stumble, sad trombone.
- **The water gun** — pressurized tank, arcing shot, dice tumbling out of the splash. Plus the Reinforced Bat as the melee fallback.
- One punching-bag target dummy to hit. **No monsters yet.**
- Dice pooling and the concurrent-dice cap, built in now.
- Controller rumble tied to the dice: tick on release, thump on landing, double-pulse on a nat 20.

**Done when:** you can stand in front of a dummy hitting it for twenty minutes because the dice feel good. If that isn't true, stop and fix it before building anything on top.

**Decide here:** fumbles = zero damage or glancing blow? Get hands on both.

---

## M3 — The chaotic half

**Goal:** nighttime, solo.

- Monster base class + JSON stat block loader (data already exported in M0.1).
- Six canon monsters: Zombie, Mummy, Werewolf, Wraith, Vampire, Frankenstein.
- One building with its canon monster group and narrative setup text (start with the Hospital's *Zombie Ward*).
- Pathfinding (`VoxelAStarGrid3D`), spawn logic tied to darkness and light level.
- Monster attacks that force **saving throws** — the big close-to-camera die.
- **Loot bags** — monsters pop into carryable, kickable bags instead of dying.
- Water balloons and Molotovs; the Sand → Glass Bottle chain; Battery Pack mod and the Shock damage type.
- Player death → Doc M rebuilds you in bed. Keep inventory.
- XP and leveling with the visible HP roll.
- **Doc M's voice, first pass** — wire up the Go/Ollama sidecar for building entrances and monster dialogue, with canned fallbacks. Cheap to do here and it transforms how the whole milestone feels.

**Done when:** a full day/night cycle is genuinely fun alone.

---

## M4 — Multiplayer 🔥

**Goal:** four people in one world.

- Host-a-game / join-by-IP flow.
- Voxel terrain replication: `VoxelTerrainMultiplayerSynchronizer`, per-player `VoxelViewer`s.
- Player movement prediction + reconciliation.
- **Server-authoritative dice** — clients animate the server's result.
- Replicated monsters, inventories, block edits.
- Downed-and-revive.
- **Headless server export target**, working, from this milestone on.

**Done when:** four people play a full night together without desync.
**Why here and not later:** every system after this gets built multiplayer-correct from birth. Retrofitting is the classic way these projects die.

---

## M5 — Scaling & content

**Goal:** the game gets meaner with more friends.

- Player-count scaling (see `01-gameplay-loop.md`): count-first, gentle capped damage, no retroactive mid-fight buffs.
- Elite variants at N ≥ 4.
- Remaining canon monsters: Basilisk, Golem, Sphinx (Ollama riddles), and the **Windego** boss.
- The Americana tier: Killer Tomato, Giant Ant, Pod Person, Martian Scout, The Ooze, Bog Gulper, Fifty-Foot Kid (`08-bestiary.md`).
- Full damage-type matrix — Water / Shock / Fire / Blunt / Silver, with monster affinities. Frankenstein heals from Shock; the Wraith ignores Blunt; the Bog Gulper shrugs off water.
- Remaining water-gun ammo types and mods.
- All 6 craftables and equipment bonuses; the full 14-supply scavenging economy.
- More biomes from the canon ten; authored building structures with their monster groups.
- Driveable vehicles — start with the Pickup Truck (capacity 4).
- Wire up the Go narration sidecar for building entrances and monster dialogue.
- Dice skin cosmetics + the recipes to craft them.
- Non-combat dice checks: mining, crafting quality, fishing, chests, taming.

**Done when:** 1 player and 6 players are both appropriately hard.

---

## M6 — Ship

**Goal:** strangers can play it.

- Headless dedicated server on a VPS. Document how to run one.
- Main menu, settings, full rebinding, audio mix, accessibility options.
- Device-aware button glyphs (Xbox / PlayStation / keyboard).
- Windows / Mac / Linux exports.
- itch.io page with pay-what-you-want, plus your own site with the direct download and the Venmo ask.
- Credits screen (Godot + Zylann's Voxel Tools attribution).
- A trailer that is 80% dice landing on 20.

---

## Ordering logic, briefly

Three things are ordered deliberately and shouldn't be shuffled:

1. **M0 first** because it's the only existential risk.
2. **M2 before M3** because if the dice don't feel good, the game has no reason to exist and you should find that out before authoring twelve monsters.
3. **M4 before M5** because multiplayer is the thing you cannot bolt on afterward.

Everything else is negotiable.

## Parking lot

Ideas that are good but not now:

- Taming monsters as pets (CHA)
- NPC villages and trading
- Dungeons with authored layouts
- Spells / INT-based magic with spell slots
- Seasons, weather
- Steam release
- Mod support
