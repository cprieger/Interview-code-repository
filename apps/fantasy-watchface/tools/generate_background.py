"""Generates the Fantasy Watchface's full-screen parchment-map background.

MEMORY CONSTRAINT THIS FILE IS DESIGNED AROUND (see CLAUDE.md/README for the
full derivation): the fenix 7X Pro's watchFace runtime memory budget is a
hard 131072 bytes (128 KB) TOTAL - not disk space, the decompressed
resource memory the whole app is allowed to use at once. This device is an
RGB222 (ARGB2222) product, and per Garmin's own bitmap-optimization guide
(SDK doc: docs/Connect_IQ_FAQ/How_Do_I_Optimize_Bitmaps.html), RGB222
devices IMPORT EVERY BITMAP AT FULL 8BPP BY DEFAULT regardless of how few
colors the source PNG actually uses - the resource compiler does NOT
auto-detect "this image only has 12 colors, I'll pack it smaller" on its
own. A full 280x280 image at 8bpp is 78,400 bytes - beyond half the ENTIRE
watch face memory budget for one image.

The lever that actually works: declaring an explicit <palette> block on
this bitmap's <bitmap> tag in resources/drawables/drawables.xml, e.g.:

    <bitmap id="BackgroundMap" filename="hud/background_map.png" dithering="none">
        <palette disableTransparency="true">
            <color>E8D4A8</color>
            ... (all colors below, hex, no leading #)
        </palette>
    </bitmap>

This forces the resource compiler to pack the image at the smallest bit
depth that covers the declared color count (opaque, so no +1 for
transparency): up to 16 colors -> 4bpp -> 280*280*0.5 = 39,200 bytes
(~38.3 KB) instead of 78,400 (~76.6 KB) at 8bpp. `dithering="none"` avoids
Floyd-Steinberg noise, which looks wrong on flat map/parchment art anyway
(it's meant for photos) - every pixel snaps hard to its nearest declared
palette color instead.

The 12-color PALETTE constant below is the single source of truth - it's
used both to draw this image AND must be copied verbatim (as hex, no #)
into drawables.xml's <palette> block. Keeping the drawing code's actual
colors and the declared import palette in exact sync matters: any color
used here that ISN'T in the declared palette gets silently snapped to
whichever declared color is closest, which could look wrong if forgotten.

Usage: python tools/generate_background.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = Path(__file__).resolve().parent.parent / "resources" / "drawables" / "hud"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SIZE = 280
SCALE = 2  # light supersampling for the large coastline/vignette curves only
random.seed(20260710)  # reproducible "hand-drawn" jitter

# ---------------------------------------------------------------- palette
# CRITICAL, discovered by actually running a first version of this image in
# the simulator (not assumed from any doc): this device's DISPLAY hardware
# is RGB222 - only 64 total colors EVER exist on the physical panel, 4
# levels per channel (0/85/170/255). Every color drawn anywhere, bitmap or
# vector, gets hardware-snapped to the nearest of those 64 regardless of
# what continuous RGB888 value you specify. A first draft of this palette
# used "nice in Pillow" continuous tans (e.g. 232,212,168) that are NOT on
# that 4-level grid - the closest hardware color to that tan turned out to
# be (255,170,170), a bright PINK, not a tan at all (confirmed by an actual
# simulator screenshot: the parchment rendered salmon-pink, land olive-grey,
# forest grey instead of green). This is a SEPARATE constraint from the
# bitmap bit-depth/memory issue documented below - fixing the palette
# declaration controls MEMORY, but only picking colors that already sit
# exactly on {0,85,170,255} per channel controls what actually RENDERS.
# Every color below is deliberately chosen from that 64-color grid so the
# Pillow preview and the on-device render match, instead of guessing.
PARCHMENT_LIGHT = (255, 255, 170)   # FFFFAA
PARCHMENT_MID = (255, 170, 85)      # FFAA55
PARCHMENT_DARK = (170, 85, 0)       # AA5500 (reused for the vignette ring too)
LAND_FILL = (170, 170, 85)          # AAAA55
INK_DARK = (85, 0, 0)               # 550000 - maroon-brown ink (coastline/mountains)
INK_MED = (85, 85, 0)               # 555500 - olive-brown ink (secondary lines)
FOREST_GREEN = (0, 85, 0)           # 005500
WATER_BLUE = (0, 170, 170)          # 00AAAA - teal (river/shallow water)
WATER_DEEP = (0, 85, 170)           # 0055AA
CREAM_HILITE = (255, 255, 255)      # FFFFFF
VIGNETTE_EDGE = PARCHMENT_DARK       # same grid color, no separate palette slot needed
INK_FINE = (0, 0, 0)                # 000000

PALETTE = [
    PARCHMENT_LIGHT, PARCHMENT_MID, PARCHMENT_DARK, LAND_FILL,
    INK_DARK, INK_MED, FOREST_GREEN, WATER_BLUE, WATER_DEEP,
    CREAM_HILITE, INK_FINE,
]


def _blob(d, cx, cy, r, jitter, n, color, alpha=255):
    """An irregular, hand-drawn-looking closed shape: n points around a
    circle of radius r, each perturbed by +/-jitter fraction, giving a
    coastline/landmass/forest-cluster silhouette instead of a perfect
    circle - real hand-drawn old maps never have perfectly round coasts."""
    pts = []
    for i in range(n):
        a = (i / n) * 2 * math.pi
        rr = r * (1.0 + random.uniform(-jitter, jitter))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    fill = color + (alpha,) if len(color) == 3 else color
    d.polygon(pts, fill=fill)
    return pts


def _river(d, points, color, width):
    d.line(points, fill=color, width=width, joint="curve")
    r = width / 2.0
    for (x, y) in (points[0], points[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def _mountain_range(d, cx, cy, span, height, n, color):
    """The classic "hairy caterpillar" cartography symbol for a mountain
    ridge: a row of small overlapping triangles along a ridge line."""
    step = span / n
    x0 = cx - span / 2
    for i in range(n):
        x = x0 + i * step
        h = height * random.uniform(0.7, 1.15)
        w = step * random.uniform(1.3, 1.7)
        d.polygon(
            [(x - w / 2, cy + h * 0.35), (x + w / 2, cy + h * 0.35), (x, cy - h * 0.65)],
            fill=color,
        )


def _compass_rose(d, cx, cy, r, color, accent):
    """Simple 8-point compass star - a common old-map cartouche motif.
    Placed at the top pole, the one part of this face's HUD matrix that's
    completely empty now that the AH-64E title banner is gone."""
    for i in range(8):
        a = i * math.pi / 4.0
        rr = r if i % 2 == 0 else r * 0.42
        x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
        d.line([cx, cy, x, y], fill=(accent if i % 2 == 0 else color), width=2)
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=accent)


def main():
    W = H = SIZE * SCALE
    img = Image.new("RGBA", (W, H), PARCHMENT_LIGHT + (255,))
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = W / 2, H / 2

    # --- base parchment mottling: a few large soft blotches, subtle ---
    for _ in range(6):
        bx = random.uniform(0.15, 0.85) * W
        by = random.uniform(0.15, 0.85) * H
        br = random.uniform(0.12, 0.24) * W
        tone = random.choice([PARCHMENT_MID, PARCHMENT_DARK])
        _blob(d, bx, by, br, 0.35, 10, tone, alpha=70)
    img = img.filter(ImageFilter.GaussianBlur(radius=SCALE * 3))
    d = ImageDraw.Draw(img, "RGBA")

    # --- landmass: wraps the lower-left, kept clear of the true center
    # (clock/date/tz2/lore-text column) and the top pole (compass rose) ---
    land_pts = _blob(d, W * 0.28, H * 0.66, W * 0.30, 0.28, 14, LAND_FILL)
    d.line(land_pts + [land_pts[0]], fill=INK_MED, width=max(2, SCALE * 2), joint="curve")

    # second, smaller landmass in the lower-right, same clearance logic
    land2_pts = _blob(d, W * 0.82, H * 0.80, W * 0.14, 0.30, 12, LAND_FILL)
    d.line(land2_pts + [land2_pts[0]], fill=INK_MED, width=max(2, SCALE * 2), joint="curve")

    # --- mountain range along the main landmass's interior ridge ---
    _mountain_range(d, W * 0.24, H * 0.58, W * 0.20, H * 0.05, 6, INK_DARK)

    # --- forest cluster near the coast ---
    _blob(d, W * 0.20, H * 0.76, W * 0.07, 0.4, 9, FOREST_GREEN)
    _blob(d, W * 0.16, H * 0.80, W * 0.045, 0.4, 8, FOREST_GREEN)

    # --- river: mountains down to the sea ---
    river_pts = [
        (W * 0.24, H * 0.60), (W * 0.30, H * 0.68), (W * 0.27, H * 0.76),
        (W * 0.33, H * 0.84), (W * 0.30, H * 0.92),
    ]
    _river(d, river_pts, WATER_BLUE, max(2, int(SCALE * 1.6)))

    # --- sparse open-water wave dashes, avoiding the dead-center HUD column ---
    for _ in range(22):
        wx = random.uniform(0.05, 0.95) * W
        wy = random.uniform(0.05, 0.95) * H
        if abs(wx - cx) < W * 0.16 and abs(wy - cy) < H * 0.30:
            continue  # keep the clock/date/tz2/lore-text column clear
        dist = math.hypot(wx - cx, wy - cy)
        if dist > W * 0.47:
            continue  # stay inside the visible bezel circle
        ww = random.uniform(0.02, 0.035) * W
        d.arc([wx - ww, wy - ww * 0.4, wx + ww, wy + ww * 0.4], 200, 340, fill=WATER_DEEP, width=2)

    # --- compass rose at the top pole (empty now that the title is gone) ---
    _compass_rose(d, cx, H * 0.115, W * 0.055, INK_DARK, CREAM_HILITE)

    # --- soft vignette ring near the true bezel edge ---
    for i, rad in enumerate(range(int(W * 0.46), int(W * 0.50), max(1, SCALE))):
        alpha = int(18 + i * 6)
        d.ellipse(
            [cx - rad, cy - rad, cx + rad, cy + rad],
            outline=VIGNETTE_EDGE + (alpha,), width=max(1, SCALE),
        )

    img = img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    out_path = OUT_DIR / "background_map.png"
    img.save(out_path)
    print(f"Wrote {out_path} ({SIZE}x{SIZE}, {len(PALETTE)}-color declared palette)")


if __name__ == "__main__":
    main()
