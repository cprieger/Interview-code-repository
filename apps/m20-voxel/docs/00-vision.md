# M20: Voxel — Vision

> Status: draft v0.2 — 2026-08-08 (revised against real M20 canon)
> Owner: Chris Rieger
> Canon reference: `05-m20-canon.md`

## One line

A cute co-op voxel survival game set inside a mad scientist's training world, where you scavenge, build, and fight B-movie monsters with a water gun — and every shot spits real dice onto the ground.

## The pitch

You wake up in a bed that isn't yours, in a world that used to be somebody's suburb. Collapsed concrete. An overgrown highway going somewhere probably bad. A gas station with the pumps dry and the shelves mostly full. Something is shambling around the school cafeteria.

A voice comes over an intercom that shouldn't exist. He introduces himself as Doctor Maxamillion, at length, to someone who did not ask. He's *delighted* you're here. He's been working on this.

You've been pulled into **M20** — Model 20, Doc M's twentieth attempt at a perfect challenge world — and the only way out is down. Scavenge the wrecks, craft a better water gun, fortify a house before dark, and fight the things he built out of his favorite drive-in movies. Every shot throws a d20 onto the pavement where everybody can see it. Every monster you beat pops into a bag of loot, because none of them were ever really alive.

Die and he just rebuilds you. He's not trying to kill you. He's trying to *teach* you, and he's insufferable about it.

Somewhere past the ruined malls there's a staircase with no light at the bottom, and something down there he didn't put there.

Play alone or with up to 8 friends. The world gets meaner the more of you there are.

## Pillars

Three things. If a feature doesn't serve one of these, cut it.

**1. Dice are the toy.**
The d20 system isn't a stat spreadsheet, it's a *physical, tactile, visible* thing. Every hit throws real dice into the world that tumble, land, and read out. The joy of a natural 20 is the joy of *seeing* the die land on 20. This is the thing nobody else has.

**2. Campy, not grim.**
M20's tone is already written into its code: *"a campy B-movie zombie apocalypse comedy — think Zombies Ate My Neighbors crossed with Army of Darkness. The monsters are scary but also ridiculous. The survivors are heroic but also kind of ridiculous too."* Chibi proportions, saturated palette, bouncy animation. A post-apocalypse that's fun to be in.

**3. Cozy → chaotic → cozy.**
Days are calm and constructive: scavenge, build, decorate. Nights are loud and dangerous. The rhythm between them is the whole game. Neither half works without the other.

**4. Nothing here is real, and that's why it's safe to be silly.**
Doc M built this world. That single fact justifies the water guns, the loot bags, the respawns, the visible dice, and the fact that a Wraith and a Killer Tomato share a map. See `09-doc-maxamillion.md` — it's the spine everything else hangs off.

## Anti-pillars

- **Not a Minecraft clone with a mod.** Dice change how combat *feels* at the input level. And you scavenge wrecked cars more than you dig holes.
- **Not hardcore survival.** No hunger death spirals, no inventory loss on death. Death costs time and dignity.
- **Not a live-service.** M20 is called *Escape the Dungeon*. This one should be finishable too.
- **Not gory.** No corpses, ever. Monsters pop into confetti and leave a bag of loot.
- **Not lethal.** Your primary weapon is a water gun. The Molotov is the one exception and Doc M has notes about it.
- **Not mouse-and-keyboard-first.** Full Xbox controller play is a requirement, not a port. See `04-controls.md`.

## The world

M20's setting is **suburban post-apocalypse**, and it's a much better voxel world than generic fantasy terrain. The ten canon tiles become the biomes:

| Biome | Danger | What it's for |
|---|:--:|---|
| Gas Station | 1 | Safe-ish. Fuel, vehicles, early supplies. |
| Overgrown Highway | 2 | Long traversal routes. Vehicles. Where car chases happen. |
| Abandoned Suburb | 2 | The starter zone. Houses to loot and to move into. |
| Forest Edge | 2 | Wood, quiet, something watching from the trees. |
| Ruined City Block | 3 | Dense verticality. Collapsed concrete and broken glass. |
| Underground Parking | 3 | Zero visibility, maximum echo. Vehicles below ground. |
| Shopping Mall | 3 | The big interior set piece. "Everything's 100% off." |
| Hospital | 4 | Medical loot, Frankenstein's Lab, the Wraith Wing. |
| Military Outpost | 4 | Best gear, worst neighbors. |
| Dungeon Entrance | 5 | "A staircase descends. There is no light below. This is the way." |

