# M20 Canon — extracted from the existing game

> Source: `Interview-code-repository/apps/m20-game` (Go backend, jQuery UI, SQLite, Ollama)
> Read at commit `548db77` — "Sprint 3: party system, equipment, inventory, tile draw, initiative combat"
> **This document is the authority on M20 rules and content. The voxel game inherits from here.**

## What M20 already is

**M20 — Escape the Dungeon.** A post-apocalyptic dungeon RPG. Not fantasy — *suburban wasteland*. Ruined city blocks, overgrown highways, abandoned suburbs, gas stations, hospitals, malls, military outposts, and somewhere out there, a staircase that goes down.

The tone is already locked in code, and it's exactly what you asked for. From `internal/ai/ollama.go`:

> "a campy B-movie zombie apocalypse comedy — think Zombies Ate My Neighbors crossed with Army of Darkness. Be fun, slightly absurd, and dramatically over-the-top. The monsters are scary but also ridiculous. The survivors are heroic but also kind of ridiculous too."

That's the north star and it's already canon. Nothing to invent.

**Existing stack:** Go 1.23 stdlib HTTP · SQLite (no CGO) · Ollama `llama3.2:1b` for riddles and monster dialogue · jQuery frontend · Prometheus + Grafana · Docker.

**Already built (3 sprints):** d20 roll engine, 8 classes, 10 monsters, thematic monster groups per building, tile/land generation, scavenging, crafting, equipment with stat bonuses, character persistence, a 4-person party system, initiative-based combat, a 5×5 fog map with a draw-two-pick-one tile mechanic, and an Exit Tile guarded by the Windego.

---

## The seven stats

**M20 does not use D&D's six.** It has seven, and they're wasteland-flavored:

| Stat | Meaning |
|---|---|
| **Strength** | Melee force |
| **Stamina** | Endurance, effective HP stat |
| **Marksmanship** | Ranged accuracy |
| **Scouting** | Perception, initiative |
| **Scavenging** | Finding supplies in the world |
| **Crafting** | Building items; gates recipes by level |
| **Salvaging** | Breaking things down for parts |

Base is **3 in everything**, plus class bonuses. Note the deliberate design: three of seven stats (Scavenging, Crafting, Salvaging) are *non-combat*. M20 is already half a survival-crafting game. That's why the voxel port is a natural fit rather than a genre change.

## The eight classes

| Class | Flavor | Bonuses | Special ability |
|---|---|---|---|
| **Scavenger** | "Trash is treasure" | Scavenging +3, Scouting +2 | Extra supplies on scavenge rolls |
| **Medic** | "Do no harm... to the living" | Stamina +3, Crafting +2 | Heal self mid-combat, once per fight |
| **Gunslinger** | "I never miss twice" | Marksmanship +4, Scouting +1 | First strike — always acts first |
| **Wrench Witch** | "It's not broken, it's in progress" | Crafting +4, Salvaging +2 | Vehicles faster and cheaper to build |
| **Brawler** | "I am the blunt instrument" | Strength +4, Stamina +2 | Crit threshold reduced by 2 (crits on 18+) |
| **Conspiracy Theorist** | "The Sphinx is a GOVERNMENT PROJECT" | Scouting +2, Scavenging +2 | +3 on Sphinx riddle checks |
| **Hoarder** | "I might need this someday" | Salvaging +3, Crafting +1 | Extra inventory slots |
| **Street Pharmacist** | "I have something for that" | Crafting +3, Stamina +2 | Craft medical items one tier early |

These are good. Keep all eight, keep the flavor text verbatim — it does a lot of tone work for free.

## The roll engine (canon)

From `internal/game/combat.go`:

```
roll   = d20                      (1–20)
total  = roll + stat + bonus

natural 1            → crit_failure
roll >= critThresh   → crit_success     (critThresh = 20; Brawler 18)
total >= 10          → success
otherwise            → failure
```

Four outcomes, not two. That's better than what I'd drafted — `crit_success / success / failure / crit_failure` maps perfectly onto four distinct dice presentations in the voxel game.

**Monsters** have `Attack` (bonus to their own d20) and `Defense` (the number the player must beat), plus `HP` and `XPReward`.

### ⚠️ Two bugs to fix in the port

