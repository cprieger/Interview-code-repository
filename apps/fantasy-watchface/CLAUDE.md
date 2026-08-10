# CLAUDE.md — Fantasy Watchface ("Etched Stone / Glowing Rune")

Context file for `apps/fantasy-watchface/`. Loaded automatically when working in
this directory. Read this before touching the code — it captures hard-won,
non-obvious findings from this session that aren't visible from the source alone.

---

## What this is

A Garmin Connect IQ watch face for the **fenix 7X Pro Sapphire Solar** (same
target device as `apps/apache-watchface`), on branch `cprieger/fantasy-watchface-v1`,
branched fresh off `main`. It reuses apache-watchface V6's *layout methodology*
(fixed pixel matrix tuned for the real 280x280 panel, corner-distance bezel
verification, day/AOD bitmap pairs, divider-based field separation) but is a
**fully separate app with its own theme** — a WoW/LOTR-flavored "etched stone,
carved with a glowing rune" parchment-map look, not a version of the Apache app.
Same seven spec fields, same corners (center/TL/TR/BL/BR/BC/very-bottom) — see the
root `.claude/agents/mobius.md` design-spec table — just restyled.

---

## Local Environment

Identical to `apps/apache-watchface` — same SDK, same devices, same key, same JDK:

| Component | Path |
|---|---|
| Connect IQ SDK 9.2.0 | `C:\Users\Chris\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2\` |
| Device files (fenix7xpro + fenix7xpronowifi) + simulator fonts | `C:\Users\Chris\AppData\Roaming\Garmin\ConnectIQ\Devices\` |
| Developer signing key | `C:\Users\Chris\.garmin\developer_key.der` (outside any repo — never touch/commit) |
| Microsoft OpenJDK 17 | `C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot\` |

Compile + run loop (from `apps/fantasy-watchface/`, Git Bash):
```bash
export PATH="/c/Program Files/Microsoft/jdk-17.0.19.10-hotspot/bin:$PATH"
SDK_BIN="/c/Users/Chris/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2/bin"
"$SDK_BIN/monkeyc.bat" -o bin/fantasy-watchface.prg -f monkey.jungle \
  -y "/c/Users/Chris/.garmin/developer_key.der" -d fenix7xpro -w
