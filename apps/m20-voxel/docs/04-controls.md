# Controls & Controller Support

> Status: draft v0.1 — 2026-08-08
> **Constraint: the game must be fully playable on an Xbox controller.** Not "supported later" — designed for from M1.

## Why this is a day-one decision

Controller support is cheap if you decide now and brutally expensive if you retrofit. The reason is almost entirely **inventory and crafting UI**.

Every survival-craft game that added gamepad support late ended up with a virtual mouse cursor you push around a grid with the stick. It is universally awful. It happens because the UI was built around drag-and-drop, and drag-and-drop has no good controller equivalent.

So the rule is:

> **No drag-and-drop. Anywhere. Ever.**

Inventory management is *verbs on a selected slot* (Move, Split, Drop, Equip), not dragging. That works identically with a mouse and a d-pad, and it's actually faster on both. If we hold this line from M1, controller support is nearly free. If we break it, M6 becomes a UI rewrite.

Secondary reason: this is a cute co-op couch-friendly game about hitting monsters with a stick. Controller is arguably the *primary* input, not the fallback.

## Xbox mapping (v1)

| Input | Action |
|---|---|
| Left stick | Move |
| Right stick | Camera |
| L3 | Sprint (toggle) |
| R3 | Crouch |
| **RT** | Attack / mine (hold to mine) |
| **LT** | Block / aim (ranged) |
| **RB** | Place block / use item |
| **LB** | Interact |
| **D-pad ←/→** | Cycle hotbar |
| **D-pad ↑** | Radial: quick-craft |
| **D-pad ↓** | Radial: emote |
| A | Jump |
| B | Back / cancel |
| X | Reload / swap tool |
| Y | Character sheet |
| View (⧉) | Inventory |
| Menu (☰) | Pause |

**Rebindable.** All of it. Use Godot's `InputMap` actions exclusively — never check a hardcoded key or joypad button anywhere in gameplay code. This is a hard rule; it's the other thing that's painful to fix later.

## UI patterns that work on both

| Need | Pattern | Why |
|---|---|---|
| Inventory | Grid with **focus-based navigation** (d-pad/stick moves focus) + a verb menu on A | No cursor. Godot has built-in focus neighbors — use them. |
| Moving items | Select slot → A → "Move to…" → pick destination | Works with mouse too. Faster than dragging, honestly. |
| Split stack | Select → X → stick left/right sets amount | One-handed, no precision needed |
| Crafting | Vertical recipe list, d-pad scrolls, A crafts, hold A crafts ×10 | Lists beat grids on a controller |
| Hotbar | Bumpers/d-pad cycle; radial menu for the full set | Standard, learnable |
| Quick actions | **Radial menus** (hold d-pad, flick stick) | The controller-native answer to a toolbar |
| Block placement | Crosshair raycast, same as mouse | Already cursor-free — no work needed |

## Combat feel on a stick

The d20 system is unusually kind to controllers here — it's not a twitch-aim game. But:

- **Soft target assist on melee.** Slight snap toward the nearest valid target within the swing cone. Tune it invisible. Mouse players get a weaker version so it's not an unfair advantage in co-op.
- **Ranged gets aim assist**, tunable in settings, off by default for mouse.
- **No precision-timing requirements.** No parry windows tighter than ~250ms.
- **Rumble is a real feedback channel** and we should use it hard:
  - Light tick when a die leaves the weapon
  - Sharp thump when it lands
  - **Big double-pulse on a natural 20**
  - Low sad buzz on a natural 1
  - This makes the dice feel physical in your hands, which is exactly pillar #1. Free juice.

## 10-foot UI

Assume someone is playing on a TV from a couch.

- Minimum body text ~24px at 1080p. Test by standing back from the monitor.
- High contrast. Never convey information by color alone.
- **The dice are already perfect for this** — they're big, in-world, and readable at distance. That's a real advantage of the design over a damage-number-in-the-corner approach. Protect it: keep dice large and don't shrink them for "realism."
- Safe-area margins on all HUD elements (5% inset).

## Glyphs

Show the right button prompts for the connected device — Xbox glyphs for Xbox pads, PlayStation for DualSense, keys for keyboard. Detect via Godot's joypad API and swap a glyph atlas. Cheap, and its absence looks amateur immediately.

Detect on input, not on connect: if someone touches the keyboard, switch to keys; if they touch the pad, switch to glyphs. Silent, no setting needed.

## Accessibility (mostly free if done now)

- Full remapping (already required above)
- Toggle vs. hold for sprint/crouch/block
- Adjustable stick deadzone and sensitivity, separate X/Y
- Camera shake slider (the nat-20 shake will bother some people — don't make them choose between the juice and comfort)
- Subtitles for monster audio cues
- Colorblind-safe dice colors: differentiate damage types by **shape and pip pattern**, not just hue

## Implementation notes

- Everything through `InputMap`. No exceptions.
- Build the UI with Godot `Control` nodes and set `focus_neighbor_*` properly from the start.
- Test every UI screen with the mouse unplugged. Make this part of the M1 done-criteria.
- The **Steam Deck** is effectively free once this works, which is a nice bonus for a downloadable indie game.

## Couch co-op — parking lot

Local split-screen is a tempting fit for this game (cute, co-op, controller-first). It is also a significant rendering and networking change: multiple viewports, multiple `VoxelViewer`s in one client, doubled draw cost.

**Not in v1.** But the controller-first decision above keeps the door open, which is the point.