A blocky overgrown highway running through a ruined mall at dusk is a *look*. Lean into it.

## Art direction

| Element | Direction |
|---|---|
| World | Blocky voxels, ~16px textures. Faded concrete, rust, sun-bleached plastic — then *saturated* greenery reclaiming it. Not a brown wasteland. |
| Characters | Chibi. Big head, 2 blocks wide, stubby limbs. MagicaVoxel `.vox`. The eight classes must be silhouette-distinct. |
| Monsters | Same chibi scale, silhouette-first — you should ID a Wraith from a Zombie at 40 blocks in the dark. Goofy-menacing. |
| Dice | Chunky, oversized, glossy. Readable pips. Colored by outcome and damage type. |
| UI | Bouncy, hand-drawn, minimal. Character sheet like a photocopied survival pamphlet. |
| Lighting | Warm gold days, deep blue-purple nights. Rim-light monsters so they read in the dark. |
| Vehicles | Blocky but readable. A pickup truck must look like a pickup truck at a glance. |

**Pipeline:** Voxel Tools ships `VoxelVoxLoader`, so MagicaVoxel `.vox` imports directly. Free tool, fast iteration, correct aesthetic by default.

## Monsters

Full roster and stat blocks in `08-bestiary.md`. Two tiers, and Doc M's film-buff habit is the in-fiction reason they coexist.

**Tier 1 — the canon ten** (folkloric, unchanged from M20): Zombie · Mummy · Werewolf · Wraith · Vampire · Basilisk · Frankenstein · Golem · Sphinx · **Windego** (boss)

**Tier 2 — Americana** (new, drive-in B-movie): Killer Tomato · Lawn Gnome · Scarecrow · Killer Bees · Martian Scout · Flying Saucer · Brain in a Jar · Pod Person · The Ooze · Evil Doll · Giant Ant · Radioactive Spider · Carnival Clown · Bog Gulper · Fifty-Foot Kid · Mutant Fish

Standouts:

- **The Sphinx** doesn't fight — it asks a riddle, generated live by Ollama. Conspiracy Theorist gets +3 because *the Sphinx is a GOVERNMENT PROJECT* (she's wrong about the government and right that it's a project).
- **Frankenstein's monster heals from Shock**, the **Wraith ignores Blunt**, and the **Bog Gulper is immune to Water** — so a player who only ever brings the squirt gun hits a wall. See `07-arsenal.md`.
- **The Windego** guards the exit and is the win condition — and it's the one monster Doc M didn't build.

**Defeated monsters become loot bags.** They freeze, pop into confetti and static, and drop a bag you can carry, kick, or punt back to base. They were constructs; he recycles them. This is how we get "not gory" for free and make rewards as physical as the dice.

Monsters appear in **thematic groups** tied to buildings, each with written narrative setup — *Zombie Ward*, *Vampire Supplier*, *Golem Sentinels*, *Undead Stock Team*. Keep that text verbatim; it does enormous tone work for free. New groups for Tier 2 write themselves: *Supermarket — Produce Section*, *Auto Repair Shop — The Ant Farm*.

**Trademark note:** stick to generic *creature types*, not film characters. "Killer Tomatoes" is a live franchise trademark even though an aggressive tomato is a generic idea, and your existing Frankenstein needs a silhouette that isn't Universal's flat-head-and-neck-bolts design. Details and the safe/unsafe list in `08-bestiary.md`.

## What makes this not-Minecraft

Worth stating plainly, because it's the honest answer to "why play this instead":

1. **Visible dice.** Every action has a readable, physical, shared result.
2. **A water gun, not a sword.** Soft, funny, and elementally typed — Water, Shock, Fire, Blunt, Silver. Loadout matters.
3. **Loot bags, not corpses.** Rewards are physical objects you can punt across the yard.
4. **Scavenging over mining.** You search wrecked cars, lockers, and pharmacy shelves. Mining is for building materials; supplies come from the world people left behind.
5. **Driveable vehicles.** Four players in a pickup outrunning a horde down an overgrown highway.
6. **Eight real classes** with different stats and abilities, not a generic avatar.
7. **An AI-driven character** narrating your whole run in a consistent, improvising voice.
8. **An ending.** Find the Dungeon Entrance. Beat the Windego. Escape.

## Success criteria

1. A first-time player laughs out loud at their first natural 20 — before they understand the stat system.
2. Four players naturally split into scavenger / builder / fighter roles without being told to.
3. Someone posts a clip of a dice roll, not a base tour.
4. Someone quotes Doc M back at their friends.
5. Someone posts a clip of the school bus.
