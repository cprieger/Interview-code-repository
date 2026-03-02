# resources/

Static game data. All public-domain / original content — zero copyright risk.

| File | Contents |
|---|---|
| `classes.go` | 8 character classes with base stats + bonuses |
| `monsters.go` | 10 folkloric monsters — Zombie → Windego. Sphinx has `HasRiddle: true` |
| `tiles.go` | 10 tile types for procedural map generation |
| `buildings.go` | 6 building types with loot tables |
| `supplies.go` | 14 scavengeable supplies + 6 craftable items + `CanCraft()` helper |
| `vehicles.go` | 6 vehicle types with speed, capacity, condition |

## Monsters

All 10 are public-domain folkloric creatures:
Zombie, Werewolf, Vampire, Mummy, Frankenstein, Basilisk, Golem, **Sphinx**, Wraith, Windego

The Sphinx (`HasRiddle: true`) triggers the Ollama AI riddle mechanic in `ai/ollama.go`.

## Adding content

Add new entries to any slice function — the handlers and generators pick them up automatically via `rand.Intn(len(slice))`.
