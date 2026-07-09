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

DAY_GREEN = (140, 255, 110, 255)
AOD_GREEN = (95, 168, 85, 255)
AMBER = (242, 211, 60, 255)
RED = (224, 90, 78, 255)
DAY_GREEN_DETAIL = (46, 110, 40, 255)   # darker green for boot stitch/tread lines
AOD_GREEN_DETAIL = (48, 84, 44, 255)
TRANSPARENT = (0, 0, 0, 0)


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
def heart(color, size=28, name="heart"):
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
    finish(img, size, size, name)


# ------------------------------------------------------------------ boot
def boot(color, detail_color, w=36, h=24, name="boot"):
    """Side-profile combat/hiking boot silhouette (toe pointing right),
    matching the client-supplied reference: angled ankle collar, laced
    tongue, rounded toe cap, thick lugged sole. Wider-than-tall canvas -
    a boot lying on its side isn't square. Replaces the earlier abstract
    two-footprint version, which the client wanted swapped for this."""
    img, d, W, H = canvas(w, h)

    outline = [
        (0.12, 0.32), (0.13, 0.20), (0.20, 0.10), (0.40, 0.06),
        (0.44, 0.14), (0.50, 0.16), (0.55, 0.24), (0.62, 0.28),
        (0.80, 0.30), (0.90, 0.38), (0.94, 0.52), (0.92, 0.66),
        (0.86, 0.76), (0.70, 0.82), (0.40, 0.84), (0.16, 0.83),
        (0.09, 0.76), (0.08, 0.62), (0.10, 0.45),
    ]
    d.polygon([(x * W, y * H) for x, y in outline], fill=color)

    lw = max(1, int(W * 0.045))
    # collar opening line
    d.line([(0.13 * W, 0.20 * H), (0.40 * W, 0.14 * H)], fill=detail_color, width=lw)
    # lace strokes
    for i in range(3):
        yy = (0.20 + i * 0.06) * H
        d.line([(0.44 * W, yy), (0.58 * W, yy + H * 0.03)], fill=detail_color, width=lw)
    # vamp seam down to toe
    d.line([(0.62 * W, 0.29 * H), (0.80 * W, 0.34 * H)], fill=detail_color, width=lw)
    # sole separation
    d.line([(0.09 * W, 0.72 * H), (0.90 * W, 0.72 * H)], fill=detail_color, width=lw)
    # tread notches
    for i in range(5):
        xx = (0.16 + i * 0.15) * W
        d.line([(xx, 0.78 * H), (xx, 0.83 * H)], fill=detail_color, width=lw)

    finish(img, w, h, name)


# --------------------------------------------------------- solar rise/set
def solar_event(color, rising, size=28, name="solar"):
    img, d, W, H = canvas(size, size)
    horizon_y = H * 0.62
    lw = line_width(W)
    sun_r = W * 0.19
    d.ellipse([W / 2 - sun_r, horizon_y - sun_r, W / 2 + sun_r, horizon_y + sun_r], fill=color)
    d.rectangle([W * 0.30, horizon_y - sun_r, W * 0.70, horizon_y + sun_r], fill=TRANSPARENT)
    d.line([W * 0.14, horizon_y, W * 0.86, horizon_y], fill=color, width=lw)
    ax = W * 0.82
    ah = H * 0.16
    if rising:
        d.polygon([(ax, H * 0.12), (ax - ah * 0.6, H * 0.12 + ah), (ax + ah * 0.6, H * 0.12 + ah)], fill=color)
    else:
        d.polygon([(ax, H * 0.30), (ax - ah * 0.6, H * 0.30 - ah), (ax + ah * 0.6, H * 0.30 - ah)], fill=color)
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


