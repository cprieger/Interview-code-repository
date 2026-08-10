# Gameplay Loop & the d20 System

> Status: draft v0.2 — 2026-08-08 (revised against real M20 canon)
> Rules authority: `05-m20-canon.md` · Port decisions: `06-porting-strategy.md`

## The loop

**Minute-to-minute (day):** search a wrecked car → roll Scavenging → find Scrap Metal → craft → fortify. Calm; dice only when something resists you.

**Minute-to-minute (night):** hear → position → **spray / lob / swing** → *dice tumble out of the splash* → read result → react → monster pops into a **loot bag**.

**Session (one in-game day, ~20 real minutes):**

1. Wake in bed. Sun's up over the suburb.
2. **Scavenge** — lockers, cars, pharmacy shelves, supermarket back rooms.
3. **Craft** — refill the water gun, blow up more balloons, smelt sand into a Glass Bottle for a Molotov, bolt a Battery Pack onto something. See `07-arsenal.md`.
4. **Build** — fortify the house you've claimed. Mine terrain for materials.
5. Dusk warning. Lights on, doors shut.
6. **Night assault** — monsters scaled to how many of you are online.
7. Survive or die. Death → Doc M rebuilds you in your bed. Keep your inventory.
8. Morning. Collect the loot bags scattered across the lawn, repair, bank XP, listen to his briefing.