1. **`Defense` is never used.** `Roll()` hardcodes `total >= 10` as the success test, and `handleCombatRoll` never passes the monster's Defense in. So a Zombie (DEF 8) and a Windego (DEF 17) are currently equally hard to hit. The port should compare `total >= monster.Defense`.
2. **Hoarder's inventory bonus disagrees with itself.** `classes.go` says "+3 inventory slots (8 total instead of 5)"; `model.go` grants 25 vs. a base of 20. The model is the newer truth — fix the class description text.

## Monsters (canon — all ten)

Deliberately **public-domain folkloric** creatures, which is a smart IP call already made. Keep it.

| Monster | HP | Attack | Defense | XP | Note |
|---|---:|---:|---:|---:|---|
| Zombie | 8 | 1 | 8 | 50 | The baseline mook. Appears in herds. |
| Mummy | 12 | 3 | 11 | 120 | "Surprisingly fast for a dead person." |
| Werewolf | 14 | 4 | 12 | 150 | Silver is your only friend. |
| Wraith | 15 | 6 | 14 | 180 | "The cold feeling you get before it's too late." |
| Vampire | 16 | 5 | 14 | 200 | "Has opinions about your neck." |
| Basilisk | 18 | 6 | 13 | 220 | Don't make eye contact. |
| Frankenstein | 20 | 5 | 10 | 250 | High HP, low Defense — a big slow wall. |
| Sphinx | 22 | 7 | 15 | 400 | **Riddle monster** — resolved by Ollama, not combat. |
| Golem | 25 | 4 | 16 | 300 | Tankiest Defense outside the boss. |
| **Windego** | **30** | **8** | **17** | **500** | **The boss.** Guards the Exit Tile. |

**On your ZAMN monster request:** the tone is already ZAMN, but the roster is folkloric rather than suburban-B-movie. My earlier invented list (Killer Tomato, Lawn Gnome, Martian Saucer…) is **cut** — it would dilute canon. If we want more monsters later, add them in the *same* public-domain folkloric register the codebase established. The ZAMN-ness should come from tone, narration, and animation, not from swapping the bestiary.

## Monster groups

Monsters don't spawn alone — they come in **thematically coherent groups** tied to buildings, ordered weakest-first with a boss last. This is a genuinely good system and should survive the port intact.

Locations with groups: Hospital, Pharmacy, Hardware Store, Police Station, School, Auto Repair Shop, Supermarket, Sphinx Chamber, Windego Den, Vampire Nest, Werewolf Pack, Basilisk Lair.

Sample group names, which tell you the whole tone: *Frankenstein's Lab*, *Zombie Ward*, *Wraith Wing*, *Vampire Supplier*, *Golem Sentinels*, *Zombie Work Crew*, *Vampire Detective*, *Zombie Officers*, *Mummy's Lesson*, *Zombie Mechanics*, *Undead Stock Team*, *Vampire Management*.

Each group carries a written narrative setup used before combat. Example (Wraith Wing):

> "The cold hits before anything else. The lights died here weeks ago. Something that used to be a patient drifts toward you — barely visible, already angry."

Keep these verbatim. Trigger them on entering the building in voxel space.

## Tiles (10) — the voxel biome list

| Tile | Danger | Encounters |
|---|:--:|---|
| Gas Station | 1 | supply, vehicle |
| Overgrown Highway | 2 | vehicle, supply, monster |
| Abandoned Suburb | 2 | supply, building, monster |
| Forest Edge | 2 | monster, supply |
| Ruined City Block | 3 | monster, supply, building |
| Underground Parking | 3 | vehicle, monster |
| Shopping Mall | 3 | supply, building, monster, vehicle |
| Hospital | 4 | supply, monster, building |
| Military Outpost | 4 | supply, monster, building |
| Dungeon Entrance | 5 | monster |

**These become the voxel world's biomes.** That's the single biggest thing the port inherits — and it's a far more distinctive setting than generic Minecraft terrain. A blocky overgrown highway running through a ruined mall is a *look*.

## Buildings (6)