def _feather(d, base, angle, length, width, sign, fill, outline, outline_w):
    """One tapered feather lobe (rounded base, pointed tip), with a black
    outline drawn as a slightly-enlarged silhouette underneath - the
    "draw twice" outline trick, since Pillow's polygon() doesn't support
    a stroke width."""
    dx, dy = sign * math.cos(angle) * length, math.sin(angle) * length
    px, py = -dy, dx
    norm = math.hypot(px, py) or 1
    px, py = px / norm, py / norm
    tip = (base[0] + dx, base[1] + dy)
    bulge_t = 0.32
    bulge = (base[0] + dx * bulge_t, base[1] + dy * bulge_t)
    b1 = (bulge[0] + px * width / 2, bulge[1] + py * width / 2)
    b2 = (bulge[0] - px * width / 2, bulge[1] - py * width / 2)
    r1 = (base[0] + px * width * 0.18, base[1] + py * width * 0.18)
    r2 = (base[0] - px * width * 0.18, base[1] - py * width * 0.18)
    pts = [r1, b1, tip, b2, r2]

    if outline_w > 0:
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        big = []
        for x, y in pts:
            vx, vy = x - cx, y - cy
            n = math.hypot(vx, vy) or 1
            big.append((x + vx / n * outline_w, y + vy / n * outline_w))
        d.polygon(big, fill=outline)
    d.polygon(pts, fill=fill)


def _feather_wing(d, root, span_len, span_h, color, outline_color, mirror):
    """US Army Aviator-wings style: several overlapping tapered feather
    lobes fanning from near-horizontal (root) to steep upward (tip), each
    with a black outline - the layered, outlined look of the actual
    insignia, not a smooth bird-wing curve or plain geometric bars (both
    tried already this session and rejected)."""
    rx, ry = root
    sign = -1 if mirror else 1
    n_feathers = 7
    outline_w = span_h * 0.055
    for i in range(n_feathers):
        t = i / (n_feathers - 1)  # 0 = root-adjacent (bottom), 1 = tip (top)
        angle = -0.05 - t * 1.10
        length = span_len * (0.55 + t * 0.55)
        width = span_h * (0.34 - t * 0.12)
        base_y_off = span_h * 0.42 - t * span_h * 0.80
        base = (rx, ry + base_y_off)
        _feather(d, base, angle, length, width, sign, color, outline_color, outline_w)


# ----------------------------------------------------------------- banner
def ah64e_banner(w=220, h=52, name="ah64e_banner"):
    img, d, W, H = canvas(w, h)
    font_path = "C:/Windows/Fonts/impact.ttf"
    text = "AH-64E"

    text_budget = W * 0.56
    pt = int(H * 0.58)
    font = ImageFont.truetype(font_path, pt)
    bbox = d.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    if tw > text_budget:
        pt = max(8, int(pt * (text_budget / tw)))
        font = ImageFont.truetype(font_path, pt)
        bbox = d.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]

    cx, cy = W / 2, H / 2
    d.text((cx, cy), text, font=font, fill=DAY_GREEN, anchor="mm")

    wing_root_y = cy + H * 0.02
    span_len = W * 0.22
    span_h = H * 0.62
    black = (10, 15, 10, 255)
    _feather_wing(d, (cx - tw / 2 - W * 0.02, wing_root_y), span_len, span_h, DAY_GREEN, black, mirror=True)
    _feather_wing(d, (cx + tw / 2 + W * 0.02, wing_root_y), span_len, span_h, DAY_GREEN, black, mirror=False)
    finish(img, w, h, name)


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
    heart(RED, name="heart_day")
    heart(AOD_GREEN, name="heart_aod")

    print("Boot:")
    boot(DAY_GREEN, DAY_GREEN_DETAIL, name="boot_day")
    boot(AOD_GREEN, AOD_GREEN_DETAIL, name="boot_aod")

    print("Solar event:")
    solar_event(AMBER, True, name="solar_rise_day")
    solar_event(AMBER, False, name="solar_set_day")
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

    print("Banner:")
    ah64e_banner()

    print("Status icons:")
    bluetooth(DAY_GREEN, name="bluetooth_day")
    bluetooth(AOD_GREEN, name="bluetooth_aod")
    bell(DAY_GREEN, name="bell_day")
    bell(AOD_GREEN, name="bell_aod")

    print("Done.")
