"""Generates the icon set for the Fantasy Watchface (V1).

Same technique as apps/apache-watchface/tools/generate_hud_icons.py: drawn
at 4x supersample with Pillow, downsampled for anti-aliasing (Monkey C's
live vector fills have no AA on a real MIP display), day/AOD variants baked
separately since there's no runtime bitmap tint API.

Icon canvas sizes intentionally match apache-watchface's constants
(BOOT_W/H=36x32, BATTERY_W/H=34x18, HEART_W/H=28x28, etc.) so the "same
style and layout" ask can reuse that project's box-layout math directly -
only the art inside each canvas changed, not the box geometry.

Usage: python tools/generate_fantasy_icons.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT_DIR = Path(__file__).resolve().parent.parent / "resources" / "drawables" / "hud"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SCALE = 4  # supersampling factor for anti-aliasing

# ---------------------------------------------------------------- palette
# "Etched stone that glows with runes" - two families, used consistently
# across every icon and (in Monkey C) every text field:
#   STONE  - cool silver-grey, the "carved rock" surface
#   RUNE   - light glowing blue, the "magic peeking through the carving"
#
# CRITICAL: every value below is deliberately chosen from this device's
# actual hardware color grid - RGB222, only 64 real colors, 4 levels per
# channel (0/85/170/255) - not just "a nice-looking RGB888 value". A first
# draft of the background map (see generate_background.py's docstring)
# used continuous, off-grid tones that the hardware silently snapped to
# something completely different (a tan parchment rendered bright pink) -
# confirmed by an actual simulator screenshot, not assumed. These icon
# colors are small/simple enough that off-grid values wouldn't have looked
# AS broken, but picking exactly-on-grid values here avoids the same class
# of surprise and keeps this Pillow preview honest about what will
# actually render on device.
STONE_DAY = (170, 170, 170, 255)      # AAAAAA
STONE_DAY_DETAIL = (85, 85, 85, 255)  # 555555
RUNE_DAY = (85, 170, 255, 255)        # 55AAFF
STONE_AOD = (85, 85, 85, 255)         # 555555 (dimmer than day's 170-grey)
STONE_AOD_DETAIL = STONE_AOD          # AOD icons simplify to one flat tone -
                                       # only 0/85 are left below AOD's own
                                       # base grey on this 4-level grid, and
                                       # 0 would vanish against the black
                                       # background, so detail lines don't
                                       # get their own darker shade in AOD.
RUNE_AOD = (0, 85, 170, 255)          # 0055AA
TRANSPARENT = (0, 0, 0, 0)

# Field accents - still fit the cool stone/rune family rather than
# reintroducing a rainbow of hues (heart stays a deliberate warm exception,
# same as apache-watchface's battery-critical-red was its one exception).
HEART_RED = (170, 0, 0, 255)          # AA0000
HEART_RED_AOD = STONE_AOD  # AOD stays monochrome, same convention as before
DAGGER_STEEL = STONE_DAY
SOLAR_GOLD = (255, 170, 0, 255)       # FFAA00
SOLAR_AMBER = (255, 85, 0, 255)       # FF5500
MANA_BLUE = RUNE_DAY
MANA_BLUE_AOD = RUNE_AOD


def canvas(w, h):
    W, H = w * SCALE, h * SCALE
    img = Image.new("RGBA", (W, H), TRANSPARENT)
    return img, ImageDraw.Draw(img), W, H


def finish(img, w, h, name):
    img = img.resize((w, h), Image.LANCZOS)
    path = OUT_DIR / f"{name}.png"
    img.save(path)
    print(f"  {name}.png ({w}x{h})")


def line_width(S, frac=0.09):
    return max(2, int(S * frac))


# ------------------------------------------------------------ steel boot
def boot(color, detail_color, w=36, h=32, name="boot"):
    """Same silhouette/canvas as apache-watchface's boot (side profile,
    toe right, ankle shaft on top) so the STEPS box layout math ports
    directly - only the surface detailing changes, from a laced
    hiking-boot tongue to horizontal sabaton (armored foot) plate seams
    plus a rivet at the ankle joint, reading as steel plate rather than
    leather/fabric."""
    img, d, W, H = canvas(w, h)

    def sy(frac):
        return (0.25 + frac * 0.75) * H

    outline = [
        (0.12, 0.32), (0.13, 0.20), (0.20, 0.10), (0.40, 0.06),
        (0.44, 0.14), (0.50, 0.16), (0.55, 0.24), (0.62, 0.28),
        (0.80, 0.30), (0.90, 0.38), (0.94, 0.52), (0.92, 0.66),
        (0.86, 0.76), (0.70, 0.82), (0.40, 0.84), (0.16, 0.83),
        (0.09, 0.76), (0.08, 0.62), (0.10, 0.45),
    ]
    d.polygon([(x * W, sy(y)) for x, y in outline], fill=color)

    # ankle shaft (greave) - same block as before
    d.rectangle([0.09 * W, 0.0, 0.45 * W, sy(0.10)], fill=color)

    lw = max(1, int(W * 0.045))
    # shaft/collar seam
    d.line([(0.09 * W, sy(0.10)), (0.45 * W, sy(0.10))], fill=detail_color, width=lw)
    # ankle rivet, where the laces used to start - a plate-armor pivot pin
    d.ellipse(
        [0.40 * W - lw, sy(0.16) - lw, 0.40 * W + lw, sy(0.16) + lw],
        fill=detail_color,
    )
    # sabaton plate seams (lames) across the foot, replacing lace strokes
    for i in range(3):
        yy = sy(0.24 + i * 0.10)
        d.line([(0.42 * W, yy), (0.86 * W, yy)], fill=detail_color, width=lw)
    # toe cap seam
    d.line([(0.62 * W, sy(0.29)), (0.80 * W, sy(0.34))], fill=detail_color, width=lw)
    # sole separation
    d.line([(0.09 * W, sy(0.72)), (0.90 * W, sy(0.72))], fill=detail_color, width=lw)
    # a single diagonal highlight streak - the "polished steel" cue
    d.line([(0.20 * W, sy(0.18)), (0.30 * W, sy(0.40))], fill=(255, 255, 255, 130), width=max(1, lw // 2))

    finish(img, w, h, name)


# ---------------------------------------------- mana potion (on its side)
def potion(glass_color, detail_color, w=34, h=18, name="potion"):
    """Corked flask lying on its side: rounded bulb body (right) + thin
    neck + round cork (left), all three segments deliberately OVERLAPPING
    (no gaps) so they read as one continuous flask instead of a circle
    with a separate bar hanging off it (a real first-draft failure mode -
    see the class-level note in this file's history/CHANGELOG). Canvas
    matches apache-watchface's BATTERY_W/H (34x18) so the Battery box's
    layout constants port directly. The bulb is outline-only (like the
    old battery chrome was outline+nub-only) so Monkey C can draw a
    proportional mana fill rectangle inside it at runtime, same technique
    as HudDraw.drawBatteryFill - just re-targeted at this bulb's inner
    bounds instead of a plain rounded rect."""
    img, d, W, H = canvas(w, h)
    lw = max(2, int(W * 0.05))

    cy = H * 0.52
    cork_w = W * 0.15
    neck_h = H * 0.30
    bulb_cx = W * 0.62
    bulb_rx = W * 0.30
    bulb_ry = H * 0.44

    # bulb OUTLINE drawn first (fill is added dynamically in Monkey C)
    d.ellipse(
        [bulb_cx - bulb_rx, cy - bulb_ry, bulb_cx + bulb_rx, cy + bulb_ry],
        outline=glass_color, width=lw,
    )
    # neck: a thin glass tube, deliberately overlapping well INTO the bulb
    # on the right (past its nominal left edge) and into the cork on the
    # left, so there's no visible seam/gap at either join.
    neck_x0 = cork_w * 0.55
    neck_x1 = bulb_cx - bulb_rx * 0.35
    d.rectangle([neck_x0, cy - neck_h / 2, neck_x1, cy + neck_h / 2], outline=glass_color, width=lw)
    # cork: filled rounded cap, overlapping the neck's left end
    d.rounded_rectangle(
        [lw * 0.5, cy - neck_h * 0.62, cork_w, cy + neck_h * 0.62],
        radius=neck_h * 0.3, fill=detail_color,
    )
    # re-stroke the bulb outline on top so the neck's overlap into it gets
    # visually capped by a clean circular edge rather than a squared notch
    d.ellipse(
        [bulb_cx - bulb_rx, cy - bulb_ry, bulb_cx + bulb_rx, cy + bulb_ry],
        outline=glass_color, width=lw,
    )
    # a small glass highlight arc (top-left of the bulb) - reads as glass, not stone
    d.arc(
        [bulb_cx - bulb_rx * 0.85, cy - bulb_ry * 0.75, bulb_cx - bulb_rx * 0.1, cy + bulb_ry * 0.05],
        200, 320, fill=(255, 255, 255, 120), width=max(1, lw // 2),
    )

    finish(img, w, h, name)


# ------------------------------------------------------------------ heart
def heart(color, size=28, name="heart", dagger_color=None):
    """Unchanged silhouette from apache-watchface (client asked to keep
    heart) - only the palette call-sites differ (still red by default,
    steel dagger recolored to match the new STONE palette instead of the
    old tactical-green detail shade)."""
    img, d, W, H = canvas(size, size)
    cx, cy = W / 2, H * 0.40
    r = W * 0.27
    d.ellipse([cx - 2 * r + r * 0.1, cy - r, cx - r * 0.1, cy + r], fill=color)
    d.ellipse([cx + r * 0.1, cy - r, cx + 2 * r - r * 0.1, cy + r], fill=color)
    tip_y = H * 0.92
    d.polygon(
        [(cx - 1.85 * r, cy + r * 0.35), (cx + 1.85 * r, cy + r * 0.35), (cx, tip_y)],
        fill=color,
    )

    if dagger_color is not None:
        cutout_y = cy - r * 0.72
        pommel_r = r * 0.13
        pommel_cy = cutout_y - r * 0.28
        d.ellipse(
            [cx - pommel_r, pommel_cy - pommel_r, cx + pommel_r, pommel_cy + pommel_r],
            fill=dagger_color,
        )
        d.rectangle(
            [cx - r * 0.05, pommel_cy, cx + r * 0.05, cutout_y - r * 0.06],
            fill=dagger_color,
        )
        guard_w = r * 0.5
        guard_h = r * 0.11
        d.rectangle(
            [cx - guard_w, cutout_y - guard_h / 2, cx + guard_w, cutout_y + guard_h / 2],
            fill=dagger_color,
        )
        blade_tip_y = tip_y + r * 0.12
        blade_w = r * 0.15
        d.polygon(
            [(cx - blade_w, cutout_y), (cx + blade_w, cutout_y), (cx, blade_tip_y)],
            fill=dagger_color,
        )

    finish(img, size, size, name)


# --------------------------------------------------------- solar rise/set
def solar_event(color, rising, size=28, name="solar"):
    """Unchanged from apache-watchface - half-sun on a horizon line."""
    img, d, W, H = canvas(size, size)
    horizon_y = H * 0.56
    lw = line_width(W)
    r = W * 0.30
    cx = W / 2.0
    bbox = [cx - r, horizon_y - r, cx + r, horizon_y + r]
    if rising:
        d.pieslice(bbox, 180, 360, fill=color)
    else:
        d.pieslice(bbox, 0, 180, fill=color)
    d.line([W * 0.10, horizon_y, W * 0.90, horizon_y], fill=color, width=lw)
    finish(img, size, size, name)


# -------------------------------------------------------------- clouds/wx
def _cloud(d, cx, cy, w, color, filled=True):
    r = w * 0.24
    pts = [(-0.30, 0.00, 1.00), (-0.02, -0.16, 1.18), (0.30, 0.02, 0.92)]
    for dx, dy, rf in pts:
        rr = r * rf
        d.ellipse([cx + w * dx - rr, cy + w * dy - rr, cx + w * dx + rr, cy + w * dy + rr], fill=color)
    d.rectangle([cx - w * 0.30, cy, cx + w * 0.30, cy + r * 0.9], fill=color)


def wx_clear(color, size=32, name="wx_clear"):
    img, d, W, H = canvas(size, size)
    cx, cy, r = W / 2, H / 2, W * 0.24
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    lw = line_width(W, 0.07)
    for i in range(8):
        a = i * math.pi / 4.0
        x0, y0 = cx + r * 1.35 * math.cos(a), cy + r * 1.35 * math.sin(a)
        x1, y1 = cx + r * 1.85 * math.cos(a), cy + r * 1.85 * math.sin(a)
        d.line([x0, y0, x1, y1], fill=color, width=lw)
    finish(img, size, size, name)


def wx_cloudy(color, size=32, name="wx_cloudy"):
    img, d, W, H = canvas(size, size)
    sun_r = W * 0.20
    sun_cx, sun_cy = W * 0.32, H * 0.30
    d.ellipse([sun_cx - sun_r, sun_cy - sun_r, sun_cx + sun_r, sun_cy + sun_r], fill=color)
    for i in range(8):
        a = i * math.pi / 4.0
        x0, y0 = sun_cx + sun_r * 1.25 * math.cos(a), sun_cy + sun_r * 1.25 * math.sin(a)
        x1, y1 = sun_cx + sun_r * 1.7 * math.cos(a), sun_cy + sun_r * 1.7 * math.sin(a)
        d.line([x0, y0, x1, y1], fill=color, width=line_width(W, 0.05))
    _cloud(d, W * 0.58, H * 0.68, W * 0.58, color)
    finish(img, size, size, name)


def wx_overcast(color, size=32, name="wx_overcast"):
    img, d, W, H = canvas(size, size)
    _cloud(d, W * 0.50, H * 0.54, W * 0.78, color)
    finish(img, size, size, name)


def wx_rain(color, size=32, name="wx_rain"):
    img, d, W, H = canvas(size, size)
    _cloud(d, W * 0.50, H * 0.42, W * 0.78, color)
    lw = line_width(W, 0.09)
    for i in range(3):
        x = W * (0.30 + i * 0.22)
        d.line([x, H * 0.68, x - W * 0.08, H * 0.90], fill=color, width=lw)
    finish(img, size, size, name)


def wx_snow(color, size=32, name="wx_snow"):
    img, d, W, H = canvas(size, size)
    _cloud(d, W * 0.50, H * 0.42, W * 0.78, color)
    r = W * 0.045
    for i in range(3):
        x = W * (0.30 + i * 0.22)
        y = H * 0.80
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)
    finish(img, size, size, name)


def wx_storm(color, size=32, name="wx_storm"):
    img, d, W, H = canvas(size, size)
    _cloud(d, W * 0.50, H * 0.38, W * 0.78, color)
    bx, by = W * 0.52, H * 0.60
    bw, bh = W * 0.16, H * 0.34
    d.polygon(
        [(bx + bw * 0.5, by), (bx - bw * 0.5, by + bh * 0.55), (bx + bw * 0.1, by + bh * 0.55),
         (bx - bw * 0.3, by + bh), (bx + bw * 0.6, by + bh * 0.40), (bx + bw * 0.05, by + bh * 0.40)],
        fill=color,
    )
    finish(img, size, size, name)


# --------------------------------------------------------- bluetooth icon
def bluetooth(color, size=22, name="bluetooth"):
    img, d, W, H = canvas(size, size)
    lw = line_width(W, 0.11)
    cx = W * 0.42
    top, bottom = H * 0.14, H * 0.86
    qh = (bottom - top) / 4.0
    d.line([cx, top, cx, bottom], fill=color, width=lw)
    d.line(
        [(cx, top), (cx + W * 0.30, top + qh), (cx - W * 0.30, top + 3 * qh), (cx, bottom)],
        fill=color, width=lw, joint="curve",
    )
    finish(img, size, size, name)


# ------------------------------------------------------------- bell icon
def bell(color, size=24, name="bell"):
    img, d, W, H = canvas(size, size)
    lw = line_width(W, 0.09)
    cx, top = W / 2, H * 0.16
    r = W * 0.30
    d.arc([cx - r, top, cx + r, top + 2 * r * 1.1], 180, 360, fill=color, width=lw)
    d.line([cx - r, top + r * 1.1, cx - r * 1.15, H * 0.68], fill=color, width=lw)
    d.line([cx + r, top + r * 1.1, cx + r * 1.15, H * 0.68], fill=color, width=lw)
    d.line([cx - r * 1.2, H * 0.68, cx + r * 1.2, H * 0.68], fill=color, width=lw)
    clapper_r = W * 0.07
    d.ellipse([cx - clapper_r, H * 0.78, cx + clapper_r, H * 0.78 + clapper_r * 2], fill=color)
    finish(img, size, size, name)


# ---------------------------------------------------------- castle walls
# Replaces apache-watchface's plain HudDraw divider lines. Two small
# repeating tiles (one horizontal, one vertical) meant to be drawn several
# times in a row by Monkey C to span whatever length a given divider needs
# - cheaper in memory than one bespoke bitmap per divider length, and reads
# as a proper crenellated wall instead of a straight rule line.
def wall_h(color, detail_color, w=14, h=8, name="wall_h"):
    """One repeat unit of a horizontal battlement: a stone course with a
    single merlon (the raised "tooth") centered in the tile, so tiling
    several of these edge-to-edge reads as a continuous crenellated wall
    top rather than a single always-the-same merlon repeating obviously -
    good enough at watch-face viewing distance/size."""
    img, d, W, H = canvas(w, h)
    # base stone course
    d.rectangle([0, H * 0.55, W, H * 0.85], fill=color)
    # merlon (the raised tooth)
    merlon_w = W * 0.5
    d.rectangle([(W - merlon_w) / 2, H * 0.15, (W + merlon_w) / 2, H * 0.55], fill=color)
    # mortar line
    d.line([0, H * 0.85, W, H * 0.85], fill=detail_color, width=max(1, int(H * 0.06)))
    finish(img, w, h, name)


def wall_v(color, detail_color, w=8, h=14, name="wall_v"):
    """Vertical counterpart - a stacked stone-block strip for the
    vertical dividers (Battery|HR, Steps|Solar, Date|Tz2)."""
    img, d, W, H = canvas(w, h)
    d.rectangle([W * 0.30, 0, W * 0.70, H], fill=color)
    # block seams
    for i in range(3):
        yy = H * (0.28 + i * 0.28)
        d.line([W * 0.20, yy, W * 0.80, yy], fill=detail_color, width=max(1, int(W * 0.10)))
    finish(img, w, h, name)


# --------------------------------------------------------------- launcher
def launcher_icon(color, size=40, name="launcher_icon"):
    """A simple rune-stone glyph: a rounded stone tablet with a glowing
    rune mark - replaces apache-watchface's HUD-reticle launcher icon,
    consistent with the new theme. Lives directly under resources/drawables/
    (NOT resources/drawables/hud/, unlike every other icon in this file) -
    matches apache-watchface's LauncherIcon convention, so it's written to
    its own path rather than through finish()/OUT_DIR."""
    img, d, W, H = canvas(size, size)
    lw = max(2, int(W * 0.05))
    d.rounded_rectangle([W * 0.18, H * 0.10, W * 0.82, H * 0.90], radius=W * 0.10, outline=color, width=lw)
    # a simple angular rune mark (like a stylized "eihwaz"/branch rune)
    d.line([W * 0.5, H * 0.24, W * 0.5, H * 0.76], fill=RUNE_DAY, width=lw)
    d.line([W * 0.5, H * 0.36, W * 0.68, H * 0.24], fill=RUNE_DAY, width=lw)
    d.line([W * 0.5, H * 0.50, W * 0.68, H * 0.62], fill=RUNE_DAY, width=lw)
    img = img.resize((size, size), Image.LANCZOS)
    path = OUT_DIR.parent / f"{name}.png"
    img.save(path)
    print(f"  {name}.png ({size}x{size}) -> {path}")


if __name__ == "__main__":
    print("Boot:")
    boot(STONE_DAY, STONE_DAY_DETAIL, name="boot_day")
    boot(STONE_AOD, STONE_AOD_DETAIL, name="boot_aod")

    print("Potion (battery):")
    potion(STONE_DAY, STONE_DAY_DETAIL, name="potion_glass_day")
    potion(STONE_AOD, STONE_AOD_DETAIL, name="potion_glass_aod")

    print("Heart:")
    heart(HEART_RED, name="heart_day", dagger_color=DAGGER_STEEL)
    heart(HEART_RED_AOD, name="heart_aod", dagger_color=STONE_AOD_DETAIL)

    print("Solar event:")
    solar_event(SOLAR_GOLD, True, name="solar_rise_day")
    solar_event(SOLAR_AMBER, False, name="solar_set_day")
    solar_event(STONE_AOD, True, name="solar_rise_aod")
    solar_event(STONE_AOD, False, name="solar_set_aod")

    print("Weather:")
    wx_clear(STONE_DAY, name="wx_clear_day")
    wx_cloudy(STONE_DAY, name="wx_cloudy_day")
    wx_overcast(STONE_DAY, name="wx_overcast_day")
    wx_rain(RUNE_DAY, name="wx_rain_day")
    wx_snow(RUNE_DAY, name="wx_snow_day")
    wx_storm(STONE_DAY_DETAIL, name="wx_storm_day")
    wx_clear(STONE_AOD, name="wx_clear_aod")
    wx_overcast(STONE_AOD, name="wx_overcast_aod")

    print("Status icons:")
    bluetooth(STONE_DAY, name="bluetooth_day")
    bluetooth(STONE_AOD, name="bluetooth_aod")
    bell(STONE_DAY, name="bell_day")
    bell(STONE_AOD, name="bell_aod")

    print("Castle walls:")
    wall_h(STONE_DAY, STONE_DAY_DETAIL, name="wall_h_day")
    wall_h(STONE_AOD, STONE_AOD_DETAIL, name="wall_h_aod")
    wall_v(STONE_DAY, STONE_DAY_DETAIL, name="wall_v_day")
    wall_v(STONE_AOD, STONE_AOD_DETAIL, name="wall_v_aod")

    print("Launcher:")
    launcher_icon(STONE_DAY)
