# Bestiary — Doc M's collection

> Status: draft v0.1 — 2026-08-08
> Canon stat blocks: `05-m20-canon.md` · Damage types: `07-arsenal.md`

## The framing that makes the roster work

Doc M built every monster in this world, and **he is a B-movie fan.** That's the in-fiction reason folkloric creatures stand next to 50s drive-in schlock — he didn't design a coherent ecosystem, he recreated his favorite films. A Wraith haunts the hospital and a Killer Tomato bounces through the supermarket because he liked both movies.

This turns what would be a tonal mishmash into a **deliberate joke**, and it means we can add basically anything as long as it would plausibly play at a 1954 drive-in.

## Monsters become loot bags

**No monster dies. They decompile.**

When defeated, a monster stops, freezes, and pops — a small burst of confetti and static — leaving a **bag of loot** on the ground with a little tag on it. Because they were never alive; they're Doc M's constructs, and he recycles.

Why this is the right call:

- Solves "not gory" completely and permanently. No corpses, no blood, ever.
- Makes the reward loop **physical and visible**, the same way the dice are. You see the bag land.
- Bags can be **kicked, carried, and thrown**, which is instantly a co-op toy. Punt the bag back to base.
- In an 8-player horde night, a floor covered in loot bags reads as *triumph* far better than a damage counter.
- Diegetically justifies why loot appears at all.

**Implementation notes:** bags persist ~2 min then get collected by Doc M ("waste not"). Cap concurrent bags and merge nearby ones into a bigger bag during hordes — both for performance and because one huge bag is more satisfying than forty small ones.

Bag contents come from the monster's existing loot table plus the building's. Rare "Overstuffed" bags on crit-kills.

## Tier 1 — Canon Ten (folkloric)

Unchanged from M20. Full stats in `05-m20-canon.md`. These stay the backbone.

| Monster | HP | Atk | Def | Weak to | Notes |
|---|--:|--:|--:|---|---|
| Zombie | 8 | 1 | 8 | Fire, Holy | The mook. Herds. |
| Mummy | 12 | 3 | 11 | **Fire** | Dry wrappings. Fire is devastating. |
| Werewolf | 14 | 4 | 12 | **Silver** | Resists everything else. |
| Wraith | 15 | 6 | 14 | Magic Water, Silver | **Immune to Blunt** — incorporeal. |
| Vampire | 16 | 5 | 14 | **Holy Water**, Fire | Burns in daylight. |
| Basilisk | 18 | 6 | 13 | Shock | Don't look at it. |
| Frankenstein | 20 | 5 | 10 | Fire | ⚡ **Shock HEALS it.** Classic gotcha. |
| Golem | 25 | 4 | 16 | **Water** (softens clay), Blunt | Slow, enormous Defense. |
| Sphinx | 22 | 7 | 15 | — | **Riddle, not combat.** Ollama-driven. |
| **Windego** | **30** | **8** | **17** | **Fire** | **Boss.** A cold thing. Guards the exit. |

The affinity spread is deliberate: a player who only ever brings the water gun will hit a wall at the Werewolf, get humiliated by the Wraith, and *heal* Frankenstein's monster if they've got batteries in.

## Tier 2 — Americana (new)

B-movie, drive-in, Saturday-matinee. Public-domain-safe creature *types*, not film characters.

### Suburbs & lawns
| Monster | Behavior | Gimmick |
|---|---|---|
| **Killer Tomato** | Bouncy, harmless-looking, arrives in numbers | Splits into two smaller ones when popped |
| **Lawn Gnome** | Tiny, chucks garden tools from range | Very high Defense, trivial HP — pure irritation |
| **Scarecrow** | Motionless until you're close | Ambush; Fire-vulnerable, obviously |
| **Killer Bees** | Swarm cloud, not a single body | Only AoE works — balloons shine here |

