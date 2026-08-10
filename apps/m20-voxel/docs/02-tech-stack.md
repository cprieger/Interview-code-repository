# Tech Stack & Architecture

> Status: draft v0.1 — 2026-08-08

## Decision: Godot 4 + Zylann's Voxel Tools (GDExtension edition)

| Piece | Choice | Why |
|---|---|---|
| Engine | **Godot 4.7.x** (4.7.1 stable, released 2026-08-04) | MIT. Free forever, no revenue share, no seat cost. You own the exe. |
| Voxel | **Zylann `godot_voxel` — GDExtension edition** | The mature voxel solution for Godot. Blocky Minecraft-style meshing, chunked infinite terrain, physics integration, `.vox` import. |
| Language | **GDScript** | See "Why not C#" below. |
| Networking | **Godot high-level multiplayer (ENet)** + `VoxelTerrainMultiplayerSynchronizer` | Built in, RPC-based, and Voxel Tools has first-class support for it. |
| Character/prop art | **MagicaVoxel** → `.vox` → `VoxelVoxLoader` | Free, the aesthetic is right by default, fast iteration. |
| Persistence | **`VoxelStreamSQLite`** | Single-file world saves, built in. Trivial to back up and to move between listen and dedicated servers. |
| Source control | Git + GitHub | Already where M20 lives. |

### Why the GDExtension edition specifically

Voxel Tools ships in two forms and this choice matters a lot:

- **Module edition** — requires a *custom build of the Godot engine* and *custom export templates*. Every platform you want to ship needs a matching custom template, and you may have to compile them yourself.
- **GDExtension edition** — a native add-on that drops into `addons/zylann.voxel/` and works with **official stock Godot 4.4.1+**. Exporting uses Godot's normal templates, out of the box.

GDExtension removes an entire category of build pain and is by far the better fit for a small solo/AI-assisted project. Prebuilt binaries cover Windows x86_64, Linux x86_64, macOS (universal x86_64 + arm64), iOS arm64, and Android x86_64/arm64 — which is every platform we care about.

**Caveat, stated honestly:** the GDExtension edition is newer and has had less testing than the module, and `FastNoise2` (the SIMD noise accelerator) isn't included. Neither is disqualifying. If we ever hit a wall, switching to the module edition later is a supported path — remove the extension files and use a module build. Design so nothing depends on which edition we're on.

### Why not C#

Godot's C# integration and GDExtension-defined classes interact badly. Because the C# "glue" is generated when Godot itself is built, it only contains core engine classes — everything from a C++ extension has to be reached through reflection:

```csharp
// This is what every Voxel Tools call would look like from C#
GodotObject model = ClassDB.Instantiate("VoxelBlockyModelCube");
model.Call("set_tile", ..., new Vector2I(1, 1));
model.Set("atlas_size_in_tiles", new Vector2I(8, 8));
```

Untyped, slow, and miserable to maintain. **Use GDScript.** It also happens to be the better AI-assisted language here — more training data in the Godot idiom, and no build step between writing and running.

### Why not the alternatives

**Luanti (formerly Minetest)** — the most mature open-source voxel engine, and genuinely tempting: crafting, inventory, multiplayer, and world-gen already exist; you'd just write Lua mods. Fastest path to *a* playable game. Rejected because:
- Shipping your own branded `.exe` means maintaining a **rebranded fork of the LGPL engine**, which is explicitly not officially supported.
- Its visual ceiling is low, and pillar #1 (dice as a high-craft physical toy) needs real rendering and physics control.
- Weaker AI-assisted tooling.

Still the right call *if* the goal changes to "playable with friends this month" rather than "a game I ship."

**Web / Three.js** — best distribution story (a URL), but we'd build the most from scratch and voxel perf ceilings in the browser are real. The download-an-exe-and-Venmo-me plan doesn't need a browser.

**Unity** — mature voxel assets exist, but there's a per-seat/revenue relationship, a heavier AI-agent workflow, and no advantage here that Godot doesn't cover.

