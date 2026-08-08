"""Generates the phosphor-green tacticool HUD icon set for the watch face.

Monkey C's live vector drawing (Dc.fillPolygon/fillCircle) has no
anti-aliasing on real MIP displays, which is why hand-drawn icons read as
crude/blobby at small sizes. These are pre-rendered instead: drawn at 4x
scale with Pillow's anti-aliasing, then downsampled - the standard
"design big, ship small" icon technique - and loaded as bitmap resources.

Day-mode and Always-On-mode variants are baked separately (different
brightness/hue) since Monkey C has no runtime bitmap tint API.

Usage: python tools/generate_hud_icons.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path(__file__).resolve().parent.parent / "resources" / "drawables" / "hud"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SCALE = 4  # supersampling factor for anti-aliasing

# V2 spec: single-hue "Tactical Green" (#39FF14 neon green) monochrome
# scheme for EVERY field in day mode - the old AMBER (solar) / RED (heart)
# per-field accent colors are gone. The watch face's only color override
# left anywhere is the battery-critical alert, which is applied at
# draw-time in Monkey C (ColorScheme.batteryColor), not baked into a
# bitmap - so it's not part of this generator at all.
DAY_GREEN = (57, 255, 20, 255)
AOD_GREEN = (95, 168, 85, 255)
DAY_GREEN_DETAIL = (30, 130, 12, 255)   # darker green for boot stitch/tread lines
AOD_GREEN_DETAIL = (48, 84, 44, 255)
TRANSPARENT = (0, 0, 0, 0)

# V4 "color variant": selective per-field accents reintroduced on top of
# the V2 monochrome base - heart goes red (with a steel-gray dagger for
# contrast), solar goes yellow (rise) / orange (set). Always-On stays
# monochrome green in both cases (color is decoration; AOD only dims,
# per the project's established rule) - only DAY variants use these.
HEART_RED = (224, 32, 32, 255)
DAGGER_STEEL = (198, 202, 206, 255)
SOLAR_YELLOW = (255, 214, 51, 255)
SOLAR_ORANGE = (255, 140, 26, 255)


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


# ---------------------------------------------------------------- battery
def battery_chrome(color, w=34, h=18, name="battery_chrome"):
    img, d, W, H = canvas(w, h)
    lw = line_width(W, 0.05)
    nub = int(W * 0.10)
    body = [lw, lw, W - nub - lw, H - lw]
    d.rounded_rectangle(body, radius=int(H * 0.12), outline=color, width=lw)
    nub_h = int((H - lw * 2) * 0.5)
    d.rounded_rectangle(
        [W - nub - lw // 2, H / 2 - nub_h / 2, W - lw // 2, H / 2 + nub_h / 2],
        radius=int(nub * 0.3), fill=color,
    )
    finish(img, w, h, name)


# ------------------------------------------------------------------ heart
def heart(color, size=28, name="heart", dagger_color=None):
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
        # V4: dagger dead-center through the heart, hilt at the top
        # cutout (the notch between the two lobes), blade running down
        # through the tip.
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


# ------------------------------------------------------------------ boot
def boot(color, detail_color, w=36, h=32, name="boot"):
    """Side-profile combat/hiking boot silhouette (toe pointing right),
    matching the client-supplied reference: angled ankle collar, laced
    tongue, rounded toe cap, thick lugged sole, plus a small ankle shaft
    on top (client: "give it like a little top to the boot, like a
    10x10 little box"). Wider-than-tall canvas - a boot lying on its
    side isn't square. Canvas grew 36x24 -> 36x32 to make room for the
    shaft; the original boot silhouette is compressed into the bottom
    75% (scale+offset below) rather than shrunk, so it reads the same
    size as before with the shaft added above it, not squeezed smaller."""
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

    # ankle shaft - a simple block sitting on top of the collar, slightly
    # overlapping it for a seamless join
    # V3: client wants it "a little more chunky" - widened 1px on each
    # side (0.12/0.42 -> 0.09/0.45, ~1px each at W=36).
    d.rectangle([0.09 * W, 0.0, 0.45 * W, sy(0.10)], fill=color)

    lw = max(1, int(W * 0.045))
    # shaft/collar seam
    d.line([(0.09 * W, sy(0.10)), (0.45 * W, sy(0.10))], fill=detail_color, width=lw)
    # collar opening line
    d.line([(0.13 * W, sy(0.20)), (0.40 * W, sy(0.14))], fill=detail_color, width=lw)
    # lace strokes
    for i in range(3):
        yy = sy(0.20 + i * 0.06)
        d.line([(0.44 * W, yy), (0.58 * W, yy + H * 0.02)], fill=detail_color, width=lw)
    # vamp seam down to toe
    d.line([(0.62 * W, sy(0.29)), (0.80 * W, sy(0.34))], fill=detail_color, width=lw)
    # sole separation
    d.line([(0.09 * W, sy(0.72)), (0.90 * W, sy(0.72))], fill=detail_color, width=lw)
    # tread notches
    for i in range(5):
        xx = (0.16 + i * 0.15) * W
        d.line([(xx, sy(0.78)), (xx, sy(0.83))], fill=detail_color, width=lw)

    finish(img, w, h, name)


# --------------------------------------------------------- solar rise/set
def solar_event(color, rising, size=28, name="solar"):
    """Half-sun sitting on a horizon line: dome above the line for sunrise,
    dome below the line for sunset - simpler and more literal than the
    previous full-circle-plus-arrow design."""
    img, d, W, H = canvas(size, size)
    horizon_y = H * 0.56
    lw = line_width(W)
    r = W * 0.30
    cx = W / 2.0
    bbox = [cx - r, horizon_y - r, cx + r, horizon_y + r]
    if rising:
        d.pieslice(bbox, 180, 360, fill=color)  # dome above the horizon
    else:
        d.pieslice(bbox, 0, 180, fill=color)  # dome below the horizon
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
    """Partly cloudy: sun peeking from behind a smaller, lower cloud - the
    sun must clearly protrude above/left of the cloud silhouette or the two
    same-color shapes merge into one blob at small sizes (that was the
    first version's bug)."""
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


# V6: the AH-64E banner bitmap (ah64e_banner(), and the _feather/
# _feather_wing helpers that drew its wing artwork) is gone - the client
# watch face now renders the airframe name as live vector text from a
# user-editable string property (source/Fonts.headerFont(), see
# ApacheWatchFaceView.drawTitleBanner()) instead of a baked bitmap with the
# literal "AH-64E" text drawn into it, since a static bitmap can't reflect
# an editable string. See CHANGELOG.md's V6 entry for the full reasoning.

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
    """Notification/message chrome - the unread-count badge is drawn
    dynamically in Monkey C on top, since it's a live number."""
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


if __name__ == "__main__":
    print("Battery:")
    battery_chrome(DAY_GREEN, name="battery_chrome_day")
    battery_chrome(AOD_GREEN, name="battery_chrome_aod")

    print("Heart:")
    # V4 color variant: heart goes red with a steel dagger through it in
    # day mode; Always-On stays monochrome green (dagger shape kept for
    # consistency, but in the dim detail green rather than steel, since
    # AOD has no accent hues at all).
    heart(HEART_RED, name="heart_day", dagger_color=DAGGER_STEEL)
    heart(AOD_GREEN, name="heart_aod", dagger_color=AOD_GREEN_DETAIL)

    print("Boot:")
    boot(DAY_GREEN, DAY_GREEN_DETAIL, name="boot_day")
    boot(AOD_GREEN, AOD_GREEN_DETAIL, name="boot_aod")

    print("Solar event:")
    # V4 color variant: yellow sunrise, orange sunset in day mode.
    # Always-On stays monochrome green (same reasoning as the heart above).
    solar_event(SOLAR_YELLOW, True, name="solar_rise_day")
    solar_event(SOLAR_ORANGE, False, name="solar_set_day")
    solar_event(AOD_GREEN, True, name="solar_rise_aod")
    solar_event(AOD_GREEN, False, name="solar_set_aod")

    print("Weather:")
    wx_clear(DAY_GREEN, name="wx_clear_day")
    wx_cloudy(DAY_GREEN, name="wx_cloudy_day")
    wx_overcast(DAY_GREEN, name="wx_overcast_day")
    wx_rain(DAY_GREEN, name="wx_rain_day")
    wx_snow(DAY_GREEN, name="wx_snow_day")
    wx_storm(DAY_GREEN, name="wx_storm_day")
    wx_clear(AOD_GREEN, name="wx_clear_aod")
    wx_overcast(AOD_GREEN, name="wx_overcast_aod")

    print("Status icons:")
    bluetooth(DAY_GREEN, name="bluetooth_day")
    bluetooth(AOD_GREEN, name="bluetooth_aod")
    bell(DAY_GREEN, name="bell_day")
    bell(AOD_GREEN, name="bell_aod")

    print("Done.")