### Sci-fi & the skies
| Monster | Behavior | Gimmick |
|---|---|---|
| **Martian Scout** | Hovers above melee reach, ray gun | Forces a dodge check; drops the best tech loot |
| **Flying Saucer** | Mid-air miniboss, beams monsters in | Must be grounded with Shock before you can hurt it |
| **Brain in a Jar** | Floats, never attacks directly | Mind-controls another monster; kill the jar to free it |
| **Pod Person** | Perfectly mimics a friendly NPC | Scouting check to spot early. Ambushes if you miss. |

### Labs & basements
| Monster | Behavior | Gimmick |
|---|---|---|
| **The Ooze** | Slow, absorbs blocks it touches and grows | Eats your base. Can't be walled out — must be fought. |
| **Evil Doll** | Plays dead among your own decorations | Free crit if it gets you. Genuinely unsettling in a cute game. |
| **Giant Ant** | Burrows through terrain, swarms | Ignores walls — your base needs depth, not height |
| **Radioactive Spider** | Wall-crawler, drops from ceilings | Webs slow you; Fire clears webs |

### Carnival & the deep
| Monster | Behavior | Gimmick |
|---|---|---|
| **Carnival Clown** | Fast, erratic, laughing | Throws pies that blind. Yes, pies. |
| **Bog Gulper** | Lurks in water, drags you in | 💧 **Immune to Water.** Punishes single-weapon players. |
| **Fifty-Foot Kid** | Miniboss. Stomps, wrecks terrain | Full boss bar; scales hardest with player count |
| **Mutant Fish Swarm** | Water-only, fast | Can't leave water — a hazard, not a hunter |

Each needs a full stat block in `data/monsters/` matching the canon JSON shape (`hp`, `attack`, `defense`, `xp_reward`, `description`, plus new `weak_to` / `immune_to` / `heals_from`).

**Add them to monster groups too.** The existing group system is the best content mechanism you have — *Supermarket: Produce Section* (Killer Tomatoes) writes itself, as does *Auto Repair Shop: The Ant Farm*.

## Trademark guidance

You said "open on their trademarks," so here's the practical line — this is general guidance, not legal advice, and worth a lawyer's eye before you charge money.

**Generally safe:** *creature types* described generically. Giant ant, blob/ooze, pod person, martian, flying saucer, evil doll, killer clown, scarecrow, brain in a jar, giant spider, swamp creature, fifty-foot giant. These are genre furniture, used across hundreds of unrelated works.

**Safe by age:** creatures from works whose copyright has expired — Shelley's *Frankenstein* (1818), Stoker's *Dracula* (1897), classical folklore. All ten canon monsters are in this bucket, which was a good call.

**Care needed — two specific traps:**

1. **"Killer Tomatoes."** The *creature* (an aggressive tomato) is a generic idea and fine. The **franchise name** is a live trademark. Safe move: keep the monster, avoid titling anything "Attack of the Killer Tomatoes," and consider a slightly distinct in-game name — *Rampage Tomato*, *Vine Horror*, or just **"Tomato"** with the description doing the joke.

2. **Your existing Frankenstein.** The novel is public domain, but the **flat head, neck bolts, and green skin are Universal's 1931 makeup design** and still protected. Since we're chibi-fying everything anyway, give him a visibly different silhouette — mismatched limbs, visible stitching, an exposed clockwork bit. The existing description already says "assembled from the best parts of the worst people," which points somewhere better than the Karloff look.

**Avoid outright:** named slashers (Freddy, Jason, Michael, Leatherface, Chucky), Gremlins/Critters/Ghoulies, and the Creature from the Black Lagoon's specific design — hence "Bog Gulper" above rather than "Gill-Man."

**Rule of thumb:** describe the monster to someone who's never seen the film. If your description still works, you're on generic ground. If you have to name the movie, rename the monster.

## Where Doc M fits

He narrates the collection. Every monster group entrance is him introducing his own creation with far too much pride — and Ollama already does exactly this via `MonsterDialogue` and building-entrance narration. His commentary is where the B-movie references live *safely*: he can gush about "a picture I saw in '54" without us ever naming it.