## Multiplayer architecture

Target: **1–8 players. Client can host (listen server), same code runs headless on a VPS later.** Build for both from day one — retrofitting authority into a voxel game is genuinely painful.

### Authority model

**Server-authoritative, always.** Even in single-player, you're running a local server with one client attached. This is the single most important architectural decision in the project: it means there is exactly one code path, single-player is just N=1, and you can never accidentally write logic that only works offline.

The server owns:
- Voxel data (the world is the server's world)
- **All dice rolls** — every d20, every damage die, every save
- Monster spawning, AI, HP, and the player-count scaling math
- Inventory and crafting results
- Day/night cycle and time

The client owns:
- Rendering and audio
- Input
- Movement prediction (with server reconciliation)
- **Dice animation** — playing a tumble that lands on the server's number

### Terrain replication

Voxel Tools' current supported approach (the 2023-04 method):

**Server:** `VoxelTerrain` + a `VoxelTerrainMultiplayerSynchronizer` child node. On player join, create a `VoxelViewer` for them, set `network_peer_id`, and enable `requires_data_block_notifications`. For viewers representing remote players, turn **off** `require_visuals` — the server doesn't need to render anyone's surroundings.

**Client:** `VoxelTerrain` + a `VoxelTerrainMultiplayerSynchronizer` with **the same node name** as the server's. The client still needs its own `VoxelViewer` so terrain knows when it may unload data — give it a slightly *larger* view distance than the server to avoid holes appearing when blocks unload early.

Two important constraints, straight from the Voxel Tools docs:

1. **Multiplayer support is explicitly experimental** and the recommended setup has changed between versions. Pin the Voxel Tools version, read the changelog before upgrading, and keep terrain-sync code isolated in one place so it's cheap to re-do.
2. **`VoxelLodTerrain` has no multiplayer support.** We must use `VoxelTerrain` with `VoxelMesherBlocky`. That's fine — blocky *is* the art direction — but it means no smooth-LOD distant terrain. Plan view distance and fog around it.

Godot RPCs run over UDP, so bulk voxel transfer has throughput limits. Mitigations: for unedited blocks, send a "generate this locally" flag instead of the data (clients have the same generator + seed); use `VoxelBlockSerializer` for edited blocks; batch small edits.

### Listen server → dedicated server

Write it once:

- All game logic lives in nodes that check `multiplayer.is_server()`. Never `if singleplayer`.
- No gameplay logic in `_process` on client-only nodes.
- The host's "player" is just a client that happens to share a process.
- Export a **headless/server build** target from the start (Godot supports a dedicated server export). If it runs headless in M4, it will run on a VPS in M6.

Ship path:
1. **v1 — listen servers.** Host from the game, friends join by IP or a code. Zero hosting cost. NAT punchthrough is the annoying part; look at Godot's ENet + a small relay/broker, or Steam networking if you ever go to Steam.
2. **v2 — dedicated.** Same binary, headless export, on a €5/mo Hetzner or DigitalOcean box. SQLite world file. Now "scale to players currently online" has an obvious meaning.

## Repo structure

```
m20-voxel/
├─ docs/                    # these design docs — the source of truth
├─ addons/zylann.voxel/     # Voxel Tools GDExtension (pinned version, vendored)
├─ scenes/
│  ├─ world/                # terrain, generator, day-night
│  ├─ player/               # controller, camera, prediction
│  ├─ monsters/             # one scene per monster
│  ├─ dice/                 # dice rig, physics, VFX  ← the crown jewel
│  └─ ui/
├─ scripts/
│  ├─ core/                 # autoloads: GameState, Net, Rng
│  ├─ d20/                  # roll resolution, modifiers, stat blocks
│  ├─ combat/
│  ├─ inventory/
│  ├─ crafting/
│  └─ net/                  # replication, spawn/despawn, scaling
├─ data/
│  ├─ blocks/               # block definitions
│  ├─ items/
│  ├─ recipes/
│  └─ monsters/             # JSON stat blocks
├─ assets/
│  ├─ vox/                  # MagicaVoxel sources
│  ├─ textures/
│  └─ audio/
└─ export/                  # export presets: win, linux, mac, server
```

Keep `data/` as plain JSON, not Godot resources. It's diffable, it's editable without opening the editor, and it's the part an AI assistant can safely bulk-edit — which matters a lot for a 40-monster roster.

## AI-assisted development setup

Godot is the best-supported engine for this in 2026 — its scene/node model is explicit and compositional, which is exactly what language models reason about well, unlike engines with implicit editor-driven workflows.

Recommended setup:

- **A Godot MCP server** connecting Claude Code to a live editor instance — lets it build scenes, write and attach scripts, create materials, run the project, and read editor errors directly. Search the Godot Asset Library for "Godot AI" / MCP integrations and pin one.
- **A `CLAUDE.md` at repo root** encoding the non-negotiables: server-authoritative, GDScript not C#, dice results come from the server, data lives in JSON. This is what stops an assistant from cheerfully writing client-authoritative combat.
- **Keep `docs/` as the source of truth** and point the assistant at it. These files are context units, which is why they're split rather than one giant GDD.
- **GDScript over C#** also helps here: no compile step, so the write→run→read-error loop is fast.

## Distribution

- **itch.io** — free, handles Windows/Mac/Linux builds, has a built-in "pay what you want" that's better than a Venmo link (people trust it, and it handles refunds/tax).
- **Your own site** — direct `.exe` download plus the Venmo/Ko-fi ask, as you described. Do both; itch is the trust anchor, your site is the one you control.
- **Steam** — $100 per app. Worth it only once the game is real and you want the friend-invite/networking layer, which genuinely solves the NAT problem for you.
- **Licensing:** Godot is MIT and Voxel Tools is MIT — you can ship a closed-source commercial game with zero obligations beyond an attribution line. Include a credits screen naming Godot Engine and Zylann's Voxel Tools. (This is a summary, not legal advice.)

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Voxel Tools multiplayer is experimental and has changed between versions | **High** | Pin the version. Isolate terrain-sync in one module. Prove it works at M4 before building content on top. |
| Dice physics performance at 8 players | Medium | Pool and cap dice from day one. Distant dice skip physics and pop the result. Budget in M2, not M5. |
| Fumbles feel bad in an action game | Medium | Prototype in M2. Streak protection. Be willing to switch to glancing-blow damage. |
| GDExtension edition less tested than module | Medium | Nothing depends on which edition. Switching is a supported fallback. |
| NAT traversal for listen servers | Medium | Accept IP-based join for v1. Solve properly (relay or Steam) only if the game gets traction. |
| Scope creep — voxel survival games are enormous | **High** | The pillars. Cut anything not serving dice / cute / cozy-chaotic. Roadmap ships something playable each milestone. |

## Sources

- [Godot Engine 4.7.1-stable](https://sourceforge.net/projects/godot-engine.mirror/files/4.6.3-stable/) · [Godot download archive](https://godotengine.org/download/archive/)
- [Zylann/godot_voxel](https://github.com/Zylann/godot_voxel) · [Getting Voxel Tools](https://voxel-tools.readthedocs.io/en/latest/getting_the_module/) · [Voxel Tools — Multiplayer](https://voxel-tools.readthedocs.io/en/latest/multiplayer/)
- [Voxel game demos (Godot 4.4)](https://github.com/Zylann/voxelgame)
- [Luanti](https://www.luanti.org/en/) · [Distributing Games Outside ContentDB](https://docs.luanti.org/for-creators/distributing-games-outside-contentdb/) · [Luanti Licensing](https://docs.luanti.org/for-creators/licensing/)
- [Godot AI — Godot Asset Library](https://godotengine.org/asset-library/asset/5050)
- [Best Voxel Game Engines in 2026](https://lab.rosebud.ai/blog/best-voxel-game-engines-2026)