| Building | Danger | Loot |
|---|:--:|---|
| Pharmacy | 1 | Bandage, Antibiotics, Painkillers |
| Hardware Store | 1 | Scrap Metal, Wire, Duct Tape, Tools |
| Auto Repair Shop | 1 | Engine Parts, Fuel, Scrap Metal, Tools |
| School | 2 | Canned Food, Bandage, Wire |
| Supermarket | 2 | Canned Food, Water Filter, Bandage |
| Police Station | 3 | First Aid Kit, Riot Gear Fragment, Radio Parts |

In voxel form these become **authored structures** that generate on matching tiles — enterable, lootable, and each with its monster group inside.

## Supplies (14)

*Medical:* Bandage (1), Painkillers (2), Antibiotics (3), First Aid Kit (3)
*Material:* Scrap Metal (1), Wire (1), Duct Tape (2), Tools (2), Engine Parts (3), Radio Parts (3), Riot Gear Fragment (4)
*Food:* Canned Food (1), Water Filter (3)
*Fuel:* Fuel (2)

*(number = rarity, 1 common → 5 rare)*

These are the voxel game's resource economy. Note it's **scavenged, not mined** — which is a real departure from Minecraft and a better fit for the setting. You break open lockers and cars, you don't dig ore.

## Craftables (6)

| Item | Materials | Craft lvl | Equippable |
|---|---|:--:|:--:|
| Molotov Cocktail | Fuel, Duct Tape | 2 | — |
| Reinforced Bat | Scrap Metal, Wire | 2 | ✓ |
| Medkit | Bandage, Antibiotics, Painkillers | 3 | ✓ |
| Improvised Armor | Scrap Metal, Duct Tape, Wire | 4 | ✓ |
| Vehicle Repair Kit | Engine Parts, Duct Tape, Tools | 4 | ✓ |
| Radio Beacon | Radio Parts, Wire, Tools | 5 | ✓ |

**Equipment bonuses** (`equipment.go`), 3 slots — weapon / armor / accessory:

```
Reinforced Bat      strength +2
Improvised Armor    stamina +3
Medkit              stamina +1
Radio Beacon        scouting +2
Vehicle Repair Kit  salvaging +2, crafting +1
```

## Vehicles (6)

| Vehicle | Speed | Capacity | Condition | Fuel |
|---|:--:|:--:|---|:--:|
| Motorcycle | 9 | 2 | operational | ✓ |
| Pickup Truck | 6 | 4 | operational | ✓ |
| Armored SUV | 5 | 5 | operational | ✓ |
| Rusty Sedan | 5 | 4 | damaged | ✓ |
| School Bus | 4 | 20 | damaged | ✓ |
| Bicycle | 4 | 1 | operational | — |

**Vehicles are a big deal for the voxel port.** Minecraft-likes rarely have driveable cars, and "four players in a pickup truck escaping a horde down an overgrown highway" is a *marketing shot*. Capacity maps directly onto co-op party size. Wrench Witch finally has a reason to exist in 3D.

## Progression

```
XP to next level = level × 100
Level up         = +4 MaxHP, HP restored to full
Inventory        = 20 slots (Hoarder 25)
Equipment        = 3 slots
```

Starting HP isn't set in `model.go` — check `generator.go` and pin it during the port.

## The Ollama layer

Six AI-narrated prompt types, all sharing the campy tone prefix, all with hardcoded fallbacks if Ollama is down:

- Sphinx riddles (with a one-word answer)
- Building entrance narration
- Monster dialogue when a group spots you

This is the most distinctive thing M20 has and it's **the hardest thing to rebuild**. Strong recommendation: don't port it — **keep the Go service running as a narration sidecar** and have the Godot server call it over HTTP. See `06-porting-strategy.md`.

## Map & party mechanics (from Sprint 3)

- 5×5 fog grid; draw two tile cards, place one
- After 5 tiles placed, 25% chance a drawn card is the **Exit Tile** (🚪) with the Windego Den boss
- Party of **up to 4** characters, each persisted separately
- Initiative: everyone rolls d20 + Scouting; monsters roll d20 + Attack; Gunslinger gets +10 so it always goes first; monsters target the lowest-HP character

**Note on party size:** canon is 4. You asked for 1–8 players. The Gunslinger's "+10 always acts first" doesn't survive contact with 8 players (two Gunslingers is a coin flip, and it makes the class mandatory). Real-time voxel combat mostly dissolves the initiative system anyway — flag as a design decision in the port.