```
```bash
"$SDK_BIN/simulator.exe" &            # start once, leave running
sleep 5
"$SDK_BIN/monkeydo.bat" bin/fantasy-watchface.prg fenix7xpro
```
`monkeydo` prints nothing and holds the connection open on success; it prints an
`Error:` block and exits immediately on a runtime crash. Silence after a few
seconds means it's running clean.

Screenshotting: native Win32 `PrintWindow` (see `apps/apache-watchface/CLAUDE.md`
for the exact PowerShell snippet — identical here, `*simulator*` process match).

---

## Finding 1: the 128KB memory ceiling + the declared-`<palette>` lesson

This device's watchFace runtime memory ceiling is a **hard 131072 bytes (128KB)**
— confirmed via the SDK's `compiler.json` `appTypes[].memoryLimit` for
`type=watchFace`.

**RGB222 devices import every bitmap at full 8bpp by default**, regardless of how
few colors the source PNG actually uses (confirmed against the SDK's own
`docs/Connect_IQ_FAQ/How_Do_I_Optimize_Bitmaps.html`) — a naive 280x280 background
image would cost ~76.6KB, more than half the entire budget, for one image. The
only fix is an **explicit `<palette>` declaration** in `resources/drawables/drawables.xml`
on the specific `<bitmap>` tag:
```xml
<bitmap id="BackgroundMap" filename="hud/background_map.png" dithering="none">
    <palette disableTransparency="true">
        <color>FFFFAA</color>
        ... (11 colors total, hex, no leading #)
    </palette>
</bitmap>
```
`disableTransparency="true"` + ≤16 colors packs at 4bpp instead of 8bpp
(280*280*0.5 = 39,200 bytes, ~38.3KB, instead of ~76.6KB). `dithering="none"`
avoids Floyd-Steinberg noise, which is wrong for flat map/parchment art anyway.

The 11-color `PALETTE` list in `tools/generate_background.py` is the single
source of truth and **must stay byte-for-byte in sync** with the `<palette>`
block in `drawables.xml` — any color used in the Python script that isn't
declared there gets silently snapped to the nearest declared color.

**Measured result**: the live simulator status-bar readout (bottom-left) showed
comfortably under budget with the full view logic + `LoreText`'s 37-entry array +
every icon wired in — see README.md for the exact number from the final pass.

---

## Finding 2: RGB222 is a 64-color hardware grid, separate from the memory issue

This device's **hardware** is RGB222 — only 64 real colors ever exist on the
physical panel, 4 levels per channel: `{0, 85, 170, 255}`. Every color, bitmap or
vector, gets silently hardware-snapped to the nearest of those 64, regardless of
what continuous RGB888 value you specify in code or a PNG.

This was caught for real, not just reasoned about: an early background draft used
continuous "nice in Pillow" tans (e.g. `RGB(232,212,168)`) that are **not** on
that grid. The nearest hardware color turned out to be bright **pink**
(`255,170,170`) — confirmed by an actual simulator screenshot (parchment
rendered salmon-pink, forest rendered grey instead of green).

**Every color constant in this app — both Python generator scripts and every
Monkey C color literal — must be built from `{0,85,170,255}` per channel.** The
theme's core palette (already grid-safe, `source/ColorScheme.mc`):

| Constant | Hex | Channels |
|---|---|---|
| `STONE_DAY` | `0xAAAAAA` | 170,170,170 |
| `STONE_DAY_DETAIL` | `0x555555` | 85,85,85 |
| `RUNE_DAY` | `0x55AAFF` | 85,170,255 |
| `STONE_AOD` | `0x555555` | 85,85,85 |
| `RUNE_AOD` | `0x0055AA` | 0,85,170 |
| `HEART_RED` | `0xAA0000` | 170,0,0 |
| `SOLAR_GOLD` / `SOLAR_AMBER` | `0xFFAA00` / `0xFF5500` | grid-safe |
| `ALERT_RED` | `0xFF0000` | 255,0,0 |

If you ever add a new color anywhere in this app, pick it from that grid first —
don't eyeball an RGB888 value and assume it'll render as expected.

---

## Finding 3 (this session, real bug): `Dc.getTextDimensions()`'s reported HEIGHT is unreliable for small vector-font sizes — use WIDTH, not height, for layout math

This is the biggest non-obvious finding from implementing the Lore Text field,
and it will bite again if a future pass adds another multi-line text block.

**What happened**: the Lore Text field (word-wrapped, 3 lines, `Fonts.loreFont()`
requesting a 7px `Graphics.getVectorFont()` size) was laid out using
`lineH = dc.getTextDimensions("Ag", stoneFont)[1] * 1.05` as the per-line
vertical pitch. A real screenshot showed the 3 lines spilling ~30px past their
allocated box, visibly crossing the divider below and overlapping the Steps/Solar
row's text.

**Root cause, confirmed by directly probing `getTextDimensions()` on-device** (a
temporary debug overlay drew the measured height for several font sizes):
requesting `Graphics.getVectorFont({:face=>"sourceSansPro", :size=>N})` for
**N = 5, 6, 7, 8, 12, 16, and 24 all measured the exact same reported height
(19px)** via `getTextDimensions("Ag", font)[1]`. Only at N=34 (the clock's size)
did the reported height jump to a different value (79px) — i.e. the *measurement*
clusters at a small number of discrete tiers rather than scaling continuously
with the requested size, at least for this face/device/SDK-version combination.
**WIDTH measurements did scale sensibly** with each requested size (used
successfully for word-wrap — line breaks land at sensible word boundaries) — this
is specifically a HEIGHT-measurement quirk, not a general font-loading bug, and
not the same issue as the "font resource must be BMFont, not TTF" gotcha
documented in `apps/apache-watchface/CLAUDE.md` (that's about `<font>` XML
resources; this is about `Graphics.getVectorFont()`, a different API, behaving
correctly for `drawText()` rendering itself — the clock, date, and every other
field render at their intended relative sizes — but not for
`getTextDimensions()`'s height return specifically).

**Fix shipped**: `FantasyWatchFaceView.drawLoreBox()` does **not** trust
`getTextDimensions()`'s height for line-spacing. It uses a fixed,
screenshot-verified `LORE_LINE_PITCH` constant instead (currently `10.0`px,
tuned by direct visual inspection of a zoomed screenshot at the longest lore
entry, not computed). Width measurements (`dc.getTextDimensions(candidate,
font)[0]` inside `wrapLoreText()`) are still used and are trustworthy.

**If you add another multi-line text field to this app** (or port this pattern to
another watch face): don't assume `getTextDimensions()[1]` gives you an accurate
per-line pitch at small vector-font sizes on this device. Verify empirically
first — add a temporary debug overlay that prints the measured value next to a
few different requested font sizes, screenshot it, and only then decide whether
to trust the reported number or hardcode a verified pitch constant. A `BUILD
SUCCESSFUL` and even a `monkeydo` run with no `Error:` block will NOT catch this
— it's a silently-wrong layout, not a crash, exactly the failure mode
apache-watchface's own doctrine warns about ("compiles and runs clean, silently
wrong").

---

## The dual-layer "etched stone / glowing rune" text technique

The core visual signature of this theme (`source/ThemeText.mc` +
`source/Fonts.mc`). Monkey C vector fonts have **no weight axis** — there's no
API for "draw this bold" or "draw this thin" on a `Graphics.FontType`. The
approximation used here: draw the same text **twice**, dead-center on the exact
same anchor point —
1. once at the field's normal ("stone") size, in the stone color
   (`ColorScheme.stoneColor()` / `STONE_DAY` or `STONE_AOD`)
2. again at a **smaller** ("rune") size — `Fonts.RUNE_RATIO` (currently `0.82`)
   of the stone size, floored at 6px — in the rune color
   (`ColorScheme.runeColor()` / `RUNE_DAY` or `RUNE_AOD`)

The size delta (not a weight delta) is what reads as "a thinner, brighter rune
peeking through the carved stone outline" at a glance. Every text field on the
face (clock, seconds, date, tz2, steps/solar values+labels, battery %, heart
rate, footer squad, lore text) routes through the one shared
`ThemeText.drawDual()` call instead of duplicating the two-draw pattern at each
site — `Fonts.mc` exposes a `roleFont()` / `roleFontRune()` getter pair per
field role for this.

**0.82 ratio, chosen by real zoomed-screenshot comparison** — 0.90 read as
barely distinguishable from the stone layer (the "glow" nearly vanished); ~0.75
read as a blurry double-stroke rather than a distinct inner highlight. 0.82 was
the point where the rune layer reads as clearly smaller/brighter without
muddying the glyph. If you change any font role's base size significantly,
re-screenshot zoomed on that field to confirm the ratio still reads cleanly at
the new size — the "how big does 82% look" answer isn't perfectly scale-invariant
at very small sizes (see Finding 3 above — small-size vector font behavior on
this device already has one confirmed quirk).

**Battery/potion field is the one exception**: on critical charge
(`ColorScheme.isBatteryCritical()`, <15%), BOTH layers collapse to a single flat
`ALERT_RED` instead of a stone/rune pair — a real alert reads faster as one flat
unmistakable color than as a two-tone glow effect.

---

## The Lore Text field: wake-only update rule

**The selected fact index must change ONLY on the sleep→active wake
transition** — never on a plain `onUpdate()` redraw, never just because the step
count changed while already awake.

Implementation (`FantasyWatchFaceView.mc`):
- `_loreIndex` is an instance var, computed via `pickLoreIndex()` (digit-sum of
  the *current* step count, mod `LoreText.ENTRIES.size()` = 37, so any step
  count — not just 4-digit ones — lands safely in bounds).
- Set **once** in `onLayout()` (cold start — guarantees the very first render
  shows something before any sleep cycle has happened).
- Set **again, and ONLY again**, in `onExitSleep()` (the correct hook for the
  sleep→active transition — confirmed already correct in apache-watchface's own
  view).
- `onUpdate()` never calls `pickLoreIndex()` — it only ever renders
  `LoreText.get(_loreIndex)`, whatever that currently holds.

**Verify this behavior directly in the simulator, not just by reading the
code**: note the displayed fact, change the step count via the simulator's data
controls while staying awake, confirm the text does **not** change; then trigger
a sleep→wake cycle (Always-On toggle / simulator sleep simulation) and confirm
the text **does** change to reflect the new step count's digit sum. A test that
only checks "does `onExitSleep()` exist and call `pickLoreIndex()`" doesn't catch
a mistaken call left in `onUpdate()` too (there wasn't one here — verified — but
this is exactly the kind of one-line regression that's invisible in a diff review
and only catches your eye live in the simulator).

---

## Castle-wall dividers instead of plain lines

`HudDraw.drawWallH()` / `drawWallV()` replace apache-watchface's plain
`Dc.drawLine()` dividers with repeated `drawBitmap()` calls of the small
`wall_h_*` (14x8) / `wall_v_*` (8x14) repeat-unit tiles, tiled edge-to-edge at
their native pitch (14px) with no gap/overlap, clamped to never draw a tile that
would start past the divider's end coordinate. See `tools/generate_fantasy_icons.py`'s
`wall_h()`/`wall_v()` for the tile art itself (one stone course + one merlon per
horizontal tile; a stacked-block strip for the vertical tile).

---

## Potion battery fill

`potion_glass_{day,aod}.png` is outline-only by design (the bulb has no fill
baked in) — `HudDraw.drawPotionFill()` draws a dynamic proportional mana-fill
rectangle inside the bulb's actual inner ellipse bounds (re-derived from the
exact fractions the icon generator used: `bulb_cx=0.62*W`, `cy=0.52*H`,
`bulb_rx=0.30*W`, `bulb_ry=0.44*H` on the 34x18 canvas), inset to 0.62x the
ellipse's own radii so every corner of the fill rect is verified inside the
ellipse (`0.62² + 0.62² ≈ 0.77 < 1`) — it can never visibly cross the outline
stroke. Same "always show a 1px sliver above 0%, never nothing" convention as
apache-watchface's original battery fill.

---

## Git Workflow

Same convention as the repo root `CLAUDE.md`: never commit to `main` directly.
This app is on branch `cprieger/fantasy-watchface-v1`, branched fresh off `main`
(not stacked on `apache-watchface`'s branch — this is a separate app). Update the
root `CHANGELOG.md` with a dated entry before any commit/PR.