**Long arc (10–20 hours):**
Push outward through the danger-rated biomes — Suburb (2) → City Block (3) → Hospital (4) → Military Outpost (4) → **Dungeon Entrance (5)**. Better supplies gate better craftables which gate deeper biomes. Punctuated by building bosses (Frankenstein's Lab, the Sphinx Chamber). Ends at the Windego, and you escape.

## Why the d20 works here

Minecraft combat is a solved, boring problem: click, cooldown, number. d20 resolution does three things:

1. **Variance creates stories.** "I crit the Golem with a Reinforced Bat" only happens with dice.
2. **It gives us a juice hook.** Every swing has a mini-payoff with a readable result.
3. **It makes stats legible.** +2 Strength isn't an invisible DPS tweak, it's a visible number on a visible die.

The risk is **fumble frustration** — a 5% whiff on every swing feels awful in an action game. See "Fumbles" below. This is the single biggest design risk in the project; prototype it in M2 and be willing to change the math.

## Characters — seven stats

**M20 uses seven wasteland stats, not D&D's six.** Base 3 in everything, plus class bonuses.

| Stat | Combat use | World use |
|---|---|---|
| **Strength** | Melee attack and damage | Mining speed, forcing doors, carry weight |
| **Stamina** | Effective HP; endurance | Sprint, resisting poison/disease |
| **Marksmanship** | Ranged attack | — |
| **Scouting** | Initiative, spotting ambushes | Perception — highlights containers, monsters, loot at range |
| **Scavenging** | — | Quality and quantity of container searches |
| **Crafting** | — | Gates recipes by level; crafting quality |
| **Salvaging** | — | Breaking wrecks and furniture down for parts |

Three of seven are non-combat. M20 was always half a survival-crafting game — which is exactly why the voxel port works.

## The eight classes

All canon. Full table with flavor text in `05-m20-canon.md`.

Scavenger · Medic · Gunslinger · Wrench Witch · Brawler · Conspiracy Theorist · Hoarder · Street Pharmacist

Two abilities need rework for real-time (see `06-porting-strategy.md`):

- **Gunslinger** — "always acts first" is meaningless without turn order, and breaks at 8 players. Proposed: **bonus damage on the first hit against an unaware target.** Preserves the fantasy, works in real-time, scales.
- **Medic** — "heal once per fight" has no meaning in an open world. Convert to a cooldown.

## The roll engine (canon)

Straight from `internal/game/combat.go`:

```
roll  = d20                        # 1–20
total = roll + stat + bonus

natural 1              → CRIT FAILURE
roll >= critThreshold  → CRIT SUCCESS      # 20 normally; Brawler 18
total >= target        → SUCCESS
otherwise              → FAILURE
```

**Four outcomes, not two** — and that's better than a plain hit/miss, because it maps onto four distinct dice presentations.

**`target` is the monster's `Defense`**, ranging 8 (Zombie) to 17 (Windego).

> ⚠️ In the current Go code, `target` is hardcoded to 10 and `Monster.Defense` is never read — so a Zombie is exactly as hard to hit as a Windego. **The voxel version must use Defense.** Worth fixing upstream too.

**Monsters attack** with `d20 + Attack` against the player.

**Monster stat block** — canon JSON shape, exported straight from Go:

```json
{
  "name": "Wraith",
  "hp": 15,
  "attack": 6,
  "defense": 14,
  "xp_reward": 180,
  "description": "The cold feeling you get before it's too late.",
  "has_riddle": false
}
```

**Progression** (canon): `XP to next level = level × 100`. Level up grants **+4 MaxHP** and full heal. Inventory 20 slots (Hoarder 25). Three equipment slots: weapon / armor / accessory.

## Fumbles — handle with care

A flat 5% "nothing happens" is the fastest way to make this feel bad. Rules:

- **A fumble is never a dead swing.** It always *does* something, just the wrong thing: you overswing and stumble, your bat takes a chunk out of a wall, you drop a torch. Comedic, not punishing — this is a campy B-movie, embarrassment is on-brand.
- **No durability loss on fumble.** Tempting; feels terrible.
- **Fumble streak protection.** Two fumbles in a row grants hidden advantage on the next roll. Never tell the player. It quietly kills the death spiral.
- **Test the alternative:** fumble = 25% damage ("glancing blow") rather than zero. Decide in M2 with hands on it.

## The dice, physically

This is the feature. Highest-craft part of the game.

**A swing, ~0.9s:**

1. `t=0` — swing starts.
2. `t=0.15` — a chunky d20 pops from the weapon tip, arcing and spinning.
3. `t=0.15–0.55` — it tumbles across the pavement with real-ish physics.
4. `t=0.55` — settles, face up, readable. Brief hitstop.
5. `t=0.6` — on a success, damage numbers fly up from where it landed.
6. `t≈2.5` — poofs into sparkles.

**The critical implementation rule:**

> **The server decides the number. The client animates a tumble guaranteed to land on it.**

Never let client physics determine the result — it desyncs across 8 players and it's trivially cheatable. Pick the result server-side, replicate it, play a freeform tumble, then blend the die's rotation to the correct face over the last ~120ms with a small hop to hide the snap. Nobody will notice.

**Four outcomes, four presentations:**

| Outcome | Treatment |
|---|---|
| **Crit success** (nat 20, or 18+ for Brawler) | Die turns gold mid-air, glows, 0.2s slow-mo, screen shake, confetti, monster comically launched, bouncy "CRIT!" |
| **Success** | Clean landing, satisfying thunk, damage number |
| **Failure** | Die lands grey and dull, small puff |
| **Crit failure** (nat 1) | Die cracked, sad trombone, you stumble, the monster taunts |

**Also:**

- **Advantage/disadvantage** — two dice roll, the discard fades out. Instantly readable. (Conspiracy Theorist's +3 riddle bonus, streak protection, etc.)
- **Saving throws** — when a monster forces one, *your* die rolls large and close to camera. Different framing, different stakes.
- **Rumble** — tick on release, thump on landing, double-pulse on a crit, low buzz on a nat 1. Makes the dice physical in your hands. See `04-controls.md`.
- **Dice skins as cosmetics** — craftable from scavenged junk. Bone, rusted scrap, hospital-plastic, cursed. Purely visual, cheap to build, enormously charming.

**Performance guardrail:** 8 players swinging at ~1Hz, plus monster attacks, is a lot of live rigidbodies. Pool them, cap concurrent dice around 40, and degrade gracefully — distant players' dice skip physics and just pop the result. Budget this in M2, not M5.

## Dice outside combat

Keeps the toy central. Uses the canon non-combat stats, which is exactly what they're for.

| Action | Check | Where the die appears |
|---|---|---|
| Searching a container | **Scavenging** vs container DC | Rolls out of the locker/trunk/shelf |
| Crafting | **Crafting** — sets quality tier | Rolls on the workbench |
| Breaking down a wreck | **Salvaging** | Rolls off the car |
| Spotting an ambush | **Scouting** | Rolls in front of you as you enter |
| Forcing a door / hard block | **Strength** | Rolls out of the door |
| **Sphinx riddle** | Scouting (+3 Conspiracy Theorist) | Big, close to camera, dramatic |
| Level up | HP gain | Rolls big, center screen |

Crafting fumbles are **funny outcomes, never material loss** — you get a Suspicious Medkit with a random buff and a random debuff. Never destroy the player's materials on a bad roll.

## Scavenging vs. mining

M20 scavenges. Minecraft mines. Resolution:

- **Mine terrain for building materials** — stone, wood, concrete. No roll, just time.
- **Scavenge containers for supplies** — the 14 canon supplies come from lockers, cars, shelves, and pharmacy back rooms, gated by a Scavenging roll.

Two clearly separated economies. Keeps the M20 identity while giving voxel players the digging and building they'll expect.

## Loot bags

Defeated monsters don't die — they **decompile**. Freeze, pop into confetti and static, leave a tagged bag on the ground. They were Doc M's constructs and he recycles.

- Bags are **physical objects**: carry, kick, punt, throw. Instantly a co-op toy.
- Contents = monster loot table + building loot table. Crit-kills can drop an **Overstuffed** bag.
- Persist ~2 minutes, then Doc M collects them ("waste not").
- **Merge nearby bags during hordes** — one big bag is both better performance and more satisfying than forty small ones.
- A yard covered in bags after an 8-player night reads as triumph far better than a damage counter would.

## Death & respawn

- Death → soft focus, fade, wake up **in your bed** with an "oof." Doc M rebuilt you, and he has opinions about how you went down.
- **Keep your inventory.** No corpse runs. He's testing you, not punishing you — taking your things would spoil the data.
- Cost: unbanked XP and the walk back.
- The bed is a **craftable anchor**; place more to shorten the walk. Respawn at the nearest.
- Multiplayer: a downed player is *downed*, not dead, for 20s — a teammate revives with a check. Rewards playing together and makes dice matter socially. **The Medic should be excellent at this.**

## Player-count scaling

Requirement: monster health and damage scale with players online. Canon tuning assumes a party of **4**; treat 4 as the balance target and 8 as the stretch.

Naive `× N` makes damage sponges, the least fun outcome. Four players don't deal 4× damage — closer to 6×, because they focus fire and nobody's ever repositioning alone. So:

```
N = players currently online (or in the local encounter)

hp     = base_hp    * (1 + 0.5  * (N - 1))      # 4p ≈ 2.5×, not 4×
damage = base_dmg   * (1 + 0.10 * (N - 1))      # gentle, capped at 1.5×
count  = ceil(base_count * (1 + 0.7 * (N - 1))) # MORE monsters, not tankier ones
```

- **Prefer count over stats.** A horde beats a sponge, and it's exactly right for zombies. Push most scaling into spawn count.
- **Damage scaling gentle and capped.** Getting one-shot because a friend logged in is infuriating.
- **Elites, not bigger numbers.** At N ≥ 4, a fraction of spawns are elite variants with an extra gimmick.
- **Never retroactively buff mid-fight.** Recompute on join/leave; apply to *newly spawned* monsters only. Exception: the Windego recalculates on join with an on-screen callout so it's legible.
- **Loot scales too.** More players must never mean less loot each, or people will kick friends to farm.

## The ending

M20 is called *Escape the Dungeon*, and the existing game already has the win condition: find the exit, beat the **Windego** (HP 30 / Attack 8 / Defense 17), get out.

Keep it. A voxel survival game you can actually *finish* is a real hook, and it matches the "not a live-service" anti-pillar. Post-escape, offer a free-play continue for people who just want to keep building.

## Open questions

- Fumble = zero damage or glancing blow? **Decide in M2, hands on.**
- Does Stamina drive a visible bar (better real-time feel) or stay purely a stat (matches canon)?
- Hunger system? Leaning no — fights the cozy pillar, and Canned Food can just be healing.
- Monsters: nightly waves, persistent building groups, or both? Leaning both.
- How much of the world is authored vs. procedural? Buildings should be authored, terrain procedural.
