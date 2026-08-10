# Review Checklist — run after every merge

> Owner: **Themis** ⚖️. Read-only audit. Report findings; don't apply fixes.

These are the things that are easy to violate accidentally and expensive to fix later. Work the list explicitly and report pass/fail per item with file and line references.

## Authority

- [ ] Any gameplay logic gated on something other than `multiplayer.is_server()`? Any `if singleplayer` branch?
- [ ] Any dice result computed, decided, or influenced client-side?
- [ ] Any client-authoritative damage, inventory change, or block edit?

## Rules correctness

- [ ] Does hit resolution use `monster.Defense`, or has the hardcoded `total >= 10` bug crept back in? *(The original Go version had this — a Zombie at DEF 8 was as hard to hit as the Windego at 17.)*
- [ ] All four outcomes handled — crit failure, failure, success, crit success?
- [ ] Crit threshold respected (20 normally, 18 for Brawler)?
- [ ] Stats match canon — the **seven** M20 stats, not D&D's six?
- [ ] Damage-type affinities applied? Frankenstein *heals* from Shock; Wraith immune to Blunt; Bog Gulper immune to Water.

## Controller

- [ ] Any drag-and-drop in a UI? *(Blocking. No exceptions.)*
- [ ] Any hardcoded key or joypad button outside `InputMap`?
- [ ] Do new `Control` nodes set `focus_neighbor_*`?
- [ ] Does every new screen work with the mouse unplugged?

## Engine constraints

- [ ] `VoxelLodTerrain` used anywhere? *(No multiplayer support — must be `VoxelTerrain`.)*
- [ ] Terrain sync code outside `scripts/net/`?
- [ ] C# introduced anywhere? *(GDScript only — GDExtension classes require reflection from C#.)*
- [ ] Voxel Tools version still pinned?

## Data

- [ ] Game data hardcoded in `.gd` instead of loaded from `data/`?
- [ ] Stats invented rather than exported from the Go canon?
- [ ] Is `data/*.json` current? Run `cd apps/m20-game && make export-check`.

## Agent boundaries

- [ ] Did any agent write outside its owned directories?
- [ ] Was `project.godot`, an autoload, or `CLAUDE.md` modified? *(Human-only.)*

## Performance

- [ ] Dice pooled and concurrent instances capped (~40)?
- [ ] Loot bags capped and merged during hordes?
- [ ] Anything doing per-frame work on a client-only node that should be server-side?

## Tone

- [ ] Any gore, corpses, or death language? *(Monsters decompile into loot bags.)*
- [ ] Does new flavor text match the campy B-movie register?
- [ ] Any monster named after a film character rather than a generic creature type?
- [ ] "Maxamillion" spelled correctly? *(Deliberately not "Maximilian".)*

---

**Output format:** group findings as **blocking** (violates a non-negotiable), **should fix**, or **nit**. Cite file and line. Suggest the fix; don't apply it.

If everything passes, say so plainly and briefly. Don't invent problems to look thorough.
