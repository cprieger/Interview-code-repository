"""Generates resources/drawables/launcher_icon.png — a simple HUD reticle glyph.

Placeholder art for local sideloading. Replace with real artwork (and re-run
or hand-author a PNG at whatever size the Connect IQ compiler requests) before
submitting to the Connect IQ Store, since Garmin also reviews launcher icons
for brand/trademark compliance.

Usage: python tools/generate_launcher_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 40
CYAN = (0, 229, 255, 255)
BLACK = (0, 0, 0, 0)

img = Image.new("RGBA", (SIZE, SIZE), BLACK)
draw = ImageDraw.Draw(img)

cx = cy = SIZE / 2
r_outer = SIZE * 0.42
r_inner = SIZE * 0.10
tick = SIZE * 0.14
width = max(2, SIZE // 20)

# Outer reticle ring
draw.ellipse(
    [cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer],
    outline=CYAN,
    width=width,
)

# Center dot
draw.ellipse(
    [cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner],
    fill=CYAN,
)

# Crosshair ticks (N/E/S/W), gapped at the ring
for dx, dy in [(0, -1), (0, 1), (-1, 0), (1, 0)]:
    x0 = cx + dx * r_outer
    y0 = cy + dy * r_outer
    x1 = cx + dx * (r_outer + tick)
    y1 = cy + dy * (r_outer + tick)
    draw.line([x0, y0, x1, y1], fill=CYAN, width=width)

out_path = Path(__file__).resolve().parent.parent / "resources" / "drawables" / "launcher_icon.png"
out_path.parent.mkdir(parents=True, exist_ok=True)
img.save(out_path)
print(f"Wrote {out_path} ({SIZE}x{SIZE})")
