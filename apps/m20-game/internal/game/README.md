# game/

Core M20 rules engine. Stateless functions — all game state lives in `character/store.go`.

| File | What it does |
|---|---|
| `combat.go` | `Roll(req, critThreshold)` — D20 with crit/success/failure classification |
| `tile.go` | `GenerateTile(id)` — random tile from resources package |
| `land.go` | `GenerateLand(n)` — map of N tiles, clamped 1-25 |
| `monster.go` | `RandomEncounter()`, `EncounterByName()` |
| `supply.go` | `Scavenge(level)` — roll-based loot with rarity filter |
| `building.go` | `ExploreBuilding()` — random building with loot and monster chance |
| `vehicle.go` | `FindVehicle()` — random vehicle with condition check |

## Roll outcomes

| Result | Condition |
|---|---|
| `crit_failure` | Natural 1 |
| `failure` | Total < 10 |
| `success` | Total >= 10 |
| `crit_success` | Natural >= critThreshold (default 20) |

Brawler class lowers critThreshold to 18. Conspiracy Theorist gets +3 on Sphinx riddle checks.
