# The Arsenal — soft weapons, damage types, mods

> Status: draft v0.1 — 2026-08-08

## The idea

**Nothing in this game is lethal, because none of it is real.** Doc M built a training world; he doesn't hand out guns, he hands out toys. You fight monsters with a water gun, water balloons, and a bat. The one genuinely dangerous thing in your kit is the Molotov, and that's because you insisted.

This is the ZAMN reference done properly — that game's starting weapon was a squirt gun — and it's the mechanical expression of pillar #2 (campy, not grim). It also makes every other soft decision consistent: monsters pop into loot bags, you respawn in bed, and your primary weapon is a Super Soaker full of glowing water.

## Damage types

Five types. This is what turns a cute arsenal into a *tactical* one — you can't just spray everything.

| Type | Source | Feel |
|---|---|---|
| **Water** | Water gun, balloons | Magic water. The default. Glows faintly. |
| **Shock** | Battery-modded gun or balloons | Arcs between close targets. Blue crackle. |
| **Fire** | Molotov | Lingering ground burn. The only AoE-over-time. |
| **Blunt** | Reinforced Bat, melee | Reliable, no ammo, short range. |
| **Silver** | Silvered ammo / silvered bat | Rare. Specifically counters a few things. |

Monster affinities live in `08-bestiary.md` — but the short version is that Frankenstein's monster **heals from shock**, the Wraith ignores **blunt** entirely, and the Bog Gulper is **immune to water**, which is a rude surprise for anyone who only brought the squirt gun.

## Weapons

### Water Gun (primary)

The signature weapon. Marksmanship-based.

- Pressurized tank with a visible water level — reload by pumping, or refill at any water source.
- Fires a readable arc, not a hitscan beam. You lead your shots.
- On hit, the d20 tumbles out of the *splash*, not the gun.
- Holding the trigger charges a heavier soak; tapping is faster and cheaper.

**Ammo types** (swap tanks):

| Tank | Effect |
|---|---|
| Plain Water | Weakest. Free, refill anywhere. |
| **Magic Water** | Standard. Doc M's own formula. Glows. |
| Holy Water | Bonus damage vs. undead — Zombie, Mummy, Vampire, Wraith |
| Brackish/Salt | Bonus vs. slime and plant types |
| Silvered | Bonus vs. Werewolf. Scarce. |

### Water Balloon (thrown / AoE)

The grenade slot. Lobbed arc, splash radius, brief slow on hit.

- Cheap to craft, stack high, spend freely.
- Great for the horde nights, which is exactly when spawn-count scaling makes crowds.
- **Modifiable** — see below.

### Molotov Cocktail (canon, kept)

Already in M20 (`Fuel + Duct Tape`, crafting level 2). The one genuinely destructive thing you own, and Doc M is visibly uneasy about it.

- Shatters into a lingering ground fire.
- Fire is the counter to Mummies (dry wrappings), the Windego (a cold thing), and anything plant-based.
- **New crafting chain, per your request:** Sand → smelt → **Glass Bottle** → + Fuel + Rag/Duct Tape → Molotov. Sand becomes a real gatherable resource, which gives beaches, playgrounds, and construction sites a reason to exist on the map.

### Reinforced Bat (canon, kept)

`Scrap Metal + Wire`, crafting level 2, Strength +2. No ammo, always works, feels good. The fallback when your tank runs dry.

## The mod system

Your batteries idea generalizes nicely into a small, extensible attachment system. Mods are **crafted from canon supplies** and slot onto the water gun or the balloons.

| Mod | Materials | On the gun | On a balloon |
|---|---|---|---|
| **Battery Pack** | Wire + Scrap Metal | Water becomes **Shock**; arcs to one nearby target | Shock burst on impact, chains between clustered monsters |
| **Pressure Tank** | Engine Parts + Duct Tape | +damage, +range, slower refire | — |
| **Wide Nozzle** | Scrap Metal + Tools | Cone spray, less damage per target, hits crowds | — |
| **Sand Weight** | Sand + Duct Tape | — | Longer throw, tighter splash |
| **Slow Leak** | Wire + Duct Tape | — | Leaves a puddle; puddles conduct Shock |

**The combo worth designing around:** a Slow Leak balloon lays a puddle, then a Battery-modded shot electrifies it and chains through everything standing in it. That's a two-item combo a player can discover on their own, which is exactly the kind of thing that makes a co-op group feel clever.

Mods should be **swappable at a workbench, not consumed** — so experimenting is free and nobody hoards.

## Crafting additions

New recipes to sit alongside M20's canon six:

| Item | Materials | Craft lvl |
|---|---|:--:|
| Glass Bottle | Sand (smelted) | 1 |
| Water Balloon (×3) | Scrap Rubber + Wire | 1 |
| Magic Water refill | Water + ??? *(Doc M's formula — a quest item)* | 2 |
| Battery Pack | Wire + Scrap Metal | 2 |
| Molotov Cocktail | **Glass Bottle** + Fuel + Duct Tape | 2 |
| Holy Water | Water + *consecrated something* | 3 |
| Pressure Tank | Engine Parts + Duct Tape | 3 |
| Silvered Ammo | Silver Scrap + Water | 4 |

Two new base materials required: **Sand** (gatherable terrain) and **Scrap Rubber** (salvaged from tires — which pairs with the existing Auto Repair Shop and vehicle wrecks). Both fit the existing scavenging economy without straining it.

> **Note:** the canon Molotov recipe is `Fuel + Duct Tape`. Adding Glass Bottle is a deliberate change — it gives sand a purpose and makes the Molotov feel *built*. Update the Go `supplies.go` too so the two games stay in sync.

## Progression through the arsenal

Not tiers of "bigger sword." Tiers of **options**:

1. **Early** — Plain Water, Bat. You have two answers to everything.
2. **Mid** — Magic Water, balloons, Molotovs, first mods. You start choosing loadouts per building.
3. **Late** — Holy/Silvered/Shock, combo mods. You *plan* for a specific monster group before you walk in.

Doc M comments on your loadout choices. He has opinions.

## Why this is better than swords

Worth stating, since "water gun" sounds like a downgrade:

- **It's funnier**, and funny is a pillar.
- **It's non-lethal**, which makes loot bags and cozy death coherent instead of arbitrary.
- **Ammo and refills** create a resource loop that melee doesn't.
- **Elemental typing** gives eight classes and ten-plus monsters something to interact with.
- **It's the ZAMN reference**, and it's the first thing anyone will notice in a screenshot.
